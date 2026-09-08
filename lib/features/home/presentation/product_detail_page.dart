import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/features/favoris/application/favorites_provider.dart';
import 'package:lilia_app/services/analytics_service.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/produit.dart';
import '../../../models/vendor_type.dart';
import '../../cart/presentation/cart_mode_conflict_dialog.dart';
import 'package:lilia_app/common_widgets/app_animations.dart';
import 'package:lilia_app/common_widgets/image_gallery.dart';
import 'package:lilia_app/utils/currency.dart';
import 'package:lilia_app/utils/snackbar.dart';
import 'package:lilia_app/features/cart/domain/cart_mutations.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage>
    with SingleTickerProviderStateMixin {
  int _quantity = 1;
  ProductVariant? _selectedVariant;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // Sélection d'office **uniquement** s'il n'y a qu'un format : il n'y a
    // alors rien à choisir. Au-delà, on laisse `null` — la fiche annonce
    // « À partir de X » et le bouton demande de choisir. L'ancienne version
    // retenait `variants.first`, c'est-à-dire la première ligne rendue par
    // PostgreSQL : un format arbitraire, qui changeait après une édition du
    // produit.
    if (widget.product.variants.length == 1) {
      _selectedVariant = widget.product.variants.first;
    }

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // `product_view` dans `initState` : la fiche a été ouverte, donc consultée.
    AnalyticsService.trackProductView(
      productId: widget.product.id,
      productName: widget.product.name,
      restaurantId: widget.product.restaurantId,
      price: widget.product.prixOriginal,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Prix unitaire retenu : celui du format choisi, sinon le **prix d'appel**.
  ///
  /// ⚠️ Le repli était `prixOriginal`, qui n'est pas ce qui est facturé : c'est
  /// le prix de référence du produit, pas celui d'un format. Sur un produit à
  /// trois tailles dont la moins chère vaut 1 000 et dont `prixOriginal` vaut
  /// 2 500, la fiche annonçait 2 500 tant que rien n'était sélectionné — un
  /// montant qu'aucun panier n'aurait jamais porté.
  double get _unitPrice => _selectedVariant?.prix ?? widget.product.startingPrice;

  double get _currentPrice => _unitPrice * _quantity;

  void _shareProduct(BuildContext context) {
    final String message =
        '''
Découvrez ${widget.product.name} sur Lilia Food !

${widget.product.description}

Prix : ${formatPrice(widget.product.startingPrice)}

Téléchargez l'app Lilia Food pour commander !
''';
    SharePlus.instance.share(
      ShareParams(
        text: message,
        subject: 'Découvrez ${widget.product.name} sur Lilia Food!',
      ),
    );
  }

  /// Pourquoi l'ajout au panier est-il impossible ? `null` s'il est possible.
  ///
  /// Aucune règle n'est recalculée ici : `product.unavailability` relaie le
  /// verdict du serveur (`availableNow`, `isAvailable`, `stockRestant`), et
  /// `restaurantIsOpen` vient de la réponse. On ne fait que traduire.
  String? get _blockedReason {
    final p = widget.product;
    if (p.restaurantIsOpen == false) return 'Boutique fermée';
    switch (p.unavailability) {
      case ProductUnavailability.epuise:
        return 'Épuisé';
      case ProductUnavailability.retire:
        return 'Indisponible';
      case ProductUnavailability.horsCreneau:
        return p.availableFrom != null && p.availableUntil != null
            ? 'Disponible de ${p.availableFrom} à ${p.availableUntil}'
            : 'Hors créneau de vente';
      case null:
        break;
    }
    if (p.variants.length > 1 && _selectedVariant == null) {
      return 'Choisissez un format';
    }
    return null;
  }

  Future<void> _addToCart() async {
    if (_selectedVariant == null && widget.product.variants.isNotEmpty) {
      context.showSnack(
        'Veuillez sélectionner une variante',
        type: SnackType.error,
      );
      return;
    }

    try {
      final added = await addToCartSafely(
        context: context,
        ref: ref,
        preview: CartItemPreview.fromProduct(widget.product, _selectedVariant!),
        quantity: _quantity,
      );
      if (!added) return; // Le client a annulé sur la modal de conflit
      // `add_to_cart` n'est plus déclenché ici : le rendu étant optimiste,
      // cet endroit ne sait plus si le serveur a accepté. Le contrôleur le
      // déclenche au retour de `POST /cart/add`.
      if (mounted) {
        context.showSuccessSnack(
          '$_quantity x ${widget.product.name} ajouté au panier',
        );
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnack(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = Theme.of(context).colorScheme;

    final isFavorite = ref
        .watch(favoritesProvider)
        .maybeWhen(
          data: (favorites) => favorites.any((p) => p.id == widget.product.id),
          orElse: () => false,
        );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // AppBar avec image
          _buildSliverAppBar(theme, isFavorite),

          // Contenu
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête du produit
                  _buildProductHeader(theme).fadeSlideIn(),

                  // Description
                  _buildDescription(),

                  // Détails produit (ingrédients, conservation, dispo horaire…)
                  // Affiché uniquement si au moins un champ pertinent.
                  if (_hasProductDetails()) _buildProductDetails(theme),

                  // Variantes
                  if (widget.product.variants.isNotEmpty)
                    _buildVariantsSection(theme),

                  // Sélecteur de quantité
                  _buildQuantitySelector(theme),

                  // Espace pour le bouton fixe
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      // Bouton fixe en bas
      bottomNavigationBar: _buildBottomBar(theme, cs).fadeSlideIn(dy: 0.5),
    );
  }

  Widget _buildSliverAppBar(ThemeData theme, bool isFavorite) {
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      stretch: true,
      backgroundColor: theme.colorScheme.surface,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
            ),
          ],
        ),
        child: IconButton(
          tooltip: 'Retour',
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: IconButton(
            tooltip: 'Retirer des favoris',
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.red : theme.colorScheme.onSurface,
            ),
            onPressed: () {
              final notifier = ref.read(favoritesProvider.notifier);
              if (isFavorite) {
                notifier.remove(widget.product);
              } else {
                notifier.add(widget.product);
              }
            },
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: IconButton(
            tooltip: 'Partager',
            icon: Icon(
              Icons.share_outlined,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: () => _shareProduct(context),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: ImageGallery(
          urls: widget.product.galleryUrls,
          placeholder: _buildPlaceholderImage(),
          heroTag: widget.product.id,
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Container(
          color: cs.surfaceContainerHighest,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.fastfood, size: 80, color: cs.outline),
                const SizedBox(height: 8),
                Text(
                  'Image non disponible',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nom du produit
          Text(
            widget.product.name,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          // Prix et badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  formatPrice(_unitPrice),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              // Badge disponibilité
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Disponible',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'Description',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.product.description,
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Vrai si on a au moins une info à afficher dans la section "Détails".
  bool _hasProductDetails() {
    final p = widget.product;
    return (p.ingredients != null && p.ingredients!.trim().isNotEmpty) ||
        p.shelfLifeDays != null ||
        p.madeToOrder ||
        (p.availableFrom != null && p.availableUntil != null) ||
        // ProductType non-FOOD est intéressant à afficher (pâtisserie, etc.)
        p.productType != ProductType.FOOD;
  }

  Widget _buildProductDetails(ThemeData theme) {
    final p = widget.product;
    final scheme = theme.colorScheme;
    final inWindow = p.isWithinAvailabilityWindow;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_outlined, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Détails produit',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Type de produit (PASTRY, BEVERAGE, GROCERY…)
            if (p.productType != ProductType.FOOD)
              _DetailRow(
                icon: Icons.category_outlined,
                label: 'Type',
                value: p.productType.label,
                accent: scheme.primary,
              ),

            // Ingrédients (allergènes)
            if (p.ingredients != null && p.ingredients!.trim().isNotEmpty)
              _DetailRow(
                icon: Icons.restaurant_menu,
                label: 'Ingrédients',
                value: p.ingredients!,
                accent: Colors.deepOrange,
              ),

            // Durée de conservation
            if (p.shelfLifeDays != null)
              _DetailRow(
                icon: Icons.access_time,
                label: 'Conservation',
                value:
                    '${p.shelfLifeDays} jour${p.shelfLifeDays! > 1 ? 's' : ''}',
                accent: Colors.teal,
              ),

            // Préparé sur commande
            if (p.madeToOrder)
              _DetailRow(
                icon: Icons.bakery_dining,
                label: 'Préparation',
                value: 'Préparé sur commande',
                accent: Colors.purple,
              ),

            // Fenêtre de disponibilité (BAKERY surtout)
            if (p.availableFrom != null && p.availableUntil != null)
              _DetailRow(
                icon: Icons.schedule,
                label: 'Disponible',
                value: '${p.availableFrom} → ${p.availableUntil}',
                accent: inWindow ? Colors.green : Colors.red,
                trailing: !inWindow
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'Hors créneau',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantsSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Text(
                'Choisir une variante',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                'Requis',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red[400],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...widget.product.variants.map((variant) {
            final isSelected = _selectedVariant?.id == variant.id;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedVariant = variant;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.08)
                      : theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withValues(alpha: 0.3),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Radio button personnalisé
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    // Label
                    Expanded(
                      child: Text(
                        variant.displayLabel,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    // Prix
                    Text(
                      formatPrice(variant.prix),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              const Text(
                'Quantité',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bouton moins
                _buildQuantityButton(
                  icon: Icons.remove,
                  onTap: () {
                    if (_quantity > 1) {
                      setState(() => _quantity--);
                    }
                  },
                  enabled: _quantity > 1,
                  theme: theme,
                ),
                // Quantité
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Container(
                    key: ValueKey<int>(_quantity),
                    width: 60,
                    alignment: Alignment.center,
                    child: Text(
                      '$_quantity',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Bouton plus
                _buildQuantityButton(
                  icon: Icons.add,
                  onTap: () {
                    setState(() => _quantity++);
                  },
                  enabled: true,
                  theme: theme,
                  isPrimary: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
    required ThemeData theme,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isPrimary
                ? theme.colorScheme.primary
                : (enabled
                      ? theme.colorScheme.surface
                      : theme.colorScheme.surfaceContainerHighest),
            borderRadius: BorderRadius.circular(12),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: isPrimary
                          ? theme.colorScheme.primary.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: isPrimary
                ? Colors.white
                : (enabled
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.outline),
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.12),
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Total
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(fontSize: 14, color: cs.onSurface),
                  ),
                  const SizedBox(height: 2),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      formatPrice(_currentPrice),
                      key: ValueKey<double>(_currentPrice),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Bouton ajouter au panier
            Expanded(
              flex: 2,
              child: ScaleTransition(
                scale: _scaleAnimation,
                // ⚠️ Ce bouton n'était **jamais** désactivé : ni le stock, ni
                // `isAvailable`, ni la fenêtre horaire, ni la fermeture de la
                // boutique ne l'arrêtaient. Le client appuyait, attendait, et
                // recevait un refus du serveur — quand le site, lui, le grisait
                // en disant pourquoi. Le backend protégeait bien la commande ;
                // c'est l'expérience qui divergeait.
                child: ElevatedButton(
                  onPressed: _blockedReason == null ? _addToCart : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    disabledBackgroundColor: cs.surfaceContainerHighest,
                    disabledForegroundColor: cs.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shopping_cart_outlined, size: 22),
                      const SizedBox(width: 8),
                      // Dire POURQUOI : « désactivé » sans raison ressemble à
                      // une panne de l'application.
                      Text(_blockedReason ?? 'Ajouter au panier'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ligne d'information utilisée dans la carte "Détails produit" (LIL-117).
/// Icône colorée + label + valeur, avec un trailing widget optionnel
/// (utilisé pour le badge "Hors créneau" sur la fenêtre horaire).
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final Widget? trailing;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: accent, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
