package com.levlofit.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

// In-app update (2026-11-03): the dashboard's Update button (lib/update_check.dart) asks this to download the APK named
// in /version.json, check its SHA-256 against the same file, and hand it to Android's installer. Android itself refuses
// an APK that is not signed with the installed app's key, so a wrong file cannot replace Levlofit.
// Answers: "installing" (installer shown), "permission" (the "install unknown apps" setting was opened; tap Update again
// once allowed), or an error, after which the app opens the download in the browser instead.
object UpdateInstaller {
    const val CHANNEL = "levlofit/update"
    private const val MAX_BYTES = 100L * 1024 * 1024

    fun handle(activity: Activity, url: String, sha256: String, result: MethodChannel.Result) {
        if (!url.startsWith("https://") || !Regex("^[0-9a-f]{64}$").matches(sha256)) {
            return result.error("bad_request", "invalid url or checksum", null)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !activity.packageManager.canRequestPackageInstalls()) {
            activity.startActivity(
                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${activity.packageName}")),
            )
            return result.success("permission")
        }
        val main = Handler(Looper.getMainLooper())
        Thread {
            val answer = runCatching { download(activity, url, sha256) }
            main.post {
                answer.onSuccess { file ->
                    val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", file)
                    activity.startActivity(
                        Intent(Intent.ACTION_VIEW)
                            .setDataAndType(uri, "application/vnd.android.package-archive")
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION),
                    )
                    result.success("installing")
                }.onFailure { result.error("download_failed", it.message ?: "download failed", null) }
            }
        }.start()
    }

    private fun download(activity: Activity, url: String, sha256: String): File {
        val dir = File(activity.cacheDir, "updates").apply { mkdirs() }
        dir.listFiles()?.forEach { it.delete() } // one update file at a time
        val file = File(dir, "levlofit-update.apk")
        val digest = MessageDigest.getInstance("SHA-256")
        val conn = (URL(url).openConnection() as HttpURLConnection).apply { connectTimeout = 15000; readTimeout = 30000 }
        try {
            if (conn.responseCode != 200) error("HTTP ${conn.responseCode}")
            var total = 0L
            conn.inputStream.use { input ->
                file.outputStream().use { out ->
                    val buf = ByteArray(64 * 1024)
                    while (true) {
                        val n = input.read(buf)
                        if (n < 0) break
                        total += n
                        if (total > MAX_BYTES) error("file too large")
                        digest.update(buf, 0, n)
                        out.write(buf, 0, n)
                    }
                }
            }
        } finally {
            conn.disconnect()
        }
        val got = digest.digest().joinToString("") { "%02x".format(it) }
        if (got != sha256) {
            file.delete()
            error("checksum mismatch")
        }
        return file
    }
}
