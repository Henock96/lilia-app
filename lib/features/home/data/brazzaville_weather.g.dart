// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brazzaville_weather.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Météo de Brazzaville pour l'en-tête de l'accueil.
///
/// Lue sur le backend Lilia (public, mis en cache côté serveur 30 min). Côté
/// app, gardée 30 min elle aussi : la recharger à chaque retour sur l'accueil
/// ne changerait rien. Échec (hors ligne, 503 sans clé, 404 sur un ancien
/// serveur) : l'en-tête masque simplement la météo.
///
/// Pas de relance automatique ([_pasDeRelance]) : Riverpod 3 rejoue sinon un
/// provider en échec avec un délai croissant — des requêtes inutiles, hors
/// ligne ou serveur sans clé, pour une donnée secondaire. La prochaine
/// lecture a lieu au prochain montage de l'accueil après expiration.

@ProviderFor(brazzavilleWeather)
final brazzavilleWeatherProvider = BrazzavilleWeatherProvider._();

/// Météo de Brazzaville pour l'en-tête de l'accueil.
///
/// Lue sur le backend Lilia (public, mis en cache côté serveur 30 min). Côté
/// app, gardée 30 min elle aussi : la recharger à chaque retour sur l'accueil
/// ne changerait rien. Échec (hors ligne, 503 sans clé, 404 sur un ancien
/// serveur) : l'en-tête masque simplement la météo.
///
/// Pas de relance automatique ([_pasDeRelance]) : Riverpod 3 rejoue sinon un
/// provider en échec avec un délai croissant — des requêtes inutiles, hors
/// ligne ou serveur sans clé, pour une donnée secondaire. La prochaine
/// lecture a lieu au prochain montage de l'accueil après expiration.

final class BrazzavilleWeatherProvider
    extends
        $FunctionalProvider<
          AsyncValue<BrazzavilleWeather>,
          BrazzavilleWeather,
          FutureOr<BrazzavilleWeather>
        >
    with
        $FutureModifier<BrazzavilleWeather>,
        $FutureProvider<BrazzavilleWeather> {
  /// Météo de Brazzaville pour l'en-tête de l'accueil.
  ///
  /// Lue sur le backend Lilia (public, mis en cache côté serveur 30 min). Côté
  /// app, gardée 30 min elle aussi : la recharger à chaque retour sur l'accueil
  /// ne changerait rien. Échec (hors ligne, 503 sans clé, 404 sur un ancien
  /// serveur) : l'en-tête masque simplement la météo.
  ///
  /// Pas de relance automatique ([_pasDeRelance]) : Riverpod 3 rejoue sinon un
  /// provider en échec avec un délai croissant — des requêtes inutiles, hors
  /// ligne ou serveur sans clé, pour une donnée secondaire. La prochaine
  /// lecture a lieu au prochain montage de l'accueil après expiration.
  BrazzavilleWeatherProvider._()
    : super(
        from: null,
        argument: null,
        retry: _pasDeRelance,
        name: r'brazzavilleWeatherProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$brazzavilleWeatherHash();

  @$internal
  @override
  $FutureProviderElement<BrazzavilleWeather> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BrazzavilleWeather> create(Ref ref) {
    return brazzavilleWeather(ref);
  }
}

String _$brazzavilleWeatherHash() =>
    r'a12caff25657a8839dba99cd2a25a59b88ad4e68';
