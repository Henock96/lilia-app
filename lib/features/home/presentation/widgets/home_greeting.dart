import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:lilia_app/core/support/support_contact.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/features/home/data/brazzaville_weather.dart';

/// « Bonjour, Awa » / « Bonsoir, Awa » selon l'heure de Brazzaville, et sur
/// la même ligne la météo réelle de la ville (OpenWeatherMap, via le backend
/// Lilia). Le prénom vient de la session déjà résolue (aucun appel backend).
///
/// Une seule ligne : le prénom s'efface (…) avant la météo quand la place
/// manque ; sur un écran étroit ou en très grand texte, « Brazzaville » tombe
/// et il reste l'icône et la température. Météo en chargement, hors ligne, en
/// panne ou trop ancienne ([kWeatherMaxAge]) : rien n'est affiché, jamais une
/// valeur de remplacement.
class HomeGreeting extends ConsumerStatefulWidget {
  const HomeGreeting({super.key, this.clock, this.launcher});

  /// Horloge injectable pour les tests ; `DateTime.now` sinon.
  final DateTime Function()? clock;

  /// Ouverture du lien d'attribution, injectable pour les tests.
  final ExternalLauncher? launcher;

  @override
  ConsumerState<HomeGreeting> createState() => _HomeGreetingState();
}

class _HomeGreetingState extends ConsumerState<HomeGreeting> {
  // L'accueil peut rester ouvert à 17 h 59 : on relit l'heure chaque minute
  // pour basculer en « Bonsoir » sans attendre une navigation.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = (widget.clock ?? DateTime.now)();
    final user = ref.watch(authStateChangeProvider).value;
    final full = (user?.nom ?? user?.displayName ?? '').trim();
    final first = full.isEmpty ? null : full.split(RegExp(r'\s+')).first;
    final hello = greetingFor(brazzavilleNow(now));
    final fetched = ref.watch(brazzavilleWeatherProvider).value;
    final weather = fetched == null || fetched.isStale(now) ? null : fetched;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.5;
        return Row(
          children: [
            Flexible(
              child: Text(
                first == null ? hello : '$hello, $first',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (weather != null) ...[
              const SizedBox(width: 6),
              _WeatherChip(
                weather: weather,
                compact: compact,
                launcher: widget.launcher,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _WeatherChip extends StatelessWidget {
  const _WeatherChip({
    required this.weather,
    required this.compact,
    this.launcher,
  });

  final BrazzavilleWeather weather;
  final bool compact;
  final ExternalLauncher? launcher;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // `container` : le titre d'AppBar fusionne la sémantique de ses enfants ;
    // sans nœud propre, VoiceOver lirait salutation et météo d'un bloc, et le
    // bouton ne serait pas atteignable seul.
    return Semantics(
      container: true,
      button: true,
      label: weather.semanticLabel,
      hint: 'Afficher la source',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showDetails(context),
        child: ConstrainedBox(
          // Cible tactile de 48 px de haut (guideline Android / iOS).
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(weather.icon, size: 16, color: cs.primary),
                const SizedBox(width: 3),
                Text(
                  compact
                      ? weather.temperatureLabel
                      : '${weather.temperatureLabel} Brazzaville',
                  maxLines: 1,
                  // Inter, pas la police d'affichage du titre : héritée de
                  // l'AppBar, elle mettait « 25° BRAZZAVILLE » en petites
                  // capitales décoratives.
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Détail et **attribution obligatoire** (plan Free OpenWeather, ODbL :
  /// « Weather data provided by OpenWeather » avec lien).
  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final t = Theme.of(ctx).textTheme;
        final cs = Theme.of(ctx).colorScheme;
        final heure = brazzavilleNow(weather.updatedAt);
        final hh = heure.hour.toString().padLeft(2, '0');
        final mm = heure.minute.toString().padLeft(2, '0');
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(weather.icon, size: 28, color: cs.primary),
                    const SizedBox(width: 12),
                    Text(weather.temperatureLabel, style: t.headlineSmall),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  weather.description.isEmpty
                      ? 'Brazzaville'
                      : '${weather.description} à Brazzaville',
                  style: t.bodyLarge,
                ),
                Text(
                  'Relevé à $hh h $mm',
                  style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  key: const Key('weather_attribution'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () {
                    final uri = Uri.parse(weather.attributionUrl);
                    final l = launcher;
                    l == null
                        ? openSupportChannel(
                            ctx,
                            uri,
                            fallbackValue: weather.attributionUrl,
                          )
                        : openSupportChannel(
                            ctx,
                            uri,
                            fallbackValue: weather.attributionUrl,
                            launcher: l,
                          );
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(weather.attributionText),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
