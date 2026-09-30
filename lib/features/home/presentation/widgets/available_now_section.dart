import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/common_widgets/stale_data_banner.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/home/domain/opening_label.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/routing/app_route_enum.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';

import '../../data/remote/home_controller.dart';
import '../../data/remote/home_repo.dart';
import '../../data/remote/restaurant_controller.dart';
import 'product_rail_card.dart';
import 'section_header.dart';
import 'section_skeleton.dart';

/// « Disponible maintenant » : ce que le client peut commander **maintenant**.
///
/// Remplace « Plats populaires », qui montrait à 01h18 dix plats de vendeurs
/// fermés. La liste vient de `GET /products/available-now`, filtrée par le
/// serveur **avant** d'être coupée ; l'application ne fait que l'afficher.
///
/// ## États, indépendants du reste de l'accueil
///
/// | État | Rendu |
/// |---|---|
/// | chargement | squelette à la hauteur du rail |
/// | liste | rail de produits |
/// | vide | [ReopeningSoon] : prochaines ouvertures **calculées par le serveur** |
/// | hors ligne, liste du même filtre | rail atténué + « Disponibilités à vérifier » |
/// | hors ligne / erreur sans liste | ligne compacte + Réessayer |
///
/// ## Fraîcheur
///
/// Rechargée au retour au premier plan et chaque minute tant qu'elle est
/// visible. Ce n'est pas une garantie : le panier et le checkout recalculent
/// ouverture et stock, et restent l'autorité.
class AvailableNowSection extends ConsumerStatefulWidget {
  const AvailableNowSection({super.key, this.onSeeAllVendors});

  /// Amène à « Toutes les boutiques » (repli sans réouverture connue).
  final VoidCallback? onSeeAllVendors;

  @override
  ConsumerState<AvailableNowSection> createState() =>
      _AvailableNowSectionState();
}

class _AvailableNowSectionState extends ConsumerState<AvailableNowSection>
    with WidgetsBindingObserver {
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh = Timer.periodic(kAvailableNowTtl, (_) => _refreshIfVisible());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshIfVisible();
  }

  /// Recharge si l'écran est réellement affiché : premier plan, et onglet
  /// Accueil actif (`TickerMode` coupé sur les onglets en arrière-plan).
  void _refreshIfVisible() {
    if (!mounted) return;
    final foreground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (!foreground || !TickerMode.valuesOf(context).enabled) return;
    final value = ref.read(availableNowProvider).value;
    final at = value?.generatedAt;
    if (at == null ||
        DateTime.now().difference(at.toLocal()) >= kAvailableNowTtl) {
      ref.invalidate(availableNowProvider);
    }
  }

  void _retry() => ref.invalidate(availableNowProvider);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(availableNowProvider);
    final filter = ref.watch(marketplaceFilterProvider);
    final railHeight = productRailCardHeight(MediaQuery.textScalerOf(context));

    // Seule une liste chargée **pour ce filtre** peut être montrée.
    final value = async.value;
    final usable = value != null && value.vendorType == filter ? value : null;

    final Widget body;
    if (usable != null && async.hasError) {
      body = _StaleRail(result: usable, height: railHeight, onRetry: _retry);
    } else if (usable != null && !async.isLoading) {
      body = usable.products.isEmpty
          ? ReopeningSoon(onSeeAllVendors: widget.onSeeAllVendors)
          : _Rail(result: usable, height: railHeight);
    } else if (async.isLoading) {
      // Rechargement en cours : l'ancienne liste du même filtre reste en
      // place plutôt que de clignoter vers un squelette.
      body = usable != null && usable.products.isNotEmpty
          ? _Rail(result: usable, height: railHeight)
          : RailSkeleton(
              height: railHeight,
              cardWidth: kProductRailCardWidth,
            );
    } else {
      body = _ErrorLine(error: async.error, onRetry: _retry);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: const SectionHeader(title: 'Disponible maintenant'),
        ),
        const SizedBox(height: LiliaSpacing.sm + 4),
        body,
        const SizedBox(height: LiliaSpacing.lg),
      ],
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.result, required this.height});

  final AvailableNow result;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: result.products.length,
      itemBuilder: (_, i) => ProductRailCard(product: result.products[i]),
    ),
  );
}

/// Hors ligne avec une liste du même filtre : elle reste, **atténuée** et
/// datée à l'heure du serveur. Le « + » reste actif — le panier et le
/// checkout tranchent, avec leur message de refus.
class _StaleRail extends StatelessWidget {
  const _StaleRail({
    required this.result,
    required this.height,
    required this.onRetry,
  });

  final AvailableNow result;
  final double height;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      StaleDataBanner(
        title: 'Disponibilités à vérifier (hors ligne)',
        loadedAt: result.generatedAt ?? DateTime.now(),
        onRetry: onRetry,
      ),
      if (result.products.isNotEmpty)
        Opacity(
          opacity: 0.6,
          child: _Rail(result: result, height: height),
        ),
    ],
  );
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e = error;
    final offline =
        e is ApiException &&
        (e.kind == ApiErrorKind.network || e.kind == ApiErrorKind.timeout);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(
              offline ? Icons.cloud_off_rounded : Icons.error_outline,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                offline
                    ? 'Hors ligne : disponibilités non chargées.'
                    : 'Impossible de charger les disponibilités.',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

/// Rien de commandable maintenant : on dit **quand** ça le redevient, avec
/// les heures calculées par le serveur (`nextOpeningAt`), jamais inventées.
///
/// - des boutiques sont ouvertes (mais rien en stock) : on le dit, sans
///   parler de réouverture ;
/// - toutes fermées, réouvertures connues : les 3 plus proches ;
/// - aucune heure connue : « fermées pour le moment », et le chemin vers la
///   liste complète.
class ReopeningSoon extends ConsumerWidget {
  const ReopeningSoon({super.key, this.onSeeAllVendors, this.now});

  final VoidCallback? onSeeAllVendors;

  /// Horloge injectable pour les tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final current = now ?? DateTime.now();
    final vendors = ref.watch(vendorsListProvider).value ?? const [];

    final Widget content;
    if (vendors.any((v) => v.isOpen == true)) {
      content = Text(
        'Aucun produit n’est disponible pour le moment dans les boutiques '
        'ouvertes.',
        style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      );
    } else {
      final reopenings =
          vendors
              .where(
                (v) =>
                    v.isOpen == false &&
                    v.nextOpeningAt != null &&
                    v.nextOpeningAt!.isAfter(current),
              )
              .toList()
            ..sort((a, b) => a.nextOpeningAt!.compareTo(b.nextOpeningAt!));
      content = reopenings.isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Les boutiques sont fermées pour le moment.',
                  style: theme.textTheme.titleSmall,
                ),
                if (onSeeAllVendors != null)
                  TextButton(
                    onPressed: onSeeAllVendors,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    child: const Text('Voir toutes les boutiques'),
                  ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Les boutiques rouvrent bientôt',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                for (final v in reopenings.take(3))
                  _ReopeningRow(vendor: v, now: current),
              ],
            );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(LiliaSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: LiliaRadius.lgAll,
      ),
      child: content,
    );
  }
}

class _ReopeningRow extends StatelessWidget {
  const _ReopeningRow({required this.vendor, required this.now});

  final RestaurantSummary vendor;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final when = reopeningWhen(vendor.nextOpeningAt!, now: now);
    return InkWell(
      onTap: () => context.goNamed(
        AppRoutes.restaurantDetail.routeName,
        pathParameters: {'id': vendor.id},
        extra: {'restaurantName': vendor.name},
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(Icons.schedule, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: vendor.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: ' · $when'),
                  ],
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
