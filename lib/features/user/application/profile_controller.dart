import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/user/data/cloudinary_service.dart';
import 'package:lilia_app/models/loyalty_transaction.dart';
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
  if (authState.asData?.value == null) throw Exception('Utilisateur non authentifie.');
  final userRepository = ref.watch(userRepositoryProvider);
  return userRepository.getUserProfile();
}

@riverpod
Future<ReferralStats> referralStats(Ref ref) async {
  final authState = ref.watch(authStateChangeProvider);
  if (authState.asData?.value == null) throw Exception('Non authentifie.');
  return ref.watch(userRepositoryProvider).getReferralStats();
}

@riverpod
Future<List<LoyaltyTransaction>> loyaltyTransactions(Ref ref) async {
  final authState = ref.watch(authStateChangeProvider);
  if (authState.asData?.value == null) throw Exception('Non authentifie.');
  return ref.watch(userRepositoryProvider).getLoyaltyTransactions();
}

@Riverpod(keepAlive: true)
class ProfileController extends _$ProfileController {
  @override
  FutureOr<void> build() {}

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

    debugPrint("1. Ouverture de la galerie...");
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    state = const AsyncLoading();
    try {
      final imageUrl = await cloudinaryService.uploadImage(image);
      if (imageUrl == null) throw Exception("Erreur lors du telechargement de l'image.");
      await updateUser({'imageUrl': imageUrl});
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
