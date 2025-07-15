import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:lilia_app/features/user/data/user_repository.dart';
import 'package:lilia_app/features/auth/controller/auth_controller.dart';

part 'profile_controller.g.dart';

@riverpod
UserRepository userRepository(UserRepositoryRef ref) {
  return UserRepository();
}

@riverpod
Future<AppUser> userProfile(Ref ref) async {
  final repository = ref.watch(profileControllerProvider.notifier);
  return repository.getUserProfile();
}

@riverpod
class ProfileController extends _$ProfileController {
  @override
  FutureOr<void> build() {
    // Ne fait rien à l'initialisation
  }

  Future<bool> updateUser(Map<String, dynamic> data) async {
    final repository = ref.read(userRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository.updateUserProfile(data);
      // Invalide le provider d'authentification pour forcer la mise à jour
      // des données de l'utilisateur partout dans l'application.
      ref.invalidate(authControllerProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<AppUser> getUserProfile() async {
    final repository = ref.read(userRepositoryProvider);
    state = const AsyncLoading();
    try {
      final user = await repository.getUserProfile();
      // Invalide le provider d'authentification pour forcer la mise à jour
      // des données de l'utilisateur partout dans l'application.
      state = const AsyncData(null);
      return user;
    } catch (e, st) {
      throw Exception('Failed to connect to the server or fetch profile: $e');
    }
  }
}