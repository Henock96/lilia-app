import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/features/auth/presentation/phone_collection_sheet.dart';

void main() {
  testWidgets('affiche le champ, le bouton Enregistrer et le bouton Plus tard',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: PhoneCollectionSheet()),
        ),
      ),
    );

    expect(find.byKey(const Key('phone_collection_field')), findsOneWidget);
    expect(find.byKey(const Key('phone_collection_save')), findsOneWidget);
    expect(find.byKey(const Key('phone_collection_skip')), findsOneWidget);
  });

  testWidgets('le bouton Plus tard ferme la feuille (skippable)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const PhoneCollectionSheet(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phone_collection_skip')), findsOneWidget);

    await tester.tap(find.byKey(const Key('phone_collection_skip')));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneCollectionSheet), findsNothing);
  });
}
