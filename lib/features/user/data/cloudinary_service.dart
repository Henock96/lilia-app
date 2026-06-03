import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  // Upload NON signé : seuls le cloud name (public) et le preset unsigned
  // `ml_default` sont utilisés côté client. Aucun API key/secret ici — la
  // signature reste serveur-only. Ne jamais embarquer l'API secret Cloudinary.
  final _cloudinary = CloudinaryPublic('dun9ev7pw', 'ml_default', cache: false);

  Future<String?> uploadImage(XFile image) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          image.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl;
    } on CloudinaryException catch (e) {
      debugPrint(e.message);
      return null;
    }
  }
}
