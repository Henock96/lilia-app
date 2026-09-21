// **Pas de barème, pas de total.**
//
// Le checkout affichait une commission de 8 % — le défaut Prisma — dès que
// `/platform-settings` tardait ou échouait, pendant que la production en
// facture 15. Sur 20 000 FCFA de panier, le client validait 22 600 et l'écran
// de paiement lui réclamait 24 000.
//
// Ces tests montent la vraie `CheckoutPage` et vérifient les trois états du
// barème : reçu, en cours, absent.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/commandes/presentation/checkout_page.dart';
import 'package:lilia_app/features/commandes/presentation/delivery_options_page.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_controller.dart';
import 'package:lilia_app/features/settings/data/platform_settings_service.dart';
import 'package:lilia_app/features/user/application/profile_controller.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/models/vendor_type.dart';

const _restaurantId = 'resto-1';

/// Panier de 20 000 FCFA — le montant de l'exemple du rapport d'audit.
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
          quantite: 2,
          createdAt: DateTime(2026, 9, 20),
          product: ProductItem(nom: 'Poulet braisé', restaurantId: _restaurantId),
          variant: VariantItem(label: 'Normale', prix: 10000),
        ),
      ],
    );

Restaurant _restaurant() => Restaurant(
      id: _restaurantId,
      name: 'Chez Lilia',
      address: 'Poto-Poto, Brazzaville',
      products: const [],
      categoriesMap: const {},
      vendorType: VendorType.RESTAURANT,
    );

class _FauxPanier extends CartController {
  @override
  Future<Cart?> build() async => _panier();
}

/// Barème de **production** : 15 %, pas les 8 % du défaut Prisma.
const _baremeProd = PlatformSettings(
  serviceFeePercent: 15,
  loyaltyPointsPerOrder: 1,
  loyaltyPointValueXaf: 100,
  loyaltyMinRedemption: 1,
  referrerBonusPoints: 1,
);

DeliveryOptions _options() => DeliveryOptions(
      isDelivery: true,
      quartier: null,
      address: null,
      newAddressRue: null,
      newAddressLocation: null,
      deliveryFee: 1000,
    );

/// Trouve un montant affiché, **quel que soit son séparateur de milliers**.
///
/// `intl` groupe les milliers avec une espace insécable étroite (U+202F) en
/// français : `montant('24 000')` avec une espace ordinaire ne
/// trouve rien, et le test échouerait en racontant que le total est absent
/// alors qu'il est à l'écran. La sonde doit mesurer le montant, pas l'encodage
/// de son espace.
Finder montant(String attendu) => find.byWidgetPredicate(
      (w) =>
          w is Text &&
          (w.data ?? '')
              .replaceAll(RegExp(r'[\s\u00A0\u202F\u2009]'), ' ')
              .contains(attendu),
      description: 'montant « $attendu »',
    );

void main() {
  /// Monte la vraie page avec un barème donné, ou en échec.
  Future<void> monter(
    WidgetTester tester, {
    PlatformSettings? bareme,
    bool enEchec = false,
    Completer<PlatformSettings>? enAttente,
  }) async {
    tester.view.physicalSize = const Size(1400, 3200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cartControllerProvider.overrideWith(_FauxPanier.new),
          restaurantControllerProvider(_restaurantId)
              .overrideWith((ref) async => _restaurant()),
          userProfileProvider.overrideWith(
            (ref) async => const AppUser(uid: 'uid-a', phone: '060000000'),
          ),
          platformSettingsProvider.overrideWith((ref) async {
            if (enEchec) throw Exception('réseau');
            if (enAttente != null) return enAttente.future;
            return bareme!;
          }),
        ],
        child: MaterialApp(home: CheckoutPage(deliveryOptions: _options())),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  testWidgets('barème reçu : le total est celui du serveur (15 %)', (
    tester,
  ) async {
    await monter(tester, bareme: _baremeProd);

    // 20 000 + 1 000 de livraison + 3 000 de commission (15 %) = 24 000.
    expect(montant('24 000'), findsWidgets);
    expect(
      montant('22 600'),
      findsNothing,
      reason: 'ce serait le total calculé avec l’ancien repli à 8 %',
    );
    expect(find.text('Valider et payer'), findsOneWidget);
  });

  testWidgets('barème absent : aucun total, et un bouton Réessayer', (
    tester,
  ) async {
    await monter(tester, enEchec: true);
    expect(find.text('Frais indisponibles'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(
      find.text('Valider et payer'),
      findsNothing,
      reason: 'on ne propose pas de payer un montant qu’on ne sait pas calculer',
    );
    expect(
      montant('22 600'),
      findsNothing,
      reason: 'le repli à 8 % ne doit plus jamais produire de montant',
    );
  });

  testWidgets('barème en cours de chargement : on attend, on n’invente pas', (
    tester,
  ) async {
    final porte = Completer<PlatformSettings>();
    await monter(tester, enAttente: porte);

    expect(
      find.text('Valider et payer'),
      findsNothing,
      reason: 'les premières frames du checkout affichaient 8 % en attendant',
    );
    expect(find.text('Frais indisponibles'), findsNothing);

    porte.complete(_baremeProd);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(find.text('Valider et payer'), findsOneWidget);
    expect(montant('24 000'), findsWidgets);
  });
}
