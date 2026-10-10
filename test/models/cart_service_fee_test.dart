import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/models/cart.dart';

/// D-4 (10/10/2026) — `GET /cart` annonce le taux de frais de service de la
/// boutique du panier. Une épicerie a le sien ; un serveur ancien ne l'envoie
/// pas, et l'app retombe alors sur le taux général.
void main() {
  Map<String, dynamic> cart({Object? serviceFeePercent, bool withField = true}) => {
        'id': 'c1',
        'userId': 'u1',
        'items': <dynamic>[],
        'createdAt': '2026-10-10T10:00:00.000Z',
        'updatedAt': '2026-10-10T10:00:00.000Z',
        if (withField) 'serviceFeePercent': serviceFeePercent,
      };

  test('taux annoncé : lu tel quel (5)', () {
    expect(Cart.fromJson(cart(serviceFeePercent: 5)).serviceFeePercent, 5);
  });

  test('taux décimal : lu en double (7,5)', () {
    expect(Cart.fromJson(cart(serviceFeePercent: 7.5)).serviceFeePercent, 7.5);
  });

  test('serveur ancien (champ absent) ou panier vide (null) : null', () {
    expect(Cart.fromJson(cart(withField: false)).serviceFeePercent, isNull);
    expect(Cart.fromJson(cart(serviceFeePercent: null)).serviceFeePercent, isNull);
  });

  test('copyWith conserve le taux', () {
    final c = Cart.fromJson(cart(serviceFeePercent: 5));
    expect(c.copyWith(items: const []).serviceFeePercent, 5);
  });
}
