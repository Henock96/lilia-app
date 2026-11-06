// L'écran de suivi : dire ce qu'on sait, et rien d'autre.
//
// Audit du 05/11/2026 : un 500 s'affichait « En attente d'attribution d'un
// livreur… » sous l'en-tête « Livreur en route », et une carte morte restait
// un rectangle vide sans un mot, alors que ce plein écran n'a rien d'autre à
// montrer.
//
// Sous Linux, le greffon rend un `Text` à la place de la vue native : le vrai
// `GoogleMap` est monté et ses callbacks restent appelables.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/commandes/data/delivery_tracking_repository.dart';
import 'package:lilia_app/features/commandes/presentation/widgets/driver_tracking_map.dart';
import 'package:lilia_app/models/location_precision.dart';

const _orderId = 'cmd-1';
const _delai = Duration(seconds: 10);

final _sansVueNative = TargetPlatformVariant.only(TargetPlatform.linux);

const _enCourse = DriverLocation(
  deliveryId: 'liv-1',
  deliveryStatus: 'EN_TRANSIT',
  latitude: -4.26,
  longitude: 15.28,
  destinationLatitude: -4.27,
  destinationLongitude: 15.29,
  destinationPrecision: LocationPrecision.exact,
);

/// Sans destination, `_fitBounds` n'a rien à cadrer : une carte saine reste
/// immobile, et son silence ne dit rien.
const _sansDestination = DriverLocation(
  deliveryId: 'liv-1',
  deliveryStatus: 'EN_TRANSIT',
  latitude: -4.26,
  longitude: 15.28,
);

final _attenteLivreur = find.textContaining('En attente d\'attribution');
final _lectureImpossible = find.text('Impossible de récupérer la position');
final _questionCarte = find.textContaining('La carte ne s\'affiche pas ?');

class _SuiviFige extends DriverLocationController {
  _SuiviFige(this._lecture);

  final FutureOr<DriverLocation?> Function() _lecture;

  @override
  FutureOr<DriverLocation?> build(String orderId) => _lecture();
}

Future<void> _ouvrir(
  WidgetTester tester,
  FutureOr<DriverLocation?> Function() lecture,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        driverLocationControllerProvider(
          _orderId,
        ).overrideWith(() => _SuiviFige(lecture)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: DriverTrackingMap(orderId: _orderId, fullscreen: true),
        ),
      ),
    ),
  );
  await tester.pump();
}

GoogleMap _carte(WidgetTester tester) =>
    tester.widget<GoogleMap>(find.byType(GoogleMap));

void main() {
  testWidgets('une panne se dit, et propose de réessayer', (tester) async {
    await _ouvrir(
      tester,
      () => throw const ApiException('panne', statusCode: 500),
    );

    expect(_lectureImpossible, findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(_attenteLivreur, findsNothing);
  });

  testWidgets('aucune livraison : on attend un livreur', (tester) async {
    await _ouvrir(tester, () => null);

    expect(_attenteLivreur, findsOneWidget);
    expect(_lectureImpossible, findsNothing);
  });

  group('carte qui ne vient pas', () {
    testWidgets(
      'une caméra immobile pose la question après le délai',
      (tester) async {
        await _ouvrir(tester, () => _enCourse);
        expect(_questionCarte, findsNothing);

        await tester.pump(_delai);

        expect(_questionCarte, findsOneWidget);
      },
      variant: _sansVueNative,
    );

    testWidgets(
      'sans recadrage prévu, le silence ne prouve rien : aucune question',
      (tester) async {
        await _ouvrir(tester, () => _sansDestination);

        await tester.pump(_delai);

        expect(_questionCarte, findsNothing);
      },
      variant: _sansVueNative,
    );

    testWidgets(
      'un recadrage réel prouve que la carte vit',
      (tester) async {
        await _ouvrir(tester, () => _enCourse);

        _carte(tester).onCameraMove!(
          const CameraPosition(target: LatLng(-4.30, 15.25), zoom: 13),
        );
        await tester.pump(_delai);

        expect(_questionCarte, findsNothing);
      },
      variant: _sansVueNative,
    );

    testWidgets(
      'un rapport de caméra sur place ne prouve rien',
      (tester) async {
        await _ouvrir(tester, () => _enCourse);

        _carte(tester).onCameraMove!(
          const CameraPosition(target: LatLng(-4.26, 15.28), zoom: 15),
        );
        await tester.pump(_delai);

        expect(_questionCarte, findsOneWidget, reason: 'caméra restée sur place');
      },
      variant: _sansVueNative,
    );

    testWidgets(
      'un recadrage après le délai retire la question',
      (tester) async {
        await _ouvrir(tester, () => _enCourse);
        await tester.pump(_delai);

        _carte(tester).onCameraMove!(
          const CameraPosition(target: LatLng(-4.30, 15.25), zoom: 13),
        );
        await tester.pump();

        expect(_questionCarte, findsNothing);
      },
      variant: _sansVueNative,
    );
  });
}
