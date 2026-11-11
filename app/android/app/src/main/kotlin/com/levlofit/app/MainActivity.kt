package com.levlofit.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The Health Connect bridge exists only in builds made with -Plevlofit.healthConnect=true; elsewhere the app's
        // step card reports "not available" and nothing is requested.
        runCatching { Class.forName("com.levlofit.app.HealthConnectPlugin").getDeclaredConstructor().newInstance() as FlutterPlugin }
            .onSuccess { flutterEngine.plugins.add(it) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UpdateInstaller.CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "install") return@setMethodCallHandler result.notImplemented()
            UpdateInstaller.handle(this, call.argument<String>("url") ?: "", call.argument<String>("sha256") ?: "", result)
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TodayWidget.CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "refresh") return@setMethodCallHandler result.notImplemented()
            TodayWidget.refresh(this)
            result.success(null)
        }
    }
}
