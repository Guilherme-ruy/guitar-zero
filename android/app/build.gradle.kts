plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Secrets exist only on the release runner. No key.properties is needed.
val signingValues = listOf(
    "ANDROID_KEYSTORE_PATH", "ANDROID_STORE_PASSWORD",
    "ANDROID_KEY_ALIAS", "ANDROID_KEY_PASSWORD",
).associateWith { System.getenv(it)?.takeIf(String::isNotEmpty) }
val hasUploadSigning = signingValues.values.all { it != null }
require(hasUploadSigning || signingValues.values.all { it == null }) {
    "Upload signing is incomplete. Set all four ANDROID_* signing variables."
}

android {
    namespace = "io.github.guilhermeruy.guitar_zero"
    compileSdk = maxOf(36, flutter.compileSdkVersion)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Keep this identity stable after the first Play Console upload.
        applicationId = "io.github.guilhermeruy.guitar_zero"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = maxOf(36, flutter.targetSdkVersion)
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadSigning) {
            create("upload") {
                storeFile = file(signingValues.getValue("ANDROID_KEYSTORE_PATH")!!)
                storePassword = signingValues.getValue("ANDROID_STORE_PASSWORD")
                keyAlias = signingValues.getValue("ANDROID_KEY_ALIAS")
                keyPassword = signingValues.getValue("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Existing APK CI remains installable for device tests.
            // The release bundle task below refuses this debug fallback.
            signingConfig = signingConfigs.getByName(if (hasUploadSigning) "upload" else "debug")
        }
    }
}

val validatePlaySigning by tasks.registering {
    doLast {
        check(hasUploadSigning) {
            "A Play AAB requires upload signing. Configure the secrets documented in docs/PLAY_STORE.md."
        }
        check(file(signingValues.getValue("ANDROID_KEYSTORE_PATH")!!).isFile) {
            "The upload keystore was not restored."
        }
    }
}
tasks.matching { it.name == "bundleRelease" }.configureEach {
    dependsOn(validatePlaySigning)
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
