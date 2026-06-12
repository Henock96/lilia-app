import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/core/network/network_observer.dart';

void main() {
  test('NoopNetworkObserver ne lève rien', () {
    const obs = NoopNetworkObserver();
    const snap = RequestSnapshot(method: 'GET', path: '/orders/my', statusCode: 200);
    expect(() => obs.onRequest(snap), returnsNormally);
    expect(
      () => obs.onError(const ApiException('x'), snap),
      returnsNormally,
    );
  });

  test('RequestSnapshot porte les champs', () {
    const snap = RequestSnapshot(
      method: 'POST', path: '/orders/checkout', statusCode: 201,
      elapsed: Duration(milliseconds: 120),
    );
    expect(snap.method, 'POST');
    expect(snap.path, '/orders/checkout');
    expect(snap.statusCode, 201);
    expect(snap.elapsed, const Duration(milliseconds: 120));
  });
}
