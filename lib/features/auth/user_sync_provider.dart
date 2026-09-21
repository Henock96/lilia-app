import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/auth/repository/firebase_auth_repository.dart';
import 'package:lilia_app/services/analytics_service.dart';
import 'package:lilia_app/utils/api_response.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:lilia_app/core/log.dart';

part 'user_sync_provider.g.dart';

@riverpod
class UserDataSynchronizer extends _$UserDataSynchronizer {
  @override
  Future<void> build() async {
    ref.listen(firebaseIdTokenProvider, (previous, next) async {
      final token = next.value;

      if (token != null) {
        // Un token est disponible, l'utilisateur est probablement connecté.
        // On lance la synchronisation.
        if (kDebugMode) {
          logDebug('Token detected. Syncing user profile...');
        }

        // Contexte Sentry : rattacher les erreurs à l'utilisateur connecté.
        // Rôle constant CLIENT pour cette app.
        //
        // ⚠️ **Sans l'adresse e-mail.** Elle était transmise ici et plus bas,
        // à trois lignes d'un `options.sendDefaultPii = false` posé dans
        // `main.dart`. Les deux ne se contredisent pas techniquement — le
        // drapeau ne coupe que la collecte *automatique* — mais quiconque
        // cherche « envoie-t-on des données personnelles à Sentry ? » lit le
        // `false` et s'arrête là.
        //
        // Et elle n'apportait rien : l'identifiant applicatif est déjà envoyé
        // juste en dessous (`id: internalId`), il rattache l'erreur au client
        // aussi sûrement, et il ne sort pas de nos systèmes. Une adresse
        // e-mail chez un tiers hors UE demande une justification ; « c'était
        // plus pratique » n'en est pas une.
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          await Sentry.configureScope(
            (scope) => scope.setUser(
              SentryUser(
                id: firebaseUser.uid,
                data: const {'role': 'CLIENT'},
              ),
            ),
          );
        }

        try {
          final res = await ref.read(apiClientProvider).getJson('/users/me');
          if (kDebugMode) {
            // Status only — never log the token nor the response body
            // (contains user PII).
            logDebug('Backend /users/me sync status: ${res.statusCode}');
          }
          final internalId = _internalUserId(res.data);
          if (internalId != null) {
            await Sentry.configureScope(
              (scope) => scope.setUser(
                SentryUser(
                  id: internalId,
                  data: {
                    'role': 'CLIENT',
                    if (firebaseUser?.uid != null) 'firebaseUid': firebaseUser!.uid,
                  },
                ),
              ),
            );
          }
          AnalyticsService.identify(internalId);
        } on ApiException catch (e) {
          if (kDebugMode) {
            logDebug('Backend sync error: ${e.kind}');
          }
        }
      } else {
        // Pas de token, l'utilisateur est déconnecté.
        // Purger le contexte Sentry au logout.
        await Sentry.configureScope((scope) => scope.setUser(null));
        // Délier le compte des envois suivants : sans cela, la session du
        // visiteur suivant sur ce téléphone resterait attribuée au précédent.
        // Il continue d'être suivi, sous l'identifiant d'installation anonyme
        // de Firebase.
        AnalyticsService.identify(null);
        if (kDebugMode) {
          logDebug('User signed out, no token available.');
        }
      }
    });
  }
}

/// Identifiant applicatif du client, extrait de `/users/me`.
///
/// Tolérant aux deux formes de réponse — `{ user: {...} }` d'origine et
/// `{ data: { user: {...} } }` d'`api-contract-v2` —, comme le fait
/// `UserRepository`. Rend `null` si la forme est inattendue : une mesure ne
/// doit jamais faire échouer une ouverture de session.
String? _internalUserId(dynamic decoded) {
  try {
    final unwrapped = ApiResponse.mapOf(decoded);
    final user = unwrapped['user'] ?? unwrapped;
    if (user is! Map) return null;
    final id = user['id'];
    return id is String && id.isNotEmpty ? id : null;
  } catch (_) {
    return null;
  }
}
