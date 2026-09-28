# LILIA FOOD — UI/UX Audit

**Date :** 2026-09-27  
**Branche observée :** `hmipoka/f309-options`  
**HEAD observé :** `369a118`  
**Phase :** 1 — Discovery et audit statique uniquement  
**Périmètre :** application Flutter client et cohérence de premier niveau avec le web, l’admin, le livreur et les contrats de `/lilia-backend`.

> Ce rapport décrit le code consulté à cette date. Il ne remplace pas une revue visuelle sur appareils réels, une analyse des métriques de production, ni l’exécution des tests. Aucun test ni build n’a été lancé pendant cette phase.

## Executive Summary

L’app cliente a déjà une base technique plus mûre qu’une simple UI à moderniser : architecture par fonctionnalités, Riverpod codegen, repositories, routes adressables, gestion de session, mutations optimistes du panier, cache à durée bornée, déduplication Analytics, états d’erreur réutilisables, instrumentation Sentry, garde contre le double checkout et suivi de livraison WebSocket avec repli HTTP. Plusieurs commentaires et tests existants montrent que des incidents de navigation, réseau et cycle de vie ont déjà été traités.

Le besoin principal n’est donc pas une réécriture globale. Il est de consolider l’identité visuelle déjà présente, d’unifier les composants et les états, puis de traiter les écarts UX qui restent visibles dans les parcours d’achat. Les écrans critiques restent fortement concentrés dans de grands fichiers, les styles sont souvent redéfinis localement et certains composants d’ajout rapide choisissent implicitement une variante. La recherche affiche encore une erreur technique brute sans action de reprise. Le Home emploie un chemin de bannière de secours qui ne correspond à aucun fichier sous `assets/images/`.

Le backend confirme le contrat F3-10 : `ProductVariant.stockConsumption`, `availableQuantity` (nullable) et `stockStatus` avec `UNLIMITED`, `AVAILABLE`, `LOW`, `OUT_OF_STOCK`. `availableQuantity` correspond au nombre de ventes possibles dans le format concerné, calculé côté serveur. Les composants d’un menu ont une variante déterminée par `MenuProduct.variantId`. Les endpoints catalogue, recherche, populaires et recommandations ne décorent pas tous les variantes avec le verdict de stock de la même façon : les cartes doivent traiter les champs absents sans inventer un stock.

### Évaluation synthétique

| Domaine | État observé | Priorité de travail |
|---|---|---|
| Navigation / accès invité | Structure solide, quatre onglets, routes d’identifiants et redirections testées | P3 — conserver et vérifier visuellement |
| Home / découverte | Marketplace, filtres, promotions et plats populaires ; fallback image manquant ; contenu vertical eager | P1/P2 |
| Recherche | Debounce 300 ms et résultats mixtes ; erreur brute sans reprise, historique/suggestions absents | P2 |
| Produit / vendeur | Variantes, options, horaires et disponibilités déjà modélisés ; formats pas uniformément choisis avant ajout rapide | P1 |
| Panier | État optimiste, rollback, panier invité et issues backend ; UX et composants encore volumineux | P1/P2 |
| Checkout / paiement | Résumé, promo, fidélité, idempotence et garde multi-étapes ; écran très monolithique | P1/P2 |
| Commandes / suivi | Listes exhaustives, WebSocket, fallback HTTP et veille cycle de vie | P3 — base solide |
| Profil / fidélité / parrainage | Fonctions présentes et servies par providers ; écran profil très volumineux | P2 |
| Design system | Tokens Flutter riches ; usages locaux nombreux ; copies non synchronisées entre clients | P1/P2 |
| Accessibilité | Plusieurs correctifs sémantiques présents ; couverture visuelle et contrastes locaux incomplets | P2 |

## Current UX Assessment

### Navigation Audit

- `StatefulShellRoute.indexedStack` garde les branches des quatre onglets. La barre utilise `NavigationBar` Material 3 et le compteur du panier s’abonne à `totalItems` avec `select`, ce qui limite les reconstructions de la coque.
- Le retour Android depuis un onglet secondaire ramène à l’accueil ; les redirections de session et les destinations protégées ont des tests dédiés. Les routes produit/menu acceptent un identifiant et ne dépendent plus uniquement de `state.extra`.
- La découverte reste accessible sans session et l’authentification est différée pour les actions qui la nécessitent. C’est cohérent avec le tunnel marketplace demandé.
- À vérifier en Phase 2 : conserver la destination après login dans les parcours panier/checkout et vérifier le comportement clavier, petits écrans et liens profonds sur appareil.

### Home Audit

- Hiérarchie actuelle : recherche, bannières, plats populaires, filtre par type de vendeur, puis liste des vendeurs. Le rail de catégories a été retiré car il ne conduisait pas à des résultats fiables. Le filtre de type de vendeur est une meilleure abstraction dans le modèle actuel.
- Les fournisseurs affichent les erreurs pour la liste principale, les plats populaires masquent l’erreur (section omise), et les bannières utilisent un fallback. Ces dégradations sont non bloquantes, mais pas toujours expliquées au client.
- **P1 — fallback cassé :** `home.dart` référence `assets/images/banner.png` pour les bannières locales de repli ; ce fichier est absent du catalogue `assets/images/`. Le chemin de repli peut donc produire un échec d’asset au lieu d’une image de secours.
- **P2 — coût de liste :** le Home est un `SingleChildScrollView` contenant une `Column`, puis un `ListView.builder(shrinkWrap: true, NeverScrollableScrollPhysics)` pour les vendeurs. Le parent doit mesurer le contenu imbriqué et les lignes déjà reçues ne bénéficient pas pleinement d’un viewport vertical paresseux. La liste serveur est bornée/paginée, ce qui limite le risque immédiat ; un sliver parent simplifierait l’évolutivité.
- La section « Plats populaires » prend une hauteur fixe et une liste horizontale ; l’animation auto-play du carrousel tourne toutes les quatre secondes. Réduire les animations hors champ et respecter `MediaQuery.disableAnimations` méritent une vérification avant décision.
- Les erreurs de bannière/plats populaires sont actuellement silencieuses ; garder le Home utilisable est raisonnable, mais une erreur durable sans indice est ambiguë.

### Search Audit

- Recherche restaurant + produit dans un même écran, debounce 300 ms, gestion des résultats vides, route directe vers le produit et `ListView` pour les résultats. C’est une base fonctionnelle.
- **P2 — échec non récupérable :** la branche `error` rend `Erreur: $err`, qui expose le texte technique et ne propose aucun bouton retry. Elle doit utiliser l’état d’erreur partagé avec reprise et message localisé.
- Pas d’historique, suggestions ou filtres de recherche visibles. À prioriser après cohérence des résultats et des erreurs : ces ajouts impliquent du stockage local/contrat et ne sont pas nécessaires pour la première simplification.
- Le repository appelle `/products/search?q=...`; l’endpoint backend renvoie produits et restaurants, sans pagination client visible dans ce parcours. Le debounce réduit les requêtes, mais ne supprime pas les appels pour les recherches successives distinctes.
- L’entrée du texte déclenche `setState` seulement à la fin du debounce ; l’action de suppression du texte est cohérente. Les cartes de résultat reprennent des styles définis localement.

### Restaurant / Vendor Audit

- Le modèle expose statut d’ouverture, type de vendeur, fenêtres de disponibilité, notes et catégories. Les filtres de vendeur, favoris et détails sont déjà intégrés.
- L’écran `restaurant_detail_screen.dart` fait 1 573 lignes et contient image de couverture, informations vendeur, produits, modales/flux d’ajout et widgets privés. Cela complique la navigation dans le code, les changements visuels isolés et la mesure des reconstructions.
- Le fichier contient de nombreuses couleurs, rayons, espacements et styles en dur ; certains badges utilisent les couleurs globales plutôt que les tokens sémantiques. L’identité varie donc selon les sections et le dark mode peut diverger.
- Le cache du menu est borné à cinq minutes et invalidé au retour tardif au premier plan ; cela est adapté à des prix et stocks périssables. Le backend filtre les vendeurs/produits publics et enrichit les variantes du menu vendeur avec le verdict stock.
- Des chemins de quick-add existent depuis le menu vendeur. Pour les produits multi-formats, un ajout direct qui choisit silencieusement `variants.first` contourne le besoin de faire choisir le format. À traiter avec le produit (P1).

### Product Audit

- La fiche adressable charge le produit par ID lorsqu’il n’est pas fourni en `extra`, ce qui protège la restauration de route. Elle gère galerie, description, détails produit, horaires, options F3-09, variantes, quantité, favori, partage et CTA fixe.
- **P1 — choix de variante inconsistant :** plusieurs raccourcis (cartes populaires, recommandations, recherche, fiche vendeur) ajoutent `variants.first` sans choix explicite. Comme le tri backend est par prix, cette action est un choix implicite du prix le plus bas, pas nécessairement le format attendu par le client. Une variante multiple doit ouvrir la fiche ou une sélection explicite ; le quick-add peut rester pour les produits à format unique.
- Contrat backend vérifié : `stockConsumption` est la consommation d’unités stock par unité vendue du format. `availableQuantity` est déjà converti en quantité vendable par format (`floor(stockRestant / stockConsumption)`) et peut valoir `null` (illimité). `stockStatus` utilise `UNLIMITED`, `AVAILABLE`, `LOW`, `OUT_OF_STOCK`. Le seuil LOW est trois ventes disponibles du format.
- Certains endpoints (`GET /products`, détail produit, listes vendeur/restaurant) passent par `withVariantStock`; `search`, `popular` et `recommendations` renvoient des variantes non systématiquement décorées par ce verdict. L’UI doit rendre « stock non communiqué » comme inconnu, pas le transformer en rupture ou en stock illimité. Le panier et checkout restent arbitré par le backend.
- La fiche fait 973 lignes et concentre état UI, règles de blocage, analytics, options, partage et panier. Une extraction vers composants purs et un contrôleur/domain adapté réduirait le coût de maintenance sans réécrire la feature.
- Menus : le backend persiste `MenuProduct.variantId`, format choisi pour chaque composant. Avant les ajustements déjà présents dans le working tree, `MenuProduct` ne lisait pas cet identifiant et `MenuCartPreview` prenait `variants.first`. La lecture/usage du format fixé par menu a été corrigée dans les changements de travail non validés listés plus bas ; elle doit être revue et testée avant livraison.

### Cart Audit

- Le panier dispose d’un contrôleur optimiste : ajout, changement de quantité et suppression mettent l’état local à jour immédiatement, sérialisent les mutations, acceptent la réponse serveur et rollback en cas d’échec. Les échecs de synchronisation remontent à un listener global de la coque. Ce mécanisme répond déjà à la latence du snackbar.
- Le repository consomme le panier retourné par les mutations backend au lieu de lancer une seconde lecture `GET /cart`. Le panier invité est conservé localement et adopté à la connexion.
- `Cart.hasIssues` reflète les lignes non commandables issues de `GET /cart`, et chaque ligne sait afficher le message d’issue. Le backend renvoie notamment `OUT_OF_STOCK`, `VARIANT_UNAVAILABLE`, la quantité encore disponible et un `hasIssues` au niveau panier.
- L’écran de panier fait 1 070 lignes et porte lignes, menus, suggestions, dialogs, minimum vendeur, quantité et récapitulatif. L’extension `hasIssues` et le blocage checkout présents dans le working tree sont alignés avec le contrat backend, mais doivent être revus avec les cas menu/rollback.
- Plusieurs styles, couleurs et contrôles de chargement restent définis dans le fichier d’écran. Une issue de stock doit donner une action utile (modifier la quantité, retirer la ligne ou retourner au produit) et le blocage du checkout doit toujours nommer la raison.

### Checkout Audit

- Le checkout présente adresse/mode, téléphone de contact, numéro de paiement distinct, notes, code promo, fidélité, frais et total. Il estime depuis `CheckoutEstimate`, actualise certaines règles par réglages serveur et envoie la sélection au `CheckoutController`.
- Le double tap est gardé avant le premier `await`, l’idempotency key est utilisée sur la création et l’erreur 426/503 invalide les réglages. C’est une protection utile contre une double commande et un décalage de version.
- **P1 — complexité UI élevée :** `checkout_page.dart` fait 2 297 lignes et conserve dans un seul `ConsumerState` un grand nombre de sous-flux et d’états (promo, fidélité, adresse, paiement, précommande, validation, erreurs). Il y a des sections privées, mais la page reste propriétaire de plusieurs décisions métier/présentation.
- Le parcours delivery options → checkout est un écran intermédiaire de plus, mais porte choix de retrait/livraison/quartier/adresse et géolocalisation ; ne pas le fusionner sans audit du coût de saisie/localisation.
- La synthèse de prix doit continuer d’afficher le montant final autoritaire du serveur et distinguer les montants estimés de tout changement de stock/prix rejeté. Aucune règle métier financière ne doit être déplacée ou recalculée dans l’UI au cours du refactor.

### Authentication Audit

- Firebase Auth est source de session, synchronisation backend via repositories, flux Google et email, récupération/redirection, collection du téléphone et synchronisation non bloquante du lastLogin sont présents.
- L’accès aux écrans de découverte reste public ; les tests routing couvrent matrice d’accès, deep destination, sortie et parcours invité.
- L’écran login/inscription comporte encore des contrôles locaux, mais l’orchestration est déléguée aux controllers/repositories. Vérifier visuellement erreurs provider Google, clavier, auto-remplissage téléphone et retour à la destination au prochain lot.
- Apple sign-in n’a pas été trouvé dans le périmètre inspecté des écrans/repositories d’auth. À confirmer comme exigence produit avant de le classer comme défaut ; ne pas ajouter une intégration sans périmètre confirmé.

### Orders Audit

- La liste sépare en cours, terminées et annulées/échec, affiche l’action pertinente selon statut et conserve les statuts inconnus dans un groupe visible plutôt que de faire disparaître la commande.
- `commande_page.dart` est modulé partiellement autour de cartes, mais les détails commande font 2 414 lignes. Ce niveau de concentration rend les régressions sur paiement, litige, statut et livraison coûteuses à isoler.
- La présentation de progression et les historiques existent. Le vocabulaire métier devra rester synchronisé avec les statuts backend (notamment `ACCEPTEE`, `PRET`, `ECHEC_LIVRAISON`).

### Tracking Audit

- L’ancien descriptif de dépôt indiquait un polling HTTP toutes les dix secondes. Le code actuel est plus avancé : position initiale HTTP, WebSocket Socket.io `/tracking` pour les mises à jour temps réel, fallback HTTP toutes les trente secondes, arrêt au statut terminal et suspension/reprise selon le cycle de vie.
- Tests dédiés au cycle de vie des sockets existent. L’écran carte gère l’absence de position et le chargement, mais un contrôle visuel de l’état GPS/connexion et des permissions reste requis.
- Le coût réseau actuel paraît borné en premier plan et interrompu en arrière-plan selon le controller ; réexaminer les transitions terminales en test device à la Phase d’implémentation.

### Profile Audit

- Profil, édition, adresses, notifications, favoris, commandes, brouillons, fidélité, parrainage, préférences et déconnexion sont joignables.
- `user_page.dart` fait 953 lignes et combine un grand nombre de sections, états et navigation. Les catégories de réglages/personnel/commandes gagneraient à être plus explicites et isolées.
- La fidélité et le parrainage ont une valeur métier documentée dans l’app ; l’interface doit exposer les règles (gain, disponibilité, conversion et moment de crédit) directement à proximité des actions.
- Le profil charge les données avec refresh et état d’erreur. Les appels de transactions/points doivent rester différés si l’utilisateur n’ouvre pas leur historique.

### Loyalty Audit

- Le solde, l’historique et l’application au checkout sont présents. Le seuil minimum et la conversion sont codés métier et doivent être montrés comme aide plutôt que rester dans les commentaires/règles internes.
- Vérifier que le parcours distingue points gagnés, bloqués, disponibles et utilisés, et que le dernier état chargé n’apparaît pas comme une promesse financière.

### Referral Audit

- Le profil affiche code et statistiques ; l’inscription permet de saisir un code et le bouton Google transmet aussi ce code. Le système de partage est donc fonctionnel dans son socle.
- L’écran doit clarifier les étapes de récompense, l’éligibilité et le statut « en attente / crédité » avec le même vocabulaire que l’API.

### Design System Audit

- Le client a déjà `LiliaColors`, sémantiques clair/sombre, tokens de spacing et radius, et un `AppTheme` Material 3. Les polices sont intégrées au bundle et le runtime Google Fonts est désactivé.
- L’admin Flutter possède des fichiers `lilia_tokens.dart`/`app_theme.dart` proches, mais les diffs montrent une divergence réelle : le gris `charcoal450` et ses commentaires de contraste ne sont pas portés partout ; certains contrôles admin réutilisent `Colors.white` alors que le client choisit un texte adapté au mode sombre ; la couleur primary claire diffère (orange600 côté client, orange500 côté admin).
- Le web contient `@lilia/design-tokens` et des CSS/Tailwind compilés, mais la sémantique de couleur action claire suit orange500 alors que l’app cliente choisit orange600 pour atteindre le contraste annoncé dans ses commentaires. Le livreur a un thème indépendant (orange `#FF6B00`, Poppins, surface grise), sans tokens partagés repérés.
- Le thème cliente a un bon système de base, mais son utilisation n’est pas systématique : 594 occurrences de déclarations couleurs/style/layout ont été trouvées dans les features interrogées avec une recherche simple. Ce chiffre est un indicateur de surface, pas un décompte d’erreurs.
- `TextTheme` global démarre de `Oswald`, tandis que le web annonce Inter body + Fraunces display ; le client expose Fraunces, Inter, Girassol, Oswald et Lora et emploie localement plusieurs styles. Il faut fixer une règle par rôle typographique au lieu d’éliminer arbitrairement les polices identitaires.

### Accessibility Audit

- Des labels Semantics explicites existent sur plusieurs cartes d’indisponibilité ; `LiliaTokens` documente des ajustements de contraste et les boutons partagés ont des zones de tap convenables.
- Les listes utilisent des cartes tappables dont l’accessibilité dépend encore de gestes/rôles locaux ; badges de stock peuvent être visuels seulement. Les couleurs vert/rouge sont parfois le seul signal d’ouverture/état.
- Les tailles de police sont souvent fixes et les textes sur certaines cartes sont tronqués par `maxLines`. Vérifier les grands textes système, landscape/tablette, navigation TalkBack/VoiceOver, focus clavier et contrastes mesurés dans un audit appareils.
- Des tests `test/a11y` sont présents, mais ils ne remplacent pas l’inspection de chaque parcours.

### Performance Audit

- Bons contrôles existants : cache image mémoire plafonné et `AppCachedImage`, cache catalogue de cinq minutes, invalidation après reprise longue, parse JSON hors isolate au-dessus d’un seuil, pagination API, `select` pour le compteur panier, debounce recherche, mutations optimistes, prévention des doubles requêtes et tâches analytics.
- Les grands écrans et l’assemblage Home list-scroll présentent la plus grande dette mesurable par inspection. Les cartes de collections horizontales sont construites par builder ; la grande page vendeur et les écrans commande/checkout doivent être examinés par profilage avant toute optimisation.
- Le suivi GPS est maintenant WS-first avec poll de secours au lieu du polling court constant décrit dans l’AGENTS historique.
- Tests d’instrumentation de performance et de latence panier existent dans le dépôt, mais aucun profil ni test n’a été exécuté dans cette phase.

### Architecture Audit

- Modèle courant : `presentation → controller/provider → repository → ApiClient`, avec modèles partagés et Riverpod codegen. Plusieurs features ont aussi une couche `domain` (panier, commande/checkout, paiements).
- L’architecture suit les conventions établies et les providers séparent souvent le cache des widgets. Pas de justification pour une migration d’état ou une réécriture Clean Architecture généralisée.
- Principale exception : la longueur de fichiers et la quantité de logique dans StatefulWidgets/ConsumerWidgets. Extraire d’abord les sections à état indépendant et les transformations testables, sans déplacer les règles de paiement/stock hors de leurs propriétaires.

### Code Quality Audit

- Les commentaires techniques détaillés, contrats, raisons de cache et cas de régression sont abondants et utiles, mais les écrans très longs rendent leur lecture et l’évolution plus difficiles.
- Les couleurs/espacements/rayons/textes et quelques durées sont définis localement dans les widgets, tandis qu’une partie équivalente existe dans le thème/tokens.
- Les widgets d’état partagé (`BuildErrorState`, `BuildLoadingState`, `ResolutionParIdentifiant`, `EmptyPlaceholderWidget`) sont déjà présents ; les branches d’erreur n’en tirent pas encore toutes parti.
- Tests ciblés de navigation, panier, suivi socket, perf et accessibilité existent. Les golden tests ne sont pas une pratique dominante dans la suite inspectée.

### Cross-platform Consistency

- Web : Next.js/React, React Query, design-token package, composants/animations et API client partagés dans un monorepo web.
- Admin : Flutter, thème/tokens copiés, mais divergences contrastes/couleurs observées. Les parcours administrateur ne doivent pas partager les interactions client, mais doivent partager le socle de marque et de statut.
- Delivery : Flutter, thème Poppins/orange/gris séparé ; lisibilité et couleur de marque différentes. Cela peut être un choix opérationnel, mais doit être explicite.
- Backend : NestJS/Prisma. Les contrats publics de variantes et menus ont été inspectés. Aucun changement backend n’est identifié comme prérequis pour l’audit UI ; F3-10 est déjà implémenté dans les vues vendeur/produit et panier côté serveur.
- Les autres clients n’ont pas fait l’objet d’un audit exhaustif écran par écran dans cette phase de découverte ; seuls leur structure, tokens/thèmes et quelques contrats concernés par le parcours produit ont été comparés.

## Critical Issues

Aucun P0 confirmé par cette analyse statique.

## Critical / Major / Minor Issues

### P1 — High

1. **Choix implicite de variante lors des ajouts rapides.** Les vues populaires, recommandations, recherche et vendeur passent souvent la première variante directement au panier. Un produit multi-format devient ambigu (prix, quantité, consommation stock, unité) et l’action peut acheter un format que l’utilisateur n’a pas choisi. Remplacer ces chemins par la fiche/sélection explicite, sauf format unique.
2. **Fichier de bannière fallback absent.** Le Home mentionne `assets/images/banner.png`, absent du dossier. Le chemin de secours n’est pas fiable, donc le Home peut échouer précisément quand l’API banner n’est pas disponible.
3. **Écrans de transaction très concentrés.** Checkout (2 297 lignes), détail commande (2 414 lignes), fiche vendeur (1 573 lignes) et panier (1 070 lignes) portent plusieurs responsabilités. Le risque est de régression et d’allongement des changements métier sensibles ; extraire en lots sûrs et testés.

### P2 — Medium

1. **Erreur de recherche brute sans retry.** Présentation technique potentiellement opaque/sensible, aucune reprise explicite.
2. **Parité de design system incomplète.** Client/admin/web/livreur divergent sur couleurs primaires, typographie, contrastes et thèmes. Le paquet web est une distribution compilée et le Flutter porte des copies locales, sans pipeline de génération partagé visible.
3. **Styles hardcodés dispersés.** De nombreux appels couleur/dimension/rayon dans la feature produit et vendeur rendent le thème dark et les changements cohérents coûteux.
4. **Home assemble des listes verticales non paresseuses.** `SingleChildScrollView` et liste nested shrink-wrap peuvent coûter en layout quand le catalogue grandit. Mesurer avant refonte en slivers.
5. **Erreurs silencieuses dans des sections secondaires.** Plats populaires/recommandations/bannières peuvent se masquer sans indication ; clarifier uniquement les erreurs répétables tout en gardant Home disponible.
6. **Profil monolithique et fidélité peu auto-explicative.** Clarifier règles et statuts à proximité du solde/du geste d’usage.
7. **Accessibilité variable par écran.** Signaux couleurs-only, textes tronqués et labels d’action manquants à vérifier sur parcours intégral.

### P3 — Low

1. Historique/suggestions/filtres dans la recherche absents. À étudier après les parcours de base.
2. Animations du carrousel et des cartes à soumettre à `disableAnimations` et à une réduction hors champ si les mesures montrent un coût.
3. Uniformiser le vocabulaire d’état pour `AVAILABLE`, `LOW`, `OUT_OF_STOCK`, `UNLIMITED` et les statuts d’ouverture.

## Quick Wins

- Réparer le fallback bannière par une asset existante ou un placeholder local réellement présent.
- Faire ouvrir le choix de format pour tout produit avec plusieurs variantes depuis chaque entrée quick-add.
- Réutiliser `BuildErrorState` avec un libellé utilisateur et un retry dans l’erreur de recherche.
- Extraire l’échelle de couleur sémantique badge et remplacer les couleurs globales ponctuelles.
- Montrer l’unité vendable du format et le verdict backend sans recalcul client ; traiter `null` comme « quantité non limitée selon le serveur » seulement si `stockStatus == UNLIMITED`.
- Conserver le `variantId` du composant de menu dans le client : le backend fixe ce format et le panier doit le respecter.

## Long-term Improvements

- Créer une source de vérité de tokens versionnée (et génération Dart/CSS ou export contrôlé) ; conserver les décisions de contraste propres à chaque support documentées.
- Faire évoluer Home vers `CustomScrollView` et slivers après mesure de la taille réelle des listes.
- Extraire par domaines visuels/états indépendants les écrans transactionnels, préserver controllers/repositories existants et écrire tests ciblés aux frontières.
- Établir un inventaire des états UI et une revue accessibilité appareil pour les parcours Home → vendeur → produit → panier → checkout → commande.
- Définir des règles d’image de catalogue (dimensions/poids, cache, placeholders) et vérifier la distribution d’images réelles, pas seulement les widgets.
- Harmoniser les codes de statut et contenus de feedback entre Flutter client, web, admin, livreur et API sans uniformiser leurs flux de travail distincts.

## Modifications observées avant/après réception de la consigne de Phase 1

Le travail de code commencé à la demande précédente dans cette conversation a déjà laissé des modifications non validées dans le working tree, avant lecture du brief demandant « Phase 1 — aucun changement de code ». Elles ne sont donc pas présentées comme des changements réalisés au cours de cet audit. Elles concernent :

- variantes produit : ajout de `availableQuantity`, `stockConsumption`, `stockStatus` et widgets `VariantSelector`, `StockBadge`, `ProductStockCard` ;
- fiche produit : selector extrait et quantité plafonnée par quantité disponible ;
- panier : bannière `hasIssues` et CTA checkout bloqué ;
- menus : lecture de `MenuProduct.variantId`, affichage du format inclus et sélection de cette variante dans le preview panier (repli sur première variante pour objets de cache/fixtures anciens).

Le contrat a été vérifié dans `lilia-backend` : `withVariantStock()` calcule les verdicts, `MenuProduct.variantId` porte le format retenu et la vue panier expose `issue`/`hasIssues`. Ces changements n’ont pas été formatés/analysés/testés : la tentative `dart format` a échoué lorsque le SDK Flutter a essayé d’écrire dans son cache hors de la zone autorisée. Les changements doivent être revus séparément avant toute intégration.

Le working tree comporte aussi des changements d’autres fichiers (Gradle, `pubspec`, registrant macOS, page À propos et `lib/generated/`) dont l’origine n’a pas été établie par l’audit. Ils ne doivent pas être écrasés ou attribués à ce travail sans inspection avec le propriétaire.

## Périmètre et limites

**Fichiers analysés :** `lib/main.dart`, `lib/theme/*`, `lib/routing/*`, `lib/common_widgets/*`, providers/repositories de `home`, `cart`, `commandes`, `auth`, `user`, écrans Home/recherche/vendeur/produit/panier/checkout/commandes/profil, modèles produit/menu/panier, tests existants de navigation, panier, tracking, performance et accessibilité ; `pubspec.yaml`; thèmes client/admin/livreur ; package `lilia-food-web/packages/design-tokens`; routes et services backend produits, restaurants, menus, panier et stock.

**Non vérifié :** rendu visuel appareil, taille des images téléchargées, profil CPU/mémoire, tests Flutter, analyse statique, build, test de compatibilité serveur en exécution, parité exhaustive des écrans web/admin/livreur, règles produits sur données réelles. Ces vérifications sont prévues après validation de l’audit et cadrage UX.

**Backend / migrations :** aucun changement backend recommandé ou effectué dans cette Phase 1. Le stock multi-unités et l’association menu-variante existent déjà dans le code backend consulté. Aucun DTO/migration requis pour les constats prioritaires.

**Risques restants :** working tree déjà sale ; les fichiers non attribués listés ci-dessus ; changements de variantes en attente de format/analyse/tests ; absence de validation device et de mesures runtime.
