// C-22 — audit du 09/10/2026 : la position rejouée par `order:watch` est la
// valeur Redis `{ lat, lng, accuracy, ts }` (`tracking.service.ts`), sans
// `timestamp` ni `eta`.

import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/commandes/data/delivery_tracking_repository.dart';
import 'package:lilia_app/features/commandes/data/tracking_socket_service.dart';

void main() {
  test('position rejouée : datée de son `ts`, pas de « maintenant »', () {
    final ts = DateTime(2026, 10, 10, 12, 0).millisecondsSinceEpoch;
    final e = DriverPositionEvent.fromJson({
      'orderId': 'o-1',
      'lat': -4.26,
      'lng': 15.28,
      'accuracy': 12,
      'ts': ts,
    });
    expect(e.timestamp, DateTime.fromMillisecondsSinceEpoch(ts));
  });

  test('diffusion en direct : `timestamp` reste la référence', () {
    final e = DriverPositionEvent.fromJson({
      'lat': -4.26,
      'lng': 15.28,
      'eta': 7,
      'timestamp': 1000,
      'ts': 5000,
    });
    expect(e.timestamp, DateTime.fromMillisecondsSinceEpoch(1000));
  });

  test('position sans ETA : l’ETA connue est conservée', () {
    final avant = DriverLocation(
      latitude: -4.26,
      longitude: 15.28,
      updatedAt: DateTime(2026, 10, 10, 12),
      etaMinutes: 9,
    );
    final apres = avant.copyWithWsPosition(
      DriverPositionEvent(
        lat: -4.27,
        lng: 15.29,
        timestamp: DateTime(2026, 10, 10, 12, 1),
      ),
    );
    expect(apres.etaMinutes, 9);
    expect(apres.latitude, -4.27);
  });

  test('position avec ETA : la nouvelle ETA remplace l’ancienne', () {
    final avant = DriverLocation(
      latitude: -4.26,
      longitude: 15.28,
      etaMinutes: 9,
    );
    final apres = avant.copyWithWsPosition(
      DriverPositionEvent(
        lat: -4.27,
        lng: 15.29,
        eta: 4,
        timestamp: DateTime(2026, 10, 10, 12, 1),
      ),
    );
    expect(apres.etaMinutes, 4);
  });
}
