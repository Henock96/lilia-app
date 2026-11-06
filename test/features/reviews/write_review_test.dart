// Modifier un avis : ne jamais écraser ce qu'on n'a pas pu relire.
//
// Audit du 05/11/2026 : une lecture ratée valait « aucun avis ». Le formulaire
// s'ouvrait vide, et l'envoi remplaçait l'avis existant par une note et un
// commentaire vides.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/reviews/data/review_repository.dart';
import 'package:lilia_app/features/reviews/presentation/screens/write_review_screen.dart';
import 'package:lilia_app/features/reviews/presentation/widgets/star_rating.dart';
import 'package:lilia_app/models/review.dart';

const _route = '/reviews/restaurant/r/my-review';

final _lectureImpossible = find.textContaining('Impossible de charger votre avis');

class _Depot extends Fake implements ReviewRepository {
  Object? panne;
  Completer<void>? barriere;
  int lectures = 0;

  @override
  Future<Review?> getMyReview(String restaurantId) async {
    lectures++;
    await barriere?.future;
    if (panne != null) throw panne!;
    return Review.fromJson(const {
      'id': 'avis-1',
      'rating': 4,
      'comment': 'Très bon poulet',
    });
  }
}

void main() {
  group('lecture de mon avis', () {
    ReviewRepository depotQuiRepond(int code) {
      final client = ApiClient.test(
        baseUrl: 'https://test.local',
        tokenProvider: () async => 'jeton',
        forceRefreshToken: () async => 'jeton',
      );
      DioAdapter(
        dio: client.dio,
      ).onGet(_route, (server) => server.reply(code, {'message': 'refus'}));
      return ReviewRepository(client);
    }

    test('404 : aucun avis', () async {
      expect(await depotQuiRepond(404).getMyReview('r'), isNull);
    });

    test('500 : une panne, pas une absence', () async {
      await expectLater(
        depotQuiRepond(500).getMyReview('r'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('modification d’un avis', () {
    late _Depot depot;

    setUp(() => depot = _Depot());

    Future<void> ouvrir(WidgetTester tester, {String? avis = 'avis-1'}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [reviewRepositoryProvider.overrideWithValue(depot)],
          child: MaterialApp(
            home: WriteReviewScreen(restaurantId: 'r', existingReviewId: avis),
          ),
        ),
      );
      await tester.pump();
    }

    void noter(WidgetTester tester, int note) => tester
        .widget<StarRatingInput>(find.byType(StarRatingInput))
        .onRatingChanged(note);

    bool envoiPossible(WidgetTester tester) =>
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).enabled;

    testWidgets('lecture ratée : le dit, et bloque l’envoi', (tester) async {
      depot.panne = const ApiException('panne', statusCode: 500);
      await ouvrir(tester);

      noter(tester, 5);
      await tester.pump();

      expect(_lectureImpossible, findsOneWidget);
      expect(
        envoiPossible(tester),
        isFalse,
        reason: 'l’envoi remplacerait un avis que le client ne voit pas',
      );
    });

    testWidgets('lecture en cours : l’envoi attend', (tester) async {
      final barriere = depot.barriere = Completer<void>();
      await ouvrir(tester);

      noter(tester, 5);
      await tester.pump();
      expect(
        envoiPossible(tester),
        isFalse,
        reason: 'sur la 4G, le client peut noter avant la réponse',
      );

      barriere.complete();
      await tester.pump();
      await tester.pump();

      expect(find.text('Très bon poulet'), findsOneWidget);
      expect(envoiPossible(tester), isTrue);
    });

    testWidgets('« Réessayer » remplit le formulaire et rouvre l’envoi', (
      tester,
    ) async {
      depot.panne = const ApiException('panne', statusCode: 500);
      await ouvrir(tester);

      depot.panne = null;
      await tester.tap(find.text('Réessayer'));
      await tester.pump();
      await tester.pump();

      expect(depot.lectures, 2);
      expect(_lectureImpossible, findsNothing);
      expect(find.text('Très bon poulet'), findsOneWidget);
      expect(envoiPossible(tester), isTrue);
    });

    testWidgets('nouvel avis : aucune lecture, envoi libre', (tester) async {
      await ouvrir(tester, avis: null);

      noter(tester, 5);
      await tester.pump();

      expect(depot.lectures, 0);
      expect(envoiPossible(tester), isTrue);
    });
  });
}
