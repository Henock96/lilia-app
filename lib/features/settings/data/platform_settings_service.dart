import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/utils/api_response.dart';
import 'package:lilia_app/utils/provider_cache.dart';

part 'platform_settings_service.g.dart';

/// Paramètres de tarification servis par le backend (`GET /platform-settings`).
///
/// L'app codait ces valeurs en dur — 8 % de commission, 1 pt = 5 XAF. Le jour
/// où l'admin change le taux via `/admin/platform-settings`, toutes les
/// versions installées continuaient d'afficher l'ancien montant sans aucun
/// signal, alors que le serveur facturait le nouveau.
///
/// ## ⚠️ Il n'y a plus de repli silencieux, et c'est le correctif
///
/// Ce fichier exposait `PlatformSettings.fallback` — 8 % de commission,
/// 1 pt = 50 XAF —, aligné sur les `@default` du schéma Prisma. Trois écrans
/// s'en servaient sous la forme `ref.watch(...).value ?? fallback`, et le
/// provider l'avait lui-même en `catch`.
///
/// Or **la production ne facture pas les défauts Prisma** : la ligne
/// `PlatformSettings` y porte `serviceFeePercent = 15` et
/// `loyaltyPointValueXaf = 100`. Le repli n'était donc pas « la même valeur en
/// attendant la réponse » : c'était une **autre tarification**. Sur un panier
/// de 20 000 FCFA, le client validait un total de 22 600 FCFA et l'écran de
/// paiement lui réclamait 24 000. Deux fenêtres l'exposaient : un
/// `/platform-settings` injoignable (le `catch` figeait la valeur fausse pour
/// toute la session, le provider étant `keepAlive`), et les premières frames
/// de chaque checkout, pendant le chargement.
///
/// La règle est désormais : **pas de réponse, pas de total.** Le provider
/// laisse remonter l'échec, et les écrans qui affichent de l'argent le
/// traitent comme ce qu'il est — une impossibilité de calculer, avec un bouton
/// « Réessayer ». Un écran vide est honnête ; un total faux ne l'est pas.
///
/// Un cache persistant du dernier barème connu a été volontairement écarté :
/// il déplacerait le problème (« cette valeur date de quand ? ») sans le
/// résoudre, et le checkout exige de toute façon le réseau.
///
/// Ces valeurs ne servent qu'à **estimer** avant checkout : le montant dû reste
/// celui de la commande créée par le serveur.
class PlatformSettings {
  final double serviceFeePercent;

  /// Forfait gagné par commande livrée. A remplacé `loyaltyPointsPer100Xaf` :
  /// le gain n'est plus proportionnel au montant, une commande de 1 000 et une
  /// de 20 000 FCFA rapportent la même chose.
  final int loyaltyPointsPerOrder;

  /// Valeur d'un point, en FCFA. **Seule** source autorisée pour convertir des
  /// points en argent à l'écran — aucun `× 5` ni `× 50` ne doit subsister dans
  /// une page.
  final int loyaltyPointValueXaf;
  final int loyaltyMinRedemption;

  /// Points versés au parrain quand son filleul est livré pour la première
  /// fois. Le filleul, lui, ne reçoit plus rien.
  final int referrerBonusPoints;

  final bool maintenanceMode;
  final String? maintenanceMessage;

  /// Version minimale requise (en-dessous, mise à jour obligatoire / hard update).
  final String? minAppVersion;

  /// Dernière version disponible (en-dessous, mise à jour facultative / soft update).
  final String? latestAppVersion;

  final String? updateUrlAndroid;
  final String? updateUrlIos;
  final String? updateMessage;

  const PlatformSettings({
    required this.serviceFeePercent,
    required this.loyaltyPointsPerOrder,
    required this.loyaltyPointValueXaf,
    required this.loyaltyMinRedemption,
    required this.referrerBonusPoints,
    this.maintenanceMode = false,
    this.maintenanceMessage,
    this.minAppVersion,
    this.latestAppVersion,
    this.updateUrlAndroid,
    this.updateUrlIos,
    this.updateMessage,
  });

  /// Convertit un nombre de points en FCFA. Point de passage **unique** :
  /// c'est ce qui garantit qu'un changement de barème côté serveur se voit
  /// partout dans l'application sans redéploiement.
  int pointsToXaf(int points) => points * loyaltyPointValueXaf;

  /// Valeurs employées quand un **champ** manque dans une réponse par
  /// ailleurs reçue — pas quand la réponse entière manque.
  ///
  /// La distinction est tout l'objet du correctif. Un champ absent d'une
  /// réponse `200` est une tolérance de parsing : le serveur les envoie tous,
  /// et retomber sur le défaut Prisma pour un champ nouveau qu'une vieille
  /// version ne connaît pas est raisonnable. Une réponse **absente**, elle,
  /// ne dit rien du barème appliqué — et c'est pour l'avoir traitée comme un
  /// champ manquant que le client affichait 8 % là où la production facture
  /// 15 %.
  ///
  /// ⚠️ Ne jamais réexposer ceci comme un repli d'écran. Aucun `?? ` ne doit
  /// pointer dessus.
  @visibleForTesting
  static const defautsDeParsing = PlatformSettings(
    serviceFeePercent: 8,
    loyaltyPointsPerOrder: 1,
    loyaltyPointValueXaf: 50,
    loyaltyMinRedemption: 1,
    referrerBonusPoints: 1,
  );

  /// Taux exploitable directement dans un produit (`0.08` pour 8 %).
  double get serviceFeeRate => serviceFeePercent / 100;

  factory PlatformSettings.fromJson(Map<String, dynamic> json) {
    return PlatformSettings(
      serviceFeePercent:
          (json['serviceFeePercent'] as num?)?.toDouble() ??
          defautsDeParsing.serviceFeePercent,
      loyaltyPointsPerOrder:
          (json['loyaltyPointsPerOrder'] as num?)?.toInt() ??
          defautsDeParsing.loyaltyPointsPerOrder,
      loyaltyPointValueXaf:
          (json['loyaltyPointValueXaf'] as num?)?.toInt() ??
          defautsDeParsing.loyaltyPointValueXaf,
      loyaltyMinRedemption:
          (json['loyaltyMinRedemption'] as num?)?.toInt() ??
          defautsDeParsing.loyaltyMinRedemption,
      referrerBonusPoints:
          (json['referrerBonusPoints'] as num?)?.toInt() ??
          defautsDeParsing.referrerBonusPoints,
      maintenanceMode: json['maintenanceMode'] as bool? ?? false,
      maintenanceMessage: json['maintenanceMessage'] as String?,
      minAppVersion: json['minAppVersion'] as String?,
      latestAppVersion: json['latestAppVersion'] as String?,
      updateUrlAndroid: json['updateUrlAndroid'] as String?,
      updateUrlIos: json['updateUrlIos'] as String?,
      updateMessage: json['updateMessage'] as String?,
    );
  }
}

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
@riverpod
Future<PlatformSettings> platformSettings(Ref ref) async {
  cachePendant(ref, kCatalogCacheTtl);
  ref.watch(staleForegroundStampProvider);

  final api = ref.watch(apiClientProvider);
  final res = await api.getJson('/platform-settings');
  return PlatformSettings.fromJson(ApiResponse.mapOf(res.data));
}
