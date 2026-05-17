# CLAUDE.md — Lilia App (Client)

App **client** Flutter de la plateforme Lilia Food (Brazzaville, Congo). Rôle `CLIENT`.

**Backend URL** : `https://lilia-backend.onrender.com`

## Écosystème

| Composant | Stack | Dossier |
|-----------|-------|---------|
| Backend API | NestJS + Prisma | `lilia-backend/` |
| **Client mobile** | **Flutter + Riverpod** | **`lilia-app/`** |
| Admin dashboard | Flutter + Riverpod | `lilia-food-admin/` |
| App livreur | Flutter + Riverpod | `lilia_food_delivery/` (com.dreesis) |

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

Base URL : `https://lilia-backend.onrender.com`

```dart
final idToken = await ref.read(firebaseIdTokenProvider.future);
final response = await client.get(uri, headers: {
  'Authorization': 'Bearer $idToken',
  'Content-Type': 'application/json',
});
final data = json.decode(response.body)['data'];
```

### Format des réponses backend
| Endpoint | Format |
|---|---|
| `GET /restaurants` | `{ data: [...], count }` |
| `GET /restaurants/:id` | `{ data: {...} }` |
| `GET /adresses` | `{ data: [...], count }` |
| `POST /adresses` | `{ data: {...}, message }` |
| `GET /quartiers` | `{ data: [...], count }` (Public) |
| `GET /users/me` | `{ user: {...} }` |
| `POST /orders/checkout` | `{ message, data: {...} }` |
| `POST /promo/validate` | objet plat |

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

## Dettes techniques restantes

1. **`NotificationService._handleNotificationData`** : switch sur `data['type']` avec cases vides (`'order_update'`, `'message'`) — code mort à supprimer ou implémenter.
2. **`fullscreen_tracking_screen`** duplique une grande partie de `driver_tracking_map.dart` (`_FullscreenMapView` vs `_MapView`). Factoriser.
3. Les onglets `Favoris` et `commandes_page` rafraîchissent leurs providers manuellement après notification FCM — pas un bug, mais à surveiller (potentiellement double-load).
4. **Event `order:status`** reçu via WS mais juste loggué (debug). Pourrait invalider `userOrdersProvider` directement (actuellement géré via FCM).
