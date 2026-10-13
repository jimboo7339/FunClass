plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.funclass.funclass"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // 启用 core library desugaring（flutter_local_notifications 需要）来自Trae
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // 彻底禁用 lint：跨盘(F:/C:) 缓存锁文件经常导致构建失败，lint 对 release 构建影响不大——来自Trae
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.funclass.funclass"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 只打 arm64-v8a：2018 年后的手机都是 64 位
        // abiFilters 是 val 不能直接 =，先用 clear 再 add ——来自Trae
        ndk {
            abiFilters.clear()
            abiFilters.add("arm64-v8a")
        }
    }

    // CI 签名：配置了 FUNCLASS_STORE_FILE 等环境变量时启用（GitHub Actions 用），
    // 本地不设这些变量，完全不受影响
    signingConfigs {
        create("ci") {
            val storePath = System.getenv("FUNCLASS_STORE_FILE")
            if (storePath != null) {
                storeFile = file(storePath)
                storePassword = System.getenv("FUNCLASS_STORE_PASSWORD")
                keyAlias = System.getenv("FUNCLASS_KEY_ALIAS")
                keyPassword = System.getenv("FUNCLASS_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // CI 注入了正式 keystore 就用它；否则维持 debug 签名，保证 flutter run --release 可用。
            // 注意：debug 签名每次构建密钥都可能不同，发布的 APK 无法覆盖安装，正式发布请配置签名
            signingConfig = if (System.getenv("FUNCLASS_STORE_FILE") != null) {
                signingConfigs.getByName("ci")
            } else {
                signingConfigs.getByName("debug")
            }
            // release 也强制 arm64-only ——来自Trae
            ndk {
                abiFilters.clear()
                abiFilters.add("arm64-v8a")
            }
        }
    }
}

// desugaring 依赖 来自Trae
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
