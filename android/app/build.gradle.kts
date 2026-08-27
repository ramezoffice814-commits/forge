import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Roadmap Item 19: real production signing, prepared but never
// generated here — see docs/RELEASE_READINESS.md for the exact
// keystore/alias/password/backup requirements this repo is
// deliberately not creating on its own. android/key.properties is
// gitignored at both the root and android/ level (never committed) and
// simply doesn't exist yet; its absence is not an error — it means
// "no real key has been provided," and the release build falls back to
// the existing, already-documented debug-signing dev/CI convenience
// below. Once a real key.properties is added (see
// android/key.properties.example), this build starts using it
// automatically with no other code change required.
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigningConfig = keystorePropertiesFile.exists()
val keystoreProperties = Properties()
if (hasReleaseSigningConfig) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    // Fails the build clearly and immediately if key.properties exists
    // but is missing a required field — the whole point of this check
    // is that once someone has declared real-release intent by adding
    // this file, an incomplete one must never be silently treated as
    // "no signing config" and quietly fall back to debug-signing a
    // release artifact.
    for (requiredKey in listOf("storeFile", "storePassword", "keyAlias", "keyPassword")) {
        check(!keystoreProperties.getProperty(requiredKey).isNullOrBlank()) {
            "android/key.properties exists but is missing '$requiredKey' — " +
                "see android/key.properties.example for the required fields."
        }
    }
}

android {
    namespace = "com.forge.app.forge"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (Roadmap Item 17) —
        // its Android implementation targets Java 8+ APIs that need
        // desugaring support on our minSdk. See
        // https://developer.android.com/studio/write/java8-support.html
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.forge.app.forge"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigningConfig) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigningConfig) {
                signingConfigs.getByName("release")
            } else {
                // No android/key.properties yet — this is a debug-signed
                // release build, suitable for CI build-validation and
                // local `flutter run --release`/`flutter build apk
                // --release`, never for a real store submission. See
                // docs/RELEASE_READINESS.md for what's needed to change
                // this.
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Pairs with isCoreLibraryDesugaringEnabled above.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
