// C-04 — audit du 09/10/2026 : après l'abandon à trois minutes, l'écran
// d'attente était figé. « Vérifier maintenant » et le push FCM ne faisaient
// plus rien, même quand le paiement avait abouti entre-temps.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/payments/application/payment_status_controller.dart';
import 'package:lilia_app/features/payments/data/payment_service.dart';

class _FauxStatut implements PaymentService {
  PaymentStatus statut = PaymentStatus.pending;
  int appels = 0;

  @override
  Future<PaymentStatusResponse> checkPaymentStatus(String paymentId) async {
    appels++;
    return PaymentStatusResponse(paymentId: paymentId, status: statut);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} non attendu ici');
}

void main() {
  late _FauxStatut service;
  late ProviderContainer container;
  late DateTime horloge;

  final provider = paymentStatusControllerProvider('pay-1');

  setUp(() {
    horloge = DateTime(2026, 10, 10, 12);
    PaymentStatusController.now = () => horloge;
    service = _FauxStatut();
    container = ProviderContainer(
      overrides: [paymentServiceProvider.overrideWithValue(service)],
    );
    container.listen(provider, (_, _) {});
  });

  tearDown(() {
    container.dispose();
    PaymentStatusController.now = DateTime.now;
  });

  Future<void> abandonner() async {
    horloge = horloge.add(const Duration(minutes: 4));
    await container.read(provider.notifier).refreshNow();
    expect(container.read(provider).phase, PaymentWaitPhase.undetermined);
  }

  test('« Vérifier maintenant » après l’abandon : le succès est vu', () async {
    await abandonner();
    service.statut = PaymentStatus.success;

    await container.read(provider.notifier).refreshNow();

    expect(container.read(provider).phase, PaymentWaitPhase.succeeded);
  });

  test('push reçu après l’abandon : vérification immédiate, échec vu',
      () async {
    await abandonner();
    service.statut = PaymentStatus.failed;

    container.read(provider.notifier).onPushReceived();
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(container.read(provider).phase, PaymentWaitPhase.failed);
  });

  test('toujours PENDING : reste « indéterminé », sans relancer de cadence',
      () async {
    await abandonner();
    final avant = service.appels;

    await container.read(provider.notifier).refreshNow();

    expect(service.appels, avant + 1);
    expect(container.read(provider).phase, PaymentWaitPhase.undetermined);
  });

  test('issue tranchée : plus aucune interrogation', () async {
    service.statut = PaymentStatus.success;
    await container.read(provider.notifier).refreshNow();
    expect(container.read(provider).phase, PaymentWaitPhase.succeeded);
    final avant = service.appels;

    await container.read(provider.notifier).refreshNow();
    container.read(provider.notifier).onPushReceived();
    await Future<void>.delayed(Duration.zero);

    expect(service.appels, avant);
  });
}
