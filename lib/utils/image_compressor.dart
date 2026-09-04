import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Compression d'image **hors main thread** (isolate via [compute]).
///
/// Le décodage / redimensionnement / ré-encodage JPEG est purement CPU et
/// bloque l'UI plusieurs centaines de ms sur une photo 12 MP d'un téléphone
/// d'entrée de gamme. On le déporte sur un isolate pour garder l'app fluide
/// pendant qu'un vendeur/client prépare sa photo.
///
/// Sur 4G Brazzaville, réduire la taille avant upload Cloudinary économise
/// aussi la data et accélère l'envoi (complément de [LIL-37]).
class ImageCompressor {
  ImageCompressor._();

  /// Compresse [bytes] : redimensionne pour que le plus grand côté ne dépasse
  /// pas [maxDimension], puis ré-encode en JPEG [quality] (0-100).
  /// Renvoie les octets d'origine si le décodage échoue (fallback sûr).
  static Future<Uint8List> compress(
    Uint8List bytes, {
    int maxDimension = 1280,
    int quality = 80,
  }) {
    return compute(
      _compressInIsolate,
      _CompressRequest(bytes, maxDimension, quality),
    );
  }
}

class _CompressRequest {
  final Uint8List bytes;
  final int maxDimension;
  final int quality;

  const _CompressRequest(this.bytes, this.maxDimension, this.quality);
}

/// Exécuté DANS l'isolate : aucune dépendance au BuildContext / plugins.
Uint8List _compressInIsolate(_CompressRequest req) {
  final decoded = img.decodeImage(req.bytes);
  if (decoded == null) return req.bytes; // format inconnu → on n'altère pas

  final bool tooLarge =
      decoded.width > req.maxDimension || decoded.height > req.maxDimension;
  final img.Image resized = tooLarge
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? req.maxDimension : null,
          height: decoded.height > decoded.width ? req.maxDimension : null,
        )
      : decoded;

  return Uint8List.fromList(img.encodeJpg(resized, quality: req.quality));
}
