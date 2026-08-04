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
2. Checkout (`checkout_page.dart`) :
   - Validation adresse / téléphone / mode (livraison/retrait)
   - Application code promo via `POST /promo/validate`
   - Toggle points fidélité (visible si ≥ 100 pts, 1 pt = 5 FCFA, tous consommés d'un coup)
   - `POST /orders/checkout` avec idempotency-key
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
- Skip gracieux si APNs indisponible (simulateur iOS — code `apns-token-not-set`)
- `onTokenRefresh` → re-register
- Quand `data.orderId` reçu → `latestUpdatedOrderIdProvider` + invalidate `userOrdersProvider`

---

## Pricing & Calculs

```dart
serviceFee = (subTotal * 0.08).roundToDouble();      // 8%
total = subTotal + deliveryFee + serviceFee - discountAmount;
// discountAmount = promo + (loyaltyPoints * 5 FCFA si useLoyaltyPoints)
```

Affichage côté checkout : ligne sous-total, frais livraison (avec "Gratuit" barré si FREE_DELIVERY), frais service 8%, réduction promo (verte), réduction points fidélité, total.

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

Résultat : `flutter analyze` **0 erreur / 0 warning**, tests **34/34**.

---

## Dettes techniques restantes

1. Les onglets `Favoris` et `commandes_page` rafraîchissent leurs providers manuellement après notification FCM — pas un bug, mais à surveiller (potentiellement double-load).
2. **Event `order:status`** reçu via WS mais juste loggué (debug). Pourrait invalider `userOrdersProvider` directement (actuellement géré via FCM).
