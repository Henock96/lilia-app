import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  // REMPLACEZ PAR VOS VRAIES INFORMATIONS CLOUDINARY
  // Exemple:
  // final _cloudinary = CloudinaryPublic('lilia-app-cloud', 'ml_default', cache: false);
  final _cloudinary = CloudinaryPublic('dun9ev7pw', 'ml_default', cache: false);

  Future<String?> uploadImage(XFile image) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(image.path, resourceType: CloudinaryResourceType.Image),
      );
      return response.secureUrl;
    } on CloudinaryException catch (e) {
      print(e.message);
      print(e.request);
      return null;
    }
  }
}

//CLOUDINARY_URL=cloudinary://779627169413964:zhYvHdrvy5xh64DG6DbCiw9JplE@dun9ev7pw
