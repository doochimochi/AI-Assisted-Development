import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    kotlin("kapt")
}

// Load API keys from local.properties (git-ignored)
val localProps = Properties().also { props ->
    rootProject.file("local.properties").takeIf { it.exists() }
        ?.inputStream()?.use(props::load)
}

android {
    namespace = "com.meetingassistant"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.meetingassistant"
        minSdk = 29          // Android 10+ for AudioPlaybackCapture (future) and modern APIs
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    buildFeatures {
        compose = true
        buildConfig = true  // enables BuildConfig generation
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            buildConfigField("String", "ANTHROPIC_API_KEY",
                "\"${localProps["ANTHROPIC_API_KEY"] ?: ""}\"")
            buildConfigField("String", "GOOGLE_SPEECH_API_KEY",
                "\"${localProps["GOOGLE_SPEECH_API_KEY"] ?: ""}\"")
        }
        debug {
            buildConfigField("String", "ANTHROPIC_API_KEY",
                "\"${localProps["ANTHROPIC_API_KEY"] ?: ""}\"")
            buildConfigField("String", "GOOGLE_SPEECH_API_KEY",
                "\"${localProps["GOOGLE_SPEECH_API_KEY"] ?: ""}\"")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation(libs.androidx.material.icons)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.room.runtime)
    implementation(libs.room.ktx)
    kapt(libs.room.compiler)
    implementation(libs.okhttp)
    implementation(libs.okhttp.sse)
    implementation(libs.moshi.kotlin)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.datastore.preferences)
    debugImplementation("androidx.compose.ui:ui-tooling")
}
