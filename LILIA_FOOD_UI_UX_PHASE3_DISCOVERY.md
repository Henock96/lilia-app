# LILIA FOOD — UI/UX Phase 3 : Discovery

**Date :** 2026-09-29 · **Dépôt principal :** `lilia-app` · **Branche :** `feature/apple-auth` · **HEAD :** `40f7bd7`
**Phase :** 3A — Discovery uniquement. **Aucun code produit n'a été modifié.**

> **Conditions de l'audit (à lire avant tout chiffre).**
> - En cours de session, macOS a retiré l'accès au dossier `~/Desktop` (`Operation not permitted` sur `ls`, `Read`, `flutter`, même hors sandbox). Les 5 dépôts ont donc été **clonés depuis GitHub** dans un dossier temporaire. `lilia-app` : même HEAD que la copie locale (`40f7bd7`, vérifié via l'API GitHub) ; seul écart connu : `lib/generated/assets.dart`, non suivi, absent du clone. Les 4 autres dépôts : **branche par défaut** de GitHub (`lilia-backend` `97506d0`, `lilia-food-admin` `23afc75`, `Lilia-food-delivery` `025dbb8`, `lilia-food-web` `b8aefa8`), qui peut différer de vos copies locales.
> - Dans le **clone de mesure uniquement** : fausse clé Maps (`MapsKeys.local.xcconfig`), sinon le build profile iOS s'arrête sur `fatalError` ; harnais de mesure `integration_test/perf_phase3_test.dart` écrit pour l'occasion. Rien de cela n'est dans votre dépôt.
> - L'app installée sur l'iPhone 12 Pro a été **remplacée par un build profile** (même bundle id) : réinstaller depuis TestFlight / App Store.
> - Toute valeur non mesurée est écrite **NOT MEASURED**, avec la raison.

---

## 1. Executive Summary

**Réponse courte à « si Lilia Food était lancée demain à Brazzaville, qu'est-ce qui ferait qu'un utilisateur continue ? »** — la base technique est solide et **fluide sur un iPhone réel** (0 frame manquée sur le scroll de l'accueil, la navigation et le scroll de la fiche vendeur). Ce qui fera partir un utilisateur, ce n'est pas la performance : c'est **la confiance et la clarté aux moments décisifs**.

Les cinq constats qui comptent le plus :

1. **Le prix final surprend.** Le panier affiche « 6 500 FCFA » sans libellé ni mention des frais ; le checkout y ajoute 15 % de service + livraison. Aucun écran avant le checkout ne le dit. (UX DEBT, P1)
2. **Des contradictions visibles.** Un produit d'une boutique **fermée** s'affiche « Disponible » avec un « + » actif sur l'accueil, puis « Boutique fermée » sur sa fiche (`Product.isOrderable` ignore `restaurantIsOpen`). Le badge de notifications compte **tout l'historique local**, jamais « lu ». Les boutons « Nous contacter » / « Assistance téléphonique » **ne font rien** (`onTap: () {}`). (BUG, P1)
3. **Accessibilité réelle en retrait des tests.** Mesuré sur émulateur : **débordement dès 1.5×** du texte (cartes « Plats populaires », prix et « + » masqués à 2.0×), puces de filtre vendeur tronquées. Icône favori à **1,26:1**. En sombre, les **CTA principaux** (« Valider et payer », pastille prix produit, « Commander à nouveau »…) gardent du blanc sur `orange400` : **2,84:1**. (BUG, P1)
4. **Erreurs techniques encore exposées** : ~35 sites affichent `e.toString()` / `'Erreur: $e'` alors que `userFacingErrorMessage()` existe (checkout, panier, adresses, avis, réclamations, options de livraison). (BUG, P1)
5. **Mauvaise connexion : on jette ce qu'on sait.** Coupure réseau sur l'accueil : la liste des vendeurs déjà affichée est **remplacée par l'erreur en ~4 s**, « 0 disponibles », sans dernière donnée connue. Pour Brazzaville, c'est le point produit n°1 après la confiance prix. (UX DEBT, P1)

**Opportunités à fort rendement sans backend** : afficher l'**ETA déjà calculée par le serveur** (aujourd'hui cachée dans l'info-bulle d'un marqueur de carte), une **barre panier persistante** sur la fiche vendeur, la **modale « Vider et ajouter »** pour le conflit de vendeur, l'**accès « Commander à nouveau »** depuis la liste des commandes, les **transformations Cloudinary** (−56 % de poids d'image mesuré).

**Ce qui n'a pas pu être testé sur appareil** : tunnel connecté (checkout → paiement → suivi → fidélité) — il aurait fallu créer un compte et une commande **réels en production** ; aucun compte de test fourni. TalkBack / VoiceOver : **NOT MEASURED**. Android physique modeste : **aucun disponible**.

**Qualité du code** : `flutter analyze` 0 problème ; **911 tests verts, 0 échec** (clone). Build release Android : **échec attendu** (clé Maps absente du clone — garde-fou volontaire du projet). Build IPA release : non lancé ; build **profile** iOS : **réussi et exécuté** sur iPhone 12 Pro.

---

## 2. Current State

### 2.1 Git

| | Valeur |
|---|---|
| Branche | `feature/apple-auth` (poussée, HEAD identique local/distant) |
| Derniers commits | `40f7bd7` Sign in with Apple · `49f866c` merge PR #27 UI/UX Phase 2 · `2775f6f` Phase 2 · F3-11, F3-10, F3-09… |
| Non suivi (local) | `lib/generated/assets.dart` (généré, 25/09) |
| Diff local | aucun fichier suivi modifié (`git status` avant la coupure d'accès) |

**CHANGES EXISTING BEFORE PHASE 3** : `lib/generated/assets.dart` (non suivi). **CHANGES INTRODUCED BY PHASE 3** : aucun dans `lilia-app` ; ce rapport.

### 2.2 Vérification des points déclarés résolus

| Point | Attendu | Constaté | Verdict |
|---|---|---|---|
| `Info.plist` localisation | clé « Always » conservée, reformulée sans promesse d'arrière-plan | `NSLocationAlwaysAndWhenInUseUsageDescription` : « …uniquement lorsque l'application est ouverte… » ; test `ios_release_config_test` adapté et vert | ✅ résolu |
| Sentry | stable 9.30.1 + `profilesSampleRate` | `pubspec.lock` 9.30.1 ; `main.dart:70` `profilesSampleRate = 0.1` | ✅ résolu |

Remarque (nouvelle, **pas** une régression de ces points) : `NSLocationWhenInUseUsageDescription` promet « afficher les restaurants proches » — l'accueil ne trie **pas** par proximité (la destination vient de l'adresse). Formulation à aligner sur l'usage réel (Guideline 5.1.1).

### 2.3 Rapports précédents revalidés

| Affirmation Phase 2 | Revalidation |
|---|---|
| 855 tests verts | **911 verts** aujourd'hui (Apple sign-in et F3 ajoutés depuis) |
| Couleurs Material nommées 373 → 281 | recompté hors `lib/theme/` : **335** (`Colors.x` sauf `transparent`). Méthode différente probablement ; pas de régression démontrable. Top : `menu_detail_page` 25, `commande_detail_page` 23, `restaurant_detail_screen` 21, `product_detail_page` 19, `checkout_page` 17 |
| `about_page.dart` version codée en dur | **toujours** `'1.3.3'` (`about_page.dart:7`) alors que `pubspec` = `1.3.5+39` ; `package_info_plus` est déjà une dépendance |
| `RecommendationsSection` jamais monté | confirmé (seule référence = sa déclaration) |
| Texte agrandi testé (5 composants) | tests verts, **mais** l'appareil montre des débordements sur des composants **non couverts** (cartes populaires, filtre vendeur) |
| `@lilia/design-tokens` « source of truth » | **pire que rapporté** : dans git, le paquet ne contient **que `package.json`** (`dist/` est gitignoré) et **aucun fichier ne l'importe**. Un clone neuf n'a aucun token partagé |
| Harnais `integration_test/perf_test.dart` | **inopérant** sur Flutter 3.47 : (1) `app.main()` rappelé à chaque test → tests 2-7 en échec ; (2) `traceAction` échoue sans `--no-dds` ; (3) sur installation neuve, le `PageView` de l'onboarding est pris pour la home. Aucun chiffre qu'il aurait produit n'est fiable |

---

## 3. Device QA

### 3.1 Matériel réellement utilisé

| Appareil | OS | Écran | Mode | Usage |
|---|---|---|---|---|
| **iPhone 12 Pro** (iPhone13,3) physique, USB | iOS 26.5 | 6.1", 1170×2532 | **profile** | profilage (timelines) |
| Émulateur **Pixel 8** (arm64) | Android 17 (API 37) | 1080×2400, 420 dpi | debug | QA visuelle, texte agrandi, sombre, hors-ligne |
| Android physique | — | — | — | **aucun disponible → NOT MEASURED** |
| iPhone petit format / iPad | — | — | — | NOT MEASURED |

Données de production : **7 vendeurs publics** (6 ouverts) au 29/09 — les paliers 10/30/50/100 vendeurs **ne peuvent pas être reproduits sur données réelles**.

### 3.2 Matrice

| Device | OS | Screen | Text Scale | Theme | Result |
|---|---|---|---:|---|---|
| Pixel 8 (émul.) | Android 17 | 1080×2400 | 1.0 | Light | ✅ lisible ; cœur favori invisible (1,26:1) |
| Pixel 8 (émul.) | Android 17 | 1080×2400 | 1.3 | Light | ✅ aucun débordement sur l'accueil |
| Pixel 8 (émul.) | Android 17 | 1080×2400 | 1.5 | Light | ❌ « BOTTOM OVERFLOWED BY 7 PIXELS » ×3 (plats populaires), « À partir de » coupé |
| Pixel 8 (émul.) | Android 17 | 1080×2400 | 2.0 | Light | ❌ débordement 41 px / 21 px, **prix et « + » masqués**, puces de filtre tronquées verticalement, noms à 1 ligne tronqués |
| Pixel 8 (émul.) | Android 17 | 1080×2400 | 1.0 | Dark | ⚠️ accueil correct ; fiche produit : pastille prix blanc sur `orange400` (2,84:1) |
| iPhone 12 Pro | iOS 26.5 | 1170×2532 | 1.0 | système | ✅ 0 frame manquée (voir §7) |
| iPhone | iOS | — | 1.5 / 2.0 | Dark | **NOT MEASURED** (pas de pilotage tactile de l'iPhone depuis cette session) |

### 3.3 Parcours exécuté sur appareil (invité, Pixel 8)

| Étape | Résultat | Observation |
|---|---|---|
| Premier lancement | ⚠️ | **Permission notifications demandée par-dessus l'onboarding**, avant toute compréhension du produit |
| Onboarding | ⚠️ | accents manquants (« Decouvrez », « reunis », « preferes ») ; palette propre (rose/violet `#D63384`, `#7B2FBE`) hors marque ; « Passer » `grey[500]` = 2,5:1 ; « Suivant » blanc sur `#FF6B35` = 2,84:1 ; ne parle que de « restaurants » |
| Accueil | ✅/⚠️ | chargé en ~3 s ; bannière, populaires, filtres, 7 vendeurs ; icône « réglages » dans la barre de recherche **décorative** (pas un bouton) ; badge « 20+ fois » sans sujet |
| Fiche vendeur | ⚠️ | **~9 s de squelette sans barre, sans retour visible, sans nom** alors que le nom est passé en `extra` ; menu sous le pli (bloc infos = ~40 % de l'écran) ; titre absent de la barre repliée ; favori = **étoile** ici, **cœur** ailleurs |
| Ajout rapide | ✅/⚠️ | ajout direct (format unique) ; retour = snackbar 2 s + badge ; pas d'action « Voir le panier » |
| Conflit de vendeur | ❌ | snackbar d'erreur « une seule boutique à la fois… Videz votre panier » **sans action** |
| Produit boutique fermée | ❌ | « + » actif sur l'accueil ; fiche : « Disponible » (vert) **et** « Boutique fermée » |
| Panier | ⚠️ | vendeur non nommé ; total non libellé, frais non annoncés ; « Standard » affiché pour un format unique |
| Checkout invité | ⚠️ | écran de connexion sans contexte (« pour finaliser votre commande, votre panier est conservé ») ; logo burger ≠ logo de l'app |
| Onglets Commandes / Profil en invité | ⚠️ | connexion plein écran, **barre d'onglets disparue**, aucun accès à « À propos », support, CGU, thème |
| Hors ligne | ❌/✅ | bandeau « Pas de connexion internet » ✅ ; message + « Réessayer » ✅ ; **liste des vendeurs effacée en ~4 s**, « 0 disponibles », carrousel en squelette |
| Retour réseau + Réessayer | ✅ | liste restaurée |
| Checkout → Paiement → Suivi → Livraison/Retrait → Historique → Fidélité | **NOT TESTED** | nécessitait un compte et une commande réels en production |

---

## 4. Complete UX Journey Review (analyse « première seconde » et « zone du pouce »)

| Écran | Compris en 1 s ? | Pourquoi | Pouce |
|---|---|---|---|
| Accueil | Partiellement | on voit « quoi manger » (bannière, populaires) mais **ni où on livre, ni quand, ni qui est ouvert maintenant** ; la liste des vendeurs commence au pli | recherche en haut (OK, geste rare) ; onglets en bas ✅ |
| Recherche | Oui | état vide = une phrase ; **aucune suggestion, catégorie ou historique** | champ en haut (clavier le rapproche) |
| Fiche vendeur | Non (chargement) puis Oui | squelette sans identité ; puis menu sous le pli | « + » à droite ✅ ; pas de CTA panier persistant |
| Fiche produit | Non si boutique fermée | message contradictoire (« Disponible » / « Boutique fermée ») ; « Choisir une variante — Requis » pour 1 seul format | CTA en barre fixe basse ✅ |
| Panier | Oui, sauf le prix | le total n'est pas le prix à payer | CTA bas droite ✅ |
| Checkout | Oui, long | 7 sections empilées ; **« Valider et payer » en bas d'un long défilement**, sans montant sur le bouton | ❌ CTA non collant |
| Détail commande | Partiellement | stepper 4 étapes ; **pour une commande en attente de paiement, la section « Payer » est après le récapitulatif et le reçu** | ❌ action principale loin |
| Suivi | Partiellement | ETA serveur disponible mais **affichée seulement dans l'info-bulle d'un marqueur** | bouton « Suivre » = `GestureDetector` |
| Profil | Oui (connecté) | invité : inaccessible | — |

**Checkout (lecture de code)** : `checkout_page.dart` (1 782 l.) — ordre : récap livraison → téléphone → instructions → promo → fidélité → créneau (précommande) → résumé → paiement → avertissement précommande → CTA → « Enregistrer pour plus tard ». Le bouton est désactivé pour une précommande sans créneau, **sans message sous le bouton**. Titre de section « Resume de la commande » (accent manquant, `checkout_page.dart:367`).

**Suivi de commande (lecture de code)** : `_OrderProgressStepper` (`order_detail_cards.dart:751`) — 4 étapes « Confirmée / En préparation / Prête / En route » :
- `EN_ATTENTE` affiche « Confirmée — en cours » alors que la commande **attend son paiement** ;
- `PAYER` / `ACCEPTEE` : aucune étape « en cours » ;
- **retrait** : le même stepper affiche une étape « En route » qui n'arrivera jamais ;
- pas d'étape « Livrée ».
L'heure « prête vers HH:MM » (`acceptanceLine`, F3-01) existe et est bien affichée ; l'**ETA livreur** (`etaMinutes`, calculée par `tracking.gateway.ts:214`) n'est visible que dans `driver_tracking_map.dart:50`.

**Recommande** : présente (détail commande livrée/annulée), mais : confirmation de 2 s pour un message multi-ligne listant les articles indisponibles ; erreur de conflit détectée par `e.toString().contains('autre restaurant')` (`commande_detail_page.dart:566`) ; pas d'aperçu modifiable ; **absente de la liste des commandes**.

---

## 5. Visual Audit

### 5.1 Hiérarchie & composants

- **Accueil** : titres « Plats Populaires » / « Tous les vendeurs » en Oswald 18 bold, cohérents. État vide « Aucun restaurant disponible » : vocabulaire « restaurant » (marketplace), gris `Colors.grey` fixe, **aucune action** (même quand un filtre est actif).
- **Carte vendeur** : bonne densité (ouvert, type, délai, frais, minimum). Fermé = `Opacity(0.6)` sur toute la carte → **divise le contraste de tous les textes** (même défaut que celui corrigé en Phase 2 sur le sélecteur de formats).
- **Fiche vendeur** : 4 couleurs d'icônes arbitraires (bleu, vert, orange, violet Material) pour Livraison / Frais / Minimum / Horaires ; bouton « Appeler +242066455381 » plus visible que le menu, numéro non formaté.
- **Iconographie favori** : cœur (carte), étoile (fiche vendeur), cœur (fiche produit).
- **Deux `EmptyPlaceholderWidget`** (`common_widgets/` et `home/presentation/widgets/`) ; 404 : « 404 - Page non trouvé ! » sans action.
- **Snackbars** : succès `green500` + blanc = **4,39:1** (sous AA) ; durée 2 s (succès) / 3 s (erreur) — trop court pour les messages multi-lignes (recommande, erreurs).

### 5.2 Typographie (constat)

| Police | Poids embarqué | Usage réel | Rôle constaté |
|---|---:|---|---|
| Oswald | 172 Ko | `TextTheme` **entier** (titres **et corps**) | tout |
| Girassol | 38 Ko | titre d'`AppBar` (1 usage) | marque |
| Inter | 1,78 Mo (regular **+ italic**) | 22 usages / 5 fichiers (badges, nav) | labels |
| Fraunces | 360 Ko | 2 usages / 1 fichier | éditorial |
| Lora | **430 Ko** | **0 usage** | aucun |

Oswald est une condensée : bonne pour titres et prix, **pénible en corps de texte** (descriptions produit, onboarding, CGU). L'italique d'Inter (906 Ko) sert à 7 `FontStyle.italic`.

**Hiérarchie proposée** (ne change pas l'identité, change le corps de texte) :

| Rôle | Police | Justification |
|---|---|---|
| Display / Headline | Oswald 600-700 | identité, déjà partout |
| Title (AppBar) | Girassol | marque, 1 usage |
| Body / Label / Caption | **Inter** | lisibilité longue, accents français, petits écrans |
| Price / Numeric | Oswald 600 **tabular** (`FontFeature.tabularFigures`) | colonnes de prix alignées |
| Éditorial ponctuel | Fraunces | à garder seulement si un usage est assumé |
| — | Lora | **retirer** (−430 Ko) |

### 5.3 Dark mode — couleurs codées en dur (classées)

| Occurrence | Classe | Détail |
|---|---|---|
| Blanc sur `colorScheme.primary` : `checkout_page.dart:431,435`, `product_detail_page.dart:462,819`, `delivery_options_page.dart:209`, `commande_detail_page.dart:466,476`, `order_success_page.dart:67`, `user_page.dart:106,359`, `address_page.dart:87`, `app_update_dialog.dart:261,271`, `lilia_quantity_stepper.dart:54` | **Bug** | 2,84:1 en sombre ; `onPrimary` / `textOnAction` existent |
| `colorScheme.outline` en couleur d'icône/texte (~24 sites, ex. `restaurant_card.dart:189`) | **Bug** | `outline` = `charcoal100` : 1,26:1 sur blanc |
| `Colors.red` + blanc (annuler, « Epuise ») | **Bug** | 3,68:1 ; texte 10 px |
| Couleurs MTN / Airtel | Payment brand | légitime |
| Blanc sur photo + dégradé noir (bannières, carte vendeur) | Image overlay | légitime |
| Palette onboarding (`#FF6B35`, `#D63384`, `#7B2FBE`) | Design-system violation | hors marque, contrastes 2,84–4,5:1 |
| Icônes Material bleu/vert/violet (fiche vendeur, profil) | Token candidate | → teintes de marque ou `onSurfaceVariant` |
| `Colors.grey` en texte (états vides) | Token candidate | → `onSurfaceVariant` |

### 5.4 Localisation / textes

- Accents manquants (chaînes visibles) : « Epuise » ×4 (`search_screen.dart:343`, `recommendations_section.dart:160`, `popular_dishes_section.dart:212`, `cart_screen.dart:920`), « Resume de la commande », « Pas de frais supplementaires », « Commandes enregistrees », « apparaitront », « Parraines », « Recompenses », « des sa premiere commande livree », « Code copie ! », « Veuillez entrer votre numero », onboarding ×3.
- Devise : « FCFA » partout sauf `promo_validation_result.dart:40,42` (« -500 XAF », sans séparateur de milliers) et `liliaFormatPrice` (« XAF », 1 usage).
- Pluriels construits à la main (`article${n>1?'s':''}`) ; « 1 article(s) » dans le panier.
- Données serveur non accentuées (« Eau Minerale Vival ») : hors code, à signaler aux vendeurs.

---

## 6. Accessibility Audit

| Sujet | Constat | Source |
|---|---|---|
| Texte 1.3 | ✅ accueil sans débordement | émulateur |
| Texte 1.5 | ❌ 3 débordements de 7 px (plats populaires) | émulateur, capture `b03_home_1.5` |
| Texte 2.0 | ❌ prix et « + » masqués ; puces filtre (`vendor_type_filter_bar.dart:17`, `height: 40`) tronquées ; cartes populaires à hauteur fixe (`popular_dishes_section.dart:30,61`, `height: 220`) | émulateur, `b01_home_x2` |
| Contraste icône favori | ❌ 1,26:1 (seuil 3:1) | calcul + capture |
| Contraste CTA sombres | ❌ 2,84:1 | calcul + capture `c02_product_dark` |
| Cibles tactiles | cœur favori = 8+20+8 = **36 px** (`GestureDetector`) ; bouton « Suivre la commande » = `GestureDetector` | code |
| Sémantique | 23 `GestureDetector` interactifs ; **1 seul `liveRegion`** (erreurs) : ajout panier, changement de statut, erreur de paiement ne sont **pas annoncés** | code |
| Reduced motion | respecté pour le carrousel ; **pas** pour `fadeSlideIn` / `staggeredIn` (`app_animations.dart`) | code |
| TalkBack / VoiceOver | **NOT MEASURED** — pas d'outil de pilotage du lecteur d'écran dans cette session ; à faire à la main (§14) | — |
| Haptique | 0 `HapticFeedback` dans `lib/` | code |

---

## 7. Performance Measurements

### 7.1 iPhone 12 Pro — mode profile (mesuré)

Harnais : `integration_test/perf_phase3_test.dart` (clone), `flutter drive --profile --no-dds`, invité, données de production (7 vendeurs), 29/09/2026 ~18:50.

| Screen | Metric | Current | Target | Device | Result |
|---|---|---:|---:|---|---|
| Accueil — scroll (12 flings) | frames analysées | 70 | — | iPhone 12 Pro | — |
| Accueil — scroll | build moy. / p90 / p99 / pire | 3,25 / 3,82 / 4,67 / 4,82 ms | < 8 ms (120 Hz) | iPhone 12 Pro | ✅ |
| Accueil — scroll | raster moy. / p99 / pire | 2,32 / 2,78 / 2,81 ms | < 8 ms | iPhone 12 Pro | ✅ |
| Accueil — scroll | frames manquées (build / raster) | **0 / 0** | 0 | iPhone 12 Pro | ✅ |
| Accueil | mémoire GPU moyenne | 136 Mo | — | iPhone 12 Pro | info |
| Accueil | cartes vendeur construites à l'ouverture | 7 / 7 | — | iPhone 12 Pro | = tout (`shrinkWrap`) |
| Navigation onglets (Panier ↔ Accueil ×4) | build moy. / pire ; frames manquées | 1,58 / 8,08 ms ; 0 / 0 | 0 | iPhone 12 Pro | ✅ |
| Fiche vendeur — scroll (8 flings) | build moy. / pire ; frames manquées | 2,95 / 7,33 ms ; 0 / 0 | 0 | iPhone 12 Pro | ✅ *probable* ¹ |
| Fiche vendeur | mémoire GPU moyenne | 177 Mo | — | iPhone 12 Pro | info |
| Démarrage | `main()` → 1re carte vendeur | 2 387 / 2 852 / 2 983 ms (3 passages) | — | iPhone 12 Pro | réseau inclus ² |
| Recherche | saisie → 1er résultat | **NOT MEASURED** | — | — | sélecteur du harnais en échec |

¹ Le harnais n'a pas confirmé l'arrivée sur la fiche (repère sous le pli sur l'écran de l'iPhone) ; la hausse de mémoire GPU (136 → 177 Mo) indique qu'une page image-lourde était affichée. À reconfirmer.
² Ce n'est **pas** un démarrage à froid : le processus et le moteur étaient déjà lancés par le harnais. **Cold start réel, first frame, mémoire process : NOT MEASURED** (`flutter run --profile --trace-startup` non exécuté — iPhone verrouillé au dernier essai).

### 7.2 Latence API de production (depuis le Mac de développement, **pas** depuis Brazzaville)

| Endpoint | 3 essais (s) |
|---|---|
| `GET /vendors?limit=50` | 3,07 · 1,57 · 1,77 |
| `GET /products/popular?limit=20` | 1,82 · 1,24 · 1,63 |
| `GET /products/search?q=poulet` | 1,75 · 1,19 · 1,17 |
| `GET /banners` | 1,21 · 1,07 · 1,10 |

Chaque écran attend **1,1 à 3 s** de réseau avant contenu (cohérent avec la topologie Oregon/Virginie/Le Cap déjà documentée). La perception de rapidité dépend donc des **squelettes et du cache**, pas du rendu.

### 7.3 Images (mesuré sur les URL réelles)

- Aucune transformation Cloudinary dans l'app ; `AppCachedImage` sans `memCacheWidth` (décodage pleine résolution).
- Vignettes vendeurs : jusqu'à 1200×800 (133 Ko) pour une carte de 150 px de haut.
- 11 images « populaires » : **755 Ko en original → 332 Ko** avec `w_480,c_limit,f_auto,q_auto` (**−56 %**). Deux images déjà petites grossissent légèrement (480×640 : 45 → 47 Ko) → utiliser `c_limit` et ne pas agrandir.
- `logo1.jpg` du splash : **1,5 Mo** dans le bundle.

### 7.4 Décision Home / slivers

**Aucun problème mesurable** sur appareil réel avec 7 vendeurs (0 frame manquée, build p99 4,7 ms). Conformément à la règle « no measurable problem → don't touch » : **ne pas migrer en slivers maintenant**. Paliers 30/50/100 : **NOT MEASURED sur appareil** (7 vendeurs en prod) ; Phase 2 a mesuré en test widget que 30/30 cartes sont construites. Recommandation : ajouter au harnais un mode « catalogue simulé » (fixture 100 vendeurs) et **re-mesurer sur un Android d'entrée de gamme** avant toute décision.

---

## 8. App Store / Play Readiness

| Sujet | État | Remarque |
|---|---|---|
| Nom | « Lilia Food » ✅ | |
| Version / build | `1.3.5+39` ✅ ; **À propos affiche 1.3.3** ❌ | `package_info_plus` disponible |
| Orientation | portrait ; `UIRequiresFullScreen` ✅ | iPad : portrait + upside-down |
| Permissions | localisation (WhenInUse + Always reformulée) ✅ ; notifications demandées **au 1er lancement** ⚠️ | demander après la 1re commande |
| Photos (`image_picker`, galerie) | pas de `NSPhotoLibraryUsageDescription` | PHPicker ne l'exige pas, mais **à vérifier** dans les e-mails ITMS de la dernière soumission |
| Suppression de compte | ✅ présente (`user_page.dart:305`) | |
| Sign in with Apple | ✅ (HEAD) | |
| Support | ❌ boutons contact **inertes** (`about_page.dart:139,147`) ; profil inaccessible aux invités | un reviewer qui cherche le support ne le trouve pas |
| Contenu | un vendeur public s'appelle **« Le Cyprien Bar à Vin »** alors que le lancement exclut l'alcool | vérifier catalogue et classification d'âge |
| `flutter analyze` | ✅ 0 problème | exécuté (clone) |
| `flutter test` | ✅ 911 / 911 | exécuté (clone) |
| `flutter build apk --release` | ❌ échec **attendu** : « Clé Google Maps absente » | garde-fou du projet ; à relancer sur votre poste |
| `flutter build appbundle` / `ipa` | **NOT RUN** | idem + `tool/release.sh` recommandé |
| Build profile iOS | ✅ installé et exécuté sur iPhone 12 Pro | |

**Parcours reviewer simulé** : Install → **pop-up notifications immédiat** → onboarding (fautes) → accueil ✅ → navigation ✅ → « Commandes »/« Profil » = mur de connexion sans explication → compte → commande → **paiement MoMo réel requis** (le reviewer ne peut pas payer) → suivi. Le principal risque de rejet n'est pas l'UI mais l'absence de **compte démo + commande de démonstration** ou d'un mode de paiement test documenté dans les notes App Review.

---

## 9. Cross-Platform Design-System Audit

| Token | Client (Flutter) | Admin (Flutter) | Delivery (Flutter) | Web client | Desired |
|---|---|---|---|---|---|
| Marque | `orange500` #E8541F | #E8541F | **#FF6B00** | **tomate #D04C35** | **décision marque unique** |
| Action (fond bouton, clair) | `orange600` #C8421A (4,94:1) | `orange500` (3,67:1) | #FF6B00 (2,86:1) | `--action-primary` #D04C35 (4,41:1) | ≥ 4,5:1 partout |
| Action (sombre) | `orange400` + texte `charcoal700` (6,2:1) | `orange400` (texte ?) | — | pas de mode sombre client | idem client |
| Texte secondaire muet | `charcoal450` #6E665F | `charcoal400` #7A726A (4,36:1) | #9E9E9E | `--text-muted` #A79C92 (**2,47:1**) | ≥ 4,5:1 |
| Succès / attention / danger (texte) | green700 / amber700 / red500 | green400 / amber400 / red400 | Material 4CAF50 / FFC107 / F44336 | #0F7B4A / #A96A00 / #B3261E | tokens « texte » ≠ « remplissage » |
| Fond | cream100 #FAF5EE | #FAF5EE | #F8F8F8 | #FDF4E8 | une crème |
| Display | Oswald | Oswald | Poppins | **Bricolage Grotesque** | une famille titre |
| Body | Oswald | Oswald | Poppins | Inter | **Inter** |
| Spacing | 4/8/12/16/20/24/32/40/48 (58 usages de `LiliaSpacing` pour 367 `EdgeInsets`) | copie | aucun | Tailwind | échelle 4 pt partagée |
| Radius | 8/12/16/20/28/pill (28 usages de `LiliaRadius` pour 227 `circular`) | copie | locaux | `--radius-pill` | idem |
| Ombres | locales | locales | locales | `--shadow-sm/md/lg` | reprendre le web |
| Statuts commande | `orderStatusInfo()` + `LiliaBadge` | propre table | propre table | propre table | vocabulaire unique (libellés) |

**Constat majeur** : ce n'est plus une divergence de nuance. **Le web client a changé de marque** (rouge tomate + Bricolage Grotesque), l'app client est orange + Oswald, le livreur orange vif + Poppins. Un client qui passe du site à l'app voit deux produits.

### Source de vérité des tokens — options

| Option | Contenu | Avantages | Risques | Coût |
|---|---|---|---|---|
| A — centralisation complète | `tokens.json` → CSS + Dart générés, CI de dérive | une seule vérité, contrastes testés une fois | outillage à maintenir ; 4 dépôts séparés (pas de monorepo commun) → copie des artefacts | 3-5 j + maintenance |
| **B — tokens partagés partiellement** | JSON des **couleurs sémantiques + échelle typo** seulement, script Dart → `lilia_tokens.g.dart` copié dans les 3 apps Flutter, CSS écrit à la main mais vérifié par test de contraste | couvre 80 % du risque (couleurs d'action, texte muet) | discipline de copie | **1-2 j** |
| C — harmoniser sans générer | corriger à la main admin/livreur/web ; `contrast_test` dupliqué | immédiat | la dérive reviendra | 0,5-1 j |

**Recommandation : C maintenant, B ensuite — mais d'abord trancher la marque** (orange ou tomate). Générer des tokens avant cette décision ne ferait que figer l'incohérence. Supprimer ou remplir `packages/design-tokens` (aujourd'hui trompeur).

---

## 10. Remaining Technical UX Debt

### 10.1 Tableau final des problèmes

Catégorie : **A = BUG**, **B = UX DEBT**.

| ID | Cat. | Area | Problem | Evidence | User Impact | Technical Impact | Priority | Recommendation |
|---|---|---|---|---|---|---|---|---|
| P3-01 | A | Catalogue | Produit d'une boutique fermée présenté « Disponible » avec « + » actif | `produit.dart:158` (`isOrderable` sans `restaurantIsOpen`) ; captures `c02`, `a05` | Ajout puis refus, confiance | Règle d'affichage dispersée | **P1** | Intégrer `restaurantIsOpen == false` au verdict d'affichage (badge + bouton), pas au modèle métier serveur |
| P3-02 | A | Accessibilité | Débordement ≥ 1.5× sur cartes populaires, puces filtre tronquées | `popular_dishes_section.dart:30,61` ; `vendor_type_filter_bar.dart:17` ; `b01`, `b03` | Prix / « + » invisibles | Hauteurs fixes | **P1** | Hauteur dérivée du `TextScaler` ; étendre `text_scaling_test` à ces 2 composants |
| P3-03 | A | Dark mode | Blanc sur `primary` (2,84:1) sur ~14 sites dont le CTA de paiement | §5.3 | CTA de paiement peu lisible | Contournement du token `textOnAction` | **P1** | `onPrimary` ; test de contraste sur `checkout_submit` en sombre |
| P3-04 | A | Accessibilité | `outline` (1,26:1) en couleur d'icône/texte, ~24 sites | `restaurant_card.dart:189` ; capture `a06` | Favori invisible | Confusion bordure/texte | **P1** | `onSurfaceVariant` ; lint maison ou test |
| P3-05 | A | Erreurs | ~35 sites affichent `e.toString()` / `'Erreur: $e'` | `grep` §16 : checkout 1085/1145, cart_screen ×5, address_page ×5, delivery_options 171/182, reviews, claims, draft_orders, notifications | Texte technique | `userFacingErrorMessage` contourné | **P1** | Faire passer `showErrorSnack` et les états d'erreur par `userFacingErrorMessage` |
| P3-06 | A | Support | « Nous contacter » / « Assistance » inertes | `about_page.dart:139,147` | Aucun recours | — | **P1** | `mailto:` / `tel:` / WhatsApp (`url_launcher` déjà là) |
| P3-07 | A | Notifications | Badge = nombre total d'historique local, jamais « lu » | `home.dart:178` ; `notification_providers.dart` | Badge permanent, ignoré | Pas d'état « lu » | **P2** | Compteur « non lues » local (timestamp de dernière ouverture) |
| P3-08 | A | À propos | Version `1.3.3` codée en dur (pubspec 1.3.5) | `about_page.dart:7` | Support confus | — | **P2** | `PackageInfo` |
| P3-09 | A | Suivi | Stepper faux pour `EN_ATTENTE`, `PAYER`, `ACCEPTEE` et pour le **retrait** | `order_detail_cards.dart:751-790` | Statut mal compris | — | **P1** | Stepper dépendant du mode (livraison/retrait) et des 7 statuts |
| P3-10 | A | Textes | Accents manquants (~15 chaînes), devise « XAF » dans la promo | §5.4 | Finition | — | **P2** | Correction + test de balayage des chaînes |
| P3-11 | B | Prix | Total panier non libellé, frais (15 % + livraison) annoncés seulement au checkout | `cart_screen.dart:241` ; capture `a11` | Surprise au paiement | — | **P1** | « Sous-total » + ligne « frais de service et livraison calculés à l'étape suivante » (ou estimation serveur si disponible) |
| P3-12 | B | Hors-ligne | Liste effacée à la coupure ; pas de dernière donnée connue | captures `d01`, `d02` | Écran vide à Brazzaville | `whenUi` montre l'erreur au lieu de la valeur précédente | **P1** | Garder `value` précédente + bandeau « hors ligne, données de HH:MM » |
| P3-13 | B | Panier | Conflit de vendeur = message sans action | `cart_mutations.dart:105` ; capture `c03` | 4 gestes pour changer de vendeur | — | **P1** | Réutiliser le pattern `CartModeConflictDialog` (« Vider et ajouter ») |
| P3-14 | B | Fiche vendeur | Squelette sans barre/retour/nom pendant ~9 s | capture `a07` | Sensation de blocage | — | **P2** | Afficher `restaurantName` (extra) + bouton retour pendant le chargement |
| P3-15 | B | Checkout | CTA « Valider et payer » en fin de défilement, sans montant | `checkout_page.dart:400-440` | Effort, doute sur le montant | — | **P2** | Barre CTA collante « Payer 8 475 FCFA » |
| P3-16 | B | Détail commande | Paiement en attente placé sous récap/reçu | `commande_detail_page.dart:249` | Action principale cachée | — | **P2** | Remonter `_PaymentSection` sous l'en-tête quand `EN_ATTENTE` |
| P3-17 | B | Permissions | Notifications demandées au 1er lancement | capture `a01` | Refus probable → pas de suivi push | — | **P2** | Demander après la 1re commande (« pour suivre votre commande ») |
| P3-18 | B | Invité | Commandes/Profil = connexion plein écran, sans contexte, sans onglets | captures `c04`, `c05` | Mur ; support et CGU inaccessibles | — | **P2** | Écran invité dans l'onglet (« Connectez-vous pour… » + À propos/Support) |
| P3-19 | B | Snackbars | 2 s / 3 s pour des messages longs ; succès 4,39:1 | `snackbar.dart` | Messages ratés | — | **P2** | Durée proportionnelle, `green700` |
| P3-20 | B | Onboarding | Accents, palette hors marque, contrastes 2,5–2,84:1 | `onboarding_screen.dart:23-47,127` | Première impression | — | **P2** | Tokens + textes « marketplace » |
| P3-21 | B | Images | Pas de transformation Cloudinary ni `memCacheWidth` | §7.3 | Data mobile, mémoire Android | −56 % possible | **P2** | Helper d'URL par usage (thumb/card/detail/full) |
| P3-22 | B | Recommande | Absente de la liste ; succès 2 s ; erreur par `contains` | `commande_detail_page.dart:530-570` | Fidélisation sous-exploitée | Fragilité | **P2** | Voir opportunités A/E |
| P3-23 | B | Design system | 4 identités visuelles ; `@lilia/design-tokens` vide dans git | §9 | Incohérence marque | Dérive | **P2** | Décision marque puis option C→B |
| P3-24 | B | Typo | Oswald en corps de texte ; Lora inutilisée (430 Ko) | §5.2 | Lisibilité | Poids bundle | **P3** | Inter pour body/label ; retirer Lora |
| P3-25 | B | Harnais perf | `perf_test.dart` inopérant (3 causes) | §2.3 | — | Mesures impossibles / fausses | **P2** | Porter les correctifs du harnais Phase 3 dans le dépôt |
| P3-26 | B | Animations | `fadeSlideIn`/`staggeredIn` ignorent « réduire les animations » | `app_animations.dart` | Confort vestibulaire | — | **P3** | `MediaQuery.disableAnimationsOf` dans l'extension |
| P3-27 | B | Permissions iOS | `NSLocationWhenInUse…` promet « restaurants proches » | `Info.plist` | Écart déclaratif | Guideline 5.1.1 | **P3** | Aligner la phrase sur l'usage (adresse de livraison) |

### 10.2 Gros fichiers (§38)

| Fichier | Lignes | Responsabilités | Découper ? |
|---|---:|---|---|
| `checkout_page.dart` | 1 782 | promo, fidélité, créneau, téléphone, paiement, garde d'envoi | **Oui, ciblé** : extraire `_buildPromoSection`, `_buildPreorderSlotPicker`, `_buildPaymentSection` en widgets → testabilité du CTA collant (P3-15) |
| `delivery_options_page.dart` | 1 255 | mode, quartier, adresse, géoloc | Non tant que P3-05 n'y est pas corrigé |
| `product_detail_page.dart` | 988 | galerie, options, formats, quantité, CTA, blocage | **Oui, 1 extraction** : `_blockedReason` + badge → une fonction pure testée (corrige P3-01 une seule fois) |
| `cart_screen.dart` | 946 | lignes, menus, suggestions, résumé | **Oui, 1 extraction** : pied de panier (P3-11) |
| `menu_detail_page.dart` | 569 | — | Non (taille raisonnable) ; seulement ses 25 couleurs |

Ne pas découper pour réduire des nombres de lignes.

---

## 11. New UX Feature Opportunities (catégorie C — PRODUCT OPPORTUNITY)

| Feature | User Problem | UX Solution | Benefit | Complexity | Backend Needed | Risk | Priority | Phase |
|---|---|---|---|---|---|---|---|---|
| F. ETA claire | « Quand est-ce que ça arrive ? » | « Arrivée estimée ~12:40 » dans l'en-tête de commande + « Prête vers » déjà là | Moins d'appels au support | Faible | **Non** (`etaMinutes` émis par WS) | ETA fausse si GPS livreur bruité → afficher une fourchette | **P1** | 3.6 |
| G. Timeline | Stepper faux (P3-09) | Timeline par mode : livraison (6 étapes) / retrait (4 étapes) avec heures | Compréhension | Moyenne | Non (horodatages `paidAt`, `acceptedAt`…) — **à vérifier** champ par champ | — | **P1** | 3.1 |
| I. Clarté prix panier | Surprise de 15 % | Sous-total + frais annoncés ; total estimé si `CheckoutEstimate` peut être appelé plus tôt | Confiance, conversion | Faible | Non (texte) / Peut-être (estimation) | — | **P1** | 3.1 |
| Barre panier persistante (vendeur) | Pas de chemin visible vers le panier | « Voir le panier · 2 articles · 7 500 FCFA » en bas de la fiche vendeur | Moins de navigation | Faible | Non | Chevauchement avec la nav | **P1** | 3.6 |
| A. Quick Reorder | Recommande enfouie | « Commander à nouveau » sur les cartes de la liste + feuille de confirmation modifiable | Rétention | Moyenne | Non (`/orders/:id/reorder` existe) | Stock changé → réutiliser les raisons F3-10 | **P1** | 3.6 |
| M. Aide contextuelle | Aucun recours joignable | « Besoin d'aide ? » sur commande/paiement/retrait → WhatsApp/appel avec n° de commande pré-rempli | Confiance | Faible | Non | Charge support | **P1** | 3.1 |
| L. Trust | « Est-ce ouvert ? combien ? quand ? » | Ouvert/fermé cohérent (P3-01), frais, ETA, politique d'annulation près du bouton payer | Conversion | Faible | Non | — | **P1** | 3.1 |
| Offline « dernière donnée connue » | Écran vide hors réseau | Liste conservée + horodatage + images en cache | Usage réel à Brazzaville | Moyenne | Non | Données périmées (prix) → le serveur arbitre au checkout | **P1** | 3.4 |
| B. Favoris | Existe (vendeurs + produits) | Rendre visibles : section « Vos favoris » sur l'accueil si ≥ 1 | Accès rapide | Faible | Non | — | **P2** | 3.6 |
| E. « Vos habitudes » | Recommande invisible | Rangée « Commander à nouveau » sur l'accueil (3 dernières commandes livrées) | Rétention | Faible-moyenne | Non (`/orders/my`) | Plafonné à 10 commandes (connu) | **P2** | 3.6 |
| Recherche : suggestions | État vide stérile | Types de vendeur en chips + 5 recherches récentes (local) | Découverte | Faible | Non | — | **P2** | 3.6 |
| Recherche : tolérance aux fautes | « poulé » ≠ « poulet » | Recherche insensible aux accents / trigrammes | Résultats | Moyenne | **Oui** (`contains` Prisma, pas d'`unaccent`) | Perf DB | **P3** | plus tard |
| Q. Filtre « Ouvert maintenant » | 1 vendeur fermé sur 7 | Chip « Ouverts » + tri ouverts d'abord | Moins de déception | Faible | Non (`isOpen` présent) | — | **P2** | 3.6 |
| N. Notifications utiles | Demande au mauvais moment (P3-17) | Demander après commande ; 5 événements max ; pas de marketing | Opt-in | Faible | Non | — | **P2** | 3.2 |
| O. Fidélité | Déjà clarifiée (Phase 2) | Solde visible au checkout avant l'étape paiement | Usage des points | Faible | Non | — | **P3** | 3.6 |
| P. Parrainage | Code copiable, **pas de bouton Partager** | « Inviter un ami » → `share_plus` (déjà dépendance) avec message + code | Acquisition | Faible | Non | — | **P2** | 3.6 |
| C. Récemment consultés | — | Rangée locale | Faible (7 vendeurs) | Faible | Non | Bruit | **P3** | plus tard |
| D. Smart Home | — | Tri par heure / historique | Faible tant que le catalogue est petit | Moyenne | Partiel | Feature creep | **P3** | plus tard |
| J. Progression checkout | 3 écrans + auth | Indicateur « Panier › Livraison › Paiement » | Moyen | Faible | Non | — | **P3** | 3.6 |
| K. Adresses Maison/Travail | Existe partiellement | Libellés + sélection rapide au checkout | Moyen | Moyenne | **À vérifier** (champ `label` ?) | — | **P3** | plus tard |
| H. Pickup guidé | Carte retrait + code existent | Bouton « Itinéraire » vers le vendeur | Moyen | Faible | Non | — | **P3** | 3.6 |
| R. Promotions | Bannières + offre boutique F3-11 | Ne pas ajouter de surface ; badge offre déjà présent | — | — | — | Bannières partout | **Ne pas faire** | — |
| `RecommendationsSection` | — | **Activate later / Redesign** : endpoint authentifié basé sur l'historique ; avec 7 vendeurs et peu d'historique, valeur faible. La remplacer par « Commander à nouveau » (E), qui utilise les mêmes données de façon explicite | — | — | Non | Code mort | **Supprimer après E** | 3.6 |

---

## 12. Micro-interactions Opportunities

| Proposition | UX benefit | Complexity | Risk | Priority |
|---|---|---|---|---|
| Snackbar « Ajouté » avec action « Voir le panier » | chemin direct | Faible | — | P1 |
| Pulsation du badge panier à l'ajout (respectant reduced motion) | feedback sans lire | Faible | distraction | P2 |
| `HapticFeedback.lightImpact` à l'ajout / confirmation de commande | confirmation tactile | Faible | batterie négligeable | P2 |
| CTA checkout collant avec montant | confiance | Faible | — | P1 |
| Annonce `SemanticsService.announce` à l'ajout et au changement de statut | lecteur d'écran | Faible | — | P1 |
| Durée de snackbar ∝ longueur | lisibilité | Faible | — | P2 |
| « Copié ! » avec icône pour code parrainage / référence paiement | feedback | Faible | — | P3 (existe partiellement) |
| Undo après « Supprimer l'article » | erreur réversible | Moyenne | sync panier optimiste | P3 |
| Pull-to-refresh sur la liste de commandes | existe (`commande_page`) | — | — | ✅ |
| Animations d'entrée en cascade | déjà là ; ajouter respect reduced motion | Faible | — | P3 |

---

## 13. Recommended Implementation Roadmap (Phase 3.1 → 3.7)

Chaque sous-phase = une branche, une PR, tests verts, `boot-smoke`.

### 3.1 — Critical UX fixes
- **Files** : `models/produit.dart` (verdict d'affichage, pas le métier), `home/.../popular_dishes_section.dart`, `product_detail_page.dart` (`_blockedReason` + badge), `about_page.dart`, `cart/presentation/cart_screen.dart` (pied), `utils/snackbar.dart`, `common_widgets/build_error_state.dart`, ~12 fichiers pour `e.toString()`, `order_detail_cards.dart` (stepper), `commande_detail_page.dart`.
- **Changes** : P3-01, P3-05, P3-06, P3-08, P3-09, P3-11, aide contextuelle (M).
- **Dependencies** : décision produit sur le texte des frais ; numéro/WhatsApp support.
- **Tests** : `product_display_verdict_test` (fermé ⇒ pas de « + », pas de « Disponible ») ; `order_progress_stepper_test` (7 statuts × 2 modes) ; test qu'aucun `showErrorSnack` ne reçoit un `DioException` brut ; `about_page_version_test`.
- **Risks** : régression d'ajout pour des vendeurs dont `restaurantIsOpen` est `null` → `null` = pas de blocage (le serveur arbitre).
- **Rollback** : revert de PR ; aucune donnée persistée.

### 3.2 — Device UX fixes
- **Files** : `restaurant_detail_screen.dart` (chargement avec nom), `checkout_page.dart` (CTA collant), `commande_detail_page.dart` (ordre des sections), `cart_mutations.dart` + `cart_mode_conflict_dialog.dart` (conflit vendeur), `notification_service.dart` (moment de la demande), `onboarding_screen.dart`, écran invité des onglets.
- **Tests** : widget tests de chaque écran ; `navigation_flow_test` invité ; test « la permission n'est pas demandée avant la 1re commande ».
- **Risks** : décalage de la demande de permission → moins d'opt-in au début ; mesurer.
- **Rollback** : revert.

### 3.3 — Accessibility
- **Files** : `popular_dishes_section.dart`, `vendor_type_filter_bar.dart`, ~14 sites blanc-sur-primary, ~24 sites `outline`, `restaurant_card.dart` (cible 48 px), `app_animations.dart`, snackbars.
- **Tests** : étendre `test/a11y/text_scaling_test.dart` aux 2 composants ; `textContrastGuideline` en sombre sur checkout, fiche produit, détail commande ; `androidTapTargetGuideline` sur la carte vendeur.
- **Manuel** : TalkBack (Pixel) + VoiceOver (iPhone) sur Accueil → Produit → Panier → Checkout, liste de contrôle §18.
- **Rollback** : revert.

### 3.4 — Performance
- **Files** : `common_widgets/app_cached_image.dart` (`memCacheWidth` selon taille affichée), helper `cloudinary_url.dart` (thumb 240 / card 480 / detail 1080 / full), `home.dart` (conservation de la dernière valeur hors-ligne), `integration_test/perf_test.dart` (correctifs du harnais), `assets/images/logo1.jpg` (recompressé).
- **Tests** : test unitaire du helper d'URL (n'agrandit pas, préserve les URL non-Cloudinary) ; harnais profile sur **Android d'entrée de gamme** avec fixture 100 vendeurs ; `home_offline_keeps_last_value_test`.
- **Risks** : URL transformées non mises en cache CDN au 1er appel (latence ponctuelle) ; images non-Cloudinary.
- **Rollback** : désactiver le helper (retour URL brute).

### 3.5 — Cross-platform consistency
- **Pré-requis** : **décision de marque** (orange vs tomate).
- **Files** : `lilia-food-admin/lib/theme/lilia_tokens.dart` (actionPrimary, charcoal450, textes feedback), `Lilia-food-delivery/lib/utilities/app_theme.dart`, `lilia-food-web/apps/*/app/globals.css` (`--action-primary`, `--text-muted`), `packages/design-tokens` (remplir ou supprimer).
- **Tests** : `contrast_test` copié dans admin et livreur ; test CSS (script) des paires de contraste web.
- **Rollback** : par dépôt.

### 3.6 — High-value UX improvements
- ETA (F), barre panier vendeur, Commander à nouveau depuis la liste + rangée accueil (A/E), partage parrainage (P), chips « Ouverts » (Q), recherche : chips + historique local, suppression de `RecommendationsSection`.
- **Tests** : un widget test par fonctionnalité + contrat analytics inchangé (`analytics_contract_test`).
- **Risks** : feature creep → une PR par fonctionnalité, chacune justifiée par un problème du §11.

### 3.7 — Final release QA
- `flutter analyze`, `flutter test`, harnais profile iPhone + Android, `tool/release.sh android|ios`, parcours manuel connecté **avec un compte de test et un mode de paiement test**, notes App Review (compte démo), vérification des e-mails ITMS.

---

## 14. Risk Matrix

| Risque | Probabilité | Impact | Mitigation |
|---|---|---|---|
| Rejet App Review : reviewer ne peut pas payer / pas de support joignable | Moyenne | Élevé | compte démo + notes ; P3-06 |
| Abandon au checkout (frais surprise) | Élevée | Élevé | P3-11, CTA avec montant |
| Désinstallation sur réseau instable | Élevée (Brazzaville) | Élevé | P3-12 |
| Régression visuelle en corrigeant ~40 sites de couleur | Moyenne | Moyen | tests de contraste avant correction, lot par écran |
| Décision de marque différée → tokens figés dans l'incohérence | Moyenne | Moyen | trancher avant 3.5 |
| Mesures perf non représentatives (7 vendeurs, iPhone haut de gamme) | Élevée | Moyen | fixture 100 vendeurs + Android d'entrée de gamme |
| Vendeur « Bar à vin » en ligne malgré la politique sans alcool | Présent | Moyen (classification d'âge) | revue catalogue |

---

## 15. Definition of Done (Phase 3)

- **UX** : aucun écran ne contredit un autre (ouvert/fermé, disponible) ; prix final annoncé avant le checkout ; aucune erreur technique visible (test) ; statut de commande correct pour les 7 statuts × 2 modes ; aide joignable depuis commande/paiement/retrait.
- **UI** : 0 blanc-sur-primary, 0 `outline` en texte/icône ; accents corrigés ; devise unique « FCFA ».
- **Accessibilité** : Accueil, Produit, Panier, Checkout, Détail commande sans débordement à 2.0× (test + capture appareil) ; cibles ≥ 48 px ; annonces lecteur d'écran à l'ajout et au changement de statut ; parcours TalkBack + VoiceOver faits et consignés.
- **Performance** : harnais du dépôt réparé ; mesures profile iPhone **et Android d'entrée de gamme** ; 100 vendeurs simulés ; images redimensionnées (−50 % d'octets sur l'accueil).
- **Cross-platform** : marque tranchée ; action ≥ 4,5:1 sur les 4 clients ; `design-tokens` rempli ou supprimé.
- **Release** : analyze 0, tests verts, `tool/release.sh` android + ios réussis sur votre poste, `boot-smoke.sh` vert.

---

## 16. Exact Files to Modify

**lilia-app** — `lib/models/produit.dart` · `lib/features/home/presentation/{home.dart,product_detail_page.dart,restaurant_detail_screen.dart,search_screen.dart}` · `lib/features/home/presentation/widgets/{popular_dishes_section.dart,vendor_type_filter_bar.dart,recommendations_section.dart (suppression),section/restaurant_card.dart}` · `lib/features/cart/presentation/{cart_screen.dart,cart_mode_conflict_dialog.dart,draft_orders_screen.dart}` · `lib/features/cart/domain/cart_mutations.dart` · `lib/features/commandes/presentation/{checkout_page.dart,commande_detail_page.dart,commande_page.dart,delivery_options_page.dart,order_success_page.dart}` · `lib/features/commandes/presentation/widgets/{order_detail_cards.dart,pickup_card.dart}` · `lib/features/address/presentation/pages/address_page.dart` · `lib/features/reviews/presentation/screens/{reviews_screen.dart,write_review_screen.dart}` · `lib/features/claims/presentation/{my_claims_page.dart,claim_detail_page.dart,claim_form_page.dart}` · `lib/features/notifications/presentation/notifications_history_screen.dart` · `lib/features/notifications/application/notification_providers.dart` · `lib/features/user/{user_page.dart,edit_profile_page.dart}` · `lib/features/user/presentation/pages/about_page.dart` · `lib/features/onboarding/presentation/onboarding_screen.dart` · `lib/services/notification_service.dart` · `lib/common_widgets/{app_cached_image.dart,app_animations.dart,lilia_quantity_stepper.dart,build_error_state.dart}` · `lib/utils/snackbar.dart` · `lib/models/promo_validation_result.dart` · `lib/core/update/app_update_dialog.dart` · `ios/Runner/Info.plist` (phrase WhenInUse) · `pubspec.yaml` (retrait Lora) · `integration_test/perf_test.dart`.

**Autres dépôts (3.5)** — `lilia-food-admin/lib/theme/{lilia_tokens.dart,app_theme.dart}` · `Lilia-food-delivery/lib/utilities/app_theme.dart` · `lilia-food-web/apps/web/app/globals.css` · `lilia-food-web/apps/admin/app/globals.css` · `lilia-food-web/packages/design-tokens/`.

**Backend** — aucun requis pour 3.1-3.6. (Recherche tolérante aux fautes : plus tard.)

## 17. Exact Tests to Add / Update

| Test | Nouveau / étendu | Vérifie |
|---|---|---|
| `test/features/home/product_display_verdict_test.dart` | nouveau | boutique fermée ⇒ pas de « Disponible », pas de « + » actif ; `null` ⇒ pas de blocage |
| `test/a11y/text_scaling_test.dart` | étendu | `PopularDishesSection` et `VendorTypeFilterBar` à 1.5/2.0 (vraies polices) |
| `test/theme/contrast_test.dart` | étendu | CTA checkout, pastille prix, stepper quantité **en sombre** ; icône favori ≥ 3:1 |
| `test/features/commandes/order_progress_stepper_test.dart` | nouveau | 7 statuts × livraison/retrait |
| `test/common_widgets/user_facing_error_message_test.dart` | étendu | `showErrorSnack` ne rend jamais `DioException`/`TypeError` bruts |
| `test/features/cart/vendor_conflict_dialog_test.dart` | nouveau | conflit de vendeur ⇒ modale « Vider et ajouter » |
| `test/features/cart/cart_footer_test.dart` | nouveau | « Sous-total » + mention des frais |
| `test/features/home/home_offline_test.dart` | nouveau | coupure réseau ⇒ la liste précédente reste affichée |
| `test/features/user/about_page_test.dart` | nouveau | version = `PackageInfo` ; contacts ouvrent `mailto:`/`tel:` |
| `test/features/notifications/unread_badge_test.dart` | nouveau | badge = non lues |
| `test/utils/cloudinary_url_test.dart` | nouveau | transformation par usage, n'agrandit pas, URL non-Cloudinary inchangée |
| `integration_test/perf_test.dart` | réparé | un seul `app.main()`, onboarding marqué vu, repère `RestaurantCard`, `--no-dds` documenté |
| `test/routing/guest_mode_test.dart` | étendu | onglets Commandes/Profil en invité ⇒ écran explicatif avec accès support |

---

### Annexe — preuves

Captures (émulateur Pixel 8) : `shots/a01…a12` (parcours invité), `b01-b03` (texte 1.3/1.5/2.0), `c01-c05` (sombre, conflit, invité), `d01-d03` (hors-ligne). Timelines iPhone : `repos/lilia-app/build/{home_scroll,tab_navigation,restaurant_detail_scroll}.timeline_summary.json`, `perf_metrics.json`. Journaux : `analyze.txt`, `test.txt`, `drive_ios*.txt`, `build_apk.txt`. Tous dans le dossier temporaire de la session.
