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

### Common Gotchas
- Firebase must be initialized before creating ProviderScope in main.dart
- Google Sign In requires initialization: `await GoogleSignIn.instance.initialize()`
- Cart repository uses broadcast stream controller - must check `_isClosed` before adding events
- When user signs out, invalidate all user-specific providers to clear cached data
- Product navigation passes objects via `extra` - handle null case for direct URL access

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
- `http`: HTTP client for backend API calls
- `flutter_local_notifications`: Local notification display
- `google_sign_in`: Google authentication
- `shared_preferences`: Local key-value storage
- `cloudinary_public`: Image upload service
- `build_runner`: Code generation tool
