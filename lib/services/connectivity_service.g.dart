// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connectivity_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Point d'injection unique de `connectivity_plus` — le seul endroit du code
/// qui touche le plugin.

@ProviderFor(connectivity)
final connectivityProvider = ConnectivityProvider._();

/// Point d'injection unique de `connectivity_plus` — le seul endroit du code
/// qui touche le plugin.

final class ConnectivityProvider
    extends $FunctionalProvider<Connectivity, Connectivity, Connectivity>
    with $Provider<Connectivity> {
  /// Point d'injection unique de `connectivity_plus` — le seul endroit du code
  /// qui touche le plugin.
  ConnectivityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectivityProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectivityHash();

  @$internal
  @override
  $ProviderElement<Connectivity> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Connectivity create(Ref ref) {
    return connectivity(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Connectivity value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Connectivity>(value),
    );
  }
}

String _$connectivityHash() => r'e66720f09edf1a8b09e450e1eaedd51da9443f0e';

/// **L'état du réseau, sans trou.**
///
/// ## Le défaut que cette forme corrige
///
/// `ConnectivityService` publiait sur un `StreamController.broadcast()` et
/// l'exposait ainsi :
///
/// ```dart
/// Stream<bool> get connectionStream async* {
///   yield _isConnected;            // ← le générateur se suspend ICI
///   yield* _controller.stream;     // ← l'abonnement n'existe pas encore
/// }
/// ```
///
/// Entre ces deux lignes il y a un **trou asynchrone**, et un `broadcast` ne
/// rejoue rien : tout événement qui y tombe est perdu. Il s'en produit
/// précisément là — `_initConnectivity()` est lancé depuis le constructeur du
/// service et y écrit à cet instant.
///
/// Symptôme observé : au rétablissement de la connexion, l'événement `true`
/// disparaissait et **la bannière restait affichée** jusqu'au changement de
/// réseau suivant. Le correctif précédent (amorcer le flux) avait supprimé un
/// défaut en en créant un autre.
///
/// ## L'ordre qui compte
///
/// On **s'abonne d'abord**, on demande l'état courant **ensuite**. Dans
/// l'ordre inverse, un changement survenu pendant l'interrogation initiale
/// serait perdu — la même erreur, déplacée d'un cran.
///
/// `distinct()` : `connectivity_plus` émet à chaque changement de transport
/// (WiFi → mobile, ajout d'un VPN). Ces transitions ne changent pas la réponse
/// à « suis-je connecté ? », et les laisser passer ferait clignoter un message
/// sans raison.
///
/// ⚠️ La classe `ConnectivityService` a été **supprimée**. Elle ne portait que
/// cet état, et le détour par un service propriétaire d'un contrôleur était
/// exactement ce qui rendait le trou possible. Une abstraction de moins.

@ProviderFor(connectivityStatus)
final connectivityStatusProvider = ConnectivityStatusProvider._();

/// **L'état du réseau, sans trou.**
///
/// ## Le défaut que cette forme corrige
///
/// `ConnectivityService` publiait sur un `StreamController.broadcast()` et
/// l'exposait ainsi :
///
/// ```dart
/// Stream<bool> get connectionStream async* {
///   yield _isConnected;            // ← le générateur se suspend ICI
///   yield* _controller.stream;     // ← l'abonnement n'existe pas encore
/// }
/// ```
///
/// Entre ces deux lignes il y a un **trou asynchrone**, et un `broadcast` ne
/// rejoue rien : tout événement qui y tombe est perdu. Il s'en produit
/// précisément là — `_initConnectivity()` est lancé depuis le constructeur du
/// service et y écrit à cet instant.
///
/// Symptôme observé : au rétablissement de la connexion, l'événement `true`
/// disparaissait et **la bannière restait affichée** jusqu'au changement de
/// réseau suivant. Le correctif précédent (amorcer le flux) avait supprimé un
/// défaut en en créant un autre.
///
/// ## L'ordre qui compte
///
/// On **s'abonne d'abord**, on demande l'état courant **ensuite**. Dans
/// l'ordre inverse, un changement survenu pendant l'interrogation initiale
/// serait perdu — la même erreur, déplacée d'un cran.
///
/// `distinct()` : `connectivity_plus` émet à chaque changement de transport
/// (WiFi → mobile, ajout d'un VPN). Ces transitions ne changent pas la réponse
/// à « suis-je connecté ? », et les laisser passer ferait clignoter un message
/// sans raison.
///
/// ⚠️ La classe `ConnectivityService` a été **supprimée**. Elle ne portait que
/// cet état, et le détour par un service propriétaire d'un contrôleur était
/// exactement ce qui rendait le trou possible. Une abstraction de moins.

final class ConnectivityStatusProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// **L'état du réseau, sans trou.**
  ///
  /// ## Le défaut que cette forme corrige
  ///
  /// `ConnectivityService` publiait sur un `StreamController.broadcast()` et
  /// l'exposait ainsi :
  ///
  /// ```dart
  /// Stream<bool> get connectionStream async* {
  ///   yield _isConnected;            // ← le générateur se suspend ICI
  ///   yield* _controller.stream;     // ← l'abonnement n'existe pas encore
  /// }
  /// ```
  ///
  /// Entre ces deux lignes il y a un **trou asynchrone**, et un `broadcast` ne
  /// rejoue rien : tout événement qui y tombe est perdu. Il s'en produit
  /// précisément là — `_initConnectivity()` est lancé depuis le constructeur du
  /// service et y écrit à cet instant.
  ///
  /// Symptôme observé : au rétablissement de la connexion, l'événement `true`
  /// disparaissait et **la bannière restait affichée** jusqu'au changement de
  /// réseau suivant. Le correctif précédent (amorcer le flux) avait supprimé un
  /// défaut en en créant un autre.
  ///
  /// ## L'ordre qui compte
  ///
  /// On **s'abonne d'abord**, on demande l'état courant **ensuite**. Dans
  /// l'ordre inverse, un changement survenu pendant l'interrogation initiale
  /// serait perdu — la même erreur, déplacée d'un cran.
  ///
  /// `distinct()` : `connectivity_plus` émet à chaque changement de transport
  /// (WiFi → mobile, ajout d'un VPN). Ces transitions ne changent pas la réponse
  /// à « suis-je connecté ? », et les laisser passer ferait clignoter un message
  /// sans raison.
  ///
  /// ⚠️ La classe `ConnectivityService` a été **supprimée**. Elle ne portait que
  /// cet état, et le détour par un service propriétaire d'un contrôleur était
  /// exactement ce qui rendait le trou possible. Une abstraction de moins.
  ConnectivityStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectivityStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectivityStatusHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return connectivityStatus(ref);
  }
}

String _$connectivityStatusHash() =>
    r'c1334d4c2d60a06c71ba887ee0a672e49f14d361';
