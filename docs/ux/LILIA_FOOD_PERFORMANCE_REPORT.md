# Lilia Food — Rapport de performance (Phase 3)

**Date :** 29/09/2026 · **App :** `lilia-app` branche `hmipoka/uiux-phase3-impl`

## 1. Environnement

| Élément | Valeur |
|---|---|
| Appareil | iPhone 12 Pro (iPhone13,3), iOS 26.5, **USB** puis déconnecté en cours de session |
| Mode | `flutter drive --profile --no-dds` |
| Données | **production**, parcours invité, lecture seule (aucune commande, aucun paiement) — 7 vendeurs publics |
| Réseau | Wi-Fi du Mac de développement (pas Brazzaville) |
| Android physique | **aucun** — NOT MEASURED |

## 2. Le harnais — sept défauts, dont trois découverts en l'exécutant

La Discovery en avait identifié trois (`app.main()` rappelé par test, onboarding pris pour l'accueil, `--no-dds`). Les exécutions sur l'iPhone en ont révélé quatre autres :

| # | Défaut | Symptôme | Correctif |
|---|---|---|---|
| 1 | `app.main()` rappelé à chaque `testWidgets` | tests 2–7 en échec | … |
| 1 bis | **flutter_test démonte l'arbre entre deux `testWidgets`** | démarrer une seule fois laissait les tests 2–7 sans application (diagnostic : « Accueil=0 cartes=0 accueil visible=0 ») | **un seul `testWidgets`** qui enchaîne 7 scénarios isolés par try/catch |
| 2 | onboarding (`PageView`) pris pour l'accueil | mesure de l'onboarding | onboarding marqué vu ; accueil = 1ʳᵉ `RestaurantCard` |
| 3 | `traceAction` sans `--no-dds` | échec | commande documentée |
| 4 | `pumpAndSettle` sur un carrousel auto-défilant | blocage jusqu'à 10 min | pompage borné |
| 5 | `find.byType(Scrollable).first` | visait le carrousel horizontal ou un onglet hors écran | défilement vertical touchable ; attente sans `.first` (un `.first` vide lève « Bad state: No element ») |
| 6 | onglets « Commandes » / « Profil » en invité | connexion plein écran **sans barre d'onglets** (P3-18) : le harnais y restait bloqué | onglets invités seulement sans `TEST_EMAIL` |
| 7 | journalisation en profile | `debugPrint` n'atteint pas la console du drive ; erreurs « Instance of 'FlutterErrorDetails' » ; un rapporteur remplacé sans chaînage avait **déclaré la suite verte avec 3 échecs** | `print`, rapporteur chaîné ; le driver écrit les résumés des scénarios réussis puis **sort en erreur** s'il y a un échec (`exit(1)` — `integrationDriver` fait `exit(0)` juste après le callback) ; timeline vide tolérée |

État : **les correctifs 1 bis à 7 n'ont pas encore produit une exécution complète** — l'iPhone s'est déconnecté pendant la compilation du 8ᵉ passage. Aucun chiffre de défilement ou de navigation de cette phase n'est donc disponible.

## 3. Mesures réellement obtenues

| Mesure | Valeur | Conditions | Remarque |
|---|---|---|---|
| `main()` → 1ʳᵉ carte vendeur | **3 278 ms** (passage 6), **2 404 ms** (passage 7) | profile, iPhone 12 Pro, prod, Wi-Fi | réseau inclus (1,1–3 s par appel mesurés en Discovery) ; **pas** un démarrage à froid système (process lancé par le drive) |
| Images « populaires » + vendeurs, originaux → `w_480,c_limit,q_auto` | **1 078 Ko → 415 Ko (−62 %)** sur 14 images Cloudinary | `curl`, prod, 29/09 | 2 images vendeur renvoient **404** en variante (supprimées de Cloudinary, originaux servis par le cache CDN) → repli sur l'original implémenté |
| Défilement accueil, navigation, fiche vendeur | — | — | **NOT MEASURED dans cette phase** ; mesures Discovery (0 frame manquée, build p99 4,7 ms) restent la seule référence |
| 10 / 30 / 50 / 100 vendeurs | — | — | **NOT MEASURED** (7 vendeurs en prod ; pas de fixture ajoutée) |
| Mémoire, cold start système | — | — | NOT MEASURED |

## 4. Optimisations effectuées

| Optimisation | Justification mesurée | Risque |
|---|---|---|
| Variante Cloudinary à la largeur affichée (paliers 240/480/720/1080/1600, `c_limit` n'agrandit jamais, pas de `f_auto` qui peut servir de l'AVIF illisible par Flutter) | −62 % d'octets | 1ʳᵉ demande d'une variante non cachée au CDN (latence ponctuelle) ; couvert par le repli |
| Hauteur des cartes « populaires » selon le texte | correction d'accessibilité, pas de perf | cartes un peu plus hautes (noms sur 2 lignes) |

Non fait, faute de mesure le justifiant : migration en slivers, `memCacheWidth` (risque de flou avec `BoxFit.cover`), recompression de `logo1.jpg` (1,5 Mo, identifié en Discovery).

## 5. Pour la prochaine mesure

```bash
flutter drive --driver=test_driver/perf_driver.dart \
  --target=integration_test/perf_test.dart --profile --no-dds -d <id>
```
iPhone **en USB, déverrouillé** ; `ios/Flutter/MapsKeys.local.xcconfig` présent. L'app installée est remplacée par un build profile : réinstaller depuis TestFlight ensuite. Refaire la même chose sur un **Android d'entrée de gamme**.
