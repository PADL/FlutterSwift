plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

apply(from = "../swift-android.gradle.kts")

repositories {
    flatDir {
        dirs("libs")
    }
}

dependencies {
    api(files("libs/flutterswift.jar"))
}

android {
    namespace = "com.example.counter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        applicationId = "com.example.counter"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = false
    }

    buildTypes {
        debug {
            isJniDebuggable = true
        }
        release {
            signingConfig = signingConfigs.getByName("debug")
            isJniDebuggable = false
        }
    }

    sourceSets {
        getByName("main") {
            @Suppress("DEPRECATION")
            jni.srcDirs()
        }
    }

    packaging {
        jniLibs {
            keepDebugSymbols += "*/arm64-v8a/*.so"
            keepDebugSymbols += "*/armeabi-v7a/*.so"
            keepDebugSymbols += "*/x86_64/*.so"
        }
    }
}

flutter {
    source = "../.."
}
