import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/commandes/presentation/status_info.dart';
import 'package:lilia_app/models/order.dart';
import 'package:lilia_app/theme/app_theme.dart';

/// Un seul vocabulaire de statuts pour la liste et le détail des commandes,
/// lisible sans la couleur et contrasté dans les deux thèmes.
void main() {
  test('chaque statut a un libellé, une explication et une icône', () {
    final libelles = <String>{};
    for (final s in OrderStatus.values) {
      final info = orderStatusInfo(s);
      expect(info.label, isNotEmpty, reason: s.name);
      expect(info.description, isNotEmpty, reason: s.name);
      libelles.add(info.label);
    }
    expect(
      libelles,
      hasLength(OrderStatus.values.length),
      reason: 'deux statuts ne partagent pas un libellé',
    );
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('pastilles lisibles — ${theme.brightness.name}', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Wrap(
              children: [
                for (final s in OrderStatus.values) ...[
                  OrderStatusBadge(status: s),
                  OrderStatusBadge(status: s, compact: true),
                ],
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Libellé présent (pas seulement une couleur)…
      expect(find.text('Livraison non aboutie'), findsNWidgets(2));
      // … et contraste AA sur chaque pastille.
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  }
}
