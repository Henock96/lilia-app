import java.util.Base64
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

    // Même raisonnement pour la signature : on casse au moment de fabriquer
    // le binaire, pas au moment de configurer le projet. Un artefact de
    // release signé avec la clé de debug est refusé par le Play Store — mieux
    // vaut l'apprendre ici que sur la console de publication.
    if (buildingRelease && !rootProject.file("key.properties").exists()) {
        throw GradleException(
            "Trousseau de signature absent : créez `android/key.properties` " +
                "(fichier gitignoré) avec keyAlias, keyPassword, storeFile et " +
                "storePassword. Sans lui, la release serait signée avec la clé " +
                "de debug et refusée par le Play Store."
        )
    }

    // Et le même raisonnement, une troisième fois, pour le DSN Sentry.
    //
    // `main.dart` lit `String.fromEnvironment('SENTRY_DSN')`. Un DSN vide ne
    // produit **aucune erreur** : le SDK se désactive tout seul, `appRunner`
    // s'exécute, l'application se compile, s'installe, se lance, se publie —
    // et ne remonte jamais le moindre plantage. Pire : sur la console Sentry,
    // l'absence d'événements ressemble à une absence de plantages.
    //
    // C'est la seule fenêtre qu'on aura sur la production, et elle dépendait
    // d'un `--dart-define` que ni `README.md`, ni `AGENTS.md`, ni `CLAUDE.md`
    // n'écrivaient dans une commande de build. Les deux gardes ci-dessus ont
    // été écrites avec ce soin ; celle-ci manquait.
    //
    // Flutter transmet les `--dart-define` à Gradle via `-Pdart-defines=`,
    // une liste de `base64(clé=valeur)` séparés par des virgules.
    if (buildingRelease) {
        val defines: List<String> =
            (project.findProperty("dart-defines") as String?)
                ?.split(",")
                ?.filter { it.isNotBlank() }
                ?.mapNotNull {
                    runCatching { String(Base64.getDecoder().decode(it)) }.getOrNull()
                }
                ?: emptyList()
        // On exige que la **clé soit présente**, pas qu'elle soit renseignée.
        //
        // Un `--dart-define=SENTRY_DSN=` explicitement vide reste accepté :
        // c'est un choix, il est écrit dans la commande, et il se relit. Ce
        // qu'on refuse, c'est l'oubli — le cas où personne n'a décidé et où
        // l'absence de télémétrie ne se remarque qu'au premier incident qu'on
        // ne saura pas expliquer.
        //
        // Exiger une valeur non vide serait pire : le seul contournement
        // serait d'inventer un DSN, et `SentryFlutter.init` échouerait à le
        // parser au démarrage de l'application.
        if (defines.none { it.startsWith("SENTRY_DSN=") }) {
            throw GradleException(
                "DSN Sentry non déclaré : ajoutez `--dart-define=SENTRY_DSN=$" +
                    "SENTRY_DSN` à la commande de build (voir tool/release.sh). " +
                    "Sans DSN, le binaire publié ne remonte AUCUN plantage, et " +
                    "rien ne le signale — ni à la compilation, ni à l'exécution, " +
                    "ni sur la console Sentry, où zéro événement ressemble à " +
                    "zéro plantage. Pour renoncer délibérément à la télémétrie, " +
                    "passez la clé vide : `--dart-define=SENTRY_DSN=`."
            )
        }
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
    // Le trousseau de signature n'existe que sur les machines qui publient.
    //
    // Ces quatre lignes faisaient `keystoreProperties["keyAlias"] as String`
    // sans garde : en l'absence de `key.properties`, le cast d'un `null`
    // levait **à la configuration** de Gradle. Toute tâche échouait alors, y
    // compris `assembleDebug` et `flutter run` — un développeur qui clone le
    // dépôt ne pouvait pas lancer l'application, et le message ne parlait pas
    // de signature. La garde `MAPS_API_KEY` juste au-dessus avait été écrite
    // avec ce soin ; celle-ci manquait.
    //
    // Absent ⇒ pas de configuration de release. Le build de debug fonctionne,
    // et c'est la garde de `buildTypes` ci-dessous qui refuse une release non
    // signée, avec la marche à suivre.
    val hasKeystore = keystorePropertiesFile.exists() &&
        keystoreProperties["keyAlias"] != null &&
        keystoreProperties["storeFile"] != null

    signingConfigs {
        if (hasKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
    buildTypes {
        release {
            // Sans trousseau, on laisse la signature de debug plutôt que de
            // casser la configuration. Produire un binaire de release signé en
            // debug serait pire s'il partait sur un store — d'où la garde
            // explicite ci-dessous, qui arrête le build au moment de le
            // fabriquer et non au moment de le configurer.
            if (hasKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("com.google.android.material:material:1.14.0")

    // Edge-to-edge support for Android 15+
    implementation("androidx.activity:activity-ktx:1.13.0")

    // Firebase dependencies
    implementation(platform("com.google.firebase:firebase-bom:34.18.0"))
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-analytics")
}
flutter {
    source = "../.."
}
