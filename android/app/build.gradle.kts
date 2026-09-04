import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

// Clé Google Maps lue depuis local.properties (gitignored) — jamais committée.
// Fallback placeholder si absente : le build passe mais Maps ne s'affiche pas.
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}
// La variable d'environnement sert aux machines qui n'ont pas de
// `local.properties` — une CI, typiquement. Elle manquait ici alors que les
// deux autres apps l'acceptaient : aucun pipeline ne pouvait produire la
// release de `lilia-app`, il échouait sur la garde ci-dessous.
val mapsApiKey: String =
    (localProperties["MAPS_API_KEY"] as String?)
        ?: providers.environmentVariable("MAPS_API_KEY").orNull
        ?: "YOUR_GOOGLE_MAPS_API_KEY"

// Refuse de produire un binaire de release sans vraie clé Maps.
//
// Le repli sur le gabarit était silencieux : `flutter build appbundle` sans
// `local.properties` produisait un APK qui compile, s'installe, se lance — et
// affiche une **carte grise** sans le moindre message. C'est exactement le
// « ça marche en debug, pas en release » qu'on cherchait à expliquer.
//
// En debug on tolère l'absence (un développeur qui ne touche pas aux cartes
// n'a pas à réclamer une clé) ; en release on casse le build, avec la marche
// à suivre.
gradle.taskGraph.whenReady {
    val buildingRelease = allTasks.any { task ->
        task.name.contains("Release") &&
            (task.name.startsWith("assemble") || task.name.startsWith("bundle"))
    }
    if (buildingRelease && mapsApiKey == "YOUR_GOOGLE_MAPS_API_KEY") {
        throw GradleException(
            "Clé Google Maps absente : ajoutez `MAPS_API_KEY=<clé>` dans " +
                "android/local.properties (fichier gitignoré), ou exportez " +
                "MAPS_API_KEY. Sans elle, le binaire de release affiche une carte grise " +
                "sans aucune erreur."
        )
    }
}


android {
    namespace = "com.dreesis.lilia.lilia_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        // Flag to enable support for the new language APIs
        isCoreLibraryDesugaringEnabled = true
        // Sets Java compatibility to Java 11
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
        }
    }
    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.dreesis.lilia.lilia_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        multiDexEnabled = true
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Injecte la clé Maps dans AndroidManifest (${MAPS_API_KEY}).
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("com.google.android.material:material:1.13.0")

    // Edge-to-edge support for Android 15+
    implementation("androidx.activity:activity-ktx:1.9.3")

    // Firebase dependencies
    implementation(platform("com.google.firebase:firebase-bom:34.18.0"))
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-analytics")
}
flutter {
    source = "../.."
}
