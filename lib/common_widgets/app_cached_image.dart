import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Cache manager partagé pour toutes les images réseau de l'app (LIL-37).
///
/// Objectif : limiter la conso data sur 4G Brazzaville en réutilisant les
/// images Cloudinary déjà téléchargées au lieu de les recharger à chaque
/// affichage (`Image.network` ne cache rien sur disque).
///
/// - `stalePeriod` : on garde une image 30 jours avant de la revalider.
/// - `maxNrOfCacheObjects` : ~400 fichiers, ce qui couvre largement un budget
///   disque de l'ordre de 100 MB pour des vignettes/photos Cloudinary
///   (≈ 200-300 KB chacune). Le cache mémoire décodé est lui plafonné à 100 MB
///   dans `main()` via `imageCache.maximumSizeBytes`.
class LiliaImageCache {
  LiliaImageCache._();

  static const key = 'liliaImageCache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 400,
    ),
  );

  /// Plafond du cache mémoire (images décodées) : 100 MB.
  /// À appeler une fois au démarrage, après `WidgetsFlutterBinding`.
  static void configureMemoryCache() {
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024;
  }
}

/// Image réseau cachée, réutilisable dans toute l'app (LIL-37).
///
/// Remplace `Image.network` : ajoute le cache disque (Cloudinary) + un
/// placeholder shimmer cohérent + un widget d'erreur par défaut.
///
/// ```dart
/// AppCachedImage(
///   imageUrl: product.imageUrl,
///   width: double.infinity,
///   height: 110,
///   errorIcon: Icons.restaurant_menu,
/// )
/// ```
class AppCachedImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Icône affichée si l'URL est nulle/vide ou si le chargement échoue.
  final IconData errorIcon;

  /// Placeholder personnalisé (sinon shimmer par défaut).
  final Widget? placeholder;

  /// Widget d'erreur personnalisé (sinon icône neutre).
  final Widget? errorWidget;

  /// Description lue par TalkBack / VoiceOver (ex. « Photo du plat Poulet DG »).
  ///
  /// Les photos de plats et de vendeurs étaient totalement muettes pour un
  /// lecteur d'écran. Passer `null` masque l'image aux technologies
  /// d'assistance — le bon choix pour une image purement décorative.
  final String? semanticLabel;

  const AppCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorIcon = Icons.image_not_supported_outlined,
    this.placeholder,
    this.errorWidget,
    this.semanticLabel,
  });

  bool get _hasUrl => imageUrl != null && imageUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (!_hasUrl) {
      child =
          errorWidget ??
          _DefaultError(width: width, height: height, icon: errorIcon);
    } else {
      child = CachedNetworkImage(
        imageUrl: imageUrl!,
        cacheManager: LiliaImageCache.instance,
        width: width,
        height: height,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, _) =>
            placeholder ?? AppShimmerBox(width: width, height: height),
        errorWidget: (_, _, _) =>
            errorWidget ??
            _DefaultError(width: width, height: height, icon: errorIcon),
      );
    }

    // `image: true` annonce le rôle ; sans label on masque le nœud, qui
    // n'apporterait rien d'autre que du bruit au lecteur d'écran.
    return Semantics(
      image: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel == null,
      child: child,
    );
  }
}

/// Avatar réseau caché (photo de profil ronde).
class AppCachedAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Widget? fallback;

  /// Description lue par les lecteurs d'écran (ex. « Photo de profil de Awa »).
  final String? semanticLabel;

  const AppCachedAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 24,
    this.fallback,
    this.semanticLabel,
  });

  bool get _hasUrl => imageUrl != null && imageUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
      child:
          fallback ??
          Icon(Icons.person, size: radius, color: theme.colorScheme.primary),
    );

    if (!_hasUrl) {
      return Semantics(
        image: true,
        label: semanticLabel,
        excludeSemantics: semanticLabel == null,
        child: placeholder,
      );
    }

    return Semantics(
      image: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel == null,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          cacheManager: LiliaImageCache.instance,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (_, _) => AppShimmerBox(
            width: radius * 2,
            height: radius * 2,
            borderRadius: BorderRadius.circular(radius),
          ),
          errorWidget: (_, _, _) => placeholder,
        ),
      ),
    );
  }
}

/// Placeholder shimmer auto-contenu (aucune dépendance externe : portable
/// vers les 3 apps). Balaye un dégradé clair de gauche à droite en boucle.
class AppShimmerBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const AppShimmerBox({super.key, this.width, this.height, this.borderRadius});

  @override
  State<AppShimmerBox> createState() => _AppShimmerBoxState();
}

class _AppShimmerBoxState extends State<AppShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1.0 - 2 * _controller.value, 0),
              end: Alignment(1.0 - 2 * _controller.value, 0),
              colors: [base, highlight, base],
              stops: const [0.25, 0.5, 0.75],
            ),
          ),
        );
      },
    );
  }
}

class _DefaultError extends StatelessWidget {
  final double? width;
  final double? height;
  final IconData icon;

  const _DefaultError({this.width, this.height, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      height: height,
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 36,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
    );
  }
}
