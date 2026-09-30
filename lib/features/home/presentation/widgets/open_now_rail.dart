import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/common_widgets/app_cached_image.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/models/vendor_type.dart';
import 'package:lilia_app/routing/app_route_enum.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';

import '../../data/remote/restaurant_controller.dart';
import 'section_header.dart';
import 'section_skeleton.dart';

const double _cardWidth = 150;

/// Hauteur d'une carte du rail pour la taille de texte courante : image (96)
/// + nom (2 lignes) + type + badge.
double openNowCardHeight(TextScaler scaler) {
  double ligne(double fontSize) => scaler.scale(fontSize) * 1.4;
  return 96 + 8 + ligne(14) * 2 + 2 + ligne(12) + 6 + ligne(11) + 10 + 8;
}

/// « Ouvert maintenant » : les vendeurs ouverts de la liste déjà chargée.
///
/// Aucun appel réseau (dérivé de `vendorsList`, déjà chargée pour la liste
/// complète), aucune décision : `isOpen == true` tel que servi. Sans vendeur
/// ouvert, la section **disparaît** — « Disponible maintenant », juste en
/// dessous, dit alors quand les boutiques rouvrent.
///
/// En panne sans liste, elle disparaît aussi : « Toutes les boutiques » porte
/// déjà le message d'erreur et « Réessayer » de la même source — deux fois le
/// même message ne dirait rien de plus.
class OpenNowRail extends ConsumerStatefulWidget {
  const OpenNowRail({super.key});

  @override
  ConsumerState<OpenNowRail> createState() => _OpenNowRailState();
}

class _OpenNowRailState extends ConsumerState<OpenNowRail> {
  /// Filtre de la dernière liste **reçue**. Pendant un rechargement (tirer
  /// pour rafraîchir, hors ligne), Riverpod garde l'ancienne liste : elle
  /// reste affichée — mais seulement sous **son** filtre (règle P3-12), jamais
  /// celle de « Tous » sous « Boulangerie » le temps que la nouvelle arrive.
  VendorType? _loadedFor;
  bool _hasLoaded = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(vendorsListProvider);
    final filter = ref.watch(marketplaceFilterProvider);
    ref.listen(vendorsListProvider, (_, next) {
      if (next is AsyncData<List<RestaurantSummary>>) {
        _loadedFor = ref.read(marketplaceFilterProvider);
        _hasLoaded = true;
      }
    });
    // Déjà en cache au montage : l'écouteur ne l'a pas vu passer.
    if (!_hasLoaded && async is AsyncData<List<RestaurantSummary>>) {
      _loadedFor = filter;
      _hasLoaded = true;
    }

    final height = openNowCardHeight(MediaQuery.textScalerOf(context));
    final value = async.value;
    if (value != null && _hasLoaded && _loadedFor == filter) {
      // Présentation seulement : `isOpen` a été décidé par le serveur, et
      // `null` (inconnu) n'est pas « ouvert ».
      final vendors = [
        for (final v in value)
          if (v.isOpen == true) v,
      ];
      if (vendors.isEmpty) return const SizedBox.shrink();
      return _Section(
        title: 'Ouvert maintenant',
        count: vendors.length,
        child: SizedBox(
          height: height,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: vendors.length,
            itemBuilder: (_, i) => _OpenVendorCard(vendor: vendors[i]),
          ),
        ),
      );
    }
    if (async.isLoading) {
      return _Section(
        title: 'Ouvert maintenant',
        child: RailSkeleton(height: height, cardWidth: _cardWidth),
      );
    }
    return const SizedBox.shrink();
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.count});

  final String title;
  final int? count;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: SectionHeader(
          // Compteur réel, tiré de la liste affichée.
          title: count == null ? title : '$title · $count',
        ),
      ),
      const SizedBox(height: LiliaSpacing.sm + 4),
      child,
      const SizedBox(height: LiliaSpacing.lg),
    ],
  );
}

class _OpenVendorCard extends StatelessWidget {
  const _OpenVendorCard({required this.vendor});

  final RestaurantSummary vendor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: _cardWidth,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.goNamed(
            AppRoutes.restaurantDetail.routeName,
            pathParameters: {'id': vendor.id},
            extra: {'restaurantName': vendor.name},
          ),
          child: Semantics(
            button: true,
            label: '${vendor.name}, ${vendor.vendorType.label}, ouvert',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: vendor.thumbnailUrl != null
                      ? AppCachedImage(
                          imageUrl: vendor.thumbnailUrl!,
                          height: 96,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: _placeholder(cs),
                        )
                      : _placeholder(cs),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vendor.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        vendor.vendorType.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: cs.successText,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Ouvert',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cs.successText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) => Container(
    height: 96,
    width: double.infinity,
    color: cs.surfaceContainerHighest,
    child: Icon(Icons.storefront_outlined, size: 32, color: cs.outline),
  );
}
