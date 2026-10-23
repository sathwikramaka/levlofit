package com.levlofit.app

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateGroupByPeriodRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.Period

/**
 * Health Connect bridge for app/lib/steps.dart (channel "levlofit/health_connect"). Compiled only into builds made
 * with -Plevlofit.healthConnect=true. Reads daily step totals only (one aggregate per local day), on request, never in
 * the background. Methods: availability, hasPermission, requestPermission, readDaily, openSettings,
 * consumeRationaleLaunch. On Android 14+ Health Connect permissions are ordinary runtime permissions
 * (Activity.requestPermissions); before that the Health Connect app's request screen is started for a result.
 */
class HealthConnectPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.ActivityResultListener,
    PluginRegistry.RequestPermissionsResultListener {
    private companion object {
        const val PROVIDER = "com.google.android.apps.healthdata"
        const val REQUEST_CODE = 4127
        val PERMISSIONS = setOf(HealthPermission.getReadPermission(StepsRecord::class))
        val RATIONALE_ACTIONS = setOf("androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE", "android.intent.action.VIEW_PERMISSION_USAGE")
    }

    private var channel: MethodChannel? = null
    private var binding: ActivityPluginBinding? = null
    private var pending: MethodChannel.Result? = null
    private var rationaleLaunch = false
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val main = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(b.binaryMessenger, "levlofit/health_connect").also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        answerPending(false)
        channel?.setMethodCallHandler(null)
        channel = null
        scope.cancel()
    }

    private var seenIntent: Intent? = null // the launch intent already reported, so a reattach does not re-arm it

    private val newIntent = PluginRegistry.NewIntentListener { intent ->
        // App already running (launchMode singleTop): Health Connect's request arrives here, not as a launch intent.
        if (intent.action in RATIONALE_ACTIONS) {
            channel?.invokeMethod("showRationale", null)
            true
        } else {
            false
        }
    }

    override fun onAttachedToActivity(b: ActivityPluginBinding) {
        binding = b
        b.addActivityResultListener(this)
        b.addRequestPermissionsResultListener(this)
        b.addOnNewIntentListener(newIntent)
        val intent = b.activity.intent
        if (intent !== seenIntent) {
            seenIntent = intent
            rationaleLaunch = intent?.action in RATIONALE_ACTIONS
        }
    }

    override fun onDetachedFromActivity() {
        // A permission dialog cannot answer once the activity is gone: settle the Dart side instead of hanging.
        answerPending(false)
        binding?.removeActivityResultListener(this)
        binding?.removeRequestPermissionsResultListener(this)
        binding?.removeOnNewIntentListener(newIntent)
        binding = null
    }

    private fun answerPending(granted: Boolean) {
        val p = pending ?: return
        pending = null
        p.success(granted)
    }

    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) = onAttachedToActivity(b)
    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    private val activity: Activity? get() = binding?.activity

    private fun status(): Int = activity?.let { HealthConnectClient.getSdkStatus(it, PROVIDER) } ?: HealthConnectClient.SDK_UNAVAILABLE

    private fun client(): HealthConnectClient? =
        activity?.takeIf { status() == HealthConnectClient.SDK_AVAILABLE }?.let { HealthConnectClient.getOrCreate(it) }

    /** Runs [block] off the main thread and answers on it; any failure is reported, never swallowed. */
    private fun answer(result: MethodChannel.Result, block: suspend () -> Any?) {
        scope.launch {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("health_connect", e.javaClass.simpleName, null) }
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "availability" -> result.success(
                when (status()) {
                    HealthConnectClient.SDK_AVAILABLE -> "available"
                    HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "update_required"
                    else -> if (android.os.Build.VERSION.SDK_INT >= 34) "unsupported" else "not_installed"
                },
            )
            "hasPermission" -> {
                val c = client() ?: return result.success(false)
                answer(result) { c.permissionController.getGrantedPermissions().containsAll(PERMISSIONS) }
            }
            "requestPermission" -> {
                val a = activity
                // Unavailable or a request already open is an error for the app, not a refusal by the person.
                if (a == null || client() == null) return result.error("health_connect", "unavailable", null)
                if (pending != null) return result.error("health_connect", "busy", null)
                pending = result
                // The contract's intent on Android 14+ (androidx...REQUEST_PERMISSIONS) is only understood by an AndroidX
                // ComponentActivity; FlutterActivity cannot start it (ActivityNotFoundException on a phone, 2026-10-17).
                // A failed start must settle the call here, or the cancelled result would answer it a second time.
                try {
                    if (android.os.Build.VERSION.SDK_INT >= 34) {
                        a.requestPermissions(PERMISSIONS.toTypedArray(), REQUEST_CODE)
                    } else {
                        a.startActivityForResult(PermissionController.createRequestPermissionResultContract().createIntent(a, PERMISSIONS), REQUEST_CODE)
                    }
                } catch (e: Exception) {
                    pending = null
                    result.error("health_connect", e.javaClass.simpleName, null)
                }
            }
            "readDaily" -> {
                val c = client() ?: return result.error("health_connect", "unavailable", null)
                val first = LocalDate.parse(call.argument<String>("firstDay"))
                val days = (call.argument<Int>("days") ?: 7).coerceIn(1, 31)
                answer(result) {
                    val groups = c.aggregateGroupByPeriod(
                        AggregateGroupByPeriodRequest(
                            metrics = setOf(StepsRecord.COUNT_TOTAL),
                            timeRangeFilter = TimeRangeFilter.between(first.atStartOfDay(), first.plusDays(days.toLong()).atStartOfDay()),
                            timeRangeSlicer = Period.ofDays(1),
                        ),
                    )
                    // Days with no record are left out (the app shows them as no data, never as zero).
                    groups.mapNotNull { g -> g.result[StepsRecord.COUNT_TOTAL]?.let { g.startTime.toLocalDate().toString() to it.toInt() } }.toMap()
                }
            }
            "openSettings" -> {
                val a = activity ?: return result.success(null)
                val intent = if (status() == HealthConnectClient.SDK_AVAILABLE) {
                    Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS)
                } else {
                    Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$PROVIDER&url=healthconnect%3A%2F%2Fonboarding"))
                }
                runCatching { a.startActivity(intent) }
                result.success(null)
            }
            "consumeRationaleLaunch" -> {
                result.success(rationaleLaunch)
                rationaleLaunch = false
            }
            else -> result.notImplemented()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pending ?: return true
        pending = null
        val granted = PermissionController.createRequestPermissionResultContract().parseResult(resultCode, data)
        result.success(granted.containsAll(PERMISSIONS))
        return true
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pending ?: return true
        pending = null
        val granted = permissions.indices.filter { grantResults.getOrNull(it) == PackageManager.PERMISSION_GRANTED }.map { permissions[it] }
        result.success(granted.containsAll(PERMISSIONS))
        return true
    }
}
