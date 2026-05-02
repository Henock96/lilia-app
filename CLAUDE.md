# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Lilia App is a Flutter e-commerce mobile application for restaurant ordering. The app uses Firebase Authentication for user management and communicates with a backend API at `https://lilia-backend.onrender.com`. The architecture follows a feature-first organization with Riverpod for state management and go_router for navigation.

## Development Commands

### Setup and Dependencies
```bash
# Install dependencies
flutter pub get

# Generate code (for Riverpod providers and routing)
dart run build_runner build --delete-conflicting-outputs

# Watch mode for continuous code generation during development
dart run build_runner watch --delete-conflicting-outputs
```

### Running the Application
```bash
# Run on default device
flutter run

# Run on specific device
flutter devices  # List available devices
flutter run -d <device-id>

# Run in release mode
flutter run --release
```

### Code Analysis and Testing
```bash
# Analyze code for issues
flutter analyze

# Run tests
flutter test

# Run specific test file
flutter test test/widget_test.dart
```

### Building
```bash
# Build APK (Android)
flutter build apk

# Build App Bundle (Android)
flutter build appbundle

# Build iOS app
flutter build ios

# Update app icons (after modifying logo1.jpg)
dart run flutter_launcher_icons
```

## Architecture Overview

### State Management Pattern
The app uses **Riverpod** with code generation (`riverpod_annotation`) for state management:
- Controllers expose streams or state using `@riverpod` annotation
- Repositories are provided via Riverpod providers
- All generated files end with `.g.dart` and are created by `build_runner`

### Feature-Based Structure
```
lib/
â”œâ”€â”€ features/           # Feature modules
â”‚   â”œâ”€â”€ auth/          # Authentication (Firebase Auth + backend sync)
â”‚   â”œâ”€â”€ cart/          # Shopping cart functionality
â”‚   â”œâ”€â”€ commandes/     # Order management
â”‚   â”œâ”€â”€ favoris/       # Favorites/wishlist
â”‚   â”œâ”€â”€ home/          # Restaurant browsing
â”‚   â”œâ”€â”€ notifications/ # Push notifications (FCM)
â”‚   â”œâ”€â”€ payments/      # Payment processing
â”‚   â””â”€â”€ user/          # User profile and settings
â”œâ”€â”€ models/            # Shared data models
â”œâ”€â”€ routing/           # Go router configuration
â”œâ”€â”€ services/          # App-wide services (notifications)
â”œâ”€â”€ common_widgets/    # Reusable UI components
â”œâ”€â”€ utilities/         # Themes, colors, styles
â””â”€â”€ main.dart
```

### Authentication Flow
1. Firebase Authentication is the source of truth for auth state
2. On successful Firebase auth, user data is synced to backend at `/auth/register`
3. All API calls use Firebase ID token in `Authorization: Bearer <token>` header
4. The `authStateChangeProvider` drives navigation redirects via go_router
5. On sign out, all user-related providers are invalidated (cart, orders, favorites, profile)

### Navigation Structure
- Uses `go_router` with `StatefulShellRoute` for bottom navigation
- 4 main tabs: Home, Cart, Orders (Commandes), Profile
- Routes defined in `AppRoutes` enum (lib/routing/app_route_enum.dart)
- Auth state changes trigger automatic redirects to signin or home
- Product detail pages receive Product objects via `state.extra`

### Data Layer Pattern
Each feature follows a consistent pattern:
- **Repository**: Handles HTTP requests, uses Firebase ID token for auth
- **Controller**: Riverpod notifier that manages state and exposes operations
- **Provider**: Generated Riverpod provider (`.g.dart` files)

Example: Cart feature
- `CartRepository`: Manages cart API calls and streams cart state
- `CartController`: Exposes cart stream and operations (add, remove, update)
- `cartControllerProvider`: Auto-generated provider for the controller

### API Communication
- Base URL: `https://lilia-backend.onrender.com`
- All authenticated endpoints require `Authorization: Bearer <firebase-token>`
- Responses are JSON-encoded
- Cart, orders, and user operations refresh their respective streams after mutations

### Code Generation Requirements
After modifying files with `@riverpod` annotations or adding new routes:
1. Run `dart run build_runner build --delete-conflicting-outputs`
2. Generated files include `*.g.dart` (controllers, providers, repositories)
3. Router is also code-generated: `app_router.g.dart`

### Push Notifications
- Firebase Cloud Messaging (FCM) integration via `NotificationService`
- Background handler: `_firebaseMessagingBackgroundHandler` (top-level function)
- Tokens registered to backend at `/notifications/register-token`
- Handles foreground, background, and terminated app states
- Order updates via notifications trigger `latestUpdatedOrderIdProvider` and refresh orders

### Stock Management (Client-Side)
Products and menus support stock tracking. Key fields and behavior:
- `Product` model (`lib/models/produit.dart`): `int? stockRestant` + `bool get isAvailable`
- `stockRestant == null` means unlimited stock; `stockRestant == 0` means out of stock
- `restaurant_detail_screen.dart`: Unavailable products are displayed with:
  - 50% opacity (`Opacity` widget)
  - Red "Epuise" badge on the product image
  - Add-to-cart button replaced by a red "Epuise" text badge
  - Price text greyed out
- Backend rejects orders containing out-of-stock products with `BadRequestException`
- Stock is reset daily by a backend cron job (5h UTC+1)

### Common Gotchas
- Firebase must be initialized before creating ProviderScope in main.dart
- Google Sign In requires initialization: `await GoogleSignIn.instance.initialize()`
- Cart repository uses broadcast stream controller - must check `_isClosed` before adding events
- When user signs out, invalidate all user-specific providers to clear cached data
- Product navigation passes objects via `extra` - handle null case for direct URL access
- Out-of-stock products (`stockRestant == 0`) must not be added to cart - check `product.isAvailable` before allowing add-to-cart actions

### Theme and Styling
- Custom theme defined in `lib/theme/app_theme.dart`
- Colors centralized in `lib/utilities/colors.dart`
- Uses Google Fonts (`google_fonts` package)
- Custom Lora font family loaded from assets

### Assets
- Images: `assets/images/`
- Fonts: `assets/fonts/lora/`
- App icon: `assets/images/logo1.jpg` (configured in pubspec.yaml for launcher icons)

## Key Dependencies
- `flutter_riverpod`: State management
- `riverpod_annotation` + `riverpod_generator`: Code generation for providers
- `go_router`: Declarative routing with deep linking
- `firebase_auth`, `firebase_core`, `firebase_messaging`: Firebase integration
- `firebase_analytics`: Event tracking et suivi utilisateur
- `http`: HTTP client for backend API calls
- `flutter_local_notifications`: Local notification display
- `google_sign_in`: Google authentication
- `shared_preferences`: Local key-value storage
- `cloudinary_public`: Image upload service
- `build_runner`: Code generation tool

---

## Modifications - FÃ©vrier 2026

### 1. Messages d'erreur backend propres
**Fichiers modifiÃ©s:**
- `lib/features/commandes/data/order_repository.dart` - Ajout de `_extractErrorMessage()` pour parser les rÃ©ponses JSON du backend NestJS et extraire le champ `message`. Les erreurs affichÃ©es sont maintenant en franÃ§ais clair au lieu de JSON brut.
- `lib/features/commandes/presentation/checkout_page.dart` - Remplacement du SnackBar rouge par `_showOrderError()` qui affiche un AlertDialog avec icÃ´ne contextuelle selon le type d'erreur (restaurant fermÃ©, stock Ã©puisÃ©, montant minimum, session expirÃ©e, etc.)
- `lib/common_widgets/build_error_state.dart` - AmÃ©lioration de `_formatError()` pour extraire les messages JSON et nettoyer les prÃ©fixes techniques
- `lib/features/user/data/adresse_repository.dart` - Messages d'erreur en franÃ§ais clair

**Messages d'erreur backend reconnus:**
| Erreur backend | IcÃ´ne | Titre affichÃ© |
|---|---|---|
| "fermÃ©" | store | Restaurant fermÃ© |
| "rupture/stock" | remove_shopping_cart | Produit indisponible |
| "minimum/montant" | monetization_on | Montant insuffisant |
| "panier vide" | shopping_cart | Panier vide |
| "adresse" | location_off | ProblÃ¨me d'adresse |
| "reconnecter" | lock | Session expirÃ©e |

### 2. Firebase Analytics intÃ©grÃ©
**Fichier crÃ©Ã©:**
- `lib/services/analytics_service.dart` - Service centralisÃ© pour tous les Ã©vÃ©nements analytics

**Fichiers modifiÃ©s:**
- `lib/main.dart` - Initialisation des propriÃ©tÃ©s utilisateur (country: CG, currency: XAF)
- `lib/routing/app_router.dart` - Ajout de `AnalyticsService.observer` au GoRouter pour le tracking automatique des Ã©crans
- `lib/features/auth/controller/auth_controller.dart` - logLogin/logSignUp (email, google)
- `lib/features/commandes/presentation/checkout_page.dart` - logBeginCheckout, logOrderCreated, logOrderFailed
- `lib/features/commandes/data/order_controller.dart` - logOrderCancelled
- `lib/features/home/presentation/home.dart` - logFavoriteToggle
- `lib/features/home/presentation/restaurant_detail_screen.dart` - logRestaurantViewed, logAddToCart
- `lib/features/home/presentation/product_detail_page.dart` - logProductViewed, logAddToCart

**Ã‰vÃ©nements trackÃ©s:**
| Ã‰vÃ©nement | ParamÃ¨tres |
|---|---|
| `order_created` + `purchase` | order_id, total, payment_method, is_delivery, restaurant_id, item_count |
| `order_failed` | error_message, payment_method, is_delivery |
| `order_cancelled` | order_id |
| `begin_checkout` | total, is_delivery |
| `restaurant_viewed` | restaurant_id, restaurant_name |
| `add_to_cart` (standard GA) | product_id, product_name, price, quantity, restaurant_id |
| `view_item` (standard GA) | product_id, product_name, price |
| `login` / `sign_up` | method (email/google) |
| `add_favorite` / `remove_favorite` | restaurant_id, restaurant_name |
| Tracking automatique des Ã©crans via GoRouter observer |

### 3. Shimmer loading pour les banniÃ¨res
**Fichier modifiÃ©:**
- `lib/features/home/presentation/home.dart` - Remplacement des images par dÃ©faut pendant le chargement par un effet shimmer animÃ© (`_ShimmerBannerPlaceholder`) avec gradient animÃ© et placeholders de texte

---

## Modifications - Mars 2026

### 1. NumÃ©ro de tÃ©lÃ©phone dans les commandes (contactPhone)
Le tÃ©lÃ©phone saisi au checkout est maintenant stockÃ© directement dans la commande au lieu d'utiliser le tÃ©lÃ©phone du profil.

**Backend:** Champ `contactPhone String?` ajoutÃ© au modÃ¨le Order (Prisma), au `CreateOrderDto`, et Ã  `createOrderFromCart` dans `orders.service.ts`.
**Client:** ParamÃ¨tre `contactPhone` ajoutÃ© Ã  `order_repository.dart`, `checkout_controller.dart`, passÃ© depuis `checkout_page.dart`.
**Admin:** `order.dart` parse `contactPhone` avec fallback sur `user.phone`.

### 2. Onboarding UI amÃ©liorÃ©
**Fichier:** `lib/features/onboarding/presentation/onboarding_screen.dart` (rÃ©Ã©crit)
- Gradient backgrounds animÃ©s par page
- Cartes flottantes avec animation (FloatingCard + AnimationController)
- FadeTransition entre pages, bouton gradient, dot indicators animÃ©s

### 3. Bouton "Tout supprimer" dans le panier
**Fichiers modifiÃ©s:**
- `lib/features/cart/data/cart_repository.dart` : mÃ©thode `clearAllItems()` (appelle `DELETE /cart/clear`)
- `lib/features/cart/application/cart_controller.dart` : `clearCart()` appelle `clearAllItems()`
- `lib/features/cart/presentation/cart_screen.dart` : bouton `Icons.delete_sweep` dans l'AppBar avec dialog de confirmation

### 4. Note restaurant dans l'AppBar
**Fichiers modifiÃ©s:**
- Backend `restaurants.service.ts` : `findOne` inclut reviews et calcule `averageRating`/`totalReviews`
- `lib/models/restaurant.dart` : champs `averageRating`, `totalReviews` ajoutÃ©s
- `lib/features/home/presentation/restaurant_detail_screen.dart` : AppBar affiche nom + Ã©toile + note

### 5. Barre de recherche amÃ©liorÃ©e
**Fichier:** `lib/features/home/presentation/widgets/search_bar_widget.dart`
- Design blanc avec ombre, icÃ´ne search colorÃ©e, icÃ´ne filtre `Icons.tune_rounded`

### 6. Commandes en brouillon (draft orders)
Permet Ã  l'utilisateur d'enregistrer sa commande depuis le checkout pour la valider plus tard.

**Fichiers crÃ©Ã©s:**
- `lib/models/draft_order.dart` : modÃ¨le DraftOrder avec sÃ©rialisation JSON
- `lib/features/cart/application/draft_orders_provider.dart` : `DraftOrdersNotifier` (@Riverpod keepAlive) avec saveDraft/restoreDraft/deleteDraft via SharedPreferences
- `lib/features/cart/presentation/draft_orders_screen.dart` : liste des brouillons avec restore/delete

**Fichiers modifiÃ©s:**
- `lib/features/commandes/presentation/checkout_page.dart` : bouton "Enregistrer pour plus tard" + `_saveDraft()` qui sauvegarde, vide le panier, dÃ©pile checkout/delivery, navigue vers brouillons
- `lib/features/user/user_page.dart` : menu item "Commandes en attente" entre Favoris et Adresses
- `lib/routing/app_route_enum.dart` : route `draftOrders` (path: `draft-orders`)
- `lib/routing/app_router.dart` : GoRoute sous profile

---

## Modifications - Avril 2026

### 1. Adaptation au backend refactorisÃ© (monorepo + global guards)
Le backend a Ã©tÃ© refactorisÃ© en architecture monorepo NestJS avec des guards globaux (`FirebaseAuthGuard` + `RolesGuard` en `APP_GUARD`). Les rÃ©ponses API sont maintenant wrappÃ©es dans `{ data: ... }`. Plusieurs corrections frontend pour s'adapter.

**ProblÃ¨me principal:** Le backend wrape dÃ©sormais toutes les rÃ©ponses dans `{ data: ... }` mais le frontend parsait le body brut.

**Fichiers modifiÃ©s:**

- `lib/features/user/data/adresse_repository.dart` :
  - `getUserAdresses()` : accÃ¨s via `json.decode(response.body)['data']` au lieu du body brut
  - `createAdresse()` : accÃ¨s via `json.decode(response.body)['data']` au lieu du body brut

- `lib/features/home/data/remote/restaurant_repo.dart` :
  - `getRestaurant()` : accÃ¨s via `json.decode(response.body)["data"]` â€” le backend `findOne()` retourne `{ data: { ...restaurant } }`

- `lib/models/restaurant.dart` :
  - `Restaurant.fromJson()` ligne 223 : parsing products null-safe `(json['products'] as List?) ?? []` au lieu de `json['products'] as List` qui crashait quand products Ã©tait null

- `lib/features/quartiers/data/quartiers_repository.dart` :
  - `getAllQuartiers()` : ajout du token Firebase en header (`Authorization: Bearer $token`) comme mesure dÃ©fensive, mÃªme si l'endpoint est `@Public()`

### 2. Frais de service (serviceFee 10%)
Le backend calcule dÃ©sormais des frais de service de 10% sur le sous-total (`OrderCalculatorService`). Le frontend a Ã©tÃ© mis Ã  jour pour calculer et afficher ces frais.

**Fichiers modifiÃ©s:**

- `lib/models/checkout.dart` :
  - Ajout du champ `int serviceFee` avec valeur par dÃ©faut 0
  - Parsing : `serviceFee: (json["serviceFee"] as num?)?.toInt() ?? 0`
  - AjoutÃ© dans `constructor`, `copyWith`, `fromMap`, `toMap`

- `lib/features/commandes/presentation/checkout_page.dart` :
  - Calcul : `final double serviceFee = (subTotal * 0.10).roundToDouble();`
  - Total mis Ã  jour : `total = subTotal + deliveryFee + serviceFee`
  - Nouvelle ligne "Frais de service (10%)" dans `_buildOrderSummary`
  - Ajout d'un SnackBar rouge quand la validation du formulaire Ã©choue (tÃ©lÃ©phone vide)

- `lib/features/commandes/presentation/delivery_options_page.dart` :
  - Calcul : `final serviceFee = (subTotal * 0.10).roundToDouble();`
  - Total mis Ã  jour : `total = subTotal + deliveryFee + serviceFee`
  - Nouvelle ligne "Frais de service (10%)" dans `_buildDeliveryFeeSummary`

### 3. Codes promo (promoCode) sur le checkout
Le backend supporte un systÃ¨me de codes promo avec 3 types de rÃ©duction : FIXED, PERCENT, FREE_DELIVERY.

**Fichiers crÃ©Ã©s:**
- `lib/models/promo_validation_result.dart` : ModÃ¨le immutable `PromoValidationResult` + enum `DiscountType` (fixed, percent, freeDelivery). Contient un getter `discountLabel` pour l'affichage formatÃ© (`-500 FCFA`, `Livraison gratuite`).
- `lib/features/commandes/data/promo_repository.dart` : `PromoRepository` (@riverpod) avec mÃ©thode `validateCode()` qui appelle `POST /promo/validate`. Parse les erreurs backend (code expirÃ©, dÃ©jÃ  utilisÃ©, montant minimum, etc.).

**Fichiers modifiÃ©s:**

- `lib/models/checkout.dart` :
  - Ajout champs `int discountAmount` (dÃ©faut 0) et `String? promoCode`
  - Parsing : `discountAmount: (json["discountAmount"] as num?)?.toInt() ?? 0`
  - Parsing : `promoCode: json["promoCode"]?["code"] as String?`

- `lib/models/order.dart` :
  - Ajout champ `double discountAmount` (dÃ©faut 0)
  - Parsing : `discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0`

- `lib/features/commandes/data/order_repository.dart` :
  - ParamÃ¨tre `String? promoCode` ajoutÃ© Ã  `createOrders()`
  - AjoutÃ© dans le body : `bodyMap['promoCode'] = promoCode`

- `lib/features/commandes/data/checkout_controller.dart` :
  - ParamÃ¨tre `String? promoCode` ajoutÃ© Ã  `placeOrder()`, propagÃ© Ã  `createOrders()`

- `lib/features/commandes/presentation/checkout_page.dart` :
  - Nouveau state : `_promoResult`, `_promoLoading`, `_promoError`, `_promoController`
  - Section "Code promo" entre Instructions et RÃ©sumÃ© : champ texte + bouton "Appliquer"
  - Quand un code est validÃ© : affiche badge vert avec code, description et rÃ©duction
  - Bouton X pour retirer le code promo
  - `_buildOrderSummary` : ligne rÃ©duction verte avec icÃ´ne `local_offer` si promo appliquÃ©e
  - `_buildDeliveryFeeLabel` : prix barrÃ© + "Gratuit" si FREE_DELIVERY
  - Total recalculÃ© : `subTotal + deliveryFee + serviceFee - discountAmount`
  - Code promo passÃ© Ã  `placeOrder(promoCode: _promoResult?.code)`
  - Gestion erreur promo ajoutÃ©e dans `_showOrderError` (icÃ´ne `local_offer` violet)

**Flux utilisateur:**
1. Saisir un code dans le champ â†’ "Appliquer"
2. Appel `POST /promo/validate` avec `{ code, restaurantId, subTotal, deliveryFee }`
3. Si valide : badge vert + rÃ©duction affichÃ©e dans le rÃ©sumÃ© + total recalculÃ©
4. Si invalide : message d'erreur sous le champ (expirÃ©, dÃ©jÃ  utilisÃ©, montant min, etc.)
5. Au checkout : code envoyÃ© dans `POST /orders/checkout` body `{ promoCode: "CODE" }`
6. Backend consomme le code de maniÃ¨re atomique dans la transaction de crÃ©ation de commande

**Types de rÃ©duction:**
| Type | Effet cÃ´tÃ© client |
|---|---|
| `FIXED` | Montant dÃ©duit du sous-total (ex: -500 FCFA) |
| `PERCENT` | Pourcentage dÃ©duit, plafonnÃ© par `maxDiscount` |
| `FREE_DELIVERY` | `deliveryFee` â†’ 0, affichage prix barrÃ© + "Gratuit" |

### 4. RÃ©sumÃ© des patterns API importants

**Format des rÃ©ponses backend (aprÃ¨s refactoring monorepo) :**
| Endpoint | Format rÃ©ponse |
|---|---|
| `GET /restaurants` | `{ data: [...], count: N }` |
| `GET /restaurants/:id` | `{ data: { ...restaurant } }` |
| `GET /adresses` | `{ data: [...], count: N }` |
| `POST /adresses` | `{ data: { ...adresse }, message: "..." }` |
| `GET /quartiers` | `{ data: [...], count: N }` (public) |
| `GET /users/me` | `{ user: { ... } }` (via @CurrentUser) |
| `POST /orders/checkout` | `{ message: "...", data: { ...order } }` |
| `POST /promo/validate` | `{ valid, promoCodeId, code, discountType, discountAmount, description, newTotal, newDeliveryFee }` |

**Guards backend :**
- `@Public()` â†’ bypass auth (GET /quartiers, GET /restaurants, GET /restaurants/:id)
- `@Roles('RESTAURATEUR', 'ADMIN')` â†’ nÃ©cessite rÃ´le spÃ©cifique
- Sans dÃ©corateur â†’ authentifiÃ© suffit (token Firebase requis)
- `@CurrentUser()` fonctionne sur toute route authentifiÃ©e (le RolesGuard peuple `request.user` automatiquement)

### 5. Reorder 1-clic
- `OrderRepository.reorder(orderId)` → POST /orders/:id/reorder (recopie articles dans le panier)
- Bouton "Recommander" ajouté dans `commande_page.dart` pour les commandes LIVRER et ANNULER
- Non bloquant : redirige vers /cart après succès

### 6. Parrainage (referral system)
**Modèles :**
- `AppUser` : ajout `referralCode String?` + `loyaltyPoints int`
- `lib/models/loyalty_transaction.dart` : nouveaux modèles `LoyaltyTransaction` + `ReferralStats`

**Backend calls :**
- `UserRepository.getReferralStats()` → GET /users/me/referral-stats
- `UserRepository.getLoyaltyTransactions()` → GET /users/me/loyalty

**Providers :**
- `referralStatsProvider` + `loyaltyTransactionsProvider` dans `profile_controller.dart`

**UI :**
- `signup_page.dart` : champ "Code de parrainage (optionnel)" avec badge +200 pts
- Passe `referralCode` à `createUserWithEmailAndPassword` → firebase_auth_repository → body sync
- `user_page.dart` : carte Parrainage (code à copier + stats parrainés/récompensés)

**Récompenses (backend) :** +500 pts parrain, +200 pts filleul à la 1ère commande

### 7. Points de fidélité
**UI :**
- `user_page.dart` : carte orange gradient avec balance + historique toggle (10 dernières transactions)
- `checkout_page.dart` : toggle SwitchListTile visible si >= 100 pts (1 pt = 5 FCFA de réduction)
- Ligne réduction "Points fidélité" dans `_buildOrderSummary` si toggle activé

**Backend calls :**
- `OrderRepository.createOrders(useLoyaltyPoints: bool)` → passe `useLoyaltyPoints: true` dans body
- `CheckoutController.placeOrder(useLoyaltyPoints: bool)` → invalide aussi `userProfileProvider` après commande

**Règles :** 1 pt par 100 FCFA, points gagnés à LIVRER, min 100 pts pour utiliser, tous les pts consommés d'un coup

### 8. Frais de service corrigés à 8%
- `checkout_page.dart` : `serviceFee = subTotal * 0.08` (était 0.10)

### 9. Fix lastLogin null sur mobile
**Cause :** `signInWithEmailAndPassword` n'appelait que Firebase, sans sync backend → `lastLogin` jamais mis à jour  
**Fix :** `firebase_auth_repository.dart` — après connexion Firebase réussie, appel POST /users/sync (non bloquant, timeout 8s, try/catch silencieux)  
Seuls `firebaseUid` et `email` sont envoyés (pas besoin du reste pour un simple lastLogin update)
