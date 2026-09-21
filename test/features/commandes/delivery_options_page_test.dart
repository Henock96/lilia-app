// Couverture de l'écran « Mode de livraison » après la remédiation
// AUDIT_2026-08-01 : les `RadioListTile` portaient `groupValue`/`onChanged`,
// dépréciés depuis Flutter 3.32 ; l'état du groupe est désormais porté par un
// `RadioGroup<bool>` ancêtre.
//
// Ces tests montent la page avec des providers surchargés — aucun appel réseau,
// aucune donnée de prod touchée.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/commandes/presentation/delivery_options_page.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_controller.dart';
import 'package:lilia_app/features/quartiers/application/quartiers_controller.dart';
import 'package:lilia_app/features/settings/data/platform_settings_service.dart';
import 'package:lilia_app/features/user/application/adresse_controller.dart';
import 'package:lilia_app/models/adresse.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/models/quartier.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/models/vendor_type.dart';

const _restaurantId = 'resto-1';

void main() {
  group('DeliveryOptionsPage — RadioGroup', () {
    testWidgets('expose un RadioGroup<bool> et deux options', (tester) async {
      await _pumpPage(tester);

      expect(find.byType(RadioGroup<bool>), findsOneWidget);
      expect(find.byType(RadioListTile<bool>), findsNWidgets(2));
      expect(find.text('Livraison a domicile'), findsOneWidget);
      expect(find.textContaining('Retrait'), findsWidgets);
    });

    testWidgets('la livraison est sélectionnée par défaut', (tester) async {
      await _pumpPage(tester);

      expect(_groupValue(tester), isTrue);
    });

    testWidgets('taper sur Retrait bascule le groupe', (tester) async {
      await _pumpPage(tester);

      await tester.tap(find.textContaining('Retrait').first);
      await tester.pump();

      expect(_groupValue(tester), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('retour sur Livraison après un Retrait', (tester) async {
      await _pumpPage(tester);

      await tester.tap(find.textContaining('Retrait').first);
      await tester.pump();
      await tester.tap(find.text('Livraison a domicile'));
      await tester.pump();

      expect(_groupValue(tester), isTrue);
    });

    testWidgets('HOME_COOK masque l\'option retrait', (tester) async {
      // Un vendeur maison n'a pas de point de vente physique : le retrait est
      // masqué et le mode livraison forcé.
      await _pumpPage(tester, vendorType: VendorType.HOME_COOK);

      expect(find.byType(RadioGroup<bool>), findsOneWidget);
      expect(find.byType(RadioListTile<bool>), findsOneWidget);
      expect(find.textContaining('Retrait'), findsNothing);
      expect(_groupValue(tester), isTrue);
    });

    testWidgets('panier vide → message, pas de RadioGroup', (tester) async {
      await _pumpPage(tester, emptyCart: true);

      expect(find.text('Votre panier est vide'), findsOneWidget);
      expect(find.byType(RadioGroup<bool>), findsNothing);
    });
  });

  // ── Adresse héritée sans quartier ──────────────────────────────────────
  //
  // Vingt adresses de production (juillet 2025 → mars 2026) n'ont aucun
  // quartier : elles précèdent la règle qui le rend obligatoire. Sans lui,
  // `DeliveryDestinationService` n'a pas de repli — ni position posée, ni
  // centroïde — et la commande part **sans destination** pour le livreur.
  //
  // L'écran se contentait de l'annoncer (« Quartier non défini »). Une annonce
  // juste, mais qui laisse le client devant un problème qu'il ne peut pas
  // résoudre depuis le tunnel de commande. Le quartier est pourtant déjà choisi
  // juste au-dessus : un tap le rattache, et répare l'adresse pour toutes les
  // commandes suivantes.
  group('DeliveryOptionsPage — compléter une adresse sans quartier', () {
    testWidgets('propose de rattacher le quartier sélectionné', (tester) async {
      await _pumpPage(tester, adresses: _adressesSansQuartier);

      expect(find.text('Quartier non défini'), findsOneWidget);
      await _choisirQuartier(tester, 'Poto-Poto');
      // Le libellé nomme ce qui sera écrit. « Compléter » obligerait à
      // l'essayer pour découvrir son effet, sur une action qui modifie une
      // donnée enregistrée.
      expect(find.text('Utiliser Poto-Poto'), findsOneWidget);
    });

    testWidgets('sans quartier choisi, renvoie vers le sélecteur au lieu d’un bouton inerte',
        (tester) async {
      await _pumpPage(
        tester,
        adresses: _adressesSansQuartier,
        quartiers: const [],
      );

      expect(find.textContaining('Choisissez votre quartier ci-dessus'),
          findsOneWidget);
      expect(find.textContaining('Utiliser '), findsNothing);
    });

    testWidgets('le tap écrit au SERVEUR, pas seulement dans l’état local',
        (tester) async {
      // C'est toute la différence entre « compléter l'adresse » et « choisir un
      // quartier pour aujourd'hui » : la seconde laisserait les commandes
      // suivantes repartir sans destination.
      final faux = _FakeAdresses(_adressesSansQuartier);
      await _pumpPage(tester, adresses: _adressesSansQuartier, controller: faux);
      await _choisirQuartier(tester, 'Poto-Poto');

      await tester.tap(find.text('Utiliser Poto-Poto'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(faux.misAJour, [('adr-sans-quartier', 'q-1')]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('une adresse complète ne propose rien', (tester) async {
      await _pumpPage(tester);

      expect(find.text('Quartier non défini'), findsNothing);
      expect(find.textContaining('Utiliser '), findsNothing);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Le quartier a deux porteurs : la liste déroulante et l'adresse. Le client
  // calcule ses frais depuis la première ; le serveur, depuis la seconde
  // (`order-checkout.service.ts` → `destination?.quartierId`).
  //
  // Tant que les deux coïncident, l'écart n'existe pas — et la page les
  // synchronise à chaque tap sur une adresse QUI A un quartier. Une adresse
  // qui n'en a pas ne peut pas les synchroniser : elle laisse le client voir
  // le tarif de la zone choisie pendant que le serveur facturera
  // `restaurant.fixedDeliveryFee`, et elle fait partir la commande en
  // `DESTINATION_UNKNOWN` — sans point de chute pour le livreur.
  //
  // La réparation est à un tap, juste au-dessus. C'est pour cela qu'on peut se
  // permettre de bloquer plutôt que d'avertir.
  group('DeliveryOptionsPage — le quartier de l’adresse fait foi', () {
    testWidgets('adresse sans quartier → « Continuer » reste inactif',
        (tester) async {
      await _pumpPage(tester, adresses: _adressesSansQuartier);
      await _choisirQuartier(tester, 'Poto-Poto');
      await _taperAdresse(tester, '7 avenue de la Tsiémé');

      expect(
        _boutonContinuer(tester).onPressed,
        isNull,
        reason: 'choisir un quartier dans la liste ne renseigne pas l’adresse, '
            'et c’est l’adresse que le serveur lira',
      );
    });

    testWidgets('après complétion de l’adresse, « Continuer » s’active',
        (tester) async {
      final faux = _FakeAdresses(_adressesSansQuartier);
      await _pumpPage(tester, adresses: _adressesSansQuartier, controller: faux);
      await _choisirQuartier(tester, 'Poto-Poto');
      await _taperAdresse(tester, '7 avenue de la Tsiémé');
      expect(_boutonContinuer(tester).onPressed, isNull);

      await tester.tap(find.text('Utiliser Poto-Poto'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }

      expect(faux.misAJour, [('adr-sans-quartier', 'q-1')]);
      expect(
        _boutonContinuer(tester).onPressed,
        isNotNull,
        reason: 'l’adresse porte désormais le quartier : les deux sources '
            'coïncident, le total affiché sera celui qui sera facturé',
      );
    });

    testWidgets('adresse avec quartier → « Continuer » actif', (tester) async {
      await _pumpPage(tester);
      await _taperAdresse(tester, '12 rue de la Paix');

      expect(_boutonContinuer(tester).onPressed, isNotNull);
    });

    testWidgets('en retrait, le quartier de l’adresse n’est pas exigé',
        (tester) async {
      // Aucune livraison, donc aucune destination à résoudre : l'exigence ne
      // doit pas déborder sur un parcours qui ne la concerne pas.
      await _pumpPage(tester, adresses: _adressesSansQuartier);
      await tester.tap(find.textContaining('Retrait').first);
      await tester.pump();

      expect(_boutonContinuer(tester).onPressed, isNotNull);
    });
  });
}

/// Le bouton de sortie de l'écran. Il n'y en a qu'un.
ElevatedButton _boutonContinuer(WidgetTester tester) => tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Continuer'),
        matching: find.byType(ElevatedButton),
      ),
    );

/// Sélectionne une adresse comme le ferait un client : en tapant sa carte.
Future<void> _taperAdresse(WidgetTester tester, String rue) async {
  await tester.tap(find.text(rue));
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// Ouvre le sélecteur de quartier et en choisit un, comme le ferait un client.
///
/// Le bouton de complétion ne s'affiche qu'une fois un quartier choisi : sans
/// lui, il n'aurait rien à rattacher. Poser `_selectedQuartier` à la main dans
/// le test aurait court-circuité précisément la condition qu'on veut vérifier.
Future<void> _choisirQuartier(WidgetTester tester, String nom) async {
  await tester.tap(find.byType(DropdownButtonFormField<Quartier>));
  await tester.pump(const Duration(milliseconds: 400));
  // Le nom apparaît deux fois quand le menu est ouvert (champ + option) :
  // `.last` vise l'option du menu.
  await tester.tap(find.text(nom).last);
  await tester.pump(const Duration(milliseconds: 400));
}

/// Valeur portée par le `RadioGroup<bool>` — c'est elle qui pilote la sélection
/// depuis que `groupValue` a quitté les tuiles.
bool? _groupValue(WidgetTester tester) =>
    tester.widget<RadioGroup<bool>>(find.byType(RadioGroup<bool>)).groupValue;

Future<void> _pumpPage(
  WidgetTester tester, {
  VendorType vendorType = VendorType.RESTAURANT,
  bool emptyCart = false,
  List<Adresse>? adresses,
  List<Quartier>? quartiers,
  _FakeAdresses? controller,
}) async {
  final faux = controller ?? _FakeAdresses(adresses ?? _adresses);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cartControllerProvider.overrideWith(
          () => _FakeCart(emptyCart ? null : _cart()),
        ),
        quartiersListProvider.overrideWith(
          (ref) async => quartiers ?? _quartiers,
        ),
        adresseControllerProvider.overrideWith(() => faux),
        // Sans barème, `_canContinue()` refuse d'avancer — c'est le correctif
        // P1-001, et il s'applique aussi ici. Le fournir est donc une
        // condition pour éprouver quoi que ce soit d'autre sur ce bouton.
        platformSettingsProvider.overrideWith(
          (ref) async => const PlatformSettings(
            serviceFeePercent: 15,
            loyaltyPointsPerOrder: 1,
            loyaltyPointValueXaf: 100,
            loyaltyMinRedemption: 1,
            referrerBonusPoints: 1,
          ),
        ),
        restaurantControllerProvider(
          _restaurantId,
        ).overrideWith((ref) async => _restaurant(vendorType)),
      ],
      child: MaterialApp(home: const DeliveryOptionsPage()),
    ),
  );
  // Les providers async se résolvent en microtask, et `flutter_animate` pose
  // des timers d'entrée qu'il faut laisser expirer — sinon le test échoue sur
  // « pending timers ». On ne peut pas utiliser `pumpAndSettle` : certaines
  // animations de l'app tournent en boucle.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

class _FakeCart extends CartController {
  _FakeCart(this._cart);
  final Cart? _cart;

  @override
  Future<Cart?> build() async => _cart;
}

/// Double du contrôleur d'adresses.
///
/// `misAJour` enregistre les appels : c'est ce qui permet de vérifier que la
/// complétion part **au serveur** et ne se contente pas de changer l'affichage.
class _FakeAdresses extends AdresseController {
  _FakeAdresses(this._liste);
  final List<Adresse> _liste;
  final List<(String, String)> misAJour = [];

  @override
  Future<List<Adresse>> build() async => _liste;

  @override
  Future<Adresse> updateAdresse(
    String adresseId, {
    String? rue,
    String? quartierId,
    String? label,
  }) async {
    misAJour.add((adresseId, quartierId ?? ''));
    final source = _liste.firstWhere((a) => a.id == adresseId);
    return Adresse(
      id: source.id,
      rue: source.rue,
      ville: source.ville,
      country: source.country,
      userId: source.userId,
      quartierId: quartierId,
      quartier: _quartiers.where((q) => q.id == quartierId).firstOrNull,
    );
  }
}

Cart _cart() => Cart(
  id: 'cart-1',
  userId: 'user-1',
  createdAt: DateTime(2026, 8, 1),
  updatedAt: DateTime(2026, 8, 1),
  items: [
    CartItem(
      id: 'item-1',
      cartId: 'cart-1',
      productId: 'prod-1',
      variantId: 'var-1',
      quantite: 2,
      createdAt: DateTime(2026, 8, 1),
      product: ProductItem(nom: 'Poulet braisé', restaurantId: _restaurantId),
      variant: VariantItem(label: 'Normal', prix: 3000),
    ),
  ],
);

Restaurant _restaurant(VendorType type) => Restaurant(
  id: _restaurantId,
  name: 'Chez Maman Lili',
  address: 'Poto-Poto, Brazzaville',
  products: const [],
  categoriesMap: const {},
  vendorType: type,
);

final _quartiers = [
  Quartier(id: 'q-1', nom: 'Poto-Poto', ville: 'Brazzaville'),
  Quartier(id: 'q-2', nom: 'Bacongo', ville: 'Brazzaville'),
];

final _adresses = [
  Adresse(
    id: 'adr-1',
    rue: '12 rue de la Paix',
    ville: 'Brazzaville',
    country: 'CG',
    userId: 'user-1',
    quartierId: 'q-1',
    quartier: _quartiers.first,
  ),
];

/// Une adresse telle qu'elles existaient avant avril 2026 : ni quartier, ni
/// position. Elle est livrable — mais sans destination pour le livreur.
final _adressesSansQuartier = [
  Adresse(
    id: 'adr-sans-quartier',
    rue: '7 avenue de la Tsiémé',
    ville: 'Brazzaville',
    country: 'CG',
    userId: 'user-1',
  ),
];
