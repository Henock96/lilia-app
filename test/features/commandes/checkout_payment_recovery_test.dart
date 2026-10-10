// C-01 / C-07 — audit du 09/10/2026.
//
// **La relance après échec de `POST /payments` doit suivre le même aiguillage
// que le chemin nominal.**
//
// Avant : « Réessayer » dans la boîte de reprise appelait directement la
// modale de virement manuel. Sous pawaPay, elle affichait un numéro
// destinataire VIDE pendant que la demande USSD partait réellement sur le
// téléphone, et « J'ai payé » menait à « Commande passée » sans interroger le
// statut. Et la boîte de reprise se fermait au retour Android.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/core/network/api_exception.dart';
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
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/models/vendor_type.dart';
import 'package:lilia_app/routing/app_route_enum.dart';

const _restaurantId = 'resto-1';

const _bareme = PlatformSettings(
  serviceFeePercent: 15,
  loyaltyPointsPerOrder: 1,
  loyaltyPointValueXaf: 100,
  loyaltyMinRedemption: 1,
  referrerBonusPoints: 1,
);

class _FauxPanier extends CartController {
  @override
  Future<Cart?> build() async => Cart(
        id: 'panier-1',
        userId: 'uid-a',
        createdAt: DateTime(2026, 10, 10),
        updatedAt: DateTime(2026, 10, 10),
        items: [
          CartItem(
            id: 'ligne-1',
            cartId: 'panier-1',
            productId: 'prod-1',
            variantId: 'var-1',
            quantite: 1,
            createdAt: DateTime(2026, 10, 10),
            product: ProductItem(nom: 'Poulet', restaurantId: _restaurantId),
            variant: VariantItem(label: 'Normale', prix: 5000),
          ),
        ],
      );
}

class _FauxAdresses extends AdresseController {
  @override
  Future<List<Adresse>> build() async => const [];
}

class _FauxCheckout extends CheckoutController {
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
    ({String? id})? seenVendorOffer,
  }) async =>
      Checkout(
        id: 'commande-1',
        restaurantId: _restaurantId,
        userId: 'uid-a',
        subTotal: 5000,
        deliveryFee: 0,
        total: 5750,
        paymentMethod: paymentMethod,
        status: 'EN_ATTENTE',
        createdAt: DateTime(2026, 10, 10),
        updatedAt: DateTime(2026, 10, 10),
        items: const [],
      );
}

/// Échoue sur les [echecs] premiers appels, puis rend [reussite].
class _FauxPaiements implements PaymentService {
  _FauxPaiements({required this.echecs, required this.reussite});
  final int echecs;
  final PaymentResponse reussite;
  final numeros = <String>[];

  @override
  Future<PaymentResponse> createPayment({
    required String orderId,
    required String phoneNumber,
    String? method,
    String? payerMessage,
  }) async {
    numeros.add(phoneNumber);
    if (numeros.length <= echecs) {
      throw const ApiException('réseau', kind: ApiErrorKind.network);
    }
    return reussite;
  }

  @override
  bool validatePhoneNumber(String phoneNumber, {String countryCode = '242'}) =>
      true;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} non attendu ici');
}

PaymentResponse _interactif() => PaymentResponse(
      paymentId: 'pay-pawapay',
      referenceId: 'ref',
      message: 'ok',
      mode: 'PAWAPAY',
      amount: 5750,
      currency: 'XAF',
      status: 'PENDING',
      pollAfterMs: 3000,
    );

PaymentResponse _manuelSansNumero() => PaymentResponse(
      paymentId: 'pay-manuel',
      referenceId: 'ref',
      message: 'ok',
      mode: 'MANUAL',
      amount: 5750,
      currency: 'XAF',
      status: 'PENDING',
      pollAfterMs: 3000,
    );

void main() {
  late _FauxPaiements paiements;

  Future<void> monter(
    WidgetTester tester, {
    required int echecs,
    required PaymentResponse reussite,
    String telephone = '06 123 45 67',
  }) async {
    tester.view.physicalSize = const Size(1400, 3200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    paiements = _FauxPaiements(echecs: echecs, reussite: reussite);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => CheckoutPage(
            deliveryOptions: DeliveryOptions(
              isDelivery: false,
              quartier: null,
              address: null,
              newAddressRue: null,
              newAddressLocation: null,
              deliveryFee: 0,
            ),
          ),
        ),
        GoRoute(
          path: '/paiement/:paymentId',
          name: AppRoutes.paymentPending.routeName,
          builder: (_, state) =>
              Text('attente ${state.pathParameters['paymentId']}'),
        ),
        GoRoute(
          path: '/commandes',
          name: AppRoutes.commandes.routeName,
          builder: (_, _) => const Text('mes commandes'),
        ),
        GoRoute(
          path: '/succes',
          name: AppRoutes.orderSuccess.routeName,
          builder: (_, _) => const Text('commande passée'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cartControllerProvider.overrideWith(_FauxPanier.new),
          adresseControllerProvider.overrideWith(_FauxAdresses.new),
          checkoutControllerProvider.overrideWith(_FauxCheckout.new),
          paymentServiceProvider.overrideWithValue(paiements),
          platformSettingsProvider.overrideWith((ref) async => _bareme),
          restaurantControllerProvider(_restaurantId).overrideWith(
            (ref) async => Restaurant(
              id: _restaurantId,
              name: 'Chez Lilia',
              address: 'Poto-Poto',
              products: const [],
              categoriesMap: const {},
              vendorType: VendorType.RESTAURANT,
            ),
          ),
          userProfileProvider.overrideWith(
            (ref) async => AppUser(uid: 'uid-a', phone: telephone),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> laisserPasser(WidgetTester tester) async {
    // `_createPaymentWithRetry` attend 2 s entre ses deux essais.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets(
      'relance réussie en mode interactif : écran d’attente, jamais la '
      'modale de virement', (tester) async {
    await monter(tester, echecs: 2, reussite: _interactif());

    await tester.tap(find.byKey(const Key('checkout_submit')));
    await laisserPasser(tester);

    expect(find.text('Commande enregistrée'), findsOneWidget);

    // C-07 : le retour Android ne ferme pas la boîte de reprise.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Commande enregistrée'), findsOneWidget);

    await tester.tap(find.text('Réessayer'));
    await laisserPasser(tester);

    expect(find.text('attente pay-pawapay'), findsOneWidget);
    expect(find.text('J\'ai payé'), findsNothing);
    expect(find.text('commande passée'), findsNothing);
    expect(paiements.numeros, hasLength(3));
  });

  testWidgets('mode manuel sans numéro destinataire : pas de modale vide',
      (tester) async {
    await monter(tester, echecs: 0, reussite: _manuelSansNumero());

    await tester.tap(find.byKey(const Key('checkout_submit')));
    await laisserPasser(tester);

    expect(find.text('Commande enregistrée'), findsOneWidget);
    expect(find.text('J\'ai payé'), findsNothing);
    expect(find.text('commande passée'), findsNothing);
  });

  testWidgets('C-03 : le numéro part sans ses espaces', (tester) async {
    await monter(tester, echecs: 0, reussite: _interactif());

    await tester.tap(find.byKey(const Key('checkout_submit')));
    await laisserPasser(tester);

    expect(paiements.numeros, ['061234567']);
    expect(find.text('attente pay-pawapay'), findsOneWidget);
  });

  testWidgets('C-03 : un numéro non congolais est refusé avant la commande',
      (tester) async {
    await monter(
      tester,
      echecs: 0,
      reussite: _interactif(),
      telephone: '123456789',
    );

    await tester.tap(find.byKey(const Key('checkout_submit')));
    await laisserPasser(tester);

    expect(paiements.numeros, isEmpty);
    expect(find.textContaining('congolais invalide'), findsOneWidget);
  });
}
