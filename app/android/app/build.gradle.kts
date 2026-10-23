import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing comes from the owner's machine only: environment variables first, then android/key.properties
// (git-ignored, see key.properties.example). Values are never printed. Without them a release build stops with a
// message instead of quietly signing with the debug key. For a local test build only, set
// LEVLOFIT_DEBUG_SIGNED_RELEASE=true (or -Plevlofit.debugSignedRelease=true) to sign a release with the debug key.
val keyProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.isFile) f.inputStream().use { load(it) }
}
fun signingValue(env: String, prop: String): String? =
    System.getenv(env)?.takeIf { it.isNotBlank() } ?: keyProperties.getProperty(prop)?.takeIf { it.isNotBlank() }
val releaseStoreFile = signingValue("LEVLOFIT_KEYSTORE_FILE", "storeFile")
val releaseStorePassword = signingValue("LEVLOFIT_KEYSTORE_PASSWORD", "storePassword")
val releaseKeyAlias = signingValue("LEVLOFIT_KEY_ALIAS", "keyAlias")
val releaseKeyPassword = signingValue("LEVLOFIT_KEY_PASSWORD", "keyPassword")
val missingSigning = listOf(
    "keystore file (LEVLOFIT_KEYSTORE_FILE / storeFile)" to releaseStoreFile,
    "keystore password (LEVLOFIT_KEYSTORE_PASSWORD / storePassword)" to releaseStorePassword,
    "key alias (LEVLOFIT_KEY_ALIAS / keyAlias)" to releaseKeyAlias,
    "key password (LEVLOFIT_KEY_PASSWORD / keyPassword)" to releaseKeyPassword,
).filter { it.second == null }.map { it.first }
val hasReleaseSigning = missingSigning.isEmpty()
val debugSignedRelease = System.getenv("LEVLOFIT_DEBUG_SIGNED_RELEASE") == "true" ||
    (findProperty("levlofit.debugSignedRelease") as String?) == "true"

// Health Connect steps: off unless the build asks for it (settings.gradle.kts includes :healthconnect then). On, it
// adds the READ_STEPS module, the Health Connect client and the Kotlin bridge, and raises minSdk to 26 (the client's
// minimum), so Android 7.x is not supported by such a build.
val healthConnect = rootProject.findProject(":healthconnect") != null

android {
    namespace = "com.levlofit.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications schedules with java.time; desugaring backports it to older Android.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.levlofit.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = if (healthConnect) maxOf(26, flutter.minSdkVersion) else flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStoreFile!!) // relative paths resolve from android/app; an absolute path is clearer
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    if (healthConnect) {
        sourceSets.getByName("main").java.srcDir("src/healthConnect/kotlin")
    }

    buildTypes {
        release {
            signingConfig = when {
                hasReleaseSigning -> signingConfigs.getByName("release")
                debugSignedRelease -> signingConfigs.getByName("debug") // local testing only, never for a store
                else -> null // the check below stops the build
            }
        }
    }
}

// Stop a release package before it is built unsigned or with the debug key by accident.
tasks.configureEach {
    if (name == "packageRelease" || name == "signReleaseBundle") {
        doFirst {
            if (!hasReleaseSigning && !debugSignedRelease) {
                throw GradleException(
                    "Release signing is not configured. Missing: ${missingSigning.joinToString("; ")}. " +
                        "Set the LEVLOFIT_* environment variables or create android/key.properties (see key.properties.example). " +
                        "For a local test build only: LEVLOFIT_DEBUG_SIGNED_RELEASE=true.",
                )
            }
            if (hasReleaseSigning && !file(releaseStoreFile!!).isFile) {
                throw GradleException("Release keystore not found at the configured LEVLOFIT_KEYSTORE_FILE / storeFile path.")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    if (healthConnect) {
        implementation(project(":healthconnect"))
        implementation("androidx.health.connect:connect-client:1.1.0") // Apache-2.0
    }
}
