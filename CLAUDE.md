# CLAUDE.md — Lilia App (Client)

App **client** Flutter de la plateforme Lilia Food (Brazzaville, Congo). Rôle `CLIENT`.

Lilia Food n'est plus une simple app de livraison de restaurants : c'est une
**marketplace locale multi-vendeurs** (restaurants, cuisines maison,
boulangeries, pâtisseries, boissons). Le terme « restaurant » dans le code
historique désigne désormais un **vendeur** typé par `vendorType`.

**Backend URL** : `https://lilia-backend.onrender.com`

## Écosystème

| Composant | Stack | Dossier |
|-----------|-------|---------|
| Backend API | NestJS + Prisma | `lilia-backend/` |
| **Client mobile** | **Flutter + Riverpod** | **`lilia-app/`** |
| Admin dashboard | Flutter + Riverpod | `lilia-food-admin/` |
| App livreur | Flutter + Riverpod | `lilia_food_delivery/` (com.dreesis) |

---

## Marketplace multi-vendeurs (LIL-110 → LIL-117)

Le catalogue mélange plusieurs types de vendeurs. `lib/models/vendor_type.dart` —
enum `VendorType` aligné sur le backend Prisma :

| `VendorType` | Label | Emoji |
|--------------|-------|-------|
| `RESTAURANT` | Restaurant | 🍽️ |
| `HOME_COOK` | Cuisine maison | 🥧 |
| `BAKERY` | Boulangerie | 🥐 |
| `BEVERAGE_SHOP` | Boissons | 🥤 |
| `GROCERY` | Épicerie | 🛒 |

- **Filtre par type** : `home/presentation/widgets/vendor_type_filter_bar.dart`
  (chips) + `vendor_type_badge.dart` sur les cartes vendeur. `restaurant_repo`
  passe `?vendorType=...` à `GET /products` et `GET /vendors`.
- **Catalogue filtré** : seuls les vendeurs `isActive: true, adminApproved: true`
  sont exposés (frontière backend, voir CLAUDE.local.md backend).
- **Produits typés** : `ProductType` (FOOD, BEVERAGE, PASTRY, GROCERY ; `ALCOHOL`
  existe en DB mais **jamais proposé** — pas de vente d'alcool au lancement).
- **Sur commande / précommande** : produits `madeToOrder` (cuisine maison,
  pâtisserie). Un panier = un seul mode : on n'autorise pas de mélanger des
  produits immédiats et des produits sur commande (garde-fou backend `cart` +
  UX modal de conflit côté `cart_controller` / `checkout_page`).

⚠️ Beaucoup de symboles s'appellent encore `restaurant*` (modèle `Restaurant`,
`restaurant_repo`, routes `/restaurants`) : c'est le **vendeur générique**, pas
seulement un restaurant. Ne pas renommer sans coordination cross-app.

---

## Commandes essentielles

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # après modif @riverpod
dart run build_runner watch --delete-conflicting-outputs   # dev
flutter run
flutter analyze
flutter build apk / appbundle / ios
dart run flutter_launcher_icons    # après changement logo
```

---

## Architecture

```
lib/
├── features/
│   ├── auth/              Firebase Auth + sync backend (/users/sync)
│   ├── address/           Adresses livraison
│   ├── cart/              Panier + draft orders (SharedPreferences)
│   ├── commandes/         Commandes + checkout + tracking GPS livreur
│   │   ├── data/
│   │   │   ├── checkout_controller.dart
│   │   │   ├── order_controller.dart / order_repository.dart
│   │   │   ├── promo_repository.dart
│   │   │   ├── tracking_socket_service.dart        # Socket.io /tracking (WS)
│   │   │   └── delivery_tracking_repository.dart   # WS + fallback HTTP 30s
│   │   └── presentation/
│   │       ├── checkout_page.dart
│   │       ├── commande_page.dart / commande_detail_page.dart
│   │       ├── fullscreen_tracking_screen.dart
│   │       └── widgets/driver_tracking_map.dart    # Google Maps + Geolocator
│   ├── favoris/           Restaurants favoris
│   ├── home/              Browsing restaurants + produits + bannières
│   ├── notifications/     Historique FCM + providers
│   ├── onboarding/        Écran accueil animé
│   ├── payments/          MTN MoMo + Airtel Money
│   ├── quartiers/         Zones livraison (public endpoint)
│   ├── reviews/           Avis clients (laisser/voir)
│   └── user/              Profil + parrainage + fidélité + brouillons
├── models/                Order, Product, Restaurant, AppUser, Checkout, PromoValidationResult, LoyaltyTransaction…
├── routing/               go_router (StatefulShellRoute 4 tabs)
├── services/
│   ├── analytics_service.dart      Firebase Analytics centralisé
│   ├── notification_service.dart   FCM + flutter_local_notifications
│   ├── connectivity_service.dart
│   └── location_service.dart
├── common_widgets/        BuildErrorState, etc.
├── constants/             AppConstants (baseUrl)
├── utilities/             Thème, AppColors
└── main.dart
```

### Navigation
4 tabs (StatefulShellRoute) : **Home, Cart, Commandes, Profile**. `app_route_enum.dart` définit toutes les routes. Redirects auth via `authStateChangeProvider` + `GoRouterRefreshStream`.

---

## State Management — Riverpod

- `@riverpod` / `@Riverpod(keepAlive: true)` (auth, cart, notifications)
- **`build_runner` OBLIGATOIRE** après modif fichier `@riverpod` → `.g.dart`
- Pattern : Controller (state + opérations) + Repository (HTTP) avec `Ref`

```dart
@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) { ... }

@riverpod
class OrderController extends _$OrderController {
  @override
  FutureOr<List<Order>> build() async => ...;
}
```

---

## Authentication

1. Firebase Auth (email/password + Google Sign-In `^7.2.0`)
2. À la connexion → `POST /users/sync` (firebaseUid + email + telephone? + referralCode?)
3. Toutes les requêtes API → header `Authorization: Bearer <firebase-id-token>`
4. `authStateChangeProvider` watch Firebase → redirects auto
5. Logout → invalidate cart, orders, favorites, profile, notificationHistory

iOS spécifique :
- `GIDClientID` + `CFBundleURLSchemes` (REVERSED_CLIENT_ID) dans `Info.plist`
- `GoogleSignIn.instance.initialize()` avant `authenticate()`

---

## API Communication

Base URL : `AppConstants.baseUrl` — défaut `https://lilia-backend.onrender.com`,
overridable au build via `--dart-define=API_URL=...` (staging, tunnel local).
Idem pour `wsUrl` via `--dart-define=WS_URL=...`.

```dart
final idToken = await ref.read(firebaseIdTokenProvider.future);
final response = await client.get(uri, headers: {
  'Authorization': 'Bearer $idToken',
  'Content-Type': 'application/json',
});
final decoded = json.decode(response.body);
final data = ApiResponse.mapOf(decoded);   // tolérant raw OU { data: ... }
```

### Helper `ApiResponse` (J2 — juin 2026)

`lib/utils/api_response.dart` — accepte les deux formes pendant la
migration backend vers `api-contract-v2` (interceptor global qui wrappe
TOUT en `{ data, message?, meta? }`).

- `ApiResponse.listOf(decoded)` → `List<dynamic>` (vide si payload inattendu)
- `ApiResponse.mapOf(decoded)` → `Map<String, dynamic>` (throw `StateError` sinon)

### Format des réponses backend
| Endpoint | Format actuel |
|---|---|
| `GET /restaurants` | `{ data: [...], count }` |
| `GET /restaurants/:id` | `{ data: {...} }` |
| `GET /adresses` | `{ data: [...], count }` |
| `POST /adresses` | `{ data: {...}, message }` |
| `GET /quartiers` | `{ data: [...], count }` (Public) |
| `GET /users/me` | `{ user: {...} }` → bientôt `{ data: { user: ... } }` (J2) |
| `POST /orders/checkout` | `{ message, data: {...} }` |
| `POST /promo/validate` | objet plat → bientôt `{ data: {...} }` (J2) |

⚠️ Une fois `api-contract-v2` mergé côté backend, TOUTES les réponses
seront wrappées. Utiliser `ApiResponse.listOf` / `mapOf` au lieu de
`decoded['data']` direct.

### Parsing erreurs
`_extractErrorMessage(body)` → lit `json['message']` (String ou List). Helper dans `order_repository.dart`.

### Idempotency checkout
`POST /orders/checkout` accepte header `idempotency-key` (UUID v4 généré côté client) — évite les doublons sur double-tap / retry.

---

## Order Flow — Côté client

1. Browsing restaurants → produit → add to cart
2. Checkout (`checkout_page.dart`) — `_startPaymentFlow`, **dans cet ordre** :
   - Validation adresse / téléphone / mode (livraison/retrait)
   - Application code promo via `POST /promo/validate`
   - Toggle points fidélité (visible si ≥ `loyaltyMinRedemption`)
   - `POST /orders/checkout` avec idempotency-key → la commande existe
   - `POST /payments` (2 tentatives ; l'appel est sûr à rejouer, le backend
     réutilise le `Payment` PENDING existant)
   - **puis seulement** la modale d'instructions, alimentée par
     `instructions.phone` / `.amount` / `.reference` du serveur

   ⚠️ L'ordre inverse (modale d'abord) affichait un numéro Airtel placeholder et
   un montant recalculé localement, et un échec de `POST /payments` était avalé
   dans un `debugPrint` : le client payait un virement que l'admin ne pouvait
   rattacher à rien. En cas d'échec définitif, `_showPaymentRecoveryDialog`
   propose de réessayer et l'erreur part dans Sentry.
3. **Order status** affiché en temps réel via FCM push :
   - `EN_ATTENTE → PAYER → EN_PREPARATION → PRET → EN_ROUTE → LIVRER`
   - + `ANNULER` à tout moment EN_ATTENTE/PAYER
4. À chaque notif FCM avec `data.orderId` :
   - `latestUpdatedOrderIdProvider` est setté
   - `userOrdersProvider` est invalidé → refresh auto
5. Quand `status == EN_ROUTE` → bouton "Suivre le livreur en direct" → ouvre `FullscreenTrackingScreen` ou affiche `DriverTrackingMap` inline

---

## Tracking GPS livreur (mai 2026 — WebSocket)

**WebSocket Socket.io `/tracking`** : push temps réel (<1s) + fallback HTTP 30s.

### Architecture

```
TrackingSocketService (@Riverpod keepAlive)
  ├─ Socket.io io.io('${wsUrl}/tracking', { auth: { token } })
  ├─ Transports: ['websocket', 'polling']  (polling = fallback Congo)
  ├─ Reconnexion auto (10 tentatives, backoff 2s → 10s max)
  ├─ Streams broadcast multi-orderId :
  │    watch(orderId) → { position: Stream<DriverPositionEvent>,
  │                       status:   Stream<String> }
  │    unwatch(orderId) → close streams + dispose room
  ├─ Re-watch automatique de toutes les commandes après reconnexion
  └─ reconnect() après refresh Firebase token

DriverLocationController(orderId) (@riverpod)
  ├─ Init : fetchDriverLocation HTTP → infos livreur (nom, phone) + dernière position DB
  ├─ Abonnement WS : streams.position → update state instantané (lag <1s)
  ├─ Fallback HTTP toutes les 30s (n'écrase pas une position WS plus récente)
  └─ ref.onDispose() → unwatch(orderId) + cancel subscriptions
```

### Events WebSocket

| Direction | Event | Payload | Effet UI |
|---|---|---|---|
| Client → Server | `order:watch` | `{ orderId }` | Rejoint room + reçoit dernière position |
| Server → Client | `driver:position` | `{ lat, lng, eta, timestamp }` | Update marker + badge "Arrive dans X min" |
| Server → Client | `order:status` | `{ status }` | Hook prêt (debug log pour l'instant) |

### Fichiers clés
- `lib/features/commandes/data/tracking_socket_service.dart` — service WS centralisé
- `lib/features/commandes/data/delivery_tracking_repository.dart` — `DriverLocation` (avec `etaMinutes`) + `DriverLocationController` réécrit WS+HTTP
- `lib/features/commandes/presentation/widgets/driver_tracking_map.dart` — Google Maps 2 markers (livreur orange + client bleu) + polyline pointillée + badge ETA
- `lib/features/commandes/presentation/fullscreen_tracking_screen.dart` — version plein écran avec stream Geolocator pour la position client

### Config Google Maps requise
- Android : `android/app/src/main/AndroidManifest.xml` → remplacer `YOUR_GOOGLE_MAPS_API_KEY`
- iOS : `ios/Runner/AppDelegate.swift` → remplacer `YOUR_GOOGLE_MAPS_API_KEY`
- Activer Maps SDK Android + iOS sur Google Cloud Console
- Geolocator → permission `LOCATION_WHEN_IN_USE` (fallback Brazzaville `-4.2634, 15.2429` si refus)

### Constantes (`AppConstants`)
- `baseUrl` : `https://lilia-backend.onrender.com`
- `wsUrl` : `https://lilia-backend.onrender.com` (même host, Socket.io handle l'upgrade)
- `trackingNamespace` : `/tracking`

---

## Push Notifications FCM

`lib/services/notification_service.dart` (`@Riverpod(keepAlive: true)`)

- `Firebase.initializeApp()` AVANT `ProviderScope` (main.dart)
- Top-level `firebaseMessagingBackgroundHandler` (avec `@pragma('vm:entry-point')`)
- Handlers : `onMessage` (foreground), `onMessageOpenedApp` (clic background), `getInitialMessage` (terminated)
- Canal Android : `high_importance_channel`
- Support iOS : `DarwinInitializationSettings`
- Token registré via `POST /notifications/register-token` (5 retries backoff 15s)
- Token supprimé au logout via `DELETE /notifications/token`
- `_fetchFcmToken()` retente `getToken()` toutes les 500 ms pendant 10 s tant
  qu'APNs répond `apns-token-not-set`, puis renonce (simulateur iOS)
- `onTokenRefresh` → re-register
- Quand `data.orderId` reçu → `latestUpdatedOrderIdProvider` + invalidate `userOrdersProvider`

### iOS — les 4 conditions d'un push qui arrive (août 2026)

Les push n'ont jamais fonctionné sur iOS jusqu'à cette date. **Le simulateur ne
permet pas de le diagnostiquer** : il n'a pas d'APNs du tout, et le message
« APNS not available (simulator?) » s'affiche aussi sur un appareil réel en
panne. Toujours tester sur iPhone physique.

Les quatre maillons, dans l'ordre où ils cassent :

1. **`aps-environment` dans les entitlements de la config compilée.** `flutter
   run` compile en **Debug** — l'entitlement ne vivait que sur Release, donc
   aucun enregistrement APNS. `Runner.entitlements` (Debug + Profile) et
   `RunnerRelease.entitlements` (Release) doivent tous deux exister.
2. **Attendre le token APNS.** Son obtention est asynchrone et n'est pas
   terminée quand `init()` s'exécute au premier lancement. Un `getToken()`
   unique échoue et perd le token pour toute la session — d'où le retry.
3. **Le bundle ID doit être identique partout** : les 6
   `PRODUCT_BUNDLE_IDENTIFIER` du projet Xcode, `GoogleService-Info.plist` et
   `iosBundleId` dans `firebase_options.dart`. Actuellement
   `com.dreesis.lilia.liliaApp`. Changer le bundle crée une **app iOS
   distincte** : nouvelle installation, session Firebase Auth perdue.
4. **Clé APNs valide dans la console Firebase** (Cloud Messaging → *Apple app
   configuration*). Sans elle, FCM accepte le message puis Apple le rejette.
   Le code d'erreur remonté par le backend distingue les cas :
   - `Request is missing required authentication credential` → aucune clé
   - `Invalid APNs credential` → clé présente mais refusée (Key ID / Team ID
     mal saisis, clé révoquée, ou `.p8` sans capability APNs).
     **Team ID de signature : `4R7BCB3ZSZ`.**

**Diagnostiquer sans passer commande** : `NotificationsService` loggue
`Échec envoi FCM — user X, code=…`. Pour reproduire hors backend, un script
Firebase Admin qui envoie sur un token de la table `FcmToken` donne le code
exact en quelques secondes (voir l'historique de la session du 2026-08-06).
⚠️ Un token accepté côté Android et refusé côté iOS avec les **mêmes**
credentials isole le problème sur APNs, pas sur Firebase.

---

## Pricing & Calculs

⚠️ **Le client ne fait plus autorité sur les montants** (août 2026). Il calcule
une **estimation** avant commande ; le montant dû est celui de la commande créée
par le serveur (`order.total`), repris tel quel dans la modale de paiement.

- `lib/features/commandes/domain/checkout_estimate.dart` — `CheckoutEstimate
  .compute()`, logique pure et testée (13 tests), qui reproduit
  `OrderCheckoutService` étape par étape.
- `lib/features/settings/data/platform_settings_service.dart` —
  `platformSettingsProvider` lit `GET /platform-settings` (public) :
  `serviceFeePercent`, `loyaltyPointValueXaf`, `loyaltyMinRedemption`. Fallback
  local aligné sur les défauts Prisma si le réseau est indisponible.

Trois divergences avec le serveur ont été corrigées à cette occasion :
1. taux de commission codé en dur à 8 % alors que l'admin peut le changer ;
2. arrondi de la fidélité — le serveur convertit en points entiers
   (`floor(dû / 5)`), le client plafonnait à la valeur brute : sur 703 FCFA dus,
   il affichait 0 à payer quand le serveur en facturait 3 ;
3. frais de livraison de repli à 500 FCFA côté client contre 1000 côté serveur
   (`kDefaultDeliveryFee` dans `models/restaurant.dart`), désormais aligné et
   signalé à l'écran par « Estimation — montant confirmé à la commande ».

Affichage côté checkout : ligne sous-total, frais livraison (avec "Gratuit" barré si FREE_DELIVERY), frais de service (taux servi par le backend), réduction promo (verte), réduction points fidélité, total.

✅ **commande_detail_page** affiche maintenant subTotal, deliveryFee (si `isDelivery`), serviceFee, discountAmount (verte avec icône `local_offer`, si > 0), total — aligné checkout (mai 2026).

---

## Promo Codes

- `lib/models/promo_validation_result.dart` — `PromoValidationResult` + enum `DiscountType` (fixed, percent, freeDelivery) + getter `discountLabel`
- `lib/features/commandes/data/promo_repository.dart` — `POST /promo/validate`
- UI : `checkout_page.dart` champ "Code promo" + "Appliquer" → badge vert validé
- Code envoyé dans body `POST /orders/checkout` `{ promoCode: "BIENVENUE500" }`

---

## Points de fidélité + Parrainage

- `AppUser` : `referralCode String?`, `loyaltyPoints int`
- `lib/models/loyalty_transaction.dart` : `LoyaltyTransaction` + `ReferralStats`
- `UserRepository.getReferralStats()` → `GET /users/me/referral-stats`
- `UserRepository.getLoyaltyTransactions()` → `GET /users/me/loyalty`
- Providers : `referralStatsProvider`, `loyaltyTransactionsProvider` (dans `profile_controller.dart`)
- UI : carte orange dans `user_page.dart` (balance + historique) + toggle dans `checkout_page.dart`
- Signup : champ "Code de parrainage (optionnel)" → passé au sync
- Règles : 1 pt = 5 FCFA, min 100 pts, gagne 1 pt par 100 FCFA à LIVRER, +500 parrain / +200 filleul à la 1ère commande

---

## Stock côté UI

Dans `restaurant_detail_screen.dart` / `product_detail_page.dart` :
- `product.isAvailable = stockRestant == null || stockRestant! > 0`
- `null` = illimité, `0` = épuisé
- Si épuisé : `Opacity(0.5)`, badge rouge "Épuisé", bouton add-to-cart désactivé
- Le backend rejette aussi côté serveur (`BadRequestException` en checkout)

---

## Reviews

`lib/features/reviews/` (mai 2026)
- `review_repository.dart` : `GET /reviews/restaurant/:id`, `POST /reviews`, `GET /reviews/can-review/:id`, stats
- Providers : `restaurantReviewsProvider`, `restaurantStatsProvider`, `canReviewProvider`, `submitReviewProvider`
- Screens : `reviews_screen.dart` (stats + liste + bouton), `write_review_screen.dart` (note 1-5 + commentaire)
- Règle : seul un client avec commande LIVRER pour ce restaurant peut laisser un avis. 1 avis max par user/resto.

---

## Reorder 1-clic

- `OrderRepository.reorder(orderId)` → `POST /orders/:id/reorder` (recopie items dans le panier)
- Bouton "Recommander" dans `commande_page.dart` + `commande_detail_page.dart` (statuts LIVRER ou ANNULER)
- Redirect vers `/cart`

---

## Draft orders

- `lib/models/draft_order.dart` + `lib/features/cart/application/draft_orders_provider.dart`
- Persistance via `SharedPreferences` (`@Riverpod(keepAlive: true) DraftOrdersNotifier`)
- Bouton "Enregistrer pour plus tard" dans `checkout_page.dart` → vide panier + dépile checkout + navigue vers liste brouillons
- Écran `draft_orders_screen.dart` (route `draft-orders` sous profile)
- Restore : recharge items dans le panier

---

## Firebase Analytics

`lib/services/analytics_service.dart` — service centralisé. `AnalyticsService.observer` ajouté au GoRouter (tracking automatique des écrans).

Événements trackés : `purchase`, `order_created`, `order_failed`, `order_cancelled`, `begin_checkout`, `add_to_cart`, `view_item`, `restaurant_viewed`, `login`/`sign_up`, `add_favorite`/`remove_favorite`.

---

## Gotchas

- `Firebase.initializeApp()` avant `ProviderScope`
- `GoogleSignIn.instance.initialize()` avant `authenticate()`
- Cart broadcast stream → check `_isClosed` avant `add()`
- Invalidate TOUS les providers user au logout
- `build_runner` après modif `@riverpod`
- Product navigation via `extra` — gérer null (URL directe)
- Out-of-stock products (`stockRestant == 0`) — bloquer côté UI
- iOS push : APNs cert requis dans Firebase Console (compte Developer)
- Rebuild natif après modif `Info.plist` / `Podfile`
- Connexion par mot de passe : sync backend non-bloquant en background (8s timeout) pour mettre à jour `lastLogin`

---

## Dépendances clés

```yaml
flutter_riverpod: ^3.3.1
riverpod_annotation: ^4.0.0
riverpod_generator: ^4.0.0+1
go_router: ^17.2.3
firebase_auth: ^6.4.0
firebase_core: ^4.7.0
firebase_messaging: ^16.2.0
firebase_analytics: ^12.3.0
google_sign_in: ^7.2.0
http: ^1.6.0
socket_io_client: ^3.1.2    # WebSocket tracking
flutter_local_notifications: ^21.0.0
google_maps_flutter: ^2.10.0
geolocator: ^13.0.4
shared_preferences: ^2.5.5
cloudinary_public: ^0.23.1
intl: ^0.20.2
iconsax: ^0.0.8
url_launcher: ^6.3.1
connectivity_plus: ^7.1.1
carousel_slider: ^5.1.2
share_plus: ^12.0.1
google_fonts: ^8.1.0
```

---

## Corrections appliquées (mai 2026)

1. ✅ **WebSocket Socket.io** : migration complète tracking (polling 10s → WS <1s). `TrackingSocketService` + `DriverLocationController` réécrit
2. ✅ **ETA temps réel** affichée dans `_DriverInfo` (badge `Arrive dans X min`)
3. ✅ **`commande_detail_page._buildSummaryCard`** : affiche maintenant serviceFee + discountAmount (cohérence avec checkout)
4. ✅ **Constantes** `wsUrl` + `trackingNamespace` ajoutées dans `AppConstants`

## Corrections robustesse (audit juin 2026)

1. ✅ **`commande_detail_page`** : `firstWhere(orElse: throw)` → recherche null-safe + UI « Commande introuvable » (plus de crash si on arrive via deep-link/notif sur une commande hors liste).
2. ✅ **`draft_orders_provider.restoreDraft`** : recherche null-safe (plus de `StateError` si le brouillon a disparu).
3. ✅ **`review.dart`** : parsing défensif (`as num?`, `tryParse`, fallbacks) — un restaurant sans avis ne crashe plus l'écran de stats.
4. ✅ **`NotificationService._handleNotificationData`** : switch `data['type']` mort supprimé, cast `orderId` null-safe.
5. ✅ **`driver_tracking_map.dart`** : duplication `_FullscreenMapView`/`_MapView` factorisée via helpers partagés (`_buildTrackingMarkers`, `_buildRoutePolyline`, `_initialMapCenter`).

## Performance (juin 2026)

1. ✅ **LIL-37 — Cache image** : `Image.network` → `AppCachedImage` /
   `AppCachedAvatar` (`common_widgets/app_cached_image.dart`) basé sur
   `cached_network_image`. Cache disque dédié `LiliaImageCache` (30 j, 400
   objets) + cache mémoire plafonné 100 MB (`configureMemoryCache()` dans
   `main()`). Placeholder shimmer auto-contenu (`AppShimmerBox`, sans dép.) +
   error widget cohérent. Économise la data 4G et fluidifie le scroll.
2. ✅ **Parsing JSON sur isolate** (`utils/json_isolate.dart`) : `parseJson()`
   déporte `jsonDecode` + mapping sur un isolate via `compute` au-delà de
   ~40 KB. Appliqué aux grosses listes : vendeurs (`restaurant_repo`), produits
   / recommandations / recherche (`home_repo`), commandes (`order_repository`).
   ⚠️ Le parser passé doit être **top-level/statique** (contrainte isolate).
3. ✅ **Compression image sur isolate** (`utils/image_compressor.dart`) :
   `ImageCompressor.compress()` (package `image`, pur Dart → `compute`)
   redimensionne ≤1280px + ré-encode JPEG 80 avant upload Cloudinary
   (`cloudinary_service`). Ne gèle plus l'UI, réduit la data envoyée.
4. ✅ **Tests de perf automatisés** : `integration_test/perf_test.dart` +
   `test_driver/perf_driver.dart` (login, scroll home, navigation 4 onglets,
   montée en charge). Mesure FPS / jank / réseau. Cf. `PERF_TESTING.md`.
   `signin_page` a des `Key` (`signin_email`/`password`/`submit`) pour le drive.

## Remédiation audit (août 2026 — `AUDIT_2026-08-01.md`)

1. ✅ **Clé Google Maps iOS sortie du code** (E-4). Elle était en dur dans
   `AppDelegate.swift`. Nouveau pattern (copié de `lilia_food_delivery`) :
   - `ios/Flutter/MapsKeys.xcconfig` — **template committé**, valeur bidon
     (`GOOGLE_MAPS_API_KEY=YOUR_GOOGLE_MAPS_API_KEY`)
   - `ios/Flutter/MapsKeys.local.xcconfig` — **valeur réelle, gitignorée**
   - `Debug.xcconfig` / `Release.xcconfig` font `#include "MapsKeys.xcconfig"`
     puis `#include? "MapsKeys.local.xcconfig"` (le `?` = optionnel, donc le
     build passe sans le fichier local ; le local écrase le template)
   - `Info.plist` lit `$(GOOGLE_MAPS_API_KEY)`, `AppDelegate.swift` la récupère
     depuis le bundle
   - ⚠️ **Reste à faire côté ops** : la clé `AIzaSyDnEX…` est dans l'historique
     git — à **révoquer**, remplacer par 3 clés restreintes (une par app) avec
     quota.
2. ✅ **Keystore retiré du dépôt** (C-1) — `upload-keystore.jks` sorti de l'index
   (`git rm --cached`, fichier local préservé). `.gitignore` durci : `*.jks`,
   `*.keystore`, `/android/key.properties`, `/android/build/`, `/android/app/build/`.
   ⚠️ Il reste dans l'historique git → rotation du keystore + Play App Signing à
   décider.
3. ✅ **Dépendances alignées** sur les 3 apps Flutter : `firebase_core ^4.10.0`,
   `firebase_auth ^6.5.2`, `firebase_messaging ^16.3.0`, `flutter_riverpod
   ^3.3.2`, `riverpod_annotation ^4.0.3`, `go_router ^17.3.0`, `dio ^5.9.2`,
   `google_maps_flutter ^2.17.1`, `flutter_local_notifications ^22.0.1`,
   `image ^4.9.1`. `build_runner` régénéré. Version app **1.2.4+29**.
4. ✅ **`RadioListTile` déprécié → `RadioGroup`** (`delivery_options_page.dart`) —
   `groupValue`/`onChanged` par tuile sont dépréciés en Flutter 3.4x ; l'état est
   maintenant porté par un `RadioGroup` parent.
5. ✅ **Garde `mounted`** ajoutée avant les `setState` post-`await`.
6. ✅ **`import 'dart:typed_data'` inutile** retiré de `api_client.dart` (déjà
   exporté par `foundation.dart`).
7. ✅ **`test/widget_test.dart`** supprimé — c'était encore le template Flutter
   (compteur), il ne testait rien de l'app.
8. ✅ **Encodage** — accents réparés dans plusieurs libellés (`vendor_type.dart`,
   `location_service.dart`, `delivery_tracking_repository.dart`).

Résultat : `flutter analyze` **0 erreur / 0 warning**, tests **40/40**.

### Tests de non-régression ajoutés

- `test/features/commandes/delivery_options_page_test.dart` — 6 widget tests sur
  le `RadioGroup` refait (providers `cart` / `quartiers` / `adresses` /
  `restaurant` surchargés, aucun appel réseau) : présence du `RadioGroup<bool>`,
  livraison par défaut, bascule retrait aller-retour, retrait masqué pour
  `HOME_COOK`, panier vide.
- `integration_test/audit_smoke_test.dart` — smoke on-device (démarrage,
  session, navigation des 4 onglets, écran mode de livraison). **S'arrête avant
  le checkout** et se saute si le panier est vide : ne mute jamais la prod.
  ```bash
  flutter test integration_test/audit_smoke_test.dart -d <device-id> \
    --dart-define=API_URL=https://lilia-backend.onrender.com \
    --dart-define=WS_URL=https://lilia-backend.onrender.com
  ```

⚠️ **Ne pas utiliser `pumpAndSettle` dans ces tests** : le carrousel de
bannières de la home s'auto-défile, l'arbre ne se stabilise donc jamais. Et son
premier argument est l'**intervalle entre frames**, pas un timeout — le timeout
vaut 10 minutes par défaut. Pomper sur un budget de temps réel borné.

⚠️ **`analysis_options.yaml` exclut `build/**`** : le checkout SwiftPM des
plugins y dépose leurs apps d'exemple (`build/macos/SourcePackages/
firebase_auth-*/example/`), ce qui remontait 122 erreurs étrangères au projet.

---

## Dettes techniques restantes

1. Les onglets `Favoris` et `commandes_page` rafraîchissent leurs providers manuellement après notification FCM — pas un bug, mais à surveiller (potentiellement double-load).
2. **Event `order:status`** reçu via WS mais juste loggué (debug). Pourrait invalider `userOrdersProvider` directement (actuellement géré via FCM).

---

## Remédiation audit (27 août 2026 — `AUDIT_2026-08-27_client_backend.md`)

`flutter analyze` **0 issue** (modes stricts activés), **75 tests** verts
(40 avant), build APK ✅.

1. **Flux de paiement** (S2/S3/S4) — cf. Order Flow et Pricing ci-dessus. Les
   constantes `mtnMomoPaymentNumber`, `airtelMoneyPaymentNumber` et
   `serviceFeeRate` ont quitté `AppConstants` : elles viennent du serveur.
2. **Accessibilité** (A1) — l'app comptait **0** `Semantics`, **0**
   `semanticLabel` et 2 tooltips pour 31 `IconButton` :
   - 25 `tooltip:` ajoutés (Flutter en dérive le label sémantique) ;
   - `AppCachedImage` / `AppCachedAvatar` acceptent un `semanticLabel` ; sans
     lui l'image est **masquée** aux lecteurs d'écran (décorative) ;
   - cartes vendeur et produit enveloppées de `Semantics(button:, label:)` —
     l'état « fermé » / « épuisé » n'était porté que par `Opacity` et une
     couleur, donc muet pour TalkBack / VoiceOver ;
   - `test/a11y/accessibility_guidelines_test.dart` exécute les 4 guidelines de
     `flutter_test` (tap targets Android + iOS, contraste, cibles étiquetées).
3. **Contrastes WCAG AA** (A2) — 4 combinaisons étaient sous le seuil, dont le
   fond de **tous** les boutons d'action (3.67:1 en clair, 2.84:1 en sombre) :
   - `actionPrimary` clair : `orange500` → `orange600` (blanc : 4.94:1) ;
   - nouveau token **`textOnAction`** — en sombre l'action est un orange clair
     sur lequel le blanc est illisible ; on y pose un texte foncé (6.20:1).
     Ne jamais remettre `Colors.white` en dur sur un bouton ;
   - `textMuted` : `charcoal450` (#6E665F) en clair, `charcoal300` en sombre ;
   - `onTertiary`, `onPrimary` et l'action du snackbar corrigés aussi.
   - `test/theme/contrast_test.dart` calcule les ratios et casse la CI à la
     moindre régression de palette.
4. **Lint** (Q2) — `riverpod_lint` était déclaré depuis des mois **sans jamais
   s'exécuter**. Il utilise désormais le bloc `plugins:` d'`analysis_options.yaml`
   (il ne passe plus par `custom_lint` depuis la 3.1). Modes stricts activés
   (`strict-casts`, `strict-inference`, `strict-raw-types`) : **195 problèmes**
   remontés, tous corrigés — l'essentiel étant du `json['x']` dynamique passé
   sans cast aux constructeurs de modèles.
5. **Tests** (Q3) — la logique monétaire n'était pas couverte :
   `checkout_estimate_test.dart` (13), `payment_instructions_test.dart` (7),
   `contrast_test.dart` (9), `accessibility_guidelines_test.dart` (6).
6. **Polices embarquées** — Inter, Oswald, Fraunces et Girassol sont bundlées
   dans `assets/fonts/` (licences OFL conservées) et
   `GoogleFonts.config.allowRuntimeFetching = false` dans `main()`. Elles
   étaient téléchargées depuis `fonts.gstatic.com` au premier lancement :
   latence au démarrage sur la 4G de Brazzaville, polices de repli hors ligne,
   et dépendance réseau à un tiers.
7. **Code mort** — `widgets/section/fallback_slider.dart` (widget vide jamais
   utilisé) supprimé.

---

## Adresse géolocalisée (1er septembre 2026)

**Règle** : la destination d'une commande appartient à **l'adresse choisie**,
jamais à la position du téléphone.

`checkout_controller.placeOrder` **n'envoie plus aucune coordonnée**. Il lisait
`locationService.lastPosition` — le GPS du téléphone au moment de payer — et le
passait en `deliveryLatitude`/`deliveryLongitude` : commander depuis son bureau
pour une livraison à domicile envoyait le livreur au bureau. La destination est
résolue côté serveur depuis l'`adresseId`. **Ne pas rétablir l'envoi de
coordonnées** : elles seraient ignorées, et la tentation de s'y fier reviendrait.

### `LocationPickerPage`

`features/address/presentation/pages/location_picker_page.dart` — repère **fixe
au centre**, carte qui glisse dessous. Un marqueur qu'on fait glisser au doigt
est masqué par ce doigt au moment de viser. Le repère est décalé d'une
demi-hauteur pour que sa **pointe** tombe sur le centre géométrique, sans quoi
le point enregistré est systématiquement au sud du point visé.

Le bouton « Utiliser ma position » n'est qu'une **aide au cadrage** : le repère
reste déplaçable, et c'est le centre final qui est confirmé. Sur Android 12+
une autorisation « approximative » rend un point à 1–3 km — sans ce déplacement
possible, l'adresse serait fausse sans que personne le sache.

⚠️ **Aucun géocodage inverse.** Testé le 01/09 sur cinq points de Brazzaville :
Google rend un Plus Code (`P6PV+J5`) trois fois sur cinq. La position est la
donnée primaire, l'adresse textuelle reste celle que le client écrit.

Le bouton de confirmation reste désactivé tant que le client n'a ni déplacé la
carte ni utilisé son GPS : un tap distrait ne doit pas enregistrer le cadrage
par défaut comme si c'était une adresse.

### `LocationService` — ce qu'il n'est plus

Plus d'initialisation au démarrage, plus de « dernière position connue ». Les
deux se tenaient : la position mise en cache au lancement servait de destination.

Il expose `currentPosition()` à la demande, avec un motif de refus explicite
(`serviceDisabled` / `denied` / `deniedForever` / `timeout`) — le `catch (_) {}`
précédent avalait tout, et le client ne savait jamais pourquoi rien ne marchait.
Corollaire : la permission est demandée **au moment où elle sert**, sur un écran
qui explique pourquoi, et non sur l'écran de démarrage.

### Formulaire d'adresse

Quartier **obligatoire** (il porte les frais de zone et le centroïde de repli),
étape carte, champ de repères pour le livreur. « Congo » a disparu : toutes les
livraisons y sont.

Les adresses créées avant cette évolution affichent « Non située — appuyez pour
la placer sur la carte » et se complètent via `PATCH /adresses/:id`.

### `LocationPrecision`

`models/location_precision.dart` — `exact` / `approximate` / `unknown`, miroir
de l'enum Prisma. Toute valeur inconnue (y compris `null`) devient `unknown` :
le repli fait **taire** la carte au lieu de la faire mentir.

`driver_tracking_map` ne pose plus de marqueur sans position, et ne demande plus
le GPS du client pour deviner sa propre destination.
