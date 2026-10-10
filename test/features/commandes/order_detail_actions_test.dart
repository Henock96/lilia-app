// Faux contrôleur de test : il expose volontairement un compteur pour les
// assertions (`avoid_public_notifier_properties` vise le code de prod).
// ignore_for_file: riverpod_lint/avoid_public_notifier_properties
// Audit du 09/10/2026 — gestes du détail de commande, sur la vraie page.
//
// C-05 : « Vérifier maintenant » doit interroger le prestataire
//        (`GET /payments/:id/status`), pas relire `by-order`.
// C-06 : l'issue d'une annulation (succès ou refus) doit s'afficher.
// C-18 : pendant l'annulation, le bouton est inactif — un seul appel.
// C-25 : un paiement en vol est signalé avant d'annuler.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/commandes/data/order_controller.dart';
import 'package:lilia_app/features/commandes/presentation/commande_detail_page.dart';
import 'package:lilia_app/features/payments/application/payment_status_controller.dart';
import 'package:lilia_app/features/payments/data/payment_service.dart';
import 'package:lilia_app/models/order.dart';

import '../../helpers/real_fonts.dart';

const _id = 'o-1';

Order _commande() => Order.fromJson({
      'id': _id,
      'status': 'EN_ATTENTE',
      'allowedActions': ['CANCEL'],
      'isDelivery': true,
      'subTotal': 20000,
      'deliveryFee': 1000,
      'serviceFee': 3000,
      'total': 24000,
      'paymentMethod': 'MTN_MOMO',
      'deliveryAddress': 'Rue Mbochis, Poto-Poto',
      'createdAt': '2026-10-09T11:00:00.000Z',
      'updatedAt': '2026-10-09T11:00:00.000Z',
      'restaurant': {'nom': 'Chez Awa', 'adresse': 'Av. de la Paix'},
      'items': <dynamic>[],
    });

class _Liste extends UserOrders {
  _Liste({this.porte, this.erreur});
  final Completer<void>? porte;
  final Object? erreur;
  int annulations = 0;

  @override
  Future<List<Order>> build() async => const [];

  @override
  Future<void> cancelOrder(String orderId) async {
    annulations++;
    if (porte != null) await porte!.future;
    if (erreur != null) throw erreur!;
  }
}

class _Paiements implements PaymentService {
  _Paiements({required this.enCours});
  final bool enCours;
  final verifications = <String>[];

  @override
  Future<PaymentStatusResponse> checkPaymentStatus(String paymentId) async {
    verifications.add(paymentId);
    return PaymentStatusResponse(
      paymentId: paymentId,
      status: PaymentStatus.success,
    );
  }

  @override
  Future<PaymentStatusResponse?> getPaymentForOrder(String orderId) async =>
      enCours
          ? PaymentStatusResponse(
              paymentId: 'p-1',
              status: PaymentStatus.pending,
            )
          : null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} non attendu ici');
}

void main() {
  late _Liste liste;
  late _Paiements paiements;

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    await chargerPolicesReelles();
  });

  Future<void> monter(
    WidgetTester tester, {
    bool paiementEnCours = false,
    Completer<void>? porte,
    Object? erreur,
  }) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    liste = _Liste(porte: porte, erreur: erreur);
    paiements = _Paiements(enCours: paiementEnCours);

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          orderDetailProvider(_id).overrideWith((ref) async => _commande()),
          userOrdersProvider.overrideWith(() => liste),
          paymentServiceProvider.overrideWithValue(paiements),
          orderPaymentProvider(_id).overrideWith(
            (ref) async => paiementEnCours
                ? PaymentStatusResponse(
                    paymentId: 'p-1',
                    status: PaymentStatus.pending,
                  )
                : null,
          ),
        ],
        child: const MaterialApp(home: OrderDetailPage(orderId: _id)),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> laisser(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('C-05 : « Vérifier maintenant » interroge le prestataire', (
    tester,
  ) async {
    await monter(tester, paiementEnCours: true);

    await tester.tap(find.byKey(const Key('payment_in_progress_check')));
    await laisser(tester);

    expect(paiements.verifications, ['p-1']);
  });

  testWidgets('C-06 : annulation réussie → le client le voit', (tester) async {
    await monter(tester);

    await tester.tap(find.byKey(const Key('order_detail_cancel')));
    await laisser(tester);
    await tester.tap(find.text('Oui, annuler'));
    await laisser(tester);

    expect(liste.annulations, 1);
    expect(find.text('Commande annulée.'), findsOneWidget);
  });

  testWidgets('C-06 : refus du serveur → son message est affiché', (
    tester,
  ) async {
    await monter(
      tester,
      erreur: const ApiException(
        'Cette commande ne peut plus être annulée.',
        statusCode: 400,
        kind: ApiErrorKind.client,
      ),
    );

    await tester.tap(find.byKey(const Key('order_detail_cancel')));
    await laisser(tester);
    await tester.tap(find.text('Oui, annuler'));
    await laisser(tester);

    expect(
      find.text('Cette commande ne peut plus être annulée.'),
      findsOneWidget,
    );
  });

  testWidgets('C-18 : pendant l’annulation, un second tap ne repart pas', (
    tester,
  ) async {
    final porte = Completer<void>();
    await monter(tester, porte: porte);

    await tester.tap(find.byKey(const Key('order_detail_cancel')));
    await laisser(tester);
    await tester.tap(find.text('Oui, annuler'));
    await laisser(tester);

    await tester.tap(
      find.byKey(const Key('order_detail_cancel')),
      warnIfMissed: false,
    );
    await laisser(tester);
    expect(find.text('Oui, annuler'), findsNothing);
    expect(liste.annulations, 1);

    porte.complete();
    await laisser(tester);
  });

  testWidgets('C-25 : paiement en vol → avertissement avant d’annuler', (
    tester,
  ) async {
    await monter(tester, paiementEnCours: true);

    await tester.tap(find.byKey(const Key('order_detail_cancel')));
    await laisser(tester);

    expect(
      find.byKey(const Key('cancel_payment_pending_warning')),
      findsOneWidget,
    );
    await tester.tap(find.text('Non, garder'));
    await laisser(tester);
    expect(liste.annulations, 0);
  });

  testWidgets('pas de paiement en vol : pas d’avertissement', (tester) async {
    await monter(tester);

    await tester.tap(find.byKey(const Key('order_detail_cancel')));
    await laisser(tester);

    expect(
      find.byKey(const Key('cancel_payment_pending_warning')),
      findsNothing,
    );
  });
}
