package com.levlofit.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The Health Connect bridge exists only in builds made with -Plevlofit.healthConnect=true; elsewhere the app's
        // step card reports "not available" and nothing is requested.
        runCatching { Class.forName("com.levlofit.app.HealthConnectPlugin").getDeclaredConstructor().newInstance() as FlutterPlugin }
            .onSuccess { flutterEngine.plugins.add(it) }
    }
}
