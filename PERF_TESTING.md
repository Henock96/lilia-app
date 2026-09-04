# Tests de performance — lilia-app

Tests automatisés mesurant **FPS / freeze UI / appels réseau / montée en charge**,
basés sur `integration_test` + `flutter_driver`.

## Fichiers

| Fichier | Rôle |
|---------|------|
| `integration_test/perf_test.dart` | Scénarios : démarrage, login, scroll home, navigation 4 onglets, montée en charge |
| `test_driver/perf_driver.dart` | Transforme les timelines en résumés chiffrés écrits dans `build/` |

## Lancer

**Sur device physique (recommandé — chiffres réalistes, mode profile) :**

```bash
flutter drive \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/perf_test.dart \
  --profile \
  -d <device-id> \
  --dart-define=TEST_EMAIL=client@test.cg \
  --dart-define=TEST_PASSWORD='Passw0rd!'
```

- Le login est **optionnel** : sans `TEST_EMAIL`, le parcours se fait en invité
  (la home est publique).
- ⚠️ Le mode `--profile` n'est **pas supporté sur simulateur iOS** : pour valider
  uniquement le harness (sans chiffres représentatifs), retirer `--profile` et
  cibler un simulateur. Les vrais chiffres doivent venir d'un **device réel en
  profile**.

## Résultats

Écrits dans `build/` :

| Fichier | Contenu |
|---------|---------|
| `home_scroll.timeline_summary.json` | Scroll de la home |
| `tab_navigation.timeline_summary.json` | Navigation entre les 4 onglets |
| `search_scroll.timeline_summary.json` | Scroll des résultats de recherche |
| `restaurant_detail_scroll.timeline_summary.json` | Scroll du détail vendeur (image-heavy) |
| `cart_scroll.timeline_summary.json` | Scroll du panier |
| `stress.timeline_summary.json` | Montée en charge (12 cycles scroll + nav) |
| `perf_metrics.json` | Métriques réseau custom (cold start, recherche, détail vendeur, stress) |

### Scénarios couverts (`perf_test.dart`)

1. Démarrage à froid + chargement réseau home
2. Scroll de la home (FPS / jank)
3. Navigation entre les 4 onglets
4. Recherche : saisie + scroll des résultats (+ temps 1er résultat réseau)
5. Détail vendeur : ouverture + scroll image-heavy (+ temps de chargement)
6. Panier : ouverture + scroll
7. Montée en charge : scroll + navigation soutenus

### Métriques réseau (`perf_metrics.json`)

| Champ | Signification |
|-------|---------------|
| `cold_start_to_home_millis` | Démarrage app → home prête (inclut cold start backend Render) |
| `home_content_loaded` | Contenu home effectivement chargé |
| `search_first_result_millis` | Saisie → 1er résultat de recherche affiché |
| `vendor_detail_load_millis` | Tap carte → page détail vendeur chargée |
| `stress_total_millis` | Durée totale du scénario de montée en charge |

### Métriques clés des `*.timeline_summary.json`

| Champ | Signification | Cible (60 fps) |
|-------|---------------|----------------|
| `average_frame_build_time_millis` | Temps moyen de build d'une frame (UI thread) | < 16.7 ms |
| `90th_percentile_frame_build_time_millis` | 90e percentile build | < 16.7 ms |
| `99th_percentile_frame_build_time_millis` | Pics (jank visible) | surveiller |
| `missed_frame_build_budget_count` | **Nombre de frames jank** (build > budget) | le plus bas possible |
| `average_frame_rasterizer_time_millis` | Temps moyen raster (GPU thread) | < 16.7 ms |
| `missed_frame_rasterizer_budget_count` | Frames jank côté raster | le plus bas possible |

`missed_frame_*_budget_count` = ce qu'on appelle les **freezes / saccades** : c'est
la métrique à suivre après les optimisations (cache image LIL-37, parsing JSON sur
isolate, compression sur isolate).

## Lien avec les optimisations

- **LIL-37 (cache image)** : moins de décodage/téléchargement d'images pendant le
  scroll → moins de jank raster sur `home_scroll`.
- **Parsing JSON sur isolate** (`utils/json_isolate.dart`) : le `jsonDecode` +
  mapping des grosses listes (vendeurs / produits / commandes) ne bloque plus le
  main thread → moins de pics sur `cold_start_to_home_millis` et au refresh.
- **Compression image sur isolate** (`utils/image_compressor.dart`) : l'encodage
  JPEG avant upload ne gèle plus l'UI.
