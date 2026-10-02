plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

val panelUrl: String = (project.findProperty("panelUrl") as String?)
    ?.takeIf { it.isNotBlank() } ?: "https://mizanoraandroid.vercel.app"

android {
    namespace = "com.mizanora.android"
    compileSdk = 34
    defaultConfig {
        applicationId = "com.mizanora.android"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
        buildConfigField("String", "PANEL_URL", "\"$panelUrl\"")
    }
    buildFeatures { buildConfig = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}
