// Manifest-only module: the Health Connect permission and the screens Health Connect links to. Included only in
// builds made with -Plevlofit.healthConnect=true (see settings.gradle.kts); the code lives in
// app/src/healthConnect/kotlin so it can use the Flutter embedding.
plugins {
    id("com.android.library")
}

android {
    namespace = "com.levlofit.healthconnect"
    compileSdk = 36
    defaultConfig {
        minSdk = 26 // Health Connect client minimum
        // MainActivity loads the bridge by name, which R8 cannot see: keep it in shrunk release builds.
        consumerProguardFiles("consumer-rules.pro")
    }
}
