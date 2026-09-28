// Texte système agrandi (1.3×, 1.5×, 2×) sur un téléphone de 360 px : aucun
// débordement sur les composants du parcours d'achat. Un débordement lève une
// exception de rendu, donc fait échouer le test.
//
// Les polices réelles sont chargées : la police carrée de `flutter_test`
// fabriquait des débordements qui n'existent pas sur l'appareil.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/commandes/presentation/widgets/checkout_order_summary.dart';
import 'package:lilia_app/features/home/data/remote/home_controller.dart';
import 'package:lilia_app/features/home/presentation/widgets/popular_dishes_section.dart';
import 'package:lilia_app/features/home/presentation/widgets/product_stock_widgets.dart';
import 'package:lilia_app/features/home/presentation/widgets/vendor_product_card.dart';
import 'package:lilia_app/features/settings/data/platform_settings_service.dart';
import 'package:lilia_app/features/user/presentation/widgets/loyalty_card.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/models/produit.dart';
import 'package:lilia_app/theme/app_theme.dart';

import '../helpers/real_fonts.dart';

Product _produit({int formats = 2}) => Product(
  id: 'p1',
  name: 'Poulet braisé à la sauce arachide',
  description: 'Mariné au gingembre, servi avec bananes plantain',
  prixOriginal: 6000,
  imageUrl: null,
  restaurantId: 'resto-1',
  restaurantName: 'Chez Awa — Poto-Poto',
  categoryId: null,
  isAvailable: true,
  variants: [
    for (var i = 0; i < formats; i++)
      ProductVariant(
        id: 'v$i',
        label: i == 0 ? 'Demi poulet' : 'Poulet entier',
        prix: 6000.0 * (i + 1) + 120000,
        stockConsumption: i + 1,
        availableQuantity: 2,
        stockStatus: 'LOW',
      ),
  ],
);

Cart _panier() => Cart(
  id: 'c',
  userId: 'u',
  createdAt: DateTime(2026, 9, 28),
  updatedAt: DateTime(2026, 9, 28),
  items: [
    CartItem(
      id: 'l',
      cartId: 'c',
      productId: 'p1',
      variantId: 'v1',
      quantite: 12,
      createdAt: DateTime(2026, 9, 28),
      product: ProductItem(
        nom: 'Poulet braisé à la sauce arachide',
        restaurantId: 'r',
      ),
      variant: VariantItem(label: 'Entier', prix: 12000),
    ),
  ],
);

const _prod = PlatformSettings(
  serviceFeePercent: 15,
  loyaltyPointsPerOrder: 1,
  loyaltyPointValueXaf: 100,
  loyaltyMinRedemption: 5,
  referrerBonusPoints: 3,
);

Map<String, Widget Function()> _composants() => {
  'Plats populaires': () => const PopularDishesSection(),
  'Carte produit vendeur': () => VendorProductCard(product: _produit()),
  'Sélecteur de formats': () => VariantSelector(
    variants: _produit().variants,
    selected: null,
    onSelected: (_) {},
  ),
  'Récapitulatif checkout': () => CheckoutOrderSummary(
    cart: _panier(),
    isDelivery: true,
    subTotal: 144000,
    deliveryFee: 0,
    originalDeliveryFee: 1500,
    deliverySubsidy: 1500,
    serviceFee: 21600,
    promo: null,
    loyaltyDiscount: 12500,
    total: 153100,
  ),
  'Carte fidélité': () =>
      const LoyaltyCardView(points: 1250, settings: _prod, history: SizedBox()),
};

void main() {
  setUpAll(chargerPolicesReelles);

  for (final echelle in [1.0, 1.3, 1.5, 2.0]) {
    for (final MapEntry(key: nom, value: construire) in _composants().entries) {
      testWidgets('$nom à $echelle×', (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              popularProductsProvider.overrideWith(
                (ref) async => [_produit(), _produit(formats: 1)],
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(360, 780),
                  textScaler: TextScaler.linear(echelle),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: construire(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(seconds: 2)); // entrées décalées
        expect(tester.takeException(), isNull);
      });
    }
  }
}
