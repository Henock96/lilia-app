import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/commandes/data/delivery_tracking_repository.dart';
import 'package:lilia_app/features/commandes/data/tracking_socket_service.dart';
import 'package:lilia_app/features/commandes/presentation/widgets/handover_code_card.dart';
import 'package:lilia_app/features/commandes/presentation/widgets/report_issue_sheet.dart';

/// Preuve de remise et recours client (Master Audit v1, F-06).
void main() {
  group('DriverLocation.handoverCode', () {
    Map<String, dynamic> payload({String? code}) => {
      'id': 'd1',
      'status': 'EN_TRANSIT',
      'handoverCode': code,
      'order': <String, dynamic>{},
    };

    test('lu depuis GET /deliveries/by-order', () {
      expect(
        DriverLocation.fromHttpJson(payload(code: '4821')).handoverCode,
        '4821',
      );
    });

    test('un serveur antérieur (champ absent) ne casse rien', () {
      expect(DriverLocation.fromHttpJson(payload()).handoverCode, isNull);
    });

    test('une position WebSocket ne fait PAS disparaître le code', () {
      final initial = DriverLocation.fromHttpJson(payload(code: '4821'));
      final moved = initial.copyWithWsPosition(
        DriverPositionEvent(lat: -4.26, lng: 15.24, timestamp: DateTime(2026)),
      );
      expect(moved.handoverCode, '4821');
      expect(moved.latitude, -4.26);
    });
  });

  testWidgets('la carte affiche le code en grand', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: HandoverCodeCard(code: '0472')),
      ),
    );
    expect(find.byKey(const Key('handover-code')), findsOneWidget);
    expect(find.text('0472'), findsOneWidget);
  });

  group('ReportIssueSheet', () {
    Future<List<OrderIssueReport?>> open(WidgetTester tester) async {
      final results = <OrderIssueReport?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    results.add(await showReportIssueSheet(context)),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      return results;
    }

    testWidgets('sans motif choisi, on ne peut pas envoyer', (tester) async {
      await open(tester);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('issue-submit')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('« non reçue » + message : rend le motif serveur exact', (
      tester,
    ) async {
      final results = await open(tester);
      await tester.tap(find.byKey(const Key('issue-NOT_RECEIVED')));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '  Personne à la porte  ');
      await tester.tap(find.byKey(const Key('issue-submit')));
      await tester.pumpAndSettle();

      expect(results.single!.kind.wire, 'NOT_RECEIVED');
      expect(results.single!.message, 'Personne à la porte');
    });
  });
}
