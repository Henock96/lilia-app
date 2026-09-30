# Lilia Food — UI/UX Phase 3.7 : Final Gap Closure & Release Gate

**Date :** 29–30/09/2026 · **Référence :** `LILIA_FOOD_UI_UX_PHASE3_IMPLEMENTATION_REPORT.md` (§11 « Problèmes non corrigés »)
**Branches (commitées le 30/09, non poussées) :** `lilia-app` `hmipoka/uiux-phase3-7` · `lilia-food-admin` `hmipoka/uiux-phase3-7` · `lilia_food_delivery` `hmipoka/uiux-phase3-7` (aucune modification) — toutes créées depuis `origin/master`.

---

## 1. Executive Summary

Les six écarts ouverts à la fin de la Phase 3 sont **corrigés et testés** : fiche vendeur en chargement (P3-14), CTA de checkout collant (P3-15), paiement en attente remonté (P3-16), onglets invités (P3-18), `Colors.white` de l'admin, « Plats populaires » hors ligne.

L'instabilité de `cart_optimistic_test.dart` est **reproduite, expliquée et résolue** sans affaiblir le test : l'assertion chronométrée (`< 16 ms` d'horloge murale) est remplacée par une assertion d'ordre déterministe et **plus forte** (elle détecte une régression que l'ancienne laissait passer).

Un parcours **iPhone physique** (installation neuve, visiteur, production en lecture seule) est passé en entier. **Aucun Android physique** ; l'émulateur Android a disparu avant le lancement.

**Aucun changement** backend, Prisma, paiement, permission, statut de commande, API, `Info.plist` ou Gradle ; `pubspec.yaml` ne change que par la déclaration des polices (§3.3). Aucune décision produit n'a été prise.

Tests : `lilia-app` **1020 → 1059**, `lilia-food-admin` **333 → 342**, `lilia_food_delivery` **104** ; 0 échec ; analyses à 0.

---

## 2. Baseline (mesurée le 29/09/2026, avant toute modification)

| Dépôt | Branche / état | `flutter analyze` | `dart analyze` | `flutter test` |
|---|---|---|---|---|
| lilia-app | `origin/master` 5f6e56f (PR #29 Phase 3 mergée) ; non suivi préexistant `lib/generated/` | 0 | 0 | **1020 ✅** (le rapport Phase 3 en annonçait 1019 : le dépôt fait foi) |
| lilia-food-admin | `origin/master` 4755c2a (PR #36 mergée) ; propre | 0 | 0 | **333 ✅** |
| lilia_food_delivery | `origin/master` 213e78e (PR #12 mergée) ; propre | 0 | 0 | **104 ✅** |
| lilia-food-web | `hmipoka/upload-heif`, **4 modifiés + 1 non suivi** (travail HEIF) | non exécuté | — | non exécuté |
| lilia-backend | `hmipoka/upload-heif`, **2 modifiés + 3 non suivis** (travail HEIF) | non exécuté | — | non exécuté |

Web et backend : travail non commité sans rapport — **non touchés** (toujours 5 entrées `git status` chacun à la fin). Aucun `reset`, `clean` ni `stash`.

---

## 3. Correctifs effectués

| ID | Problème | Action | Statut |
|---|---|---|---|
| P3-14 | Fiche vendeur anonyme et sans retour pendant le chargement (et en erreur) | `AppBar` avec retour pendant chargement/erreur, titre = nom **transmis par l'écran d'origine** ; lien profond ⇒ **aucun titre** (le repli inventé `'Votre Restaurant'` du routeur est supprimé de l'affichage). Aucun appel réseau ajouté. | **FIXED** |
| P3-15 | CTA « Valider et payer » en fin de défilement, sans montant | `CheckoutSubmitBar` collante : **même total** que le récapitulatif, `SafeArea`, au-dessus du clavier (`resizeToAvoidBottomInset`), hauteur **minimale** (plus de rognage à 2×), raison affichée quand désactivé (créneau de précommande), indicateur annoncé aux lecteurs d'écran. La page garde seule la garde de double envoi. | **FIXED** |
| P3-16 | Paiement en attente placé sous articles / livraison / total | Pour `EN_ATTENTE` : section de paiement (« Payer maintenant » ou « Paiement en cours ») **sous l'en-tête**, suivie de la bannière « paiement non abouti » (dont le texte dit « ci-dessus »). Aucun autre statut ne change. | **FIXED** |
| P3-18 | Visiteur tapant Commandes/Profil : connexion plein écran, sans onglets, sans support | La coque affiche une **invitation dans l'onglet** (`GuestTabPrompt`) en gardant sa barre : explication, « Se connecter ou créer un compte » (ramène sur l'onglet via `from`), e-mail/appel support, « À propos ». **Règle d'accès inchangée** (voir §3.1). | **FIXED** |
| Admin colors | Blanc sur fonds sous le seuil AA ; indicateurs blancs invisibles | Voir §3.2. | **FIXED** (classement complet) |
| Offline popular dishes | « Plats populaires » disparaissait au lieu de garder sa dernière liste | Liste conservée + `StaleDataBanner` daté (même règle que les vendeurs, P3-12). La section n'a pas de filtre : pas de risque de contexte croisé. Sans liste antérieure ou liste vide ⇒ rien d'inventé. | **FIXED** |
| Test instable | `cart_optimistic_test` « ajout visible AVANT la réponse serveur » | Voir §7. | **FIXED** |
| Polices (découvert en QA) | `google_fonts` : « Inter-SemiBold not found in the application assets » ×7 variantes sur iPhone | Voir §3.3. | **FIXED** |

### 3.1 P3-18 — pourquoi l'invitation vit dans la coque, pas dans le routeur

Première approche tentée : rendre les **racines** `/commandes` et `/profile` publiques dans `protected_locations.dart` avec une garde d'écran. Elle modifiait **17 tests** qui encodent des décisions établies (déconnexion depuis Profil → connexion, 401 → connexion, sortie de l'écran de connexion vers le parent public). C'était une refonte de navigation : **abandonnée et intégralement annulée**.

Retenu : `BottomNavigationPage._goBranch` affiche l'invitation au lieu de naviguer. Le routeur, `resolveRedirect`, la table protégée et leurs 163 tests restent identiques. Piles des onglets préservées (`IndexedStack`), retour Android referme l'invitation, toute navigation du routeur l'efface, une session ouverte l'annule.

Constat au passage : avec `initialLocation: true`, `goBranch` **passe** par `redirect` dans go_router 17 (observé en test), contrairement à ce que dit le commentaire de `_goBranch`, conservé tel quel.

### 3.3 Polices — graisses jamais rendues sur l'appareil

**Cause.** `allowRuntimeFetching = false` et seules les polices **variables** embarquées. `google_fonts` cherche un fichier au nom exact de la variante (`Inter-SemiBold.ttf`) ; introuvable, il retombe sur la famille du `pubspec` (`Inter` variable) **à sa graisse par défaut**. Les 7 variantes du thème (Inter 400/500/600/700, Oswald 400/500/600) n'étaient donc jamais rendues telles que conçues. `Fraunces` a une graisse par défaut de 900, mais son helper `fraunces()` n'est **appelé nulle part** (code mort, laissé).

**Correctif.** Instances statiques **générées localement** depuis les variables déjà embarquées (fontTools : wght 400/500/600/700, Inter à opsz 14), réduites aux plages latines, à la ponctuation (dont U+202F d'`intl`), aux symboles monétaires, aux flèches et aux signes mathématiques ; OFL. Déclarées dans `pubspec.yaml` avec leur graisse ; les variables droites sortent du bundle (Inter italique conservée). Poids : 1,18 Mo de statiques contre 1,05 Mo de variables retirées, **+127 Ko**. Aucun changement de code applicatif.

**Tests.** `test/theme/bundled_fonts_test.dart` (9 tests) : chaque variante demandée est déclarée et présente ; aucune graisse demandée hors bundle. `test/helpers/real_fonts.dart` charge désormais les mêmes statiques que l'appareil. Effet de bord révélé : `loyalty_card_test` « contraste AA » ne passait que parce que la police carrée de `flutter_test` remplissait la zone de blanc. Avec de vrais glyphes, `textContrastGuideline` ne voit que deux teintes du dégradé (1,11:1), ce qui est un faux négatif. Il est remplacé par un calcul exact de chaque texte contre les deux extrémités du dégradé (≥ 4,5:1), vérifié rouge avec l'ancien blanc à 60 %.

**Appareil.** Relancé sur l'iPhone, qui n'était plus relié qu'en **Wi-Fi** : **0 « unable to load font »** au démarrage, contre plus de 20 dès les premiers écrans au passage précédent. En revanche, l'accueil n'a pas fini de charger dans le délai du scénario : le rendu visuel des graisses **reste à vérifier à l'œil** sur appareil.

### 3.2 Admin — classement des 55 `Colors.white`

L'admin ne branche **que** `AppTheme.light` (pas de `darkTheme`).

| Classe | Sites | Traitement |
|---|---|---|
| **Texte/icône sur fond d'action sous le seuil** | gestes vendeur `orderActionLook` : `Colors.green` 2,78:1 (Accepter, Prête), `Colors.red` 3,68:1 (Refuser, Annuler), `Colors.teal` 3,67:1 (Remise) ; `orange[700]` 2,70:1 (détail commande ×2) ; `Colors.orange` 2,16:1 (filtre « aujourd'hui », compteurs) ; `Colors.green`/`red` (paiements, snackbars de gestes) ; `green.shade700` 4,12:1 (incident) ; boutons Paramètres sur `orange500` avec texte gris du thème 2,55:1 ; snackbars succès `green400` 3,13:1 | **Fond corrigé** : `green700` 6,57, `red500` 5,97 (jetons ajoutés, **valeurs du client**), `orange600` 4,94, `teal.shade700` 5,32 ; libellé blanc conservé (intentionnel) |
| **Indicateur de chargement blanc dans un bouton désactivé** | Connexion, création vendeur, bannière, paramètres plateforme, paiements, Paramètres ×5 | Blanc à **1,28–1,94:1** (invisible) → `charcoal700` (9–13:1) |
| **Intentionnel (A)** | icônes blanches sur fonds désormais conformes, `black87` des snackbars (16:1), badge sur `cs.primary` (4,94), icône sur photo produit, définitions de thème/jetons | Conservé |
| **Surface blanche (B)** | carte/AppBar/champs de Paramètres, conteneurs détail commande/paiements, alerte nouvelle commande, incident | **Conservé** : correct en thème clair seul ; à reprendre **si un thème sombre est branché** |

---

## 4. Product Decisions Required

| Sujet | État constaté | Décision attendue |
|---|---|---|
| **Marque** | Apps : orange + Oswald. Web : tomate `#D04C35` + Bricolage Grotesque | Choisir la marque unique — bloque tokens partagés et onboarding |
| **Typographie** | Oswald en corps de texte ; Lora embarquée, **1 seule mention** dans `lib/` (un commentaire) ; Bricolage côté web | Harmonisation éventuelle, après la marque |
| **Permission de notifications** | Demandée au premier lancement (inchangé) | *When should notification permission be requested?* |
| **Numéro de support** | `+242 06 745 46 10` dans `SupportContact` uniquement (réutilisé par l'invitation P3-18, pas de nouveau numéro) | Confirmation par l'exploitation |
| **Onboarding (P3-20)** | Hors marque, contrastes 2,5–2,84:1 | **BLOCKED — BRAND DECISION** |
| **`@lilia/design-tokens`** | `package.json` seul, aucun import ; web avec travail HEIF non commité | Supprimer ou remplir **après** la marque |
| **Orange de l'app livreur** | `#C8421A` depuis la Phase 3 | Validation visuelle |
| **Couleurs des gestes vendeur (admin)** | Vert/rouge/teal assombris pour l'AA (§3.2) | Validation visuelle souhaitée (changement perçu par les vendeurs) |

## 5. Deferred / P2

- **Favoris sur l'accueil** — DEFERRED P2 (7 vendeurs en prod ; données présentes mais intégration non triviale : favoris produits locaux, vendeurs serveur).
- **`RecommendationsSection`** — DEFERRED, données insuffisantes / décision produit ; non montée.
- **Recherches récentes, chip « Ouverts »** — P2, non commencés.
- **Slivers sur l'accueil** — non migré : mesure Phase 3 (iPhone 12 Pro, profile) = 0 frame manquée avec 7 vendeurs ; aucune nouvelle mesure ne justifie un changement.

---

## 6. Tests

| Commande | Avant | Après |
|---|---|---|
| lilia-app `flutter analyze` / `dart analyze` | 0 / 0 | **0 / 0** |
| lilia-app `flutter test` | 1020 ✅ | **1059 ✅** (+39) |
| lilia-food-admin `flutter analyze` / `dart analyze` | 0 / 0 | **0 / 0** |
| lilia-food-admin `flutter test` | 333 ✅ | **342 ✅** (+9) |
| lilia_food_delivery `flutter analyze` / `dart analyze` / `flutter test` | 0 / 0 / 104 | **0 / 0 / 104 ✅** (non modifié) |
| Ciblés (commandes, routage, accueil, panier) après les dernières retouches | — | **480 ✅** |
| web / backend | non exécutés (non modifiés) | non exécutés |

Nouveaux tests — chacun **vérifié rouge sur le code d'origine** sauf mention :

| Fichier | Tests | Preuve de sensibilité |
|---|---|---|
| `test/features/home/restaurant_detail_loading_test.dart` | 3 : nom + retour pendant chargement ; lien profond sans nom inventé ; erreur avec retour | par construction (aucun `AppBar` à HEAD) |
| `test/features/commandes/checkout_submit_bar_test.dart` | 6 : total + tap ; désactivé + raison ; envoi annoncé ; SafeArea ; CTA visible sans défiler **et** après défilement (petit écran) ; même total que le récapitulatif | SafeArea retirée ⇒ rouge |
| `test/a11y/text_scaling_test.dart` | +4 : barre de validation à 1 / 1,3 / 1,5 / 2× sans débordement | — |
| `test/features/commandes/pending_payment_order_test.dart` | 8 : payer avant articles/total ; paiement en cours avant total ; bannière sous le bouton ; 5 statuts sans section de paiement | **3 rouges** sur HEAD, 5 verts des deux côtés |
| `test/routing/guest_tabs_test.dart` | 6 : Commandes dans la coque ; Profil + support + À propos ; connexion ramène ; connecté ; **règle d'accès intacte** ; retour Android | **4 rouges** sur HEAD |
| `test/features/home/popular_dishes_offline_test.dart` | 3 : conservé et daté puis retour en ligne ; premier chargement hors ligne ; liste vide | 1 rouge sur HEAD (le cas corrigé) |
| `lilia-food-admin/test/theme/action_colors_contrast_test.dart` | 9 : chaque geste vendeur, fonds remplacés, filtre inactif, indicateur sur boutons désactivés (et blanc < 3:1 prouvé) | lit les couleurs à la source |

Aucun test supprimé, désactivé ni `skip` ; aucun délai allongé. Modifications de tests existants : `text_scaling_test` (ajout d'un composant) et `cart_optimistic_test` (§7).

---

## 7. Test instability — `cart_optimistic_test.dart`

**Reproduction.** Au calme : 3,4–6,7 ms. Sous charge CPU (10 × `yes`) : 4–12 ms. Sous charge CPU + suite concurrente : 6 / 8,5 / **15,96** / 6,4 / 11,3 / **22,21 ms → échec**. Le panier était pourtant **à jour** : seule l'assertion `lessThan(16)` échouait.

**Cause.** `CartController._muter` applique l'état optimiste **de façon synchrone, avant tout `await`** ; le chronomètre mesurait en plus la préparation synchrone de la requête Dio et la charge de la machine. **Dépendance à l'environnement, pas un bug.**

**Correctif (test seulement, aucun code applicatif).** Le relevé se fait dans le **même tour synchrone** que le tap : quantité = 1 **et** ligne affichée `optimistic-…` (donc pas encore la réponse serveur). Aucune frame ne peut s'intercaler : la promesse « une frame » est prouvée par construction. La mesure reste affichée à titre informatif.

**Preuves.** Régression simulée (mise à jour différée d'une seule micro-tâche, invisible pour l'ancien chronomètre) ⇒ **rouge** « Expected: <1> Actual: <0> — Le panier est à jour dès le tap. » Sous la même charge : 8/8 verts, dont un passage à **27,31 ms** qui aurait échoué avant.

---

## 8. Manual QA

Parcours automatisé **sur iPhone physique** (« Mipoks », iOS 26.5, build debug, production en **lecture seule** : aucune commande, aucun ajout au panier, aucune déconnexion). Test d'intégration temporaire, **supprimé après usage**.

| Test | Résultat | Appareil | Notes |
|---|---|---|---|
| Lancement / onboarding | ✅ | iPhone | installation neuve : onboarding → « Passer » → accueil **sans mur de connexion** |
| Home | ✅ | iPhone | vendeurs chargés depuis la prod, aucune exception |
| Plats populaires | ✅ (en ligne) | iPhone | visible ; le hors-ligne n'est prouvé qu'en test |
| Vendor (P3-14) | ✅ | iPhone | **en-tête « Les Gateaux Gourmands » observé pendant le chargement**, fiche chargée, retour sans exception |
| Guest — Commandes (P3-18) | ✅ | iPhone | invitation **dans la coque**, barre d'onglets visible |
| Guest — Profil / support / À propos | ✅ | iPhone | invitation, support visible, « À propos » ouvert puis refermé |
| Search | non testé | — | |
| Product / variante | non testé | — | |
| Cart / Checkout (P3-15) / Payment | **non testé sur appareil** | — | session visiteur ; aucun paiement réel (règle) — couvert par tests widget |
| Order / pending payment (P3-16) / Tracking / Pickup | **non testé sur appareil** | — | aucune commande sur l'appareil — couvert par tests widget |
| Offline (mode avion) | **non testé** | — | couvert par tests widget |
| Accessibility (VoiceOver / TalkBack) | **non testé** | — | |
| Android | **non testé** | — | aucun appareil physique ; l'émulateur (API 37) s'est fermé avant l'installation (`adb: device 'emulator-5554' not found`) ; l'APK debug a compilé |

---

## 9. Known Limitations

- **Android physique indisponible** ; aucun passage sur émulateur non plus.
- **TalkBack et VoiceOver non testés** : l'accessibilité n'est **pas** « fully validated ».
- **Mode avion réel non testé** (hors-ligne prouvé en test seulement).
- **Parcours connecté, checkout, paiement réel, suivi, retrait : non testés sur appareil.**
- Captures 2× non refaites ; texte agrandi prouvé en test seulement.
- Polices : anomalie `google_fonts` **corrigée** (§3.3), mais le rendu des graisses n'a pas été revu à l'œil sur appareil. Fraunces (helper mort) et Lora (inutilisée) restent embarquées : à trancher avec la typographie.
- Couleurs admin corrigées **sans revue visuelle sur appareil** (contraste calculé et testé seulement).
- Images : le repli ne couvre qu'une variante Cloudinary en échec, pas un original absent (2 photos vendeur en 404, action ops Phase 3).
- ETA : estimation serveur à vol d'oiseau, affichée « environ » — inchangée, non revalidée sur une livraison réelle.
- Release iOS/Android **non buildée** (exige `SENTRY_DSN`, clés Maps et trousseau via `tool/release.sh`) : aucun fichier natif, `Info.plist`, Gradle ni `pubspec` modifié ; `ios_release_config_test` vert ; build debug iOS installé et lancé sur l'iPhone.

---

## 10. Final Release Gate

```text
RELEASE GATE

Code quality:        PASS — diff relu (commentaires et justifications conservés, reformatage limité aux lignes touchées)
Static analysis:     PASS — 0/0 sur les 3 apps
Automated tests:     PASS — 1050 / 342 / 104, 0 échec ; instabilité connue résolue
Regression:          PASS — règles d'accès, redirections (163 tests), garde de double envoi inchangées
UI/UX:               PASS WITH LIMITATIONS — 6 écarts fermés ; parcours connecté non vu sur appareil
Accessibility:       PASS WITH LIMITATIONS — contrastes calculés, texte agrandi et sémantique testés ; VoiceOver/TalkBack non exécutés
Performance:         PASS WITH LIMITATIONS — pas de nouvelle mesure ; mesure Phase 3 : 0 frame manquée
Offline:             PASS WITH LIMITATIONS — prouvé en test, mode avion réel non testé
iOS readiness:       PASS WITH LIMITATIONS — debug installé et parcouru sur iPhone ; release non buildée ; polices corrigées, rendu à revoir à l'œil
Android readiness:   BLOCKED (validation) — aucun appareil ni émulateur exécuté ; APK debug compilé
Manual device QA:    PASS WITH LIMITATIONS — parcours visiteur iPhone complet ; checkout/commande/suivi non vus
Product decisions:   BLOCKED — marque, typographie, permission notifications, numéro support, onboarding, tokens
Known blockers:      aucun blocage de code ; blocages de validation (Android, lecteurs d'écran, parcours connecté)
```

**CRITICAL BLOCKERS**
- Aucun dans le code livré.
- Validation Android absente (appareil ou émulateur) — à lever avant publication Play Store.

**NON-CRITICAL LIMITATIONS**
- VoiceOver/TalkBack, mode avion, parcours connecté et paiement non testés sur appareil.
- Graisses Inter/Oswald désormais embarquées : rendu à revoir à l'œil sur appareil.
- Couleurs admin sans revue visuelle sur appareil ; release non buildée.

**PRODUCT DECISIONS REQUIRED**
- Marque (orange vs tomate) → tokens, onboarding, typographie.
- Moment de la demande de permission de notifications.
- Numéro de support `+242 06 745 46 10`.
- Validation visuelle : orange livreur, couleurs des gestes vendeur admin.

**DEFERRED ITEMS**
- Favoris sur l'accueil (P2), `RecommendationsSection`, recherches récentes, chip « Ouverts », migration slivers (non justifiée).

**Verdict :** le code est **prêt pour une validation humaine** au prochain gate. La release reste conditionnée à une passe Android, à une passe lecteurs d'écran et aux décisions produit ci-dessus.

---

## Annexe — fichiers modifiés

**lilia-app** — modifiés : `commandes/presentation/checkout_page.dart`, `commandes/presentation/commande_detail_page.dart`, `home/presentation/bottom_navigation_bar.dart`, `home/presentation/restaurant_detail_screen.dart`, `home/presentation/widgets/popular_dishes_section.dart`, `routing/app_router.dart`, `pubspec.yaml`, `test/a11y/text_scaling_test.dart`, `test/features/cart/cart_optimistic_test.dart`, `test/features/user/loyalty_card_test.dart`, `test/helpers/real_fonts.dart`. Nouveaux fichiers de police : `assets/fonts/{inter,oswald}/static/*.ttf` (8). Nouveaux : `auth/presentation/guest_tab_prompt.dart`, `commandes/presentation/widgets/checkout_submit_bar.dart`, 6 fichiers de test (dont `test/theme/bundled_fonts_test.dart`), ce rapport. `lib/generated/` : non suivi préexistant, laissé tel quel.

**lilia-food-admin** — `theme/lilia_tokens.dart` (+`green700`, +`red500`), `order_actions_panel.dart`, `order_action_dispatch.dart`, `order_detail_screen.dart`, `restaurant_orders_screen.dart`, `admin_vendors_screen.dart`, `create_restaurant_screen.dart`, `payments_screen.dart`, `platform_settings_screen.dart`, `signin_page.dart`, `banner_form_screen.dart`, `incident_detail_screen.dart`, `settings_screen.dart` ; nouveau test `test/theme/action_colors_contrast_test.dart`.

**lilia_food_delivery / lilia-food-web / lilia-backend** — aucune modification.

Commité le 30/09/2026 sur les branches `hmipoka/uiux-phase3-7` (lilia-app, lilia-food-admin), **non poussé** : en attente de validation humaine.
