import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing comes from android/key.properties (git-ignored; copy key.properties.example and fill it in).
// A release build NEVER falls back to the debug key: without key.properties (or with an incomplete one) the build fails.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKey = keystorePropertiesFile.exists()
if (hasReleaseKey) keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }

android {
    namespace = "com.eldermin.eldermin_teacher_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        
        applicationId = "com.eldermin.eldermin_teacher_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseKey) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

// Fail fast, before any release task runs, instead of silently producing a debug-signed release.
gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any { it.name.contains("Release", ignoreCase = true) && it.project == project }
    if (buildsRelease) {
        if (!hasReleaseKey) {
            throw GradleException(
                "Release signing is not configured: android/key.properties is missing. " +
                    "Copy android/key.properties.example to android/key.properties and fill in the upload keystore details. " +
                    "A release build is never signed with the debug key."
            )
        }
        val missing = listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
            .filter { keystoreProperties.getProperty(it).isNullOrBlank() }
        if (missing.isNotEmpty()) {
            throw GradleException("android/key.properties is incomplete, missing: ${missing.joinToString()}.")
        }
        if (!file(keystoreProperties.getProperty("storeFile")).exists()) {
            throw GradleException("android/key.properties storeFile does not exist: ${keystoreProperties.getProperty("storeFile")}.")
        }
    }
}

flutter {
    source = "../.."
}
