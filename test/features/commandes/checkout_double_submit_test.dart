// Faux contrôleurs de test : ils exposent volontairement des compteurs pour
// les assertions (`avoid_public_notifier_properties` vise le code de prod).
// ignore_for_file: riverpod_lint/avoid_public_notifier_properties
// **Un tap, une commande.**
//
// Le bouton « Valider et payer » n'était grisé que par `CheckoutController`,
// qui ne couvre qu'une des trois étapes du tunnel :
//
//   ① createAdresse()           bouton ACTIF   (~800 ms depuis Brazzaville)
//   ② placeOrder()              bouton grisé
//   ③ _createPaymentWithRetry() bouton ACTIF   (jusqu'à 2 essais + 2 s)
//
// Deux taps dans ① créaient deux adresses. Deux taps dans ③ repartaient avec
// une clé d'idempotence neuve — donc sans la protection serveur.
//
// Ces tests tapent plusieurs fois, à des instants choisis dans chacune des
// trois fenêtres, et comptent ce qui est réellement parti.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/commandes/data/checkout_controller.dart';
import 'package:lilia_app/features/commandes/presentation/checkout_page.dart';
import 'package:lilia_app/features/commandes/presentation/delivery_options_page.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_controller.dart';
import 'package:lilia_app/features/payments/data/payment_service.dart';
import 'package:lilia_app/features/settings/data/platform_settings_service.dart';
import 'package:lilia_app/features/user/application/adresse_controller.dart';
import 'package:lilia_app/features/user/application/profile_controller.dart';
import 'package:lilia_app/models/adresse.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/models/checkout.dart';
import 'package:lilia_app/models/quartier.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/models/vendor_type.dart';

const _restaurantId = 'resto-1';

const _bareme = PlatformSettings(
  serviceFeePercent: 15,
  loyaltyPointsPerOrder: 1,
  loyaltyPointValueXaf: 100,
  loyaltyMinRedemption: 1,
  referrerBonusPoints: 1,
);

Cart _panier() => Cart(
      id: 'panier-1',
      userId: 'uid-a',
      createdAt: DateTime(2026, 9, 20),
      updatedAt: DateTime(2026, 9, 20),
      items: [
        CartItem(
          id: 'ligne-1',
          cartId: 'panier-1',
          productId: 'prod-1',
          variantId: 'var-1',
          quantite: 1,
          createdAt: DateTime(2026, 9, 20),
          product: ProductItem(nom: 'Poulet', restaurantId: _restaurantId),
          variant: VariantItem(label: 'Normale', prix: 5000),
        ),
      ],
    );

class _FauxPanier extends CartController {
  @override
  Future<Cart?> build() async => _panier();
}

/// Compte les adresses créées — c'est la fenêtre ①.
class _FauxAdresses extends AdresseController {
  _FauxAdresses(this.porte);
  final Completer<void>? porte;
  int creations = 0;

  @override
  Future<List<Adresse>> build() async => const [];

  @override
  Future<Adresse> createAdresse({
    required String rue,
    String ville = 'Brazzaville',
    String pays = 'Congo',
    String? quartierId,
    double? latitude,
    double? longitude,
    String? landmark,
    String? label,
  }) async {
    creations++;
    if (porte != null) await porte!.future;
    return Adresse(
      id: 'adr-$creations',
      rue: rue,
      ville: ville,
      country: pays,
      userId: 'uid-a',
      quartierId: quartierId,
    );
  }
}

/// Compte les commandes créées — c'est la fenêtre ②.
class _FauxCheckout extends CheckoutController {
  _FauxCheckout(this.porte);
  final Completer<void>? porte;
  int commandes = 0;

  @override
  FutureOr<void> build() {}

  @override
  Future<Checkout> placeOrder({
    String? adresseId,
    required String paymentMethod,
    required bool isDelivery,
    String? note,
    String? contactPhone,
    String? promoCode,
    bool useLoyaltyPoints = false,
    String? idempotencyKey,
    DateTime? scheduledFor,
  }) async {
    commandes++;
    state = const AsyncLoading();
    if (porte != null) await porte!.future;
    state = const AsyncData(null);
    return Checkout(
      id: 'commande-$commandes',
      restaurantId: _restaurantId,
      userId: 'uid-a',
      subTotal: 5000,
      deliveryFee: 1000,
      total: 6750,
      paymentMethod: paymentMethod,
      status: 'EN_ATTENTE',
      createdAt: DateTime(2026, 9, 20),
      updatedAt: DateTime(2026, 9, 20),
      items: const [],
    );
  }
}

/// Compte les encaissements ouverts — c'est la fenêtre ③.
class _FauxPaiements implements PaymentService {
  _FauxPaiements(this.porte);
  final Completer<void>? porte;
  int paiements = 0;

  @override
  Future<PaymentResponse> createPayment({
    required String orderId,
    required String phoneNumber,
    String? method,
    String? payerMessage,
  }) async {
    paiements++;
    if (porte != null) await porte!.future;
    return PaymentResponse(
      paymentId: 'pay-$paiements',
      referenceId: 'ref',
      message: 'ok',
      mode: 'MANUAL',
      amount: 6750,
      currency: 'XAF',
      status: 'PENDING',
      pollAfterMs: 3000,
      instructions: const PaymentInstructions(
        phone: '060000000',
        amount: 6750,
        reference: 'REF-1',
        methodLabel: 'MTN Mobile Money',
        message: 'Envoyez le montant',
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} non attendu ici');
}

Restaurant _restaurant() => Restaurant(
      id: _restaurantId,
      name: 'Chez Lilia',
      address: 'Poto-Poto',
      products: const [],
      categoriesMap: const {},
      vendorType: VendorType.RESTAURANT,
    );

/// Options de livraison avec une **nouvelle** adresse : c'est le cas qui ouvre
/// la fenêtre ①, et le plus courant pour un premier client.
DeliveryOptions _optionsNouvelleAdresse() => DeliveryOptions(
      isDelivery: true,
      quartier: Quartier(id: 'q-1', nom: 'Poto-Poto', ville: 'Brazzaville'),
      address: null,
      newAddressRue: 'Rue Bayonne',
      newAddressLocation: null,
      deliveryFee: 1000,
    );

void main() {
  late _FauxAdresses adresses;
  late _FauxCheckout checkout;
  late _FauxPaiements paiements;

  Future<void> monter(
    WidgetTester tester, {
    Completer<void>? porteAdresse,
    Completer<void>? porteCommande,
    Completer<void>? portePaiement,
  }) async {
    tester.view.physicalSize = const Size(1400, 3200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    adresses = _FauxAdresses(porteAdresse);
    checkout = _FauxCheckout(porteCommande);
    paiements = _FauxPaiements(portePaiement);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cartControllerProvider.overrideWith(_FauxPanier.new),
          adresseControllerProvider.overrideWith(() => adresses),
          checkoutControllerProvider.overrideWith(() => checkout),
          paymentServiceProvider.overrideWithValue(paiements),
          platformSettingsProvider.overrideWith((ref) async => _bareme),
          restaurantControllerProvider(_restaurantId)
              .overrideWith((ref) async => _restaurant()),
          userProfileProvider.overrideWith(
            (ref) async => const AppUser(uid: 'uid-a', phone: '060000000'),
          ),
        ],
        child: MaterialApp(
          home: CheckoutPage(deliveryOptions: _optionsNouvelleAdresse()),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  /// Tape le bouton d'envoi **par sa clé**.
  ///
  /// Pas par son libellé : pendant l'envoi il affiche un indicateur, le texte
  /// disparaît, et le test échouerait sur un finder vide au lieu de mesurer
  /// ce qui l'intéresse. `warnIfMissed: false` parce qu'un bouton désactivé
  /// n'a pas de cible de pointage — et c'est précisément le résultat attendu.
  Future<void> taper(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const Key('checkout_submit')),
      warnIfMissed: false,
    );
  }

  testWidgets('deux taps dans la MÊME frame : une seule commande', (
    tester,
  ) async {
    await monter(tester);

    await taper(tester);
    await taper(tester);
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(adresses.creations, 1, reason: 'fenêtre ① — une seule adresse');
    expect(checkout.commandes, 1, reason: 'fenêtre ② — une seule commande');
    expect(paiements.paiements, 1, reason: 'fenêtre ③ — un seul encaissement');
  });

  testWidgets('tap pendant la création de l’ADRESSE (fenêtre ①)', (
    tester,
  ) async {
    final porte = Completer<void>();
    await monter(tester, porteAdresse: porte);

    await taper(tester);
    await tester.pump();
    // L'adresse est en vol. C'est ici que le bouton restait actif.
    await taper(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await taper(tester);
    await tester.pump();

    expect(
      adresses.creations,
      1,
      reason:
          'un aller-retour de 800 ms sans aucun indicateur : deux taps '
          'créaient deux adresses identiques dans le carnet du client',
    );

    porte.complete();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(checkout.commandes, 1);
    expect(paiements.paiements, 1);
  });

  testWidgets('tap pendant la création de la COMMANDE (fenêtre ②)', (
    tester,
  ) async {
    final porte = Completer<void>();
    await monter(tester, porteCommande: porte);

    await taper(tester);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await taper(tester);
    }

    expect(checkout.commandes, 1);

    porte.complete();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(paiements.paiements, 1);
  });

  testWidgets('tap pendant l’ouverture du PAIEMENT (fenêtre ③)', (
    tester,
  ) async {
    final porte = Completer<void>();
    await monter(tester, portePaiement: porte);

    await taper(tester);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
      await taper(tester);
    }

    expect(
      checkout.commandes,
      1,
      reason:
          '`_idempotencyKey` vient d’être remise à zéro : un second tap ici '
          'repartait avec une clé neuve, donc sans protection serveur',
    );
    expect(paiements.paiements, 1);

    porte.complete();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(tester.takeException(), isNull);
  });
}
