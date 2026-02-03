import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'onboarding_provider.g.dart';

const String _onboardingCompletedKey = 'onboarding_completed';

/// Provider pour SharedPreferences
@Riverpod(keepAlive: true)
Future<SharedPreferences> sharedPreferences(Ref ref) async {
  return await SharedPreferences.getInstance();
}

/// Provider pour vérifier si l'onboarding a été complété
@Riverpod(keepAlive: true)
class OnboardingStatus extends _$OnboardingStatus {
  @override
  Future<bool> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return prefs.getBool(_onboardingCompletedKey) ?? false;
  }

  /// Marquer l'onboarding comme complété
  Future<void> completeOnboarding() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(_onboardingCompletedKey, true);
    state = const AsyncData(true);
  }

  /// Réinitialiser l'onboarding (pour les tests)
  Future<void> resetOnboarding() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(_onboardingCompletedKey, false);
    state = const AsyncData(false);
  }
}
