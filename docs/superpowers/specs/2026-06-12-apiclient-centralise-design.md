# LIL-136 — ApiClient centralisé (dio + interceptors) pour les 3 apps Flutter

**Date** : 2026-06-12
**Issue** : LIL-136 (Sprint 4, priorité High)
**Apps** : `lilia-app` (référence), `lilia-food-admin`, `lilia_food_delivery`

## Problème

Chaque repository réimplémente : récupération du token Firebase, construction des
headers, parsing d'erreur. La logique d'erreur partagée n'est appliquée qu'à un
seul repo de `lilia-app` → duplication massive, `catch(_){}` muets, comportements
incohérents (timeout, refresh token, messages). Aucune des 3 apps n'a `dio` ni
`sentry` : toutes sur `http: ^1.6.0`.

## Décisions cadrées (validées)

1. **Partage du code** : copie par app (les 3 sont des dépôts git isolés, pas de
   package partagé). « Single point » entendu **par app**, pas cross-app.
2. **Sentry** : non installé. On expose un **hook abstrait** `NetworkObserver`
   (no-op par défaut) ; l'implémentation Sentry viendra dans une issue dédiée.
3. **Déroulé** : `lilia-app` d'abord (design validé end-to-end), puis réplication
   sur `lilia-food-admin` (6 repos) et `lilia_food_delivery` (2 repos).
4. **Déwrapping** : l'`ApiClient` renvoie le `Response`/body brut ; le repo garde
   `ApiResponse.mapOf/listOf` + `parseJson` (isolate) — préserve l'optim perf et
   les cas spéciaux (`/users/me` → `{user}`, PDF reçu binaire).
5. **Retry POST** : retry libre des méthodes idempotentes (GET/PUT/PATCH/DELETE) ;
   retry des POST **uniquement** s'ils portent un header `Idempotency-Key`
   (checkout). Évite les commandes en double.
6. **Auth repo** : `firebase_auth_repository` reste **hors** ApiClient (il fournit
   le `tokenProvider` qui alimente le client → éviter le cycle). On migre les
   autres repos + `payment_service` + `notification_service`.

## Architecture

### Arborescence (identique dans chaque app)
```
lib/core/network/
├── api_client.dart        # façade Dio
├── api_exception.dart     # exception typée
├── network_observer.dart  # hook abstrait + NoopNetworkObserver
└── interceptors/
    ├── auth_interceptor.dart
    ├── retry_interceptor.dart
    └── error_interceptor.dart
```

### `ApiClient` (façade Dio)
- Construit `Dio` : `baseUrl = AppConstants.baseUrl`, `connectTimeout` 15 s,
  `receiveTimeout` 30 s (alignés sur le cold start Render). Accepte les codes
  4xx/5xx sans throw natif Dio (`validateStatus: (_) => true`) — c'est
  l'`ErrorInterceptor` qui décide.
- **Découplé de Firebase** : reçoit `Future<String?> Function() tokenProvider`.
  Câblé dans le provider depuis `firebaseIdTokenProvider`. Testable sans Firebase.
- Méthodes : `getJson`, `postJson`, `patchJson`, `putJson`, `deleteJson`
  (renvoient `Response<dynamic>` ou la String body) + `downloadBytes(path)` pour
  le PDF reçu (`responseType: bytes`).
- Le repo déwrappe lui-même (`ApiResponse.mapOf/listOf`) et garde `parseJson`
  isolate pour les grosses listes.
- Ordre des interceptors : `AuthInterceptor` → `RetryInterceptor` →
  `ErrorInterceptor` → `ObserverInterceptor` (observer en dernier).

### Interceptors
- **AuthInterceptor** : injecte `Authorization: Bearer <token>` via
  `tokenProvider`. Sur réponse `401`, force `getIdToken(forceRefresh: true)` **une
  seule fois** (flag par requête via `extra`) puis rejoue la requête. Échec après
  refresh → laisse passer en `ApiException(kind: unauthorized)`.
- **RetryInterceptor** : 3 tentatives max, backoff exponentiel 400/800/1600 ms +
  jitter ±20 %. Déclenché sur `5xx`, timeout (`connectionTimeout`,
  `receiveTimeout`, `sendTimeout`), `connectionError`. **Jamais sur 4xx.**
  Condition d'idempotence : méthode ∈ {GET,PUT,PATCH,DELETE} **ou** header
  `Idempotency-Key` présent (POST checkout).
- **ErrorInterceptor** : convertit toute issue (DioException OU réponse statut
  ≥ 400) en `ApiException` :
  - parse le message FR depuis `{message}` : String → tel quel ; List → joint par
    `. ` ; sinon fallback fourni par l'appelant.
  - mappe `kind` : timeout→`timeout`, connectionError→`network`, 401→`unauthorized`,
    5xx→`server`, autres 4xx→`client`, reste→`unknown`.

### `ApiException`
```dart
enum ApiErrorKind { network, timeout, unauthorized, server, client, unknown }

class ApiException implements Exception {
  final String message;     // FR, prêt à afficher
  final int? statusCode;
  final ApiErrorKind kind;
  const ApiException(this.message, {this.statusCode, this.kind = ApiErrorKind.unknown});
  @override String toString() => message;
}
```
Remplace les `throw Exception(...)` + `_extractErrorMessage` locaux. Les
controllers (`AsyncValue.guard`) la propagent → l'UI lit `error.toString()`.

### `NetworkObserver` (hook, sans Sentry)
```dart
class RequestSnapshot {
  final String method, path;
  final int? statusCode;
  final Duration? elapsed;
}
abstract class NetworkObserver {
  void onRequest(RequestSnapshot r);
  void onError(ApiException e, RequestSnapshot r);
}
class NoopNetworkObserver implements NetworkObserver { /* no-op par défaut */ }
```
Branché en dernier interceptor. `SentryNetworkObserver` (futur) : breadcrumbs.

### Providers
```dart
@Riverpod(keepAlive: true)
NetworkObserver networkObserver(Ref ref) => const NoopNetworkObserver();

@Riverpod(keepAlive: true)
ApiClient apiClient(Ref ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return ApiClient(
    baseUrl: AppConstants.baseUrl,
    tokenProvider: () => auth.currentUser?.getIdToken(),
    forceRefreshToken: () => auth.currentUser?.getIdToken(true),
    observer: ref.watch(networkObserverProvider),
  );
}
```
`httpClientProvider` est retiré une fois tous les repos migrés.

## Migration des repositories (lilia-app)

10 repos `data/` + `payment_service` + `notification_service`. Pour chacun :
1. Remplacer `http.get/post/...` + headers manuels par `ref.read(apiClientProvider)`.
2. Supprimer le `_extractErrorMessage` local — l'`ApiException` porte déjà le message.
3. Conserver `ApiResponse.mapOf/listOf` + `parseJson` (grosses listes).
4. Supprimer les `catch(_){}` muets (4 occurrences) : laisser remonter
   l'`ApiException`, ou logger via l'observer si une valeur de repli est légitime.
5. `firebase_auth_repository` (`/users/sync`) reste sur `http` (hors scope, cycle token).

Cas particuliers à préserver :
- `order_repository.downloadReceipt` → `apiClient.downloadBytes`.
- `order_repository.createOrders` → header `Idempotency-Key` conservé (active le retry POST).
- `user_repository` `/users/me` → `{user}` (pas `{data}`) : déwrapping spécifique gardé.

## Tests

- `api_exception` : mapping `{message}` String/List/absent → message + kind.
- `retry_interceptor` : retry sur 503/timeout, pas sur 400 ; POST sans clé non
  retryé, POST avec `Idempotency-Key` retryé. (MockAdapter Dio.)
- `auth_interceptor` : 401 → un seul force-refresh + replay ; second 401 → unauthorized.
- Au moins un repo migré (`order_repository`) couvert end-to-end via MockAdapter.

## Dépendances

Ajouter à chaque `pubspec.yaml` : `dio: ^5.7.0`. Retirer `http` quand plus aucun
import (lilia-app conserve `http` tant que `firebase_auth_repository` l'utilise).

## Definition of Done

- [ ] Un seul point d'injection token + parsing erreur **par app**.
- [ ] Aucun `catch(_){}` muet restant (4 lilia-app, 3 delivery, 0 admin).
- [ ] Pattern appliqué aux 3 apps.
- [ ] `flutter analyze` propre + tests interceptors/exception verts (chaque app).

## Hors scope (issues futures)

- Implémentation `SentryNetworkObserver` réelle (SDK + DSN + release tracking).
- Extraction d'un package `lilia_network` partagé (les 3 repos restent dupliqués).
- Migration de `firebase_auth_repository` vers l'ApiClient.
