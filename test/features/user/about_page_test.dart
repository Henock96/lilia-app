// P3-06 / P3-08 — la page « À propos » dit la vraie version et ses contacts
// ouvrent réellement quelque chose.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/support/support_contact.dart';
import 'package:lilia_app/features/user/presentation/pages/about_page.dart';
import 'package:lilia_app/theme/app_theme.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Lilia Food',
      packageName: 'com.lilia.app',
      version: '1.3.5',
      buildNumber: '39',
      buildSignature: '',
    );
  });

  Future<List<Uri>> monter(
    WidgetTester tester, {
    bool ouvertureReussie = true,
  }) async {
    final ouvertes = <Uri>[];
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AboutPage(
          launcher: (uri) async {
            ouvertes.add(uri);
            return ouvertureReussie;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ouvertes;
  }

  testWidgets('version = binaire installé, pas une constante', (tester) async {
    await monter(tester);
    expect(find.text('Version 1.3.5 (39)'), findsOneWidget);
    expect(find.textContaining('1.3.3'), findsNothing);
  });

  testWidgets('« Nous contacter » ouvre un mailto: vers le support', (
    tester,
  ) async {
    final ouvertes = await monter(tester);
    await tester.tap(find.text('Nous contacter'));
    await tester.pump();
    expect(ouvertes.single.scheme, 'mailto');
    expect(ouvertes.single.path, SupportContact.email);
  });

  testWidgets('« Assistance téléphonique » ouvre un tel:', (tester) async {
    final ouvertes = await monter(tester);
    await tester.tap(find.text('Assistance téléphonique'));
    await tester.pump();
    expect(ouvertes.single.toString(), 'tel:${SupportContact.phoneE164}');
  });

  testWidgets('aucune application : la coordonnée est copiée et c\'est dit', (
    tester,
  ) async {
    String? copie;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copie = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await monter(tester, ouvertureReussie: false);
    await tester.tap(find.text('Nous contacter'));
    await tester.pump();
    await tester.pump();
    expect(copie, SupportContact.email);
    expect(find.textContaining('a été copié'), findsOneWidget);
  });

  test('mailto : objet encodé sans « + », référence de commande reprise', () {
    final uri = SupportContact.emailUri(orderReference: 'LF-1234');
    expect(uri.toString(), isNot(contains('+')));
    expect(Uri.decodeComponent(uri.query), contains('commande LF-1234'));
  });
}
