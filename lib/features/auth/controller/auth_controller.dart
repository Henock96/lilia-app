import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';

part 'auth_controller.g.dart';

@riverpod
class AuthController extends _$AuthController {
  @override
  Stream<AppUser?> build() {
    // Écoute les changements d'état d'authentification de Firebase
    return ref.watch(authRepositoryProvider).authStateChanges();
  }

  Future<void> sigInInUserWithEmailAndPassword(String email, String password) async {
    final authRepository = ref.read(authRepositoryProvider);
    await authRepository.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> createUserWithEmailAndPassword(String email, String password) async {
    final authRepository = ref.read(authRepositoryProvider);
    await authRepository.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    final authRepository = ref.read(authRepositoryProvider);
    await authRepository.signOut();
  }
}
