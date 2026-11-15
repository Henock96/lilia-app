// Double de test : ses compteurs publics sont faits pour être lus par le test.
// ignore_for_file: riverpod_lint/avoid_public_notifier_properties

import 'package:lilia_app/features/commandes/data/order_repository.dart';
import 'package:lilia_app/models/checkout_quote.dart';

/// Devis serveur fixe pour les tests d'écran (durcissement lot 5, F-40).
///
/// Le checkout et les options de livraison n'affichent plus aucun montant
/// calculé localement : sans devis, ils attendent. Tout test qui monte ces
/// écrans doit donc fournir le sien — `devis == null` simule un serveur qui
/// refuse de chiffrer.
class FauxDevis extends OrderRepository {
  FauxDevis(this.devis);
  final CheckoutQuote? devis;

  /// Paramètres reçus au dernier appel, pour les tests qui vérifient ce que
  /// l'écran demande.
  bool? dernierIsDelivery;
  String? dernierQuartierId;

  @override
  Future<CheckoutQuote> quote({
    required bool isDelivery,
    String? adresseId,
    String? quartierId,
    String? promoCode,
    bool useLoyaltyPoints = false,
    DateTime? scheduledFor,
  }) async {
    dernierIsDelivery = isDelivery;
    dernierQuartierId = quartierId;
    return devis ?? (throw Exception('Devis indisponible'));
  }
}

/// Devis ordinaire : sous-total, livraison, frais de service, total entiers.
CheckoutQuote devisDe({
  required double subTotal,
  double deliveryFee = 0,
  required double serviceFee,
  double loyaltyDiscount = 0,
}) => CheckoutQuote.fromJson({
  'subTotal': subTotal,
  'deliveryFee': deliveryFee,
  'deliveryFeeBeforePromo': deliveryFee,
  'serviceFee': serviceFee,
  'loyalty': {'pointsUsed': 0, 'discountXaf': loyaltyDiscount},
  'total': subTotal + deliveryFee + serviceFee - loyaltyDiscount,
});
