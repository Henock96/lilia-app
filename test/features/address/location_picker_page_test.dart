// « Corriger la position » et « Placer sur la carte » — la carte qui ne vient pas.
//
// Le 05/11/2026, une clé Maps refusant le certificat du binaire laissait une
// carte vide et muette sur « Corriger » : le chien de garde n'était armé que sans
// position connue, parce qu'un seul booléen disait à la fois « confirmable » et
// « la carte vit ».
//
// Mesuré le même jour sur « Placer » : carte morte, un glissement déclenche
// `onCameraMoveStarted` sans bouger la caméra, et la page rendait le cadrage par
// défaut. Le backend le classe `EXACT` : un point arbitraire devient l'adresse.
//
// Sous Linux, le greffon rend un `Text` à la place de la vue native : le vrai
// `GoogleMap` est monté et ses callbacks restent appelables.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lilia_app/features/address/presentation/pages/location_picker_page.dart';
import 'package:lilia_app/services/location_service.dart';

final _sansVueNative = TargetPlatformVariant.only(TargetPlatform.linux);

const _positionConnue = LatLng(-4.2634, 15.2429);
const _cadrageParDefaut = LatLng(-4.2634, 15.2429);
const _porteDuClient = LatLng(-4.2795, 15.2571);
const _delai = Duration(seconds: 10);

final _avertissementDiscret = find.textContaining('est conservée');
final _issueSansPosition = find.text('Continuer sans position');

class _GpsQuiRepond extends LocationService {
  @override
  Future<LocationResult> currentPosition() async => LocationResult.success(
    Position(
      latitude: _porteDuClient.latitude,
      longitude: _porteDuClient.longitude,
      timestamp: DateTime.utc(2026, 11, 6),
      accuracy: 8,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    ),
  );
}

Future<void> _ouvrir(WidgetTester tester, {LatLng? position}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [locationServiceProvider.overrideWithValue(_GpsQuiRepond())],
      child: MaterialApp(home: LocationPickerPage(initialPosition: position)),
    ),
  );
}

/// Ouvre la page par-dessus un hôte, pour lire ce qu'elle rend à la confirmation.
Future<List<PickedLocation?>> _ouvrirEnLisantLeResultat(
  WidgetTester tester,
) async {
  final rendus = <PickedLocation?>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [locationServiceProvider.overrideWithValue(_GpsQuiRepond())],
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => rendus.add(
              await Navigator.of(context).push<PickedLocation>(
                MaterialPageRoute(builder: (_) => const LocationPickerPage()),
              ),
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return rendus;
}

GoogleMap _carte(WidgetTester tester) =>
    tester.widget<GoogleMap>(find.byType(GoogleMap));

/// Un doigt glisse sur une carte morte : le geste démarre, la caméra reste.
void _glisserSurCarteMorte(WidgetTester tester) =>
    _carte(tester).onCameraMoveStarted?.call();

/// La caméra rapporte un mouvement, sans avoir quitté sa place.
void _rapportImmobile(WidgetTester tester, LatLng ici) =>
    _carte(tester).onCameraMove!(CameraPosition(target: ici, zoom: 13));

/// La carte se déplace vraiment sous le doigt du client.
void _deplacerLaCarte(WidgetTester tester, {LatLng vers = _porteDuClient}) {
  _carte(tester).onCameraMoveStarted?.call();
  _carte(tester).onCameraMove!(CameraPosition(target: vers, zoom: 13));
}

bool _confirmable(WidgetTester tester) =>
    tester.widget<FilledButton>(find.bySubtype<FilledButton>()).enabled;

void main() {
  group('position déjà connue', () {
    testWidgets(
      'une carte muette déclenche l\'avertissement discret, pas la notice',
      (tester) async {
        await _ouvrir(tester, position: _positionConnue);

        await tester.pump(_delai);

        expect(_avertissementDiscret, findsOneWidget);
        expect(_issueSansPosition, findsNothing);
      },
      variant: _sansVueNative,
    );

    testWidgets(
      'un déplacement avant le délai désarme l\'avertissement',
      (tester) async {
        await _ouvrir(tester, position: _positionConnue);

        await tester.pump(const Duration(seconds: 5));
        _deplacerLaCarte(tester);
        await tester.pump(_delai);

        expect(_avertissementDiscret, findsNothing);
      },
      variant: _sansVueNative,
    );

    testWidgets(
      'un déplacement après le délai retire l\'avertissement',
      (tester) async {
        await _ouvrir(tester, position: _positionConnue);
        await tester.pump(_delai);
        expect(_avertissementDiscret, findsOneWidget);

        _deplacerLaCarte(tester);
        await tester.pump();

        expect(_avertissementDiscret, findsNothing);
      },
      variant: _sansVueNative,
    );

    testWidgets(
      'glisser sur une carte morte ne retire pas l\'avertissement',
      (tester) async {
        await _ouvrir(tester, position: _positionConnue);
        await tester.pump(_delai);

        _glisserSurCarteMorte(tester);
        await tester.pump();

        expect(_avertissementDiscret, findsOneWidget);
      },
      variant: _sansVueNative,
    );

    testWidgets(
      'la position reste confirmable pendant l\'avertissement',
      (tester) async {
        await _ouvrir(tester, position: _positionConnue);

        await tester.pump(_delai);

        expect(_confirmable(tester), isTrue);
      },
      variant: _sansVueNative,
    );
  });

  group('aucune position connue', () {
    testWidgets(
      'une carte muette offre de continuer sans position',
      (tester) async {
        await _ouvrir(tester);

        await tester.pump(_delai);

        expect(_issueSansPosition, findsOneWidget);
        expect(_avertissementDiscret, findsNothing);
        expect(_confirmable(tester), isFalse);
      },
      variant: _sansVueNative,
    );

    testWidgets(
      'la notice pose une question : une carte qui marche peut être au repos',
      (tester) async {
        await _ouvrir(tester);

        await tester.pump(_delai);

        expect(find.textContaining('La carte ne s\'affiche pas ?'), findsOneWidget);
        expect(find.textContaining('La carte ne se charge pas'), findsNothing);
        final rouge = Theme.of(
          tester.element(find.byType(GoogleMap)),
        ).colorScheme.errorContainer;
        expect(
          tester
              .widgetList<Material>(find.byType(Material))
              .where((m) => m.color == rouge),
          isEmpty,
        );
      },
      variant: _sansVueNative,
    );

    testWidgets(
      'un déplacement avant le délai ouvre la confirmation, sans notice',
      (tester) async {
        await _ouvrir(tester);

        await tester.pump(const Duration(seconds: 5));
        _deplacerLaCarte(tester);
        await tester.pump(_delai);

        expect(_issueSansPosition, findsNothing);
        expect(_confirmable(tester), isTrue);
      },
      variant: _sansVueNative,
    );

    testWidgets(
      'glisser sur une carte morte n\'ouvre pas la confirmation',
      (tester) async {
        await _ouvrir(tester);

        _glisserSurCarteMorte(tester);
        await tester.pump(_delai);

        expect(_confirmable(tester), isFalse);
        expect(_issueSansPosition, findsOneWidget);
      },
      variant: _sansVueNative,
    );

    testWidgets(
      'un rapport de caméra immobile n\'ouvre pas la confirmation',
      (tester) async {
        await _ouvrir(tester);

        _rapportImmobile(tester, _cadrageParDefaut);
        await tester.pump();

        expect(_confirmable(tester), isFalse);
      },
      variant: _sansVueNative,
    );

    testWidgets(
      'un déplacement réel rend le point visé, jamais le cadrage par défaut',
      (tester) async {
        final rendus = await _ouvrirEnLisantLeResultat(tester);

        _deplacerLaCarte(tester);
        await tester.pump();
        await tester.tap(find.bySubtype<FilledButton>());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(rendus.single?.latitude, _porteDuClient.latitude);
        expect(rendus.single?.longitude, _porteDuClient.longitude);
      },
      variant: _sansVueNative,
    );

    testWidgets(
      'le GPS sur carte morte rend confirmable sans faire croire que la carte vit',
      (tester) async {
        await _ouvrir(tester);

        await tester.tap(find.byTooltip('Utiliser ma position'));
        await tester.pump();
        await tester.pump(_delai);

        expect(_confirmable(tester), isTrue);
        expect(_avertissementDiscret, findsOneWidget);
        expect(_issueSansPosition, findsNothing);
      },
      variant: _sansVueNative,
    );

    testWidgets(
      'une caméra restée au cadrage n\'écrase pas la position du GPS',
      (tester) async {
        final rendus = await _ouvrirEnLisantLeResultat(tester);

        await tester.tap(find.byTooltip('Utiliser ma position'));
        await tester.pump();
        _rapportImmobile(tester, _cadrageParDefaut);
        await tester.pump();
        await tester.tap(find.bySubtype<FilledButton>());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(rendus.single?.latitude, _porteDuClient.latitude);
        expect(rendus.single?.longitude, _porteDuClient.longitude);
      },
      variant: _sansVueNative,
    );
  });
}
