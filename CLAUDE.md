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
├── features/           # Feature modules
│   ├── auth/          # Authentication (Firebase Auth + backend sync)
│   ├── cart/          # Shopping cart functionality
│   ├── commandes/     # Order management
│   ├── favoris/       # Favorites/wishlist
│   ├── home/          # Restaurant browsing
│   ├── notifications/ # Push notifications (FCM)
│   ├── payments/      # Payment processing
│   └── user/          # User profile and settings
├── models/            # Shared data models
├── routing/           # Go router configuration
├── services/          # App-wide services (notifications)
├── common_widgets/    # Reusable UI components
├── utilities/         # Themes, colors, styles
└── main.dart
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

## Modifications - Février 2026

### 1. Messages d'erreur backend propres
**Fichiers modifiés:**
- `lib/features/commandes/data/order_repository.dart` - Ajout de `_extractErrorMessage()` pour parser les réponses JSON du backend NestJS et extraire le champ `message`. Les erreurs affichées sont maintenant en français clair au lieu de JSON brut.
- `lib/features/commandes/presentation/checkout_page.dart` - Remplacement du SnackBar rouge par `_showOrderError()` qui affiche un AlertDialog avec icône contextuelle selon le type d'erreur (restaurant fermé, stock épuisé, montant minimum, session expirée, etc.)
- `lib/common_widgets/build_error_state.dart` - Amélioration de `_formatError()` pour extraire les messages JSON et nettoyer les préfixes techniques
- `lib/features/user/data/adresse_repository.dart` - Messages d'erreur en français clair

**Messages d'erreur backend reconnus:**
| Erreur backend | Icône | Titre affiché |
|---|---|---|
| "fermé" | store | Restaurant fermé |
| "rupture/stock" | remove_shopping_cart | Produit indisponible |
| "minimum/montant" | monetization_on | Montant insuffisant |
| "panier vide" | shopping_cart | Panier vide |
| "adresse" | location_off | Problème d'adresse |
| "reconnecter" | lock | Session expirée |

### 2. Firebase Analytics intégré
**Fichier créé:**
- `lib/services/analytics_service.dart` - Service centralisé pour tous les événements analytics

**Fichiers modifiés:**
- `lib/main.dart` - Initialisation des propriétés utilisateur (country: CG, currency: XAF)
- `lib/routing/app_router.dart` - Ajout de `AnalyticsService.observer` au GoRouter pour le tracking automatique des écrans
- `lib/features/auth/controller/auth_controller.dart` - logLogin/logSignUp (email, google)
- `lib/features/commandes/presentation/checkout_page.dart` - logBeginCheckout, logOrderCreated, logOrderFailed
- `lib/features/commandes/data/order_controller.dart` - logOrderCancelled
- `lib/features/home/presentation/home.dart` - logFavoriteToggle
- `lib/features/home/presentation/restaurant_detail_screen.dart` - logRestaurantViewed, logAddToCart
- `lib/features/home/presentation/product_detail_page.dart` - logProductViewed, logAddToCart

**Événements trackés:**
| Événement | Paramètres |
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
| Tracking automatique des écrans via GoRouter observer |

### 3. Shimmer loading pour les bannières
**Fichier modifié:**
- `lib/features/home/presentation/home.dart` - Remplacement des images par défaut pendant le chargement par un effet shimmer animé (`_ShimmerBannerPlaceholder`) avec gradient animé et placeholders de texte
