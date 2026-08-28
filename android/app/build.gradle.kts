import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// CI creates this file from repository secrets. It is ignored locally, so no
// production signing material is ever committed to the repository.
val signingProperties = Properties()
val signingPropertiesFile = rootProject.file("key.properties")
if (signingPropertiesFile.exists()) {
    signingPropertiesFile.inputStream().use { signingProperties.load(it) }
}

val releaseTasksRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
val requiredSigningProperties = listOf(
    "storeFile",
    "storePassword",
    "keyAlias",
    "keyPassword",
)
val hasReleaseSigning = signingPropertiesFile.exists() &&
    requiredSigningProperties.all { !signingProperties.getProperty(it).isNullOrBlank() }

android {
    namespace = "dev.servergy.servergy"
    // flutter_secure_storage requires Android API 37 at compile time.
    // This does not change the Android 12 (API 31) installation minimum.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.servergy.servergy"
        // Android 12 (API 31) is Servergy's supported minimum.
        minSdk = 31
        // Android 17 requires an explicit runtime grant for LAN access. The
        // app handles that permission before SSH, WOL, and discovery actions.
        targetSdk = 37
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.create("servergyRelease") {
                    keyAlias = signingProperties.getProperty("keyAlias")
                    keyPassword = signingProperties.getProperty("keyPassword")
                    storeFile = file(signingProperties.getProperty("storeFile"))
                    storePassword = signingProperties.getProperty("storePassword")
                }
            } else if (releaseTasksRequested) {
                throw GradleException(
                    "A production release requires android/key.properties and " +
                        "the configured production keystore. Use the signed GitHub " +
                        "release workflow when local signing material is unavailable.",
                )
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
