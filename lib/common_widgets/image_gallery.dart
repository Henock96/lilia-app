import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

/// Carrousel d'images réutilisable pour les en-têtes de détail (produit,
/// restaurant, menu). Affiche :
/// - le [placeholder] si [urls] est vide ;
/// - une simple image (avec Hero optionnel) s'il n'y a qu'une URL ;
/// - un carrousel défilable avec indicateurs de page sinon.
///
/// Le [heroTag] n'est appliqué qu'à la première image (la cover) pour éviter
/// les tags Hero dupliqués qui crashent les transitions.
class ImageGallery extends StatefulWidget {
  final List<String> urls;
  final Widget placeholder;
  final String? heroTag;

  /// Position des indicateurs de page (dots). Par défaut en bas au centre ;
  /// passer [Alignment.topCenter] quand un titre/nom est superposé en bas.
  final AlignmentGeometry indicatorAlignment;
  final EdgeInsets indicatorPadding;

  const ImageGallery({
    super.key,
    required this.urls,
    required this.placeholder,
    this.heroTag,
    this.indicatorAlignment = Alignment.bottomCenter,
    this.indicatorPadding = const EdgeInsets.only(bottom: 12),
  });

  @override
  State<ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<ImageGallery> {
  int _current = 0;

  Widget _image(String url) => Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => widget.placeholder,
      );

  Widget _maybeHero(int index, Widget child) =>
      (index == 0 && widget.heroTag != null)
          ? Hero(tag: widget.heroTag!, child: child)
          : child;

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;

    if (urls.isEmpty) return widget.placeholder;
    if (urls.length == 1) return _maybeHero(0, _image(urls.first));

    return Stack(
      fit: StackFit.expand,
      children: [
        CarouselSlider.builder(
          itemCount: urls.length,
          itemBuilder: (_, index, _) => _maybeHero(index, _image(urls[index])),
          options: CarouselOptions(
            height: double.infinity,
            viewportFraction: 1.0,
            enableInfiniteScroll: true,
            onPageChanged: (index, _) => setState(() => _current = index),
          ),
        ),
        Align(
          alignment: widget.indicatorAlignment,
          child: Padding(
            padding: widget.indicatorPadding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(urls.length, (i) {
                final active = i == _current;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white60,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 2),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}
