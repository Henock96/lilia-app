// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_settings_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Charge les paramètres publics — et **laisse remonter l'échec**.
///
/// Le `catch` qui retombait sur des valeurs codées en dur a disparu : il
/// transformait une panne réseau en tarification silencieusement différente de
/// celle du serveur (voir l'en-tête de ce fichier).
///
/// ## Le barème se périme, comme les prix
///
/// Ce provider était `@Riverpod(keepAlive: true)` **sans expiration**, et son
/// en-tête l'assumait : « une fois le barème obtenu, il vaut pour la session ».
///
/// Or une session Android dure des heures, parfois des jours — le processus
/// survit aux mises en arrière-plan. Le serveur, lui, ne garde sa propre copie
/// que **soixante secondes** (`PlatformSettingsService.CACHE_TTL_MS`),
/// précisément pour que l'auto-réparation multi-instances fonctionne.
///
/// Un administrateur qui passe la commission de 8 à 15 % : le serveur facture
/// le nouveau taux au bout d'une minute, le client continue d'afficher
/// l'ancien jusqu'au prochain démarrage à froid. Sur un panier de 20 000 FCFA,
/// c'est 1 400 FCFA d'écart entre le total validé et le montant réclamé sur le
/// téléphone — la symptomatologie exacte du repli codé en dur qu'on vient de
/// supprimer, avec une fenêtre plus étroite.
///
/// Deux mécanismes, les mêmes que le catalogue :
///
/// * [cachePendant] borne la durée de vie à [kCatalogCacheTtl]. Naviguer
///   d'écran en écran ne coûte rien ; au-delà, le prochain accès relit.
/// * [staleForegroundStampProvider] force la relecture au **retour au premier
///   plan** après ce même délai. Sans lui, un téléphone posé deux heures sur
///   l'écran de paiement garderait son barème : le minuteur aurait bien
///   relâché le lien, mais rien ne redemanderait la valeur tant que personne
///   ne navigue — et reprendre l'application est exactement le moment où le
///   client regarde à nouveau son total.
///
/// Un échec se rejoue par `ref.invalidate(platformSettingsProvider)` — c'est
/// ce que fait le bouton « Réessayer » des écrans monétaires.

@ProviderFor(platformSettings)
final platformSettingsProvider = PlatformSettingsProvider._();

/// Charge les paramètres publics — et **laisse remonter l'échec**.
///
/// Le `catch` qui retombait sur des valeurs codées en dur a disparu : il
/// transformait une panne réseau en tarification silencieusement différente de
/// celle du serveur (voir l'en-tête de ce fichier).
///
/// ## Le barème se périme, comme les prix
///
/// Ce provider était `@Riverpod(keepAlive: true)` **sans expiration**, et son
/// en-tête l'assumait : « une fois le barème obtenu, il vaut pour la session ».
///
/// Or une session Android dure des heures, parfois des jours — le processus
/// survit aux mises en arrière-plan. Le serveur, lui, ne garde sa propre copie
/// que **soixante secondes** (`PlatformSettingsService.CACHE_TTL_MS`),
/// précisément pour que l'auto-réparation multi-instances fonctionne.
///
/// Un administrateur qui passe la commission de 8 à 15 % : le serveur facture
/// le nouveau taux au bout d'une minute, le client continue d'afficher
/// l'ancien jusqu'au prochain démarrage à froid. Sur un panier de 20 000 FCFA,
/// c'est 1 400 FCFA d'écart entre le total validé et le montant réclamé sur le
/// téléphone — la symptomatologie exacte du repli codé en dur qu'on vient de
/// supprimer, avec une fenêtre plus étroite.
///
/// Deux mécanismes, les mêmes que le catalogue :
///
/// * [cachePendant] borne la durée de vie à [kCatalogCacheTtl]. Naviguer
///   d'écran en écran ne coûte rien ; au-delà, le prochain accès relit.
/// * [staleForegroundStampProvider] force la relecture au **retour au premier
///   plan** après ce même délai. Sans lui, un téléphone posé deux heures sur
///   l'écran de paiement garderait son barème : le minuteur aurait bien
///   relâché le lien, mais rien ne redemanderait la valeur tant que personne
///   ne navigue — et reprendre l'application est exactement le moment où le
///   client regarde à nouveau son total.
///
/// Un échec se rejoue par `ref.invalidate(platformSettingsProvider)` — c'est
/// ce que fait le bouton « Réessayer » des écrans monétaires.

final class PlatformSettingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<PlatformSettings>,
          PlatformSettings,
          FutureOr<PlatformSettings>
        >
    with $FutureModifier<PlatformSettings>, $FutureProvider<PlatformSettings> {
  /// Charge les paramètres publics — et **laisse remonter l'échec**.
  ///
  /// Le `catch` qui retombait sur des valeurs codées en dur a disparu : il
  /// transformait une panne réseau en tarification silencieusement différente de
  /// celle du serveur (voir l'en-tête de ce fichier).
  ///
  /// ## Le barème se périme, comme les prix
  ///
  /// Ce provider était `@Riverpod(keepAlive: true)` **sans expiration**, et son
  /// en-tête l'assumait : « une fois le barème obtenu, il vaut pour la session ».
  ///
  /// Or une session Android dure des heures, parfois des jours — le processus
  /// survit aux mises en arrière-plan. Le serveur, lui, ne garde sa propre copie
  /// que **soixante secondes** (`PlatformSettingsService.CACHE_TTL_MS`),
  /// précisément pour que l'auto-réparation multi-instances fonctionne.
  ///
  /// Un administrateur qui passe la commission de 8 à 15 % : le serveur facture
  /// le nouveau taux au bout d'une minute, le client continue d'afficher
  /// l'ancien jusqu'au prochain démarrage à froid. Sur un panier de 20 000 FCFA,
  /// c'est 1 400 FCFA d'écart entre le total validé et le montant réclamé sur le
  /// téléphone — la symptomatologie exacte du repli codé en dur qu'on vient de
  /// supprimer, avec une fenêtre plus étroite.
  ///
  /// Deux mécanismes, les mêmes que le catalogue :
  ///
  /// * [cachePendant] borne la durée de vie à [kCatalogCacheTtl]. Naviguer
  ///   d'écran en écran ne coûte rien ; au-delà, le prochain accès relit.
  /// * [staleForegroundStampProvider] force la relecture au **retour au premier
  ///   plan** après ce même délai. Sans lui, un téléphone posé deux heures sur
  ///   l'écran de paiement garderait son barème : le minuteur aurait bien
  ///   relâché le lien, mais rien ne redemanderait la valeur tant que personne
  ///   ne navigue — et reprendre l'application est exactement le moment où le
  ///   client regarde à nouveau son total.
  ///
  /// Un échec se rejoue par `ref.invalidate(platformSettingsProvider)` — c'est
  /// ce que fait le bouton « Réessayer » des écrans monétaires.
  PlatformSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'platformSettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$platformSettingsHash();

  @$internal
  @override
  $FutureProviderElement<PlatformSettings> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PlatformSettings> create(Ref ref) {
    return platformSettings(ref);
  }
}

String _$platformSettingsHash() => r'65909b7b2fb34d81289036ec66d3e773128915bc';
