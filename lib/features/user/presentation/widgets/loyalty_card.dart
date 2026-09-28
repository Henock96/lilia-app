import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lilia_app/features/settings/data/platform_settings_service.dart';
import 'package:lilia_app/features/user/application/profile_controller.dart';
import 'package:lilia_app/models/loyalty_transaction.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';
import 'package:lilia_app/utils/currency.dart';

/// Carte fidélité du profil — branchée sur les providers.
///
/// Le barème vient du serveur (`platformSettingsProvider`) : aucune
/// conversion points → FCFA n'est écrite en dur. Sans barème, on affiche le
/// solde (juste, il vient du profil) et on tait la conversion — le repli
/// local valait 1 pt = 50 XAF quand la production en applique 100.
class LoyaltyCard extends ConsumerWidget {
  const LoyaltyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
    final settings = ref.watch(platformSettingsProvider).value;
    return userAsync.maybeWhen(
      data: (user) => LoyaltyCardView(
        points: user.loyaltyPoints,
        settings: settings,
        history: const _HistoriqueBranche(),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// La carte elle-même, sans provider — testable.
///
/// L'ordre répond aux quatre questions du client, dans l'ordre où il se les
/// pose : combien j'ai → ça vaut quoi → comment en gagner → comment m'en
/// servir. Tout est visible près du solde, sans page d'aide.
class LoyaltyCardView extends StatefulWidget {
  const LoyaltyCardView({
    super.key,
    required this.points,
    required this.settings,
    required this.history,
  });

  final int points;

  /// `null` : barème indisponible — on ne convertit rien.
  final PlatformSettings? settings;

  /// Contenu de l'historique, déplié à la demande (chargé seulement alors).
  final Widget history;

  @override
  State<LoyaltyCardView> createState() => _LoyaltyCardViewState();
}

class _LoyaltyCardViewState extends State<LoyaltyCardView> {
  bool _showHistory = false;

  // Dégradé de marque **profond** : le blanc y tient ≥ 4.9:1. L'ancien
  // (#FF8C00 → #FFB347) ne donnait que 2.3 à 1.8:1, et portait des textes de
  // 11 px en blanc à 60 %.
  static const _gradient = LinearGradient(
    colors: [LiliaColors.orange600, LiliaColors.orange700],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const _blanc = Colors.white;

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final points = widget.points;
    final seuil = s?.loyaltyMinRedemption;
    final utilisable = seuil != null && points >= seuil;

    return Container(
      decoration: BoxDecoration(
        gradient: _gradient,
        borderRadius: LiliaRadius.lgAll,
        boxShadow: [
          BoxShadow(
            color: LiliaColors.orange600.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(LiliaSpacing.sp5),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: _blanc),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.stars, color: _blanc, size: 22),
                const SizedBox(width: LiliaSpacing.sm),
                const Expanded(
                  child: Text(
                    'Points de fidélité',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _showHistory = !_showHistory),
                  style: TextButton.styleFrom(foregroundColor: _blanc),
                  child: Text(_showHistory ? 'Masquer' : 'Historique'),
                ),
              ],
            ),
            const SizedBox(height: LiliaSpacing.sm),
            // 1. Solde
            Semantics(
              label: '$points point${points > 1 ? 's' : ''} de fidélité',
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$points',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: LiliaSpacing.sm),
                  Text(
                    points > 1 ? 'points' : 'point',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            // 2. Valeur, et où en est le client par rapport au seuil
            if (s == null)
              const Text(
                'Valeur indisponible pour le moment',
                style: TextStyle(fontSize: 13),
              )
            else ...[
              Text(
                'Soit ${formatPrice(s.pointsToXaf(points).toDouble())} de '
                'réduction',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: LiliaSpacing.xs),
              Text(
                utilisable
                    ? 'Utilisables dès votre prochaine commande.'
                    : 'Encore ${s.loyaltyMinRedemption - points} pt avant '
                          'de pouvoir les utiliser (minimum '
                          '${s.loyaltyMinRedemption} pt).',
                style: const TextStyle(fontSize: 13),
              ),
            ],
            const SizedBox(height: LiliaSpacing.sp3),
            const Divider(color: Colors.white38, height: 1),
            const SizedBox(height: LiliaSpacing.sp3),
            // 3. Comment gagner
            _Regle(
              icon: Icons.add_circle_outline,
              titre: 'Gagner',
              texte: s == null
                  ? 'Chaque commande livrée vous rapporte des points.'
                  : '+${s.loyaltyPointsPerOrder} pt par commande livrée '
                        '(${formatPrice(s.pointsToXaf(s.loyaltyPointsPerOrder).toDouble())}). '
                        'Une commande payée en partie avec des points n’en '
                        'rapporte pas.',
            ),
            const SizedBox(height: LiliaSpacing.sm),
            // 4. Comment utiliser
            const _Regle(
              icon: Icons.shopping_bag_outlined,
              titre: 'Utiliser',
              texte:
                  'Au paiement, activez « Utiliser mes points » : la réduction '
                  's’applique au total de la commande.',
            ),
            if (_showHistory) ...[
              const SizedBox(height: LiliaSpacing.sp3),
              const Divider(color: Colors.white38, height: 1),
              const SizedBox(height: LiliaSpacing.sm),
              widget.history,
            ],
          ],
        ),
      ),
    );
  }
}

class _Regle extends StatelessWidget {
  const _Regle({required this.icon, required this.titre, required this.texte});

  final IconData icon;
  final String titre;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.white),
        const SizedBox(width: LiliaSpacing.sm),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$titre : ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: texte),
              ],
            ),
            style: const TextStyle(fontSize: 13, height: 1.3),
          ),
        ),
      ],
    );
  }
}

/// Historique : chargé **seulement** quand le client le déplie.
class _HistoriqueBranche extends ConsumerWidget {
  const _HistoriqueBranche();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(loyaltyTransactionsProvider)
        .when(
          data: (transactions) => LoyaltyHistoryList(transactions),
          loading: () => const Padding(
            padding: EdgeInsets.all(LiliaSpacing.sm),
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
          error: (_, _) => Row(
            children: [
              const Expanded(
                child: Text(
                  'Historique indisponible pour le moment.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(loyaltyTransactionsProvider),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        );
  }
}

class LoyaltyHistoryList extends StatelessWidget {
  const LoyaltyHistoryList(this.transactions, {super.key});

  final List<LoyaltyTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Text(
        'Aucun mouvement pour l’instant.',
        style: TextStyle(fontSize: 13),
      );
    }
    return Column(
      children: [
        for (final t in transactions.take(10))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: LiliaSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.reason,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: LiliaSpacing.sm),
                // Le signe porte le sens (gain / dépense), pas la couleur.
                Text(
                  '${t.points > 0 ? "+" : ""}${t.points} pt',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
