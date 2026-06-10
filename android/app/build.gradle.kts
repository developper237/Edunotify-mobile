plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // Le plugin est déjà là, c'est bien
}

android {
    namespace = "cm.edunotify.edunotify_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.2.12479018"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "cm.edunotify.edunotify_mobile"
        minSdk = flutter.minSdkVersion // Conseil : mets 21 en dur ici pour Firebase/Notifications
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 1. Support pour les fonctions Java 8+
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // 2. Importation de la BoM Firebase (Gestionnaire de versions)
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))

    // 3. Ajout des SDK Firebase (sans spécifier de version grâce à la BoM)
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-messaging") // Requis pour tes notifications
}
