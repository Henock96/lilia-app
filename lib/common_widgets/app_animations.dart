import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';

/// Système d'animation centralisé de l'app — durées/courbes cohérentes et
/// widgets réutilisables pour un rendu « premium » homogène.
///
/// S'appuie sur `flutter_animate`. Préférer ces helpers aux animations ad-hoc.
class AppMotion {
  AppMotion._();

  /// Durées standard.
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration base = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 550);

  /// Décalage entre items d'une liste en cascade.
  static const Duration stagger = Duration(milliseconds: 60);

  /// Courbe d'entrée standard (douce, légèrement appuyée).
  static const Curve curve = Curves.easeOutCubic;
}

/// Raccourcis d'animation d'entrée cohérents, appliqués sur n'importe quel
/// widget : `monWidget.fadeSlideIn()`.
extension AppAnimateX on Widget {
  /// Apparition fondu + léger glissement vertical.
  Widget fadeSlideIn({Duration? delay, double dy = 0.12}) => animate()
      .fadeIn(duration: AppMotion.base, delay: delay, curve: AppMotion.curve)
      .slideY(begin: dy, end: 0, duration: AppMotion.base, curve: AppMotion.curve);

  /// Apparition fondu + léger zoom (cartes, vignettes).
  Widget fadeScaleIn({Duration? delay}) => animate()
      .fadeIn(duration: AppMotion.base, delay: delay, curve: AppMotion.curve)
      .scaleXY(begin: 0.96, end: 1, duration: AppMotion.base, curve: AppMotion.curve);

  /// Entrée en cascade selon l'index dans une liste/grille.
  Widget staggeredIn(int index, {double dy = 0.12}) =>
      fadeSlideIn(delay: AppMotion.stagger * index, dy: dy);
}

/// Enveloppe un widget tactile d'un retour visuel d'appui (léger scale-down).
/// Idéal pour cartes et boutons custom afin de paraître « réactif ».
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
    this.duration = const Duration(milliseconds: 120),
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final Duration duration;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Bloc « skeleton » animé (effet shimmer) pour les états de chargement —
/// remplace avantageusement les `CircularProgressIndicator` (perçu plus rapide).
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).brightness == Brightness.dark
        ? LiliaColors.charcoal600
        : LiliaColors.charcoal100;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(radius),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: const Duration(milliseconds: 1100),
          color: Colors.white.withValues(alpha: 0.45),
        );
  }
}
