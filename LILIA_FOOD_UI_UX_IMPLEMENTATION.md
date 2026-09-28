# LILIA FOOD — UI/UX Phase 2 : rapport d'implémentation

**Date :** 2026-09-28 · **Dépôt :** `lilia-app` · **Branche :** `hmipoka/f309-options` (HEAD `369a118`) · **Rien n'est commité.**

> **Mise à jour 28/09/2026 (après décisions).** Commité sur `hmipoka/uiux-phase2`, rebasé sur `master` (F3-10, F3-11). `Info.plist` : clé « Always » **conservée** — avertissement Apple ITMS-90683 dû à `geolocator_apple` (compilé par SwiftPM, son interrupteur `BYPASS_PERMISSION_LOCATION_ALWAYS` ne s'applique pas) — mais reformulée sans promettre d'arrière-plan ; test adapté. `sentry_flutter` : `10.0.0-rc.0` → **9.30.1** (dernière stable), `profilesSampleRate` rétabli. Rebase : modèle `ProductVariant` de F3-10 conservé (`isInStock` = `!isSoldOut`), sélecteur partagé gardé sur la fiche produit, devis serveur F3-11 conservé et ligne « offre boutique » portée dans `CheckoutOrderSummary`. **855 tests verts, 0 échec.**
**Base :** `LILIA_FOOD_UI_UX_AUDIT.md` (Phase 1, 27/09/2026).

# Executive Summary

La Phase 2 a corrigé des défauts **vérifiés dans le code**, en commençant par les parcours d'achat. Chaque constat de l'audit a été revalidé avant correction ; deux étaient inexacts ou incomplets, et la revalidation a fait apparaître des défauts plus graves que ceux listés.

Ce qui change pour le client :

1. **Ajout rapide unifié** (5 écrans) : plus aucun format choisi à sa place, un format épuisé n'est plus proposé, un conflit « sur commande / immédiat » ouvre la modale de choix au lieu d'un message d'erreur, et le visiteur peut ajouter depuis les 5 écrans (3 le refusaient alors que le panier invité existe).
2. **Les pannes se voient tout de suite.** Riverpod 3 relance tout seul un provider en erreur pendant ~38 s ; l'accueil et la recherche affichaient un chargement pendant tout ce temps. Le bouton « Réessayer » de la liste des vendeurs **ne relançait rien** (mauvais provider invalidé).
3. **Lisibilité** : une quinzaine de textes sous le seuil WCAG AA corrigés et verrouillés par test (remise promo à 2.3:1 et remise fidélité à 1.35:1 au checkout, carte fidélité à 1.8–2.3:1, étapes à venir du suivi à ~1.2:1, pastilles de statut, badges).
4. **Écrans monolithiques allégés** : checkout 2 297 → 1 735 lignes, détail commande 2 414 → 1 374, fiche vendeur 1 573 → 1 286, sans déplacer une règle métier.
5. **Fidélité compréhensible** sans page d'aide : solde → valeur → seuil restant → comment gagner → comment utiliser.

**Tests :** 780 → **844 verts** (+64). **1 échec, préexistant et hors périmètre** (`Info.plist` modifié avant cette mission, voir [Pre-existing Changes](#pre-existing-changes)). `flutter analyze` : 0 problème.
**Performance :** un gain mesuré (reconstructions du carrousel : 3 → 0 sur 13 s). **Temps de frame sur appareil : NON MESURÉ.**

---

## P1 Fixed

### Variant Selection

**Problem.** L'audit affirmait que plusieurs quick-add sélectionnaient `variants.first`. **Revalidé : c'était inexact** — les 5 chemins distinguaient déjà 1 et plusieurs formats. Mais la vérification a révélé d'autres défauts, présents sur ces 5 chemins :

| Défaut | Où | Conséquence |
|---|---|---|
| 4 copies divergentes de la feuille de choix de format | populaires, recommandations, recherche, suggestions panier | un format **épuisé** restait sélectionnable (succès affiché, puis ligne défaite par le serveur) |
| format unique épuisé ajouté sans contrôle | 5 chemins | même faux succès |
| `addItem` appelé directement | 4 chemins + Favoris | conflit « sur commande / immédiat » affiché en erreur, au lieu de la modale « Vider et ajouter » (`addToCartSafely`) |
| `FirebaseAuth.currentUser == null` → « Connectez-vous » | populaires, recherche, suggestions | le **visiteur** bloqué, alors que le panier invité existe et que 2 autres écrans l'acceptaient |
| `showErrorSnack(e.toString())` | fiche vendeur | exception brute affichée |
| bouton « + » en `GestureDetector` 28–36 px | 5 chemins | cible < 48 px, aucune sémantique, `Colors.white` sur `primary` (illisible en sombre) |
| prix `formatPrice(displayPrice)` | populaires, recommandations, recherche, suggestions | prix d'un format annoncé sans « À partir de » |
| Favoris : présélection du « seul format en stock » parmi plusieurs | fiche Favoris (travail préexistant) | choix fait à la place du client |

**Solution.** Un seul chemin : `quickAddProduct()` + `QuickAddButton` (`lib/features/cart/presentation/quick_add.dart`).
- 1 format vendable → ajout direct ; plusieurs → feuille partagée `showVariantSelectionSheet` (le format épuisé y est grisé et non sélectionnable) ; fiche vendeur → ouvre la fiche produit (parité web, conservée) ; options F3-09 → fiche produit (inchangé).
- Le stock affiché est **le verdict serveur** (`stockStatus`) ; aucun recalcul. Verdict absent (recherche, populaires : ces endpoints ne passent pas par `withVariantStock`) → rien n'est affiché, le serveur arbitre.
- Icône du bouton : `+` pour un ajout direct, `tune` pour « choisir un format » ; libellé TalkBack distinct (« Ajouter X au panier » / « Choisir un format pour X »).
- Zone de tap 48 px autour du dessin d'origine, `onPrimary` (= `textOnAction`) pour l'icône.
- `StockBadge` reconstruit sur `LiliaBadge` : n'affiche que les deux états utiles (« Plus que N disponibles », « Épuisé »), avec icône.
- Repli `json['status']` retiré de `ProductVariant.fromJson` : le backend n'émet que `stockStatus` (vérifié dans `stock-units.ts`).
- `VariantSelector` : plus d'`Opacity(0.55)` sur un format épuisé (elle divisait le contraste du mot « Épuisé »), sémantique radio (`inMutuallyExclusiveGroup`, `checked`), hauteur ≥ 56 px.

**Files.** `quick_add.dart` (nouveau), `product_stock_widgets.dart`, `popular_dishes_section.dart`, `recommendations_section.dart`, `search_screen.dart`, `cart_screen.dart`, `restaurant_detail_screen.dart`, `favoris_detail_page.dart`, `models/produit.dart`.

**Tests.** `test/features/cart/quick_add_test.dart` (10) : format unique, plusieurs formats (rien avant le choix, épuisé refusé, format choisi ajouté), fermeture de la feuille, format unique épuisé, LOW/UNLIMITED/AVAILABLE ajoutables, verdict absent, cible 48 px, icône en sombre. `test/features/home/vendor_product_card_test.dart` (5).

### Banner Fallback

**Problem.** `assets/images/banner.png` référencé, jamais présent. Corrigé par le travail préexistant (repli graphique local) — **revu et validé**, puis complété :
- avec l'API en panne, le repli n'apparaissait qu'après **~38 s de shimmer** (relance automatique Riverpod, voir P2.1) ;
- le carrousel faisait un `setState` sur **tout l'écran d'accueil** toutes les 4 s ;
- l'auto-défilement ignorait « réduire les animations ».

**Solution.** `whenUi` (erreur visible pendant les relances), `ValueNotifier` limité aux points d'indicateur, `autoPlay: !MediaQuery.disableAnimationsOf(context)`. Plus aucun asset référencé n'est absent du bundle (contrôle exhaustif des chaînes `assets/…` de `lib/`).

**Files.** `home.dart`, `utils/async_value_ui.dart` (nouveau).

**Tests.** `test/features/home/home_screen_states_test.dart` : API en erreur → repli immédiat, aucun `AssetImage` ; liste vide → même repli. `test/perf/home_carousel_rebuild_test.dart` (voir Performance).

### Screen Decomposition

**Problem.** Checkout 2 297 lignes (un `State` de 2 096), détail commande 2 414, fiche vendeur 1 573.

**Solution.** Extraction de **sections d'affichage** ; paiement, idempotence, création de commande, annulation, réclamation, recommande restent dans leurs propriétaires. Aucun montant n'est recalculé dans un widget extrait.

| Écran | Avant | Après | Extrait |
|---|---:|---:|---|
| `checkout_page.dart` | 2 297 | 1 735 | `CheckoutOrderSummary` (montants reçus de `CheckoutEstimate`), `PaymentInstructionsDialog` (montant/numéro/référence résolus par la page depuis la réponse serveur ; gestes rendus à la page) |
| `commande_detail_page.dart` | 2 414 | 1 374 | `order_detail_cards.dart` : en-tête, progression, vendeur, articles, livraison, récapitulatif ; `_OrderCard` remplace 6 copies de la même décoration |
| `restaurant_detail_screen.dart` | 1 573 | 1 286 | `VendorProductCard` |
| `user_page.dart` | 953 | 777 | `LoyaltyCard` / `LoyaltyCardView` |
| `commande_page.dart` | 768 | 661 | table de statuts dédupliquée (ci-dessous) |

**Vocabulaire des statuts** : deux tables divergentes (liste et détail) → une seule, `orderStatusInfo()` dans `status_info.dart`, avec une **intention** (`LiliaBadgeVariant`) au lieu d'une couleur Material ; `pickupStatusInfo` y a rejoint le reste (ré-exporté par la page pour ses importeurs).

Défauts corrigés pendant l'extraction : « J'ai paye » en blanc sur ambre MTN (~2:1) → style d'action du thème ; accents manquants (« Reference a rappeler », « Etapes », « numero ») ; montant vert sur vert pâle ; étapes à venir du stepper en `outline` (~1.2:1) ; `Colors.green.shade700` / `Colors.orange.shade800` en texte.

**Tests.** `checkout_order_summary_test.dart` (5), `payment_instructions_dialog_test.dart` (4), `order_detail_cards_test.dart` (2), `order_status_info_test.dart` (3) ; les 99 tests commandes existants restent verts.

**Non fait :** `cart_screen.dart` (946 lignes après retrait des doublons) et `product_detail_page.dart` n'ont pas été découpés davantage — voir Remaining Issues.

## P2 Fixed

### P2.1 — Recherche / erreurs / retry
- Recherche : `BuildErrorState` + « Réessayer » (travail préexistant, validé) **et** `whenUi` : sans lui, l'erreur restait cachée ~38 s derrière le spinner.
- `BuildErrorState` : `ApiException` affiche son message (déjà rédigé pour le client) ; `TypeError`, `SocketException`, `TimeoutException`, `DioException`… deviennent une phrase compréhensible, le détail part dans `logDebug`. Message annoncé aux lecteurs d'écran (`liveRegion`), gris fixe remplacé par `onSurfaceVariant`.
- Tests : `search_screen_test.dart` (succès, vide, erreur réseau, erreur interne, reprise), `user_facing_error_message_test.dart` (5).

### P2.5 — Erreurs silencieuses du Home

| Section | Catégorie | Comportement |
|---|---|---|
| Liste des vendeurs | critique | message + « Réessayer » **qui relance enfin `vendorsListProvider`** |
| Bannières | facultative | repli éditorial local, immédiat |
| Plats populaires | secondaire | disparaît **avec son titre** (le titre restait orphelin au-dessus d'un vide) |
| Recommandations | — | widget **jamais monté** dans l'app (code mort, signalé) |

Test : la contre-épreuve a montré qu'un test naïf passait **aussi avec le bug** (la relance automatique rétablissait la liste seule) ; le test coupe désormais la relance auto et échoue sur l'ancien code.

### P2.6 — Profil / fidélité
`LoyaltyCard` répond dans l'ordre : solde → « Soit X FCFA de réduction » (barème serveur, rien en dur) → « Utilisables dès votre prochaine commande » **ou** « Encore N pt avant de pouvoir les utiliser (minimum M pt) » → Gagner (+N pt par commande livrée ; pas de points sur une commande payée en partie avec des points) → Utiliser (« Utiliser mes points » au paiement). Historique chargé à la demande, avec reprise en cas d'erreur. Dégradé orange600 → orange700 (blanc ≥ 4.9:1 ; l'ancien #FF8C00 → #FFB347 tombait à 1.8–2.3:1). Tuile « Utiliser mes points » du checkout : fond `amber[50]` fixe (illisible en sombre) → surface du thème ; « Reduction » → « Réduction ». Tests : `loyalty_card_test.dart` (6).

### P2.2 / P2.3 — Design system, styles codés en dur
Voir [Design System](#design-system).

### P2.4 — Home / performance
Voir [Performance](#performance). Pas de migration en slivers.

### P2.7 — Accessibilité
Voir [Accessibility](#accessibility).

## Design System

**Consolidé, pas remplacé.** Ajouts au socle existant (`LiliaColors`, `LiliaSemantics`, `AppTheme`) :
- `LiliaColors.green700`, `amber700`, `red500` : teintes **de texte** sur fond clair (contraste justifié, testé) ;
- `ColorScheme.successText` / `warningText` (extension `LiliaFeedbackText`) : le vert/ambre de *remplissage* n'est pas une couleur de texte ;
- `LiliaBadge` : rendu du premier composant partagé de statut — 0 appelant avant, 6 usages après ; icône optionnelle ; couleurs exposées (`liliaBadgeColors`) et testées ; **retrait** de `fromOrderStatus` et des variantes « statut de commande », qui mappaient des statuts inexistants côté API (`CONFIRMED`, `DELIVERED`…) — même piège que `LiliaOrderStatus`, supprimé en août.

**Couleur primaire (§13) — décision documentée, non appliquée hors client :**

| Rôle | Valeur | Justification |
|---|---|---|
| Marque (logo, illustrations, grands aplats, accents) | `orange500` #E8541F | identité ; sans texte dessus |
| Action (fond de bouton + texte blanc), clair | `orange600` #C8421A | blanc 4.94:1 (orange500 : 3.67:1) |
| Action, sombre | `orange400` + texte `charcoal700` | 6.20:1 (blanc : 2.84:1) |

Constat vérifié : web (`@lilia/design-tokens`, `--lilia-action-primary: orange-500`) et admin (`actionPrimary: orange500`) utilisent la couleur de marque comme couleur d'action ; le livreur utilise `#FF6B00` (~2.9:1 avec du blanc). **Recommandation**, pas de modification dans ces dépôts (chacun sa branche et sa revue) : web et admin → `action-primary: orange-600` en clair ; livreur → aligner sur les tokens.

**Typographie (§14) — règle constatée :** titres d'app bar `Girassol` (marque), `TextTheme` complet en `Oswald`, badges et petits libellés en `Inter`, `Fraunces` (2 usages) pour les titres éditoriaux. `Lora` est embarquée (2 fichiers déclarés, 424 Ko dans le bundle ; 1.5 Mo dans le dossier) mais **utilisée 0 fois**. Proposition (non appliquée : changement visuel global) : Display → Fraunces, Titres/AppBar → Girassol/Oswald, **Body et labels → Inter** (Oswald, condensée, est pénible en corps de texte long), retrait de Lora du `pubspec.yaml` (modifié hors mission — non touché).

**Styles codés en dur (§16)** — sur `lib/` : couleurs Material nommées **373 → 281**, `BorderRadius.circular` **267 → 226**, `Colors.white` **100 → 87**. Restants volontaires et documentés : couleurs d'opérateur MTN/Airtel (marques), textes blancs sur photos/dégradés (indépendants du thème), icônes de la modale d'erreur du checkout.

**Tokens cross-platform (§29)** : `@lilia/design-tokens` se dit « source of truth for web and Flutter » mais le paquet ne contient que `dist/` (pas de source) et le Flutter porte des copies. Proposition : un `tokens.json` source dans `lilia-food-web/packages/design-tokens/src`, un script de génération vers `dist/tokens.css` et `lilia_tokens.g.dart` (copié dans les 3 apps Flutter), `contrast_test` rejoué dans chaque app. **Non implémenté** (§29 : ne pas bloquer la phase).

## Accessibility

| Écran / composant | Correctif | Vérification |
|---|---|---|
| Bouton d'ajout rapide (5 écrans) | 48 px, libellé explicite, nœud sémantique propre (il fusionnait avec la carte parente) | `androidTapTargetGuideline`, `bySemanticsLabel` |
| Sélecteur de formats | radio sémantique, stock annoncé, contraste préservé pour l'épuisé | test widget |
| Checkout | promo 2.3:1 et fidélité 1.35:1 → ≥ 4.5 ; « Requis », avertissement « sur commande », promo appliquée ; tuile fidélité en sombre | `textContrastGuideline`, `contrast_test` |
| Instructions de paiement | bouton « J'ai payé » ≥ 4.5, champs copiables étiquetés | `textContrastGuideline` clair + sombre |
| Commandes (liste + détail) | pastilles libellé + icône + contraste ; stepper lisible, étapes annoncées « terminée / en cours / à venir » | tests dédiés |
| Cartes vendeurs | pastille Ouvert/Fermé : blanc sur green700/red500 + icône (était 2.8/3.7:1) | `contrast_test` |
| Erreurs de chargement | `liveRegion` | — |
| Carrousel | respecte « réduire les animations » | — |
| Fidélité | contraste, solde annoncé en une phrase | `textContrastGuideline` |

**Texte agrandi (§24)** : `test/a11y/text_scaling_test.dart` — 5 composants × 1.0/1.3/1.5/2.0 sur 360 px, **avec les vraies polices** (`test/helpers/real_fonts.dart`). Sans elles, `flutter_test` rend chaque glyphe en carré plein et fabrique de faux débordements (14 échecs artificiels observés, 0 avec les polices réelles). Témoin de débordement vérifié rouge. **Aucun `ellipsis` ajouté pour masquer un problème.**

**Non fait :** TalkBack / VoiceOver sur appareil, navigation clavier, parcours complet Home → Tracking. NON MESURÉ.

## Performance

| Mesure | Avant | Après | Méthode |
|---|---:|---:|---|
| Reconstructions de la liste des vendeurs pendant 13 s d'auto-défilement (30 vendeurs) | **3** (une par bannière) | **0** | `test/perf/home_carousel_rebuild_test.dart`, instances de `RestaurantCard`, sur `home.dart` de HEAD puis actuel |
| Cartes vendeurs construites à l'ouverture (30 vendeurs, ~3 visibles) | 30 | 30 | idem — constat, non corrigé |
| Délai avant affichage d'une erreur (accueil, recherche) | jusqu'à ~38 s | immédiat | tests widget avec relance Riverpod active |
| Vignettes de la fiche vendeur | `NetworkImage` (cache mémoire seul) | `AppCachedImage` (cache disque 30 j) | analyse de code |
| Feedback « ajouté au panier » | déjà optimiste | inchangé | lecture de `CartController._muter` |

Le `shrinkWrap` construit **toutes** les cartes vendeurs (30/30 mesurées). Pas de migration en slivers : aucune mesure de temps de frame sur appareil ne montre de jank, et c'est l'écran le plus fréquenté. À reconsidérer au-delà de ~50 vendeurs actifs ou sur mesure `flutter run --profile`.

**Temps de frame, mémoire, premier rendu, scroll sur appareil : NON MESURÉ** (pas d'appareil dans cette session).

## Tests

| Nouveau fichier | Tests |
|---|---:|
| `test/features/cart/quick_add_test.dart` | 10 |
| `test/features/home/search_screen_test.dart` | 5 |
| `test/features/home/home_screen_states_test.dart` | 5 |
| `test/features/home/vendor_product_card_test.dart` | 5 |
| `test/features/commandes/checkout_order_summary_test.dart` | 5 |
| `test/features/commandes/payment_instructions_dialog_test.dart` | 4 |
| `test/features/commandes/order_status_info_test.dart` | 3 |
| `test/features/commandes/order_detail_cards_test.dart` | 2 |
| `test/features/user/loyalty_card_test.dart` | 6 |
| `test/common_widgets/user_facing_error_message_test.dart` | 5 |
| `test/a11y/text_scaling_test.dart` | 20 |
| `test/perf/home_carousel_rebuild_test.dart` | 1 |
| `test/theme/contrast_test.dart` (étendu) | +15 |

Préexistants (non suivis) conservés : `variant_selector_test.dart`, `product_variant_stock_test.dart`. Aucun test supprimé. Pas de golden tests (§27) : les polices en test ne sont pas celles de l'appareil ; les contrastes et la sémantique sont vérifiés par guidelines, plus robustes.

## Files Changed

**Nouveaux (lib) :** `cart/presentation/quick_add.dart`, `commandes/presentation/widgets/{checkout_order_summary,order_detail_cards,payment_instructions_dialog}.dart`, `home/presentation/widgets/vendor_product_card.dart`, `user/presentation/widgets/loyalty_card.dart`, `utils/async_value_ui.dart`.
**Modifiés par cette phase (lib) :** `common_widgets/{build_error_state,lilia_badge}.dart`, `theme/lilia_tokens.dart`, `commandes/presentation/{checkout_page,commande_detail_page,commande_page,status_info}.dart`, `home/presentation/{home,search_screen,restaurant_detail_screen}.dart`, `home/presentation/widgets/{popular_dishes_section,recommendations_section,product_stock_widgets,section/restaurant_card}.dart`, `cart/presentation/cart_screen.dart`, `favoris/presentation/favoris_detail_page.dart`, `user/user_page.dart`, `models/produit.dart`.
**Tests :** voir ci-dessus + `test/helpers/real_fonts.dart`.

## Pre-existing Changes

### PRE_EXISTING_WORKTREE_CHANGES

Inventaire fait avant toute modification (`git status`, `git diff`). **Rien n'a été reset, checkout, stash, supprimé ou réécrit.**

| Fichier | Nature | Traitement |
|---|---|---|
| `android/app/build.gradle.kts`, `android/gradle.properties`, `android/gradle/wrapper/gradle-wrapper.properties`, `android/settings.gradle.kts` | montées Firebase BoM / Gradle 9.8 / AGP 9.4.1 ; commentaires du migrateur **dupliqués** dans `gradle.properties` | non touchés |
| `ios/Runner/Info.plist` | libellé de localisation reformulé, **ajout de `NSLocationAlwaysAndWhenInUseUsageDescription`** et `UIRequiresFullScreen` | non touché — **fait échouer** `ios_release_config_test` (voir Risks) |
| `macos/Flutter/GeneratedPluginRegistrant.swift`, `pubspec.lock`, `lib/generated/` | générés | non touchés |
| `pubspec.yaml` | version 1.3.4+38, montées de dépendances dont **`sentry_flutter: ^10.0.0-rc.0` (pré-version)** et `go_router ^18` | non touché |
| `lib/main.dart` | `profilesSampleRate` retiré (n'existe plus en Sentry 10 rc) | non touché |
| `lib/features/user/presentation/pages/about_page.dart` | version affichée codée en dur `1.3.3` ≠ `pubspec` `1.3.4` | non touché — signalé |
| Variantes / stock : `models/produit.dart`, `models/menu.dart`, `cart/domain/cart_mutations.dart`, `cart_mutations_test.dart`, `home/presentation/{product_detail_page,menu_detail_page}.dart`, `widgets/product_stock_widgets.dart`, `favoris/…` (3 fichiers), `cart_screen.dart` (bandeau `hasIssues`), `search_screen.dart`, `home.dart`, 2 tests | travail d'une session précédente | **revu comme travail à valider** : validé (menus `variantId`, blocage checkout `hasIssues`, quantité bornée) ; corrigé (repli `json['status']`, présélection Favoris, `ProductStockCard` jamais utilisé → supprimé, `showVariantSelectionSheet` jamais branché → branché) |
| `LILIA_FOOD_UI_UX_IMPLEMENTATION.md`, `LILIA_FOOD_UI_UX_FINAL_REVIEW.md` | rapports d'une session précédente | **remplacés** (livrables demandés) ; texte d'origine conservé en annexe car certaines affirmations sont inexactes (« tous les tests passent ») |

## Remaining Issues

1. `Info.plist` : clé « Always » ajoutée hors mission — test rouge, risque de refus App Store ; décision au propriétaire.
2. `sentry_flutter 10.0.0-rc.0` (pré-version) en production + profiling désactivé.
3. Accueil : construction non paresseuse de toutes les cartes vendeurs (mesurée) ; slivers à décider sur mesure appareil.
4. `cart_screen.dart` (946), `product_detail_page.dart` (979), `menu_detail_page.dart` non découpés.
5. `RecommendationsSection` jamais monté : à brancher ou supprimer (décision produit).
6. 281 couleurs Material nommées restantes, surtout `menu_detail_page`, `driver_tracking_map`, `reviews_screen`, `product_detail_page`, `address_page`.
7. Typographie par rôle et retrait de `Lora` : proposés, non appliqués.
8. Web / admin / livreur : couleur d'action non accessible ; tokens sans source commune.
9. `about_page.dart` : version codée en dur.

## Risks

- **Changement de comportement volontaire :** le visiteur peut désormais ajouter depuis les populaires, la recherche et les suggestions (panier invité). Aligné sur le mode invité existant ; à confirmer produit.
- **Couleurs de statut** changées (intention au lieu de couleur Material) : deux statuts peuvent partager une teinte (Payée/Acceptée, En préparation/En route, Prête/Livrée), distingués par libellé et icône.
- **« N tailles » → « N formats »** sur la fiche vendeur (vocabulaire aligné sur « Choisissez un format »).
- Extraction du détail de commande faite par déplacement mécanique (corps inchangés) puis corrections de couleurs ; couverte par 113 tests commandes, **non vérifiée visuellement sur appareil**.
- Aucun parcours manuel sur appareil (§31) : non effectué.

## Recommended Phase 3

1. Trancher `Info.plist` et Sentry 10 rc avant toute release.
2. Profilage appareil (`--profile`) de l'accueil ; slivers si jank mesuré.
3. Découper `cart_screen` et `product_detail_page` sur le même modèle.
4. Source de tokens commune + correction de la couleur d'action web/admin/livreur.
5. Règle typographique par rôle ; retirer `Lora`.
6. Recherche : historique, suggestions, filtres (P3 de l'audit).
7. Revue TalkBack / VoiceOver du parcours Home → Tracking.

---

<details>
<summary>Annexe — rapport d'implémentation précédent (session antérieure, conservé tel quel)</summary>

# Lilia Food — UI/UX refactor Phase 2

## Portée

Refactor incrémental côté client Flutter. Les règles de stock restent celles du backend : `availableQuantity`, `stockStatus`, `stockConsumption` et `MenuProduct.variantId` sont relayés par les modèles et l’UI. Aucun endpoint ni calcul métier backend n’a été modifié.

## Changements réalisés

### Formats et disponibilité

- `ProductVariant` lit le verdict et la quantité vendable fournis par l’API. Une quantité inconnue reste inconnue ; le client ne calcule pas le stock à partir de `stockConsumption`.
- `VariantSelector` présente le libellé, le prix, la conversion, le statut de stock, le focus visuel et les états accessibles. Les formats épuisés sont désactivés.
- La quantité dans la fiche produit est plafonnée à `availableQuantity` quand cette donnée est fournie. Le panier reste soumis à la validation finale du backend.
- La fiche Favoris réutilise le sélecteur partagé et ne choisit plus le premier format quand plusieurs variantes sont vendables. Son bouton d’ajout respecte aussi le parcours des produits à options.
- Le prix dans la liste Favoris utilise le prix d’appel du modèle et annonce « À partir de » pour plusieurs formats.
- Les variantes et leur statut sont conservés dans la sérialisation locale des Favoris.
- Les menus utilisent le `variantId` configuré pour chaque composant. Le premier format est utilisé uniquement pour un cache historique dépourvu de `variantId` ; un identifiant renseigné mais absent du produit rend l’aperçu non ajoutable.
- Le panier signale les lignes en issue de stock et désactive le passage au checkout tant qu’elles restent présentes.

### Écrans et états

- Les erreurs de recherche passent par `BuildErrorState` et permettent de relancer la requête.
- Les bannières d’accueil disposent d’un fallback graphique local, sans référence à `assets/images/banner.png` qui n’existe pas. Le fallback s’applique aussi à une image distante en échec.
- Le composant `ProductStockCard` est disponible pour les surfaces catalogue qui adoptent le nouveau rendu. Les listes actuelles du restaurant gardent leur composition propre ; la fiche détail montre les statuts précis par variante.

### Compatibilité de dépendance existante

Le `pubspec.yaml` déjà modifié dans le working tree sélectionne `sentry_flutter 10.0.0-rc.0`, où `SentryFlutterOptions.profilesSampleRate` n’existe plus. Cette affectation dans `main.dart` bloquait l’analyse et la compilation des tests. Elle a été retirée ; `tracesSampleRate` et les autres options Sentry restent inchangés. Le profiling Sentry n’est donc plus configuré par l’application avec cette version.

## Découpage de composants

- `lib/features/home/presentation/widgets/product_stock_widgets.dart` : `VariantSelector`, `StockBadge`, `ProductStockCard`, `showVariantSelectionSheet`.
- `lib/features/home/presentation/product_detail_page.dart` : état de sélection, quantité bornée, ajout au panier ; composition UI séparée des règles de validation API.
- `lib/features/home/presentation/menu_detail_page.dart` et `lib/features/cart/domain/cart_mutations.dart` : format de chaque composant de menu.
- `lib/features/cart/presentation/cart_screen.dart` : affichage de l’issue de stock et verrou de checkout.
- `lib/features/home/presentation/search_screen.dart` : rendu d’erreur et reprise de recherche.
- `lib/features/home/presentation/home.dart` : fallback de bannière.
- `lib/features/favoris/presentation/favoris_detail_page.dart` et `favoris_page.dart` : sélection et prix d’appel des Favoris.

## Vérifications

- `flutter analyze` : **aucun diagnostic**.
- `flutter test --reporter=compact` : **tous les tests passent** (758 tests lors du dernier passage complet).
- Tests ciblés après les derniers changements : sélecteur, parsing de stock, mutations et formats de menus — **tous passent** (24 assertions/tests rapportés par le runner).
- `git diff --check` : aucune erreur d’espacement détectée lors de la revue.
- Mesure de performances spécifique à l’accueil : **NON MESURÉE**. Aucune migration vers des slivers ni promesse de gain runtime n’est faite sans profilage sur appareil.
- Parcours manuel sur appareil (variantes, panier, checkout, bannière sans réseau) : **NON EFFECTUÉ** dans cette session.

## Travail préexistant préservé

### Présent dans le working tree avant cette phase

- `android/app/build.gradle.kts`, `android/gradle.properties`, `android/gradle/wrapper/gradle-wrapper.properties`, `android/settings.gradle.kts`.
- `lib/features/user/presentation/pages/about_page.dart`.
- `macos/Flutter/GeneratedPluginRegistrant.swift`.
- `pubspec.yaml`, `pubspec.lock` et `lib/generated/`.

Ces changements n’ont pas été réécrits. Le changement de dépendance Sentry a révélé l’incompatibilité de compilation décrite plus haut.

### Travail antérieur de cette demande, conservé et complété

Le modèle de variantes, l’écran de détail produit, les mutations panier, les modèles/écrans de menu et l’avertissement panier étaient déjà modifiés avant cette phase. `LILIA_FOOD_UI_UX_AUDIT.md` était déjà présent comme livrable d’audit. Ils ont été relus puis prolongés, sans réinitialisation du dépôt.

## Suites conseillées

- Profilage sur appareil Android/iOS de l’accueil avec les tailles de catalogue représentatives avant d’envisager un changement de structure de scroll.
- Parcours manuel réseau dégradé et confirmation du comportement d’indisponibilité lors du checkout.
- Vérifier avec l’équipe si le profiling Sentry doit être restauré via la nouvelle API ou si la désactivation est voulue avec la version `10.0.0-rc.0`.
- Étendre progressivement le nouveau badge aux autres cartes catalogue après validation visuelle sur appareil.

</details>
