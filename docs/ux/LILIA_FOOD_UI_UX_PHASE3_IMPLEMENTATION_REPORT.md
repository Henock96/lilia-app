# Lilia Food — UI/UX Phase 3 : rapport d'implémentation

**Date :** 29/09/2026 · **Référence :** `LILIA_FOOD_UI_UX_PHASE3_DISCOVERY.md`
**Branches (non commitées, non poussées) :** `lilia-app` `hmipoka/uiux-phase3-impl` · `lilia-food-admin` `hmipoka/uiux-phase3-contrastes` · `lilia_food_delivery` `hmipoka/uiux-phase3-contrastes`
**Détail ligne à ligne :** `PHASE3_IMPLEMENTATION_TRACKER.md` · accessibilité, performance, release : rapports voisins.

## 1. Résumé exécutif

Les cinq constats majeurs de la Discovery sont traités dans l'app client : **prix annoncé avant le tunnel**, **plus de contradiction ouvert/fermé**, **erreurs techniques retirées de l'écran** (avec une garde qui balaie `lib/`), **timeline livraison ≠ retrait** (détail et liste), **accueil qui garde sa liste hors ligne**. S'y ajoutent l'ETA visible, la version réelle, des contacts qui ouvrent vraiment quelque chose, un badge de notifications qui s'éteint, la modale de conflit de boutique, « Commander à nouveau » depuis la liste, les images redimensionnées (−62 % mesuré), et les contrastes de l'admin et de l'app livreur.

Deux sondes ont été trouvées **aveugles** et réparées : le test de texte agrandi (vert pendant que l'appareil débordait) et le harnais de performance (7 défauts, cf. rapport de performance).

**Aucun changement backend, métier, paiement, permission ou schéma.** Le serveur reste l'autorité : le client affiche des estimations explicitement nommées comme telles.

Tests `lilia-app` : **911 → 1019**, 0 échec ; `flutter analyze` et `dart analyze` : 0.

## 2. Baseline vérifiée (Phase 0)

Voir le tracker, §Baseline. Points saillants : `feature/apple-auth` déjà mergée dans `origin/master` (branche de travail créée depuis `origin/master`) ; `lilia-food-web` et `lilia-backend` portent un travail HEIF **non commité** — non touchés ; l'admin porte un commit local non poussé (`22a55ac`) — conservé, travail fait sur une autre branche.

Points déclarés résolus, revérifiés : `Info.plist` localisation (test `ios_release_config_test` vert) et Sentry `9.30.1` — **pas de régression**.

## 3. Corrections — Phase 3.1 (confiance)

| Sujet | Décision clé |
|---|---|
| Boutique fermée (P3-01) | règle unique `Product.unavailability` ; `restaurantIsOpen == null` **ne bloque pas** (le serveur arbitre au panier et au checkout, F3-03) ; le « + » refuse avec un message qui nomme la boutique |
| Prix du panier (P3-11) | frais de service calculés au **taux servi par `/platform-settings`** avec l'arrondi du checkout ; livraison **annoncée, jamais inventée** ; barème injoignable ⇒ « Calculés à l'étape suivante » (le bouton reste actif) ; mention « offres, codes promo et points à l'étape suivante, montant final confirmé avant le paiement ». Le devis serveur (`POST /orders/quote`) n'est **pas** appelé depuis le panier : il exige mode et adresse, inconnus à ce stade |
| Erreurs (P3-05) | `userFacingErrorMessage` étendu (`CartException`, `AuthFailure`, 500) ; **délai dépassé à la création de commande = issue inconnue**, jamais « échec » |
| Support (P3-06) | `mailto:` / `tel:` sans `canLaunchUrl` (piège Android 11+ documenté) ; échec ⇒ copie + message ; « Besoin d'aide ? » sur chaque commande, référence pré-remplie |
| Version (P3-08) | `package_info_plus` |
| Timeline (P3-09) | 6 phases livraison / 5 retrait ; statuts terminaux ou inconnus ⇒ rien ; la liste réutilise la même règle |
| ETA (P3.1.7) | `0` serveur = destination inconnue ⇒ pas de chiffre ; position > 5 min ⇒ pas de chiffre |
| Notifications (P3-07) | non-lues locales par compte ; tri corrigé (l'écran affichait l'ordre inverse) |
| Conflit de boutique (P3-13) | modale « Vider et ajouter » |

## 4. Phase 3.2 (accessibilité) — voir `LILIA_FOOD_ACCESSIBILITY_REPORT.md`

## 5. Phase 3.3 (connectivité, performance) — voir `LILIA_FOOD_PERFORMANCE_REPORT.md`

Hors ligne : la liste est conservée **pour le même filtre** et datée ; un filtre changé hors ligne montre l'erreur, jamais la liste d'un autre filtre. Aucune file de commandes hors ligne (non demandée, non justifiée).

## 6. Phase 3.4 — design system

| Constat | Traitement |
|---|---|
| Admin : même palette que le client **avant** son correctif d'août (boutons 3,67:1, blanc sur orange sombre 2,84:1, `textMuted` 4,36:1) | ✅ port du correctif (`orange600`, `textOnAction`, `charcoal450`/`300`) + test de contraste |
| Livreur : `#FF6B00` + blanc 2,86:1, `textLight` 2,68:1, succès/erreur Material | ✅ aligné sur l'orange d'action client + teintes foncées ; **changement visuel à valider** |
| Web client : marque « tomate » `#D04C35` + Bricolage Grotesque, app : orange + Oswald | ⛔ **décision produit** — non tranchée ; ne pas générer de tokens avant |
| `@lilia/design-tokens` : `package.json` seul dans git, **aucun import** (vérifié) | ⛔ à supprimer ou remplir après la décision ; dépôt web avec travail non commité |
| `--text-muted` web à 2,47:1 | **défini mais jamais utilisé** dans `apps/web` (vérifié) — sans effet actuel |
| Typographie : Oswald en corps de texte, Lora 430 Ko inutilisée | ⏸ non traité : retirer Lora est sûr (0 usage, à revérifier), passer le corps en Inter change toute l'app — décision de design |

## 7. Phase 3.5 — fonctionnalités (vérifier avant d'ajouter)

| Idée | Constat | Décision |
|---|---|---|
| Commander à nouveau | existait sur le détail ; endpoint serveur qui vérifie produit/format/options/stock et nomme les écarts | ✅ ajouté à la liste, geste partagé (`reorder_action.dart`) |
| Panier persistant | serveur pour les connectés, `guest_cart_store` (SharedPreferences, par compte) pour les invités, tests existants | ✅ rien à faire |
| Favoris | vendeurs côté serveur (`/favorites`), produits locaux **par compte** | ✅ existant, cohérent |
| Aide contextuelle | réclamation F3-06 existait pour certains statuts | ✅ « Besoin d'aide ? » (e-mail avec référence, appel) sur toutes les commandes |
| Recherches récentes, chip « Ouverts », section favoris sur l'accueil | non implémentés | ⏸ valeur réelle mais P2 ; 7 vendeurs en production |
| `RecommendationsSection` | toujours non montée, endpoint basé sur l'historique | ⏸ **laissée non montée** (données insuffisantes à 7 vendeurs) ; suppression possible après une rangée « Vos habitudes » |
| Notifications marketing | — | ❌ non créées (consentement) |

## 8. Fichiers principaux

Nouveaux (`lilia-app/lib`) : `cart/domain/cart_price_preview.dart`, `cart/presentation/cart_price_summary.dart`, `commandes/domain/{order_timeline,order_error_presentation}.dart`, `commandes/presentation/{reorder_action.dart,widgets/order_timeline_view.dart}`, `home/presentation/widgets/product_availability_badge.dart`, `common_widgets/stale_data_banner.dart`, `core/support/support_contact.dart`, `utils/cloudinary_url.dart`.
Supprimés (code mort) : `commandes/presentation/{order_progress_stepper,progress_step}.dart`.
Modifiés : 40 fichiers `lib/` (voir `git diff --stat`), `ios/Runner/Info.plist` (phrase « quand utilisée »), `integration_test/perf_test.dart`, `test_driver/perf_driver.dart`, `PERF_TESTING.md`.
Autres dépôts : `lilia-food-admin/lib/theme/{lilia_tokens,app_theme}.dart` ; `lilia_food_delivery/lib/utilities/app_theme.dart`.

Formatage : 16 fichiers n'étaient pas formatés à `HEAD` ; les modifications y ont été rejouées **sans** formateur pour garder un diff sémantique.

## 9. Tests exécutés (résultats réels)

| Commande | Résultat |
|---|---|
| `lilia-app` `flutter analyze` / `dart analyze` | 0 / 0 |
| `lilia-app` `flutter test` | **1019 passés, 0 échec** (passage calme) ; lors d'un passage concurrent d'une compilation Xcode : 1019 + 1 échec de `cart_optimistic_test.dart` « l'ajout est visible AVANT la réponse serveur » — **instabilité préexistante** : il chronomètre en temps réel (`< 16 ms`) et échoue aussi 3 fois sur 4 sur `origin/master` pur sous la même charge |
| `lilia-food-admin` `flutter analyze` / `dart analyze` / `flutter test` | 0 / 0 / 333 passés |
| `lilia_food_delivery` `flutter analyze` / `flutter test` | 0 / 104 passés |
| `flutter drive --profile` iPhone 12 Pro | voir rapport de performance |
| web / backend | **non exécutés** (non modifiés) |

Nouveaux tests : 18 fichiers (garde anti-`e.toString()`, garde d'accents, contrastes, texte agrandi, timeline × 2 modes × statuts, ETA, hors ligne, conflit de boutique, badge non-lus, à propos, redimensionnement d'images, rachat, animations réduites). Plusieurs ont été **vérifiés rouges sans le correctif** (texte agrandi, filtre, garde d'erreurs).

## 10. Revue des modifications (auto-revue)

- Une première passe `dart format` avait reformaté 3 fichiers hors périmètre et 16 fichiers non formatés : **annulée et rejouée** proprement.
- `userFacingErrorMessage` rendait un message générique pour `CartException` après la normalisation : **corrigé avant la fin** (régression qui aurait masqué les refus du panier).
- Un commentaire affirmait que le rachat vérifie l'ouverture de la boutique : **faux** (vérifié dans `order-reorder.service.ts`), corrigé.
- Le harnais, un moment, déclarait la suite verte alors que 3 tests échouaient (rapporteur non chaîné) : corrigé.
- Changements de `.g.dart` (2) : empreintes Riverpod régénérées par `build_runner`, attendues.

## 11. Problèmes non corrigés

P3-14 (fiche vendeur sans nom pendant le chargement), P3-15 (CTA de checkout non collant), P3-16 (ordre des sections d'une commande en attente de paiement), P3-17 (permission notifications au premier lancement), P3-18 (onglets invités sans barre ni accès au support), P3-20 (onboarding hors marque), P3-23/24 (marque et typographie), écrans admin avec `Colors.white` codé en dur, « Plats populaires » qui disparaît hors ligne au lieu de garder sa dernière valeur.

## 12. Décisions produit nécessaires

1. **Marque unique** : orange (apps) ou tomate (site) — bloque toute source de tokens partagée.
2. Validation du **nouvel orange de l'app livreur**.
3. Numéro de support `+242 06 745 46 10` à confirmer.
4. Moment de la demande de permission de notifications.
5. Compte et commande de démonstration pour l'App Review.

## 13. Risques résiduels

- Validations **manuelles** non faites : TalkBack/VoiceOver, Android physique, captures 2×, mode avion réel, parcours connecté et paiement réel.
- Le redimensionnement d'images dépend de Cloudinary ; le repli sur l'original couvre les variantes en échec, pas une panne de l'original.
- ETA serveur au vol d'oiseau : sous-estime en ville ; présentée comme « environ ».
