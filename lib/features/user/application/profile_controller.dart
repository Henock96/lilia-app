import 'package:image_picker/image_picker.dart';
import 'package:lilia_app/features/auth/app_user_model.dart';
import 'package:lilia_app/features/user/data/cloudinary_service.dart';
import 'package:lilia_app/models/loyalty_transaction.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:lilia_app/features/user/data/user_repository.dart';
import 'package:lilia_app/features/auth/domain/auth_failure.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/core/network/api_exception.dart';

part 'profile_controller.g.dart';

// Maintenu en vie : lu par des contrôleurs qui le sont (panier, adresses,
// profil, session). Sans état propre, il ne dépend que d'`apiClient`, lui-même
// maintenu en vie — le garder ne coûte rien, le recréer sous un contrôleur
// vivant est ce que `only_use_keep_alive_inside_keep_alive` interdit.
@Riverpod(keepAlive: true)
UserRepository userRepository(Ref ref) {
  return UserRepository(ref.watch(apiClientProvider));
}

/// Ces trois providers refusent de travailler sans session.
///
/// Ils levaient `Exception('Utilisateur non authentifie.')` — préfixé de
/// « Exception: » par `BuildErrorState`, et sans accents. Ils lèvent désormais
/// un [AuthFailure], dont le message est écrit pour un client et dit quoi
/// faire.
///
/// ## M-08 — « pas encore résolu » n'est pas « déconnecté »
///
/// Ces trois providers testaient `authState.asData?.value == null`. Cette
/// condition est vraie dans **deux** situations que rien ne distingue :
/// personne n'est connecté, ou Firebase n'a simplement pas encore répondu. Au
/// démarrage à froid, ils échouaient donc le temps de la résolution, et le
/// client d'une session parfaitement valide lisait « Votre session a expiré.
/// Reconnectez-vous pour continuer. »
///
/// [_sessionOuverte] lève l'ambiguïté en attendant la **première émission** du
/// flux Firebase : pendant le bootstrap le provider reste en chargement — ce
/// qu'il est réellement — au lieu de conclure. `ref.watch(...future)` le fait
/// rejouer à chaque changement de session, donc rien ne reste bloqué.
Future<AppUser> _sessionOuverte(Ref ref) async {
  final user = await ref.watch(authStateChangeProvider.future);
  if (user == null) throw kAuthSessionExpired;
  return user;
}

@riverpod
Future<AppUser> userProfile(Ref ref) async {
  await _sessionOuverte(ref);
  final userRepository = ref.watch(userRepositoryProvider);
  return userRepository.getUserProfile();
}

@riverpod
Future<ReferralStats> referralStats(Ref ref) async {
  await _sessionOuverte(ref);
  return ref.watch(userRepositoryProvider).getReferralStats();
}

@riverpod
Future<List<LoyaltyTransaction>> loyaltyTransactions(Ref ref) async {
  await _sessionOuverte(ref);
  return ref.watch(userRepositoryProvider).getLoyaltyTransactions();
}

@Riverpod(keepAlive: true)
class ProfileController extends _$ProfileController {
  @override
  FutureOr<void> build() {}

  /// Met à jour le profil. Rend `null` en cas de succès, sinon **le message à
  /// montrer**.
  ///
  /// Rendait `bool`, et les appelants devaient aller relire l'erreur dans
  /// `state` pour savoir quoi dire. La feuille de saisie du numéro ne le
  /// faisait pas : elle arrêtait simplement son indicateur, et le client
  /// n'obtenait **rien** — ni message, ni fermeture (M-03).
  Future<String?> updateUser(Map<String, dynamic> data) async {
    final repository = ref.read(userRepositoryProvider);
    state = const AsyncLoading();
    try {
      await repository.updateUserProfile(data);
      ref.invalidate(userProfileProvider);
      state = const AsyncData(null);
      return null;
    } catch (e, st) {
      state = AsyncError(e, st);
      // `ApiException.message` est déjà en français et prêt à afficher — c'est
      // le contrat de `ErrorInterceptor`. Toute autre erreur est technique et
      // n'apprendrait rien au client.
      return e is ApiException
          ? e.message
          : 'Enregistrement impossible. Veuillez réessayer.';
    }
  }

  Future<void> updateProfilePicture() async {
    final picker = ImagePicker();
    final cloudinaryService = CloudinaryService();

    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      // ⚠️ `requestFullMetadata` vaut `true` par défaut. Dans ce mode,
      // `image_picker` lit les métadonnées du `PHAsset` après la sélection —
      // ce qui exige l'autorisation photothèque, donc
      // `NSPhotoLibraryUsageDescription` dans `Info.plist`. Cette clé n'y est
      // pas, et iOS termine le processus quand une autorisation est demandée
      // sans chaîne d'usage : la photo de profil faisait planter
      // l'application.
      //
      // On n'a aucun usage de ces métadonnées — l'image est recompressée par
      // `ImageCompressor` avant l'envoi. Les refuser supprime le besoin
      // d'autorisation au lieu de le documenter : avec un déploiement iOS 15
      // minimum, `PHPickerViewController` rend le fichier sans rien demander.
      requestFullMetadata: false,
    );
    if (image == null) return;

    state = const AsyncLoading();
    try {
      final imageUrl = await cloudinaryService.uploadImage(image);
      if (imageUrl == null) {
        throw Exception("Erreur lors du telechargement de l'image.");
      }
      await updateUser({'imageUrl': imageUrl});
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
