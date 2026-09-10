// === Signing Release Android (SIDELOAD INTERNAL) INFO ===
// Keystore: goldenity-pos-release.jks | Alias: goldenity-pos
// Validity: 10000 hari (27 tahun, sampai 2053) | Generated: 2026-09-10
// PASSWORD LIAT DI: E:\Goldenity\_keystores\GOLDENITY_POS_V2_KEYSTORE_INFO.txt
// Signing config otomatis fallback ke debug jika key.properties / .jks tidak ditemukan
// Build Commands:
//   Debug APK (test install):     flutter build apk --debug
//   Release APK (split per ABI): flutter build apk --release --split-per-abi
//   Release AAB (Play Store):    flutter build appbundle --release

import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { stream ->
        keystoreProperties.load(stream)
    }
}

val releaseStoreFilePath = keystoreProperties.getProperty("storeFile")?.trim().orEmpty()
val releaseStorePassword = keystoreProperties.getProperty("storePassword")?.trim().orEmpty()
val releaseKeyAlias = keystoreProperties.getProperty("keyAlias")?.trim().orEmpty()
val releaseKeyPassword = keystoreProperties.getProperty("keyPassword")?.trim().orEmpty()
val releaseStoreFileExists =
    releaseStoreFilePath.isNotEmpty() && rootProject.file(releaseStoreFilePath).exists()
val hasValidReleaseSigning =
    releaseStoreFileExists &&
        releaseStorePassword.isNotEmpty() &&
        releaseKeyAlias.isNotEmpty() &&
        releaseKeyPassword.isNotEmpty()

android {
    namespace = "com.goldenity.pos"
    compileSdk = 34
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.goldenity.pos"
        minSdk = 24
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // iWare 32-bit ARM POS hardware prioritized: force armeabi-v7a to be
        // included in all installer.apk outputs (older Mediatek / Allwinner
        // boards ship with 32-bit BSPs even on 64-bit SoC) while still
        // supporting modern arm64 and x86_64 for mobile/tablets.
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }
    }

    splits {
        abi {
            // Matches "flutter build apk --split-per-abi" — produce one
            // optimized APK per ABI so armeabi-v7a installer.apk is the
            // tiny, single-target payload preferred for flashing iWare POS.
            isEnable = true
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86_64")
            isUniversalApk = false
        }
    }

    signingConfigs {
        create("release") {
            if (releaseStoreFilePath.isNotEmpty()) {
                storeFile = rootProject.file(releaseStoreFilePath)
            }
            if (releaseStorePassword.isNotEmpty()) {
                storePassword = releaseStorePassword
            }
            if (releaseKeyAlias.isNotEmpty()) {
                keyAlias = releaseKeyAlias
            }
            if (releaseKeyPassword.isNotEmpty()) {
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // Sideloaded tablet APKs are prioritized for runtime stability over
            // binary size. R8 minification caused release builds that installed
            // but failed to open reliably on target devices.
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = if (hasValidReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
