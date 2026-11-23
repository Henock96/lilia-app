// Avis sans commentaire public (23/11/2026, App Review 1.2).
//
// Un texte libre écrit par un client, ou la réponse d'une boutique, publié à
// d'autres clients est du contenu généré par les utilisateurs : Apple exige
// alors signalement et blocage. Tant qu'ils n'existent pas, la liste des avis
// ne montre aux autres que la note ; l'auteur seul relit son commentaire et
// la réponse qu'il a reçue.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/reviews/presentation/widgets/review_card.dart';
import 'package:lilia_app/features/reviews/presentation/widgets/star_rating.dart';
import 'package:lilia_app/models/review.dart';

Review _avis() => Review.fromJson({
  'id': 'r1',
  'rating': 4,
  'comment': 'Un peu tiède',
  'user': {'nom': 'Awa M.'},
  'vendorReply': 'Désolés, ça ne se reproduira pas.',
});

Future<void> _afficher(WidgetTester tester, {required bool isOwner}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewCard(review: _avis(), isOwner: isOwner),
        ),
      ),
    );

void main() {
  testWidgets('un autre client ne voit ni le commentaire ni la réponse', (
    tester,
  ) async {
    await _afficher(tester, isOwner: false);

    expect(find.text('Un peu tiède'), findsNothing);
    expect(find.byKey(const Key('review-vendor-reply')), findsNothing);
    expect(find.text('Désolés, ça ne se reproduira pas.'), findsNothing);
  });

  testWidgets('un autre client voit encore l’auteur et la note', (
    tester,
  ) async {
    await _afficher(tester, isOwner: false);

    expect(find.text('Awa M.'), findsOneWidget);
    expect(find.byType(StarRating), findsOneWidget);
    expect(find.byIcon(Icons.star), findsNWidgets(4));
  });

  testWidgets('l’auteur relit son commentaire et la réponse reçue', (
    tester,
  ) async {
    await _afficher(tester, isOwner: true);

    expect(find.text('Un peu tiède'), findsOneWidget);
    expect(find.byKey(const Key('review-vendor-reply')), findsOneWidget);
    expect(find.text('Désolés, ça ne se reproduira pas.'), findsOneWidget);
  });
}
