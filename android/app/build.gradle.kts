import java.util.Properties
import java.io.FileInputStream
import java.io.FileNotFoundException

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
try {
    val keystorePropertiesFile = rootProject.file("key.properties")
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} catch (e: FileNotFoundException) {
    println("Warning: key.properties file not found. Ensure the file is present before building the release version.")
}

android {
    namespace = "com.adeeteya.classipod"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.adeeteya.classipod"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        externalNativeBuild {
            cmake {
                cppFlags += "-std=c++17"
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    buildFeatures {
        resValues = true
    }

    packaging {
        resources.excludes += "DebugProbesKt.bin"
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as? String
            keyPassword = keystoreProperties["keyPassword"] as? String
            storePassword = keystoreProperties["storePassword"] as? String
            val storeFilePath = keystoreProperties["storeFile"] as? String
            if (storeFilePath != null) {
                storeFile = file(keystoreProperties["storeFile"] as String)
            }
        }
    }

    buildTypes {
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isDebuggable = false
            isJniDebuggable = false
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
        }
    }

    flavorDimensions += "default"
    productFlavors {
        create("production") {
            dimension = "default"
            resValue("string", "app_name", "Classipod")
            applicationIdSuffix = ""
            ndk {
                abiFilters += "arm64-v8a"
            }
        }
        create("dev") {
            dimension = "default"
            resValue("string", "app_name", "Classipod Dev")
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
        }
    }
}

androidComponents {
    onVariants(selector().withFlavor("default" to "production")) { variant ->
        variant.packaging.jniLibs.excludes.addAll(
            listOf(
                "lib/armeabi-v7a/**",
                "lib/x86/**",
                "lib/x86_64/**",
            ),
        )
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
