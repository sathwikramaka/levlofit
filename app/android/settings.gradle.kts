pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("com.android.library") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

include(":app")

// Health Connect steps (owner approval needed to ship): only builds made with -Plevlofit.healthConnect=true (or
// LEVLOFIT_HEALTH_CONNECT=true) include the module that declares READ_STEPS. Every other build asks for nothing.
if (providers.gradleProperty("levlofit.healthConnect").orNull == "true" || System.getenv("LEVLOFIT_HEALTH_CONNECT") == "true") {
    include(":healthconnect")
}
