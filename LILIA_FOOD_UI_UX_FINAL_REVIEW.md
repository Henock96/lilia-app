# LILIA FOOD — UI/UX Phase 2 : revue finale

**Date :** 2026-09-28 · **Dépôt :** `lilia-app` · **Rien n'est commité.** · Détail des changements : `LILIA_FOOD_UI_UX_IMPLEMENTATION.md`.

> **Mise à jour 28/09/2026 (après décisions).** Commité sur `hmipoka/uiux-phase2`, rebasé sur `master` (F3-10, F3-11). `Info.plist` : clé « Always » **conservée** — avertissement Apple ITMS-90683 dû à `geolocator_apple` (compilé par SwiftPM, son interrupteur `BYPASS_PERMISSION_LOCATION_ALWAYS` ne s'applique pas) — mais reformulée sans promettre d'arrière-plan ; test adapté. `sentry_flutter` : `10.0.0-rc.0` → **9.30.1** (dernière stable), `profilesSampleRate` rétabli. Rebase : modèle `ProductVariant` de F3-10 conservé (`isInStock` = `!isSoldOut`), sélecteur partagé gardé sur la fiche produit, devis serveur F3-11 conservé et ligne « offre boutique » portée dans `CheckoutOrderSummary`. **855 tests verts, 0 échec.**

## Executive Summary

**Verdict : favorable pour le code livré, sous deux réserves qui ne relèvent pas de cette phase** — l'`Info.plist` et la pré-version Sentry présents dans l'arbre de travail avant la mission. Les deux doivent être tranchés avant une release.

Le second passage de revue (§36) a trouvé et corrigé **trois défauts dans le travail déjà fait** — deux dans les changements préexistants, un dans les miens :
1. Favoris : présélection du « seul format en stock » parmi plusieurs (choix implicite) → aligné sur la fiche produit.
2. Favoris : ajout via `addItem` direct (conflit de mode non proposé) et libellé du bouton en blanc forcé (2.84:1 en sombre).
3. Mon `QuickAddButton` : sans `container: true`, son libellé fusionnait avec la carte vendeur parente et le bouton disparaissait pour TalkBack. Détecté par un test, corrigé.

Il a aussi mis en évidence **deux tests qui ne testaient rien** tels que je les avais d'abord écrits — le test « Réessayer relance la liste des vendeurs » passait aussi sur le code bogué (la relance automatique Riverpod rétablissait la liste seule), et un test de débordement ne détectait rien sur une carte donnée. Le premier a été refait et vérifié rouge sur l'ancien code ; le second est documenté comme défensif, non probant.

## P1 status

| | Statut | Preuve |
|---|---|---|
| P1.1 Variantes / quick-add | ✅ corrigé, 5 chemins + Favoris | `quick_add_test` (10), `vendor_product_card_test` (5), `variant_selector_test`, `product_variant_stock_test` |
| P1.2 Repli bannière | ✅ validé + complété (erreur immédiate, rebuilds, animations) | `home_screen_states_test` (5), `home_carousel_rebuild_test` |
| P1.3 Écrans monolithiques | ✅ partiel : checkout, détail commande, fiche vendeur, profil | 113 tests commandes verts ; `cart_screen` / `product_detail_page` non découpés |

## P2 status

| | Statut |
|---|---|
| P2.1 Recherche / erreurs / retry | ✅ message client, reprise, erreur visible pendant les relances |
| P2.2 Design system | ✅ consolidé (feedback text, badges, statuts) ; décision couleur documentée ; cross-app **non appliqué** |
| P2.3 Styles codés en dur | ✅ partiel : couleurs 373 → 281, rayons 267 → 226 sur `lib/` |
| P2.4 Home / performance | ✅ rebuilds mesurés et supprimés ; slivers **non** migrés (pas de mesure appareil) |
| P2.5 Erreurs silencieuses | ✅ catégorisées ; « Réessayer » vendeurs réparé |
| P2.6 Profil / fidélité | ✅ carte refondue |
| P2.7 Accessibilité | ✅ partiel : contrastes, cibles, sémantique, texte agrandi testés ; **aucune revue appareil** |

## P3 status

| | Statut |
|---|---|
| Vocabulaire des statuts | ✅ table unique de statuts de commande ; vocabulaire de stock (« Plus que N disponibles », « Épuisé », « formats ») |
| Animations | ✅ carrousel respecte « réduire les animations » ; autres animations non revues |
| Historique / suggestions / filtres de recherche | ❌ non commencé |

## Before / After

| Mesure | Avant | Après |
|---|---:|---:|
| Tests verts | 780 | 844 |
| Tests en échec | 1 (Info.plist, préexistant) | 1 (le même) |
| `flutter analyze` | 0 | 0 |
| `checkout_page.dart` | 2 297 l. | 1 735 l. |
| `commande_detail_page.dart` | 2 414 l. | 1 374 l. |
| `restaurant_detail_screen.dart` | 1 573 l. | 1 286 l. |
| Feuilles de choix de format | 4 copies | 1 |
| Tables de statuts de commande | 2 | 1 |
| Couleurs Material nommées (`lib/`) | 373 | 281 |
| Reconstructions liste vendeurs / 13 s de carrousel | 3 | 0 |
| Délai d'affichage d'une erreur (accueil, recherche) | ~38 s | immédiat |
| Contraste remise promo / fidélité (checkout, clair) | 2.3 / 1.35:1 | ≥ 4.5:1 |

## Design System status

- Socle conservé (`LiliaColors`, `LiliaSemantics`, `AppTheme`) ; ajouts justifiés par contraste et testés : `green700`, `amber700`, `red500`, `successText`, `warningText`, `liliaBadgeColors`.
- `LiliaBadge` devenu le composant de statut réel (6 usages) ; mapping de statuts fictifs supprimé.
- **Décision couleur :** marque `orange500` ; action `orange600` (clair) / `orange400` + texte foncé (sombre). Web et admin utilisent encore `orange500` comme action (3.67:1), livreur `#FF6B00` (~2.9:1) — **recommandation non appliquée**.
- Typographie par rôle **proposée**, non appliquée ; `Lora` inutilisée (424 Ko).
- Source de tokens partagée : **proposée** (JSON → CSS + Dart), non implémentée.

## Accessibility status

- Vérifié par test : contrastes AA (thème + badges + statuts + fidélité + instructions de paiement + récapitulatif checkout), cibles 48 px (quick-add, instructions de paiement, carte vendeur), sémantique (quick-add, formats, stepper, solde fidélité, erreurs `liveRegion`), texte agrandi 1.0–2.0× sur 5 composants **avec les vraies polices**.
- Statuts jamais portés par la seule couleur sur les zones traitées (ouvert/fermé, commandes, stock).
- **Non vérifié :** TalkBack / VoiceOver réels, clavier, parcours complet, paysage/tablette.

## Performance status

- **Mesuré :** carrousel → 0 reconstruction de la liste (était 3 / 13 s) ; construction de 30/30 cartes vendeurs à l'ouverture (constat, non corrigé).
- **Par analyse :** vignettes vendeur passées au cache disque ; erreurs affichées sans attendre les relances.
- **Conservé sans changement :** cache image, cache catalogue 5 min, pagination, debounce, panier optimiste (vérifié : le feedback n'attend pas l'API), WS tracking, JSON isolate.
- **NON MESURÉ :** temps de frame, mémoire, premier rendu, scroll sur appareil.

## Architecture status

`presentation → controller/provider → repository → ApiClient` conservé. Aucun package, aucune couche, aucun changement de navigation ou d'état. Nouveaux fichiers = widgets d'affichage et une extension de rendu (`whenUi`, 28 lignes). Règles métier (paiement, stock, calcul, création de commande, auth) **non déplacées** ; les widgets extraits reçoivent des montants déjà calculés. Aucun contrat backend modifié.

## Tests executed

- `flutter analyze` (complet) — plusieurs passages.
- `flutter test` (complet) — après chaque lot ; dernier passage : **844 verts, 1 échec**.
- `flutter test test/a11y` — 26/26.
- Ciblés : `test/features/{cart,home,commandes,favoris,user}`, `test/theme`, `test/perf/home_carousel_rebuild_test.dart`.
- Contre-épreuves : cible de relance des vendeurs (test rouge sur l'ancien code) ; rebuilds du carrousel (mesuré sur `home.dart` de HEAD puis restauré) ; témoin de débordement (rouge) ; Flexible du prix populaire (**non concluante**, documentée).

## Tests passed

844. Tous les nouveaux tests ; toute la suite existante sauf l'échec ci-dessous.

## Tests unavailable

- `test/platform/ios_release_config_test.dart` — « pas de chaîne Always » : **échoue à cause de l'`Info.plist` préexistant**, non modifié par respect de la règle 0. Le test documente que cette clé décrirait un usage inexistant (risque de refus App Store).
- Tests d'intégration sur appareil (`integration_test/`) : non lancés (pas d'appareil).
- Golden tests : volontairement non créés (polices de test ≠ appareil).

## Files modified

Voir `LILIA_FOOD_UI_UX_IMPLEMENTATION.md` › *Files Changed* et *Pre-existing Changes* (inventaire `PRE_EXISTING_WORKTREE_CHANGES`).

## Known limitations

- Aucune validation visuelle ni parcours manuel sur appareil (§31).
- Le visiteur peut désormais ajouter depuis les 5 écrans de quick-add — cohérent avec le mode invité, à confirmer produit.
- Teintes de statut regroupées par intention (plusieurs statuts partagent une teinte, distingués par libellé et icône).
- `RecommendationsSection` modifié mais jamais monté dans l'app.

## Remaining technical debt

1. `Info.plist` « Always » + `sentry_flutter 10.0.0-rc.0` (préexistants).
2. Liste des vendeurs non paresseuse.
3. `cart_screen.dart`, `product_detail_page.dart`, `menu_detail_page.dart` à découper.
4. 281 couleurs Material restantes (`menu_detail_page`, `driver_tracking_map`, `reviews_screen`, `product_detail_page`, `address_page` en tête).
5. Couleur d'action web/admin/livreur ; tokens sans source commune.
6. Typographie par rôle ; `Lora`.
7. `about_page.dart` : version codée en dur, déjà désalignée du `pubspec`.

## Recommended next steps

1. Décider `Info.plist` et Sentry, puis rendre la suite 100 % verte.
2. Revue visuelle + TalkBack/VoiceOver du parcours Home → Tracking sur un Android d'entrée de gamme.
3. `flutter run --profile` sur l'accueil avec le nombre réel de vendeurs ; slivers si jank.
4. Découpage `cart_screen` / `product_detail_page`.
5. Tokens partagés + couleur d'action accessible sur web/admin/livreur.
6. P3 recherche (historique, suggestions, filtres).

---

<details>
<summary>Annexe — revue finale précédente (session antérieure, conservée telle quelle)</summary>

# Lilia Food — revue finale Phase 2

## Conclusion

**Revue favorable pour les changements livrés dans cette phase.** Le choix de format est explicite dans la fiche et les Favoris, les états de stock par variante sont relayés depuis le backend, les menus honorent leur `variantId`, et une ligne de panier signalée invalide bloque le checkout. Les erreurs de recherche sont récupérables et les bannières n’utilisent plus un asset absent.

Cette revue ne certifie pas l’apparence sur appareils réels : aucun appareil ni parcours UI manuel n’a été exécuté dans cette session. Les performances de l’écran d’accueil sont **NON MESURÉES**.

## Décisions de contrat

- `availableQuantity` est le nombre d’unités vendables dans la variante sélectionnée, tel que fourni par l’API ; `null` signifie que la quantité n’est pas connue par cette réponse.
- `stockConsumption` sert à expliquer le contenu d’un format. Le client ne divise pas le stock pour produire une quantité disponible.
- `stockStatus` porte notamment le verdict `LOW`. Le client ne réinvente pas le seuil d’alerte.
- `MenuProduct.variantId` choisit le format des composants d’un menu. Le fallback sur la première variante ne concerne que les données legacy sans identifiant.
- Le backend garde la décision finale à l’ajout et au checkout. Une donnée d’inventaire inconnue n’est pas transformée en rupture côté client.

## Revue des risques

| Zone | Résultat | Risque résiduel |
|---|---|---|
| Sélecteur de formats | Variantes épuisées non sélectionnables ; sélection accessible et quantité bornée | Les endpoints qui omettent le stock affichent « Stock à vérifier » ; le backend arbitre la commande |
| Panier | Issues contextuelles visibles ; checkout désactivé si `hasIssues` | Vérifier par parcours manuel le texte exact des erreurs de stock renvoyées sur les différents endpoints |
| Menus | Format explicitement configuré utilisé | Anciennes données sans `variantId` gardent le fallback historique |
| Recherche | Erreur avec bouton Réessayer | Le parcours API complet n’a pas de test widget dédié |
| Bannières | Fallback graphique local pour API vide/erreur et échec d’image | Vérification visuelle réelle à faire sur plusieurs tailles d’écran |
| Performance accueil | Aucune migration structurelle spéculative | Mesures de frame/build/rebuild sur appareil à effectuer avant optimisation supplémentaire |
| Design system | Les nouveaux composants consomment `ColorScheme` et réutilisent `LiliaTokens` indirectement via le thème | Aucun grand balayage des valeurs codées en dur ou modification typographique globale n’a été effectué, car cela changerait l’identité de nombreux écrans hors de cette portée |
| Sentry | L’affectation retirée restaure la compilation avec le paquet déjà résolu | `profilesSampleRate` n’est plus actif ; décider de sa nouvelle configuration avant une mise en production qui dépend du profiling |

## Findings de l’audit revalidés

L’affirmation générale selon laquelle tous les ajouts rapides choisissaient implicitement la première variante était trop large. Les sections populaires, recommandations et recherche demandaient déjà un choix pour plusieurs variantes ; le détail restaurant ouvrait la fiche. Le défaut certain se trouvait dans le détail des Favoris, qui pré-sélectionnait la première variante. Cette phase corrige ce parcours et les composants de menu ; elle ne remplace pas les parcours déjà explicites.

La structure scroll de l’accueil (colonne et listes non défilables) n’a pas été migrée vers des slivers : l’audit ne fournit pas de mesure runtime et le changement toucherait une page très fréquentée. La structure reste une piste conditionnée à un profilage représentatif.

## Résultats de validation

- Analyse statique : `flutter analyze` — **No issues found**.
- Suite complète : `flutter test --reporter=compact` — **All tests passed**, 758 au dernier passage complet.
- Suite ciblée après les dernières modifications : `variant_selector_test.dart`, `product_variant_stock_test.dart`, `cart_mutations_test.dart` — **All tests passed**.
- Diff whitespace : `git diff --check` — aucune erreur au moment de la revue.

## Changements maintenus hors périmètre UI

Les modifications Gradle, `about_page.dart`, `GeneratedPluginRegistrant.swift`, `pubspec.yaml`, `pubspec.lock` et `lib/generated/` étaient présentes avant la phase et ont été préservées. `main.dart` a été touché uniquement pour supprimer une option Sentry devenue inexistante dans la dépendance résolue, afin de rétablir l’analyse et l’exécution des tests. Aucun fichier backend n’a été modifié.

</details>
