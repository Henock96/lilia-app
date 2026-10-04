// En-tête de l'accueil : salutation selon l'heure de Brazzaville et météo
// réelle servie par le backend Lilia (`GET /weather/brazzaville`, source
// OpenWeatherMap). Ces tests fixent aussi ce que l'en-tête refuse d'afficher.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/home/data/brazzaville_weather.dart';
import 'package:lilia_app/features/home/presentation/widgets/home_greeting.dart';

/// 2026-10-02 21:05 UTC = 22:05 à Brazzaville.
final _soir = DateTime.utc(2026, 10, 2, 21, 5);

Map<String, dynamic> _json({
  num temp = 24.6,
  int code = 801,
  bool isDay = false,
  DateTime? updatedAt,
}) => {
  'city': 'Brazzaville',
  'temperatureC': temp,
  'conditionCode': code,
  'description': 'Peu nuageux',
  'isDay': isDay,
  'observedAt': '2026-10-02T21:00:00.000Z',
  'updatedAt': (updatedAt ?? _soir).toIso8601String(),
  'attribution': {
    'text': 'Weather data provided by OpenWeather',
    'url': 'https://openweathermap.org/',
  },
};

void main() {
  group('greetingFor', () {
    test('Bonjour de 5 h à 17 h 59, Bonsoir ensuite', () {
      DateTime at(int h, [int m = 0]) => DateTime(2026, 10, 1, h, m);
      expect(greetingFor(at(4, 59)), 'Bonsoir');
      expect(greetingFor(at(5)), 'Bonjour');
      expect(greetingFor(at(12)), 'Bonjour');
      expect(greetingFor(at(17, 59)), 'Bonjour');
      expect(greetingFor(at(18)), 'Bonsoir');
      expect(greetingFor(at(23)), 'Bonsoir');
    });

    test(
      'heure de Brazzaville = UTC+1, quel que soit le fuseau du téléphone',
      () {
        final utc = DateTime.utc(2026, 10, 1, 17, 30);
        expect(brazzavilleNow(utc).hour, 18);
        expect(greetingFor(brazzavilleNow(utc)), 'Bonsoir');
      },
    );
  });

  group('BrazzavilleWeather.fromJson (contrat backend)', () {
    test('lecture et arrondi', () {
      final w = BrazzavilleWeather.fromJson(_json());
      expect(w.temperatureLabel, '25°');
      expect(w.conditionCode, 801);
      expect(w.attributionText, 'Weather data provided by OpenWeather');
      expect(w.attributionUrl, 'https://openweathermap.org/');
    });

    test('description accessible prononçable', () {
      final w = BrazzavilleWeather.fromJson(_json());
      expect(w.semanticLabel, 'Météo à Brazzaville : 25 degrés, peu nuageux');
    });

    test('réponse incomplète : rejetée, jamais une météo partielle', () {
      expect(
        () => BrazzavilleWeather.fromJson({'conditionCode': 800}),
        throwsFormatException,
      );
      expect(
        () => BrazzavilleWeather.fromJson({
          'temperatureC': 20,
          'conditionCode': 800,
        }),
        throwsFormatException,
        reason: 'sans updatedAt, impossible de savoir si elle est actuelle',
      );
    });

    test('icônes : codes OpenWeatherMap, jour et nuit', () {
      IconData icone(int code, {bool day = true}) =>
          BrazzavilleWeather.fromJson(_json(code: code, isDay: day)).icon;
      expect(icone(800), Icons.wb_sunny_rounded);
      expect(icone(800, day: false), Icons.nightlight_round);
      expect(icone(211), Icons.thunderstorm_rounded);
      expect(icone(501), Icons.water_drop_rounded);
      expect(icone(741), Icons.foggy);
      expect(icone(804), Icons.cloud_rounded);
    });

    test('au-delà de 2 h, la valeur est périmée', () {
      final w = BrazzavilleWeather.fromJson(_json());
      expect(w.isStale(_soir.add(const Duration(minutes: 119))), isFalse);
      expect(w.isStale(_soir.add(const Duration(minutes: 121))), isTrue);
    });
  });

  group('HomeGreeting', () {
    Future<void> monter(
      WidgetTester tester, {
      required Future<BrazzavilleWeather> Function() meteo,
      AppUser? user,
      double largeur = 390,
      double texte = 1,
      List<Uri>? ouverts,
    }) async {
      tester.view.physicalSize = Size(largeur * 3, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateChangeProvider.overrideWith((ref) => Stream.value(user)),
            brazzavilleWeatherProvider.overrideWith((ref) => meteo()),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(largeur, 800),
                textScaler: TextScaler.linear(texte),
              ),
              child: Scaffold(
                appBar: AppBar(
                  title: HomeGreeting(
                    clock: () => _soir,
                    launcher: (uri) async {
                      ouverts?.add(uri);
                      return true;
                    },
                  ),
                  actions: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.notifications),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('« Bonsoir, Awa » et la météo sur la même ligne', (
      tester,
    ) async {
      final semantique = tester.ensureSemantics();
      await monter(
        tester,
        user: const AppUser(uid: 'u', nom: 'Awa Ngoma'),
        meteo: () async => BrazzavilleWeather.fromJson(_json()),
      );
      final salut = find.text('Bonsoir, Awa');
      final meteo = find.text('25° Brazzaville');
      expect(salut, findsOneWidget);
      expect(meteo, findsOneWidget);
      expect(
        (tester.getCenter(salut).dy - tester.getCenter(meteo).dy).abs(),
        lessThan(4),
      );
      expect(
        find.bySemanticsLabel('Météo à Brazzaville : 25 degrés, peu nuageux'),
        findsOneWidget,
      );
      semantique.dispose();
    });

    testWidgets('météo indisponible : salutation seule, aucune valeur', (
      tester,
    ) async {
      await monter(tester, meteo: () async => throw Exception('503'));
      expect(find.text('Bonsoir'), findsOneWidget);
      expect(find.textContaining('°'), findsNothing);
    });

    testWidgets('valeur de plus de 2 h : masquée', (tester) async {
      await monter(
        tester,
        meteo: () async => BrazzavilleWeather.fromJson(
          _json(updatedAt: _soir.subtract(const Duration(hours: 3))),
        ),
      );
      expect(find.textContaining('°'), findsNothing);
    });

    testWidgets('petit écran, texte 2× et prénom long : pas de débordement', (
      tester,
    ) async {
      await monter(
        tester,
        largeur: 320,
        texte: 2,
        user: const AppUser(uid: 'u', nom: 'Maximilienne-Bénédicte Okemba'),
        meteo: () async => BrazzavilleWeather.fromJson(_json()),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('25°'), findsOneWidget, reason: 'mode compact');
      expect(find.text('25° Brazzaville'), findsNothing);
    });

    testWidgets('attribution OpenWeather visible et cliquable', (tester) async {
      final ouverts = <Uri>[];
      await monter(
        tester,
        ouverts: ouverts,
        meteo: () async => BrazzavilleWeather.fromJson(_json()),
      );
      await tester.tap(find.text('25° Brazzaville'));
      await tester.pumpAndSettle();
      expect(find.text('Weather data provided by OpenWeather'), findsOneWidget);
      expect(find.text('Relevé à 22 h 05'), findsOneWidget);
      await tester.tap(find.byKey(const Key('weather_attribution')));
      await tester.pump();
      expect(ouverts, [Uri.parse('https://openweathermap.org/')]);
    });
  });
}
