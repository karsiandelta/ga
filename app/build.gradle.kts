plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.cristian.oyetio"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.cristian.oyetio"
        minSdk = 28
        targetSdk = 35
        versionCode = 4
        versionName = "1.3"
    }

    signingConfigs {
        getByName("debug") {
            // Clave fija para que cada nueva versión se instale encima de la anterior
            storeFile = file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    androidResources {
        // El modelo de voz se copia tal cual
        noCompress += listOf("mdl", "fst", "int", "conf", "mat")
    }
}

dependencies {
    // Reconocimiento de voz sin internet
    implementation("com.alphacephei:vosk-android:0.3.47@aar")
    implementation("net.java.dev.jna:jna:5.13.0@aar")
}
