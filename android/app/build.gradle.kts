plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    // El plugin de Flutter debe aplicarse después de Android y Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.gestion_dormitorios"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Soporte para notificaciones en dispositivos antiguos
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.gestion_dormitorios"
        // MinSdk 21 es el mínimo para Firebase y notificaciones modernas
        minSdk = flutter.minSdkVersion 
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 👇 CORRECCIÓN AQUÍ: buildTypes en plural y formato correcto para Kotlin DSL
    buildTypes {
        getByName("release") {
            // Configuración para release
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Librería necesaria para el soporte de Java 8 (desugaring)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")

    // Firebase
    implementation(platform("com.google.firebase:firebase-bom:34.8.0"))
    implementation("com.google.firebase:firebase-analytics")
}
