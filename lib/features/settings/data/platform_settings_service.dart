import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/utils/api_response.dart';

part 'platform_settings_service.g.dart';

/// Paramètres de tarification servis par le backend (`GET /platform-settings`).
///
/// L'app codait ces valeurs en dur — 8 % de commission, 1 pt = 5 XAF. Le jour
/// où l'admin change le taux via `/admin/platform-settings`, toutes les
/// versions installées continuaient d'afficher l'ancien montant sans aucun
/// signal, alors que le serveur facturait le nouveau.
///
/// ⚠️ Les valeurs de [PlatformSettings.fallback] servent **uniquement** quand
/// `GET /platform-settings` est injoignable. Elles reprennent les `@default`
/// du modèle Prisma, jamais une constante inventée côté client — et elles ne
/// facturent rien : le montant dû est celui de la commande créée par le
/// serveur.
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

  /// Valeurs de repli, alignées sur les défauts Prisma. Utilisées tant que la
  /// requête n'a pas abouti (réseau instable) — jamais pour facturer.
  static const fallback = PlatformSettings(
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
          fallback.serviceFeePercent,
      loyaltyPointsPerOrder:
          (json['loyaltyPointsPerOrder'] as num?)?.toInt() ??
          fallback.loyaltyPointsPerOrder,
      loyaltyPointValueXaf:
          (json['loyaltyPointValueXaf'] as num?)?.toInt() ??
          fallback.loyaltyPointValueXaf,
      loyaltyMinRedemption:
          (json['loyaltyMinRedemption'] as num?)?.toInt() ??
          fallback.loyaltyMinRedemption,
      referrerBonusPoints:
          (json['referrerBonusPoints'] as num?)?.toInt() ??
          fallback.referrerBonusPoints,
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

/// Charge les paramètres publics. En cas d'échec réseau, retombe sur
/// [PlatformSettings.fallback] plutôt que de bloquer le tunnel de commande.
@Riverpod(keepAlive: true)
Future<PlatformSettings> platformSettings(Ref ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final res = await api.getJson('/platform-settings');
    return PlatformSettings.fromJson(ApiResponse.mapOf(res.data));
  } catch (_) {
    return PlatformSettings.fallback;
  }
}
