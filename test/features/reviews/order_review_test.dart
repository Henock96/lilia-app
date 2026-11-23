// Lot B (15/11/2026) — avis par commande.
//
// Le serveur publie sur `GET /orders/:id` un verdict par case (boutique,
// livreur). L'app n'invite à noter que sur `CAN`, ne recopie pas la règle de
// preuve, et garde son comportement d'avant face à un serveur sans verdict.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/reviews/data/review_repository.dart';
import 'package:lilia_app/features/reviews/presentation/widgets/rate_driver_sheet.dart';
import 'package:lilia_app/features/reviews/presentation/widgets/review_card.dart';
import 'package:lilia_app/models/order.dart';
import 'package:lilia_app/models/review.dart';

class _Depot extends Fake implements ReviewRepository {
  final appels = <Map<String, Object?>>[];

  @override
  Future<Review> createReview({
    required String restaurantId,
    required int rating,
    String? comment,
    String? orderId,
  }) async {
    appels.add({
      'restaurantId': restaurantId,
      'rating': rating,
      'comment': comment,
      'orderId': orderId,
    });
    return Review.fromJson({'id': 'avis', 'rating': rating});
  }
}

Map<String, dynamic> _order({Object? review}) => {
  'id': 'o1',
  'restaurantId': 'shop',
  'userId': 'c1',
  'subTotal': 4000,
  'deliveryFee': 1000,
  'total': 5000,
  'paymentMethod': 'MTN_MOMO',
  'status': 'LIVRER',
  'createdAt': '2026-11-15T10:00:00.000Z',
  'updatedAt': '2026-11-15T11:00:00.000Z',
  'restaurant': {'nom': 'Chez Awa'},
  'items': const <Object>[],
  'review': ?review,
};

void main() {
  group('verdict d’avis', () {
    test('lu tel que publié', () {
      final order = Order.fromJson(
        _order(review: {'vendor': 'CAN', 'driver': 'DONE'}),
      );
      expect(order.review?.vendor, ReviewSlot.can);
      expect(order.review?.driver, ReviewSlot.done);
    });

    test('serveur antérieur : pas de verdict, pas d’invite inventée', () {
      expect(Order.fromJson(_order()).review, isNull);
    });

    test('valeur inconnue : aucune invite', () {
      final order = Order.fromJson(
        _order(review: {'vendor': 'PEUT_ETRE', 'driver': null}),
      );
      expect(order.review?.vendor, ReviewSlot.no);
      expect(order.review?.driver, ReviewSlot.no);
    });
  });

  testWidgets('feuille boutique : l’avis part avec la commande', (
    tester,
  ) async {
    // Taille téléphone : la feuille dépasse la fenêtre de test par défaut.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final depot = _Depot();
    bool? resultat;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reviewRepositoryProvider.overrideWithValue(depot)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                resultat = await RateDriverSheet.showForVendor(
                  context,
                  vendor: const RateVendorTarget(
                    restaurantId: 'shop',
                    orderId: 'o1',
                    restaurantName: 'Chez Awa',
                  ),
                );
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    // Une image pour pousser la route, puis la fin de son animation.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.text('Comment était votre commande chez Chez Awa ?'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('4 étoiles'));
    await tester.enterText(find.byType(TextField), '  Très bon  ');
    await tester.pump();
    await tester.ensureVisible(find.text('Envoyer ma note'));
    await tester.pump();
    await tester.tap(find.text('Envoyer ma note'));
    await tester.pump(const Duration(seconds: 1));

    expect(depot.appels, [
      {
        'restaurantId': 'shop',
        'rating': 4,
        'comment': 'Très bon',
        'orderId': 'o1',
      },
    ]);
    expect(resultat, isTrue);
  });

  testWidgets('la réponse de la boutique s’affiche sous l’avis de son auteur', (
    tester,
  ) async {
    final review = Review.fromJson({
      'id': 'r1',
      'rating': 5,
      'comment': 'Parfait',
      'user': {'nom': 'Awa M.'},
      'vendorReply': 'Merci, à bientôt !',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReviewCard(review: review, isOwner: true)),
      ),
    );
    expect(find.byKey(const Key('review-vendor-reply')), findsOneWidget);
    expect(find.text('Merci, à bientôt !'), findsOneWidget);
  });

  testWidgets('sans réponse, aucun encart', (tester) async {
    final review = Review.fromJson({
      'id': 'r1',
      'rating': 5,
      'vendorReply': '',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReviewCard(review: review, isOwner: true)),
      ),
    );
    expect(find.byKey(const Key('review-vendor-reply')), findsNothing);
  });
}
