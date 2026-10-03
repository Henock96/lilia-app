import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/utils/api_response.dart';
import 'package:lilia_app/utils/provider_cache.dart';

part 'brazzaville_weather.g.dart';

/// Heure de Brazzaville : WAT, UTC+1, sans heure d'été.
///
/// On ne se fie pas au fuseau du téléphone : un appareil mal réglé (ou un
/// testeur à Paris) dirait « Bonsoir » en plein après-midi congolais.
DateTime brazzavilleNow([DateTime? utcNow]) =>
    (utcNow ?? DateTime.now()).toUtc().add(const Duration(hours: 1));

/// « Bonjour » de 5 h à 18 h, « Bonsoir » ensuite.
///
/// Brazzaville est à 4° de l'équateur : le soleil se couche vers 18 h toute
/// l'année, un seuil fixe suffit.
String greetingFor(DateTime brazzavilleTime) {
  final h = brazzavilleTime.hour;
  return h >= 5 && h < 18 ? 'Bonjour' : 'Bonsoir';
}

/// Au-delà, une valeur servie par le serveur n'est plus affichée : la météo
/// d'il y a trois heures présentée comme actuelle serait une donnée fausse.
/// Même borne que le serveur (`MAX_AGE_SECONDS`).
const kWeatherMaxAge = Duration(hours: 2);

/// Météo de Brazzaville telle que la sert `GET /weather/brazzaville`.
///
/// Source : OpenWeatherMap, **appelé par le backend Lilia** — la clé ne vit
/// que côté serveur. Licence du plan Free : usage commercial autorisé,
/// attribution obligatoire ([attributionText], [attributionUrl]).
class BrazzavilleWeather {
  const BrazzavilleWeather({
    required this.temperatureC,
    required this.conditionCode,
    required this.description,
    required this.isDay,
    required this.updatedAt,
    required this.attributionText,
    required this.attributionUrl,
  });

  /// Rejette toute réponse incomplète (`FormatException`) : pas de météo
  /// plutôt qu'une météo partielle.
  factory BrazzavilleWeather.fromJson(Map<String, dynamic> json) {
    final temp = json['temperatureC'];
    final code = json['conditionCode'];
    final updated = DateTime.tryParse('${json['updatedAt']}');
    if (temp is! num || code is! num || updated == null) {
      throw const FormatException('météo incomplète');
    }
    final attribution = json['attribution'];
    final a = attribution is Map<String, dynamic>
        ? attribution
        : const <String, dynamic>{};
    return BrazzavilleWeather(
      temperatureC: temp.round(),
      conditionCode: code.toInt(),
      description: json['description'] is String
          ? json['description'] as String
          : '',
      isDay: json['isDay'] == true,
      updatedAt: updated,
      attributionText: a['text'] is String
          ? a['text'] as String
          : 'Weather data provided by OpenWeather',
      attributionUrl: a['url'] is String
          ? a['url'] as String
          : 'https://openweathermap.org/',
    );
  }

  final int temperatureC;

  /// Identifiant de condition OpenWeatherMap (2xx orage … 800 dégagé,
  /// 801-804 nuages).
  final int conditionCode;

  /// Description en français fournie par OpenWeatherMap (« Peu nuageux »).
  final String description;
  final bool isDay;

  /// Heure à laquelle le serveur a lu la valeur chez OpenWeatherMap.
  final DateTime updatedAt;
  final String attributionText;
  final String attributionUrl;

  bool isStale(DateTime now) => now.difference(updatedAt) > kWeatherMaxAge;

  /// « 25° ».
  String get temperatureLabel => '$temperatureC°';

  /// « Météo à Brazzaville : 25 degrés, peu nuageux » — lu par VoiceOver et
  /// TalkBack, qui prononceraient mal le symbole « ° ».
  String get semanticLabel {
    final d = description.isEmpty ? '' : ', ${description.toLowerCase()}';
    return 'Météo à Brazzaville : $temperatureC degrés$d';
  }

  IconData get icon => switch (conditionCode) {
    >= 200 && < 300 => Icons.thunderstorm_rounded,
    >= 300 && < 600 => Icons.water_drop_rounded,
    >= 600 && < 700 => Icons.ac_unit_rounded,
    >= 700 && < 800 => Icons.foggy,
    800 => isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round,
    801 || 802 => isDay ? Icons.wb_cloudy_rounded : Icons.nights_stay_rounded,
    _ => Icons.cloud_rounded,
  };
}

/// Météo de Brazzaville pour l'en-tête de l'accueil.
///
/// Lue sur le backend Lilia (public, mis en cache côté serveur 30 min). Côté
/// app, gardée 30 min elle aussi : la recharger à chaque retour sur l'accueil
/// ne changerait rien. Échec (hors ligne, 503 sans clé, 404 sur un ancien
/// serveur) : l'en-tête masque simplement la météo.
///
/// Pas de relance automatique ([_pasDeRelance]) : Riverpod 3 rejoue sinon un
/// provider en échec avec un délai croissant — des requêtes inutiles, hors
/// ligne ou serveur sans clé, pour une donnée secondaire. La prochaine
/// lecture a lieu au prochain montage de l'accueil après expiration.
@Riverpod(retry: _pasDeRelance)
Future<BrazzavilleWeather> brazzavilleWeather(Ref ref) async {
  final res = await ref
      .watch(apiClientProvider)
      .getJson('/weather/brazzaville');
  final weather = BrazzavilleWeather.fromJson(ApiResponse.mapOf(res.data));
  // Seul un succès est gardé : un échec mis en cache masquerait la météo
  // pendant 30 min après le retour du réseau.
  if (ref.mounted) cachePendant(ref, const Duration(minutes: 30));
  return weather;
}

Duration? _pasDeRelance(int retryCount, Object error) => null;
