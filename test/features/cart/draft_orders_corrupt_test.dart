// C-12 — audit du 09/10/2026 : un brouillon illisible effaçait la liste
// entière (try/catch global → liste vide → réécrite vide au prochain
// enregistrement).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/cart/application/draft_orders_provider.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/models/draft_order.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/fake_auth_repository.dart';

DraftOrder _brouillon(String id) {
  final items = [
    CartItem(
      id: 'i-$id',
      cartId: 'c',
      productId: 'p-$id',
      variantId: 'v-$id',
      quantite: 1,
      createdAt: DateTime(2026, 10, 1),
      product: ProductItem(nom: 'Plat $id', restaurantId: 'resto-1'),
      variant: VariantItem(label: 'Normal', prix: 2000),
    ),
  ];
  return DraftOrder(
    id: id,
    restaurantName: 'Chez Lilia',
    items: items,
    totalPrice: 2000,
    createdAt: DateTime(2026, 10, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('un brouillon illisible est écarté, les autres survivent', () async {
    SharedPreferences.setMockInitialValues({
      'draft_orders__invite': [
        _brouillon('a').toJson(),
        '{"format":"inconnu"',
        _brouillon('b').toJson(),
      ],
    });
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      ],
    );
    addTearDown(c.dispose);

    final drafts = await c.read(draftOrdersProvider.future);

    expect(drafts.map((d) => d.id), containsAll(<String>['a', 'b']));
    expect(drafts, hasLength(2));
  });
}
