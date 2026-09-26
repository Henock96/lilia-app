import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/commandes/data/order_repository.dart';
import 'package:lilia_app/models/checkout_quote.dart';

part 'checkout_quote_provider.g.dart';

/// Devis serveur du panier courant (F3-11) — `POST /orders/quote`.
///
/// Recalculé à chaque changement du panier (il est observé) et de chaque
/// entrée du checkout (paramètres de la famille). Le récapitulatif l'affiche
/// dès qu'il est là ; le checkout renvoie l'offre qu'il annonçait.
@riverpod
Future<CheckoutQuote> checkoutQuote(
  Ref ref, {
  required bool isDelivery,
  String? adresseId,
  String? quartierId,
  String? promoCode,
  bool useLoyaltyPoints = false,
  DateTime? scheduledFor,
}) {
  ref.watch(cartControllerProvider);
  return ref
      .read(orderRepositoryProvider.notifier)
      .quote(
        isDelivery: isDelivery,
        adresseId: adresseId,
        quartierId: quartierId,
        promoCode: promoCode,
        useLoyaltyPoints: useLoyaltyPoints,
        scheduledFor: scheduledFor,
      );
}
