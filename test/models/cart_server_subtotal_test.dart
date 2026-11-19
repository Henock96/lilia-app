import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/models/cart.dart';

/// Lot 6 (L6-3) — `GET /cart` annonce `subTotalXaf`. Il fait foi ; le calcul
/// local ne sert qu'en son absence (panier invité, serveur ancien) et pendant
/// une mise à jour optimiste, où il serait périmé.
void main() {
  Map<String, dynamic> cart({Object? subTotalXaf, bool withField = true}) => {
        'id': 'c1',
        'userId': 'u1',
        'items': <dynamic>[
          {
            'id': 'i1',
            'cartId': 'c1',
            'productId': 'p1',
            'variantId': 'v1',
            'quantite': 2,
            'createdAt': '2026-11-19T10:00:00.000Z',
            'product': <String, dynamic>{},
            'variant': <String, dynamic>{},
            'unitPriceXaf': 1500,
          },
        ],
        'createdAt': '2026-11-19T10:00:00.000Z',
        'updatedAt': '2026-11-19T10:00:00.000Z',
        if (withField) 'subTotalXaf': subTotalXaf,
      };

  test('sous-total serveur présent : il fait foi', () {
    // Le serveur sait ce que le client ignore (prix revu, ligne indisponible).
    expect(Cart.fromJson(cart(subTotalXaf: 2800)).totalPrice, 2800);
  });

  test('serveur ancien ou panier invité : calcul local', () {
    expect(Cart.fromJson(cart(withField: false)).totalPrice, 3000);
    expect(Cart.fromJson(cart(subTotalXaf: null)).totalPrice, 3000);
  });

  test('lignes modifiées localement : le sous-total serveur est écarté', () {
    final serveur = Cart.fromJson(cart(subTotalXaf: 2800));
    final optimiste = serveur.copyWith(
      items: [serveur.items.first.copyWith(quantite: 3)],
    );
    expect(optimiste.subTotalXaf, isNull);
    expect(optimiste.totalPrice, 4500);
  });

  test('copyWith sans toucher aux lignes : sous-total conservé', () {
    final serveur = Cart.fromJson(cart(subTotalXaf: 2800));
    expect(serveur.copyWith(userId: 'u2').totalPrice, 2800);
  });

  test('panier vide : 0, même si le serveur annonce autre chose', () {
    final vide = Cart.fromJson({...cart(subTotalXaf: 2800), 'items': <dynamic>[]});
    expect(vide.totalPrice, 0);
  });
}
