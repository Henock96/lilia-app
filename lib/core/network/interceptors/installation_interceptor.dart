import 'package:dio/dio.dart';

import '../../device/installation_id.dart';

/// Pose l'identifiant d'installation sur chaque requête sortante.
///
/// ## Pourquoi un interceptor et pas un en-tête statique
///
/// L'identifiant se lit dans les préférences locales, donc de façon
/// **asynchrone**. Il ne peut pas figurer dans les `BaseOptions.headers`, qui
/// sont construits au démarrage de l'application, avant que le stockage local
/// ne soit disponible. La première requête partirait sans, et ce serait
/// précisément `POST /users/sync` — celle qui compte.
///
/// ## Jamais bloquant
///
/// Si le stockage local est indisponible, l'en-tête est simplement omis. Le
/// serveur traite un signal absent comme absent : il ne refuse rien. Faire
/// échouer une requête parce qu'un signal anti-abus n'a pas pu être posé
/// reviendrait à empêcher un client de commander pour protéger un programme de
/// fidélité.
class InstallationInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final id = await InstallationId.get();
    if (id != null) {
      options.headers['X-Lilia-Installation-Id'] = id;
      options.headers['X-Lilia-Platform'] = InstallationId.platform;
    }
    handler.next(options);
  }
}
