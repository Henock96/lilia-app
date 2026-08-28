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
/// Ces valeurs ne servent qu'à **estimer** avant checkout : le montant dû reste
/// celui de la commande créée par le serveur.
class PlatformSettings {
  final double serviceFeePercent;
  final int loyaltyPointsPer100Xaf;
  final int loyaltyPointValueXaf;
  final int loyaltyMinRedemption;
  final bool maintenanceMode;
  final String? maintenanceMessage;

  const PlatformSettings({
    required this.serviceFeePercent,
    required this.loyaltyPointsPer100Xaf,
    required this.loyaltyPointValueXaf,
    required this.loyaltyMinRedemption,
    this.maintenanceMode = false,
    this.maintenanceMessage,
  });

  /// Valeurs de repli, alignées sur les défauts Prisma. Utilisées tant que la
  /// requête n'a pas abouti (réseau instable) — jamais pour facturer.
  static const fallback = PlatformSettings(
    serviceFeePercent: 8,
    loyaltyPointsPer100Xaf: 1,
    loyaltyPointValueXaf: 5,
    loyaltyMinRedemption: 100,
  );

  /// Taux exploitable directement dans un produit (`0.08` pour 8 %).
  double get serviceFeeRate => serviceFeePercent / 100;

  factory PlatformSettings.fromJson(Map<String, dynamic> json) {
    return PlatformSettings(
      serviceFeePercent:
          (json['serviceFeePercent'] as num?)?.toDouble() ??
          fallback.serviceFeePercent,
      loyaltyPointsPer100Xaf:
          (json['loyaltyPointsPer100Xaf'] as num?)?.toInt() ??
          fallback.loyaltyPointsPer100Xaf,
      loyaltyPointValueXaf:
          (json['loyaltyPointValueXaf'] as num?)?.toInt() ??
          fallback.loyaltyPointValueXaf,
      loyaltyMinRedemption:
          (json['loyaltyMinRedemption'] as num?)?.toInt() ??
          fallback.loyaltyMinRedemption,
      maintenanceMode: json['maintenanceMode'] as bool? ?? false,
      maintenanceMessage: json['maintenanceMessage'] as String?,
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
