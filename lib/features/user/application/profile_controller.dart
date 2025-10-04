import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/user/data/cloudinary_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:lilia_app/features/user/data/user_repository.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';

part 'profile_controller.g.dart';

@riverpod
UserRepository userRepository(Ref ref) {
  return UserRepository();
}

@riverpod
Future<AppUser> userProfile(Ref ref) async {
  final authState = ref.watch(authStateChangeProvider);

  if (authState.asData?.value == null) {
    throw Exception('Utilisateur non authentifié.');
  }

  final userRepository = ref.watch(userRepositoryProvider);
  final user = await userRepository.getUserProfile();
  return user;
}

@Riverpod(keepAlive: true)
class ProfileController extends _$ProfileController {
  @override
  FutureOr<void> build() {
    // Rien à faire ici
  }

  Future<bool> updateUser(Map<String, dynamic> data) async {
    final repository = ref.read(userRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository.updateUserProfile(data);
      ref.invalidate(userProfileProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<void> updateProfilePicture() async {
    final picker = ImagePicker();
    final cloudinaryService = CloudinaryService();

    // 1. Sélectionner l'image
    debugPrint("1. Ouverture de la galerie...");
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image == null) {
      debugPrint("Sélection d'image annulée.");
      return;
    }
    debugPrint("2. Image sélectionnée: ${image.path}");

    state = const AsyncLoading();

    try {
      // 2. Uploader sur Cloudinary
      debugPrint("3. Téléversement vers Cloudinary...");
      final imageUrl = await cloudinaryService.uploadImage(image);
      if (imageUrl == null) {
        debugPrint("4. Échec du téléversement Cloudinary, URL est nulle.");
        throw Exception("Erreur lors du téléversement de l'image.");
      }
      debugPrint("4. Image téléversée, URL: $imageUrl");

      // 3. Mettre à jour le profil utilisateur
      debugPrint("5. Mise à jour du profil utilisateur via le backend...");
      await updateUser({'imageUrl': imageUrl});
      debugPrint("6. Processus de mise à jour du profil terminé.");
    } catch (e, st) {
      debugPrint("ERREUR lors de la mise à jour de la photo de profil: $e");
      debugPrint(st.toString());
      state = AsyncError(e, st);
    }
  }
}
