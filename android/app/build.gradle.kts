import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val signingProperties = Properties()
val signingPropertiesFile = rootProject.file("key.properties")
if (signingPropertiesFile.exists()) {
    signingPropertiesFile.inputStream().use { signingProperties.load(it) }
}

android {
    namespace = "com.eshokfix.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // Android Lint crashes inside image_picker_android during release analysis
    // (JavaDocParser NoSuchMethodError). Keep debug analysis/tests enabled and
    // skip only the broken dependency lint pass for release packaging.
    lint {
        checkReleaseBuilds = false
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            if (signingPropertiesFile.exists()) {
                keyAlias = signingProperties["keyAlias"] as String
                keyPassword = signingProperties["keyPassword"] as String
                storeFile = file(signingProperties["storeFile"] as String)
                storePassword = signingProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        getByName("debug") {
            // Use the same persistent certificate as release so updates can be
            // installed over the previous debug build without uninstalling.
            if (signingPropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
        getByName("release") {
            if (signingPropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    defaultConfig {
        applicationId = "com.eshokfix.mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.core:core:1.15.0")
}

flutter {
    source = "../.."
}
