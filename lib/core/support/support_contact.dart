import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:lilia_app/core/log.dart';
import 'package:lilia_app/utils/snackbar.dart';

/// Coordonnées du support client, en **un seul endroit**.
///
/// - `contact@liliafood.com` : adresse publiée par les CGU et la politique de
///   confidentialité du site (`lilia-food-web/apps/web/content/legal`).
/// - Le numéro était déjà affiché par la page « À propos » ; il n'est publié
///   nulle part ailleurs (à confirmer côté exploitation, voir le tracker
///   Phase 3, P3-06).
class SupportContact {
  SupportContact._();

  static const email = 'contact@liliafood.com';
  static const phoneDisplay = '+242 06 745 46 10';
  static const phoneE164 = '+242067454610';

  /// `mailto:` avec un objet, et la référence de commande quand il y en a une
  /// — le support n'a plus à la demander.
  static Uri emailUri({String? orderReference}) => Uri(
    scheme: 'mailto',
    path: email,
    query: _encode({
      'subject': orderReference == null
          ? 'Lilia Food — demande d\'aide'
          : 'Lilia Food — commande $orderReference',
    }),
  );

  static Uri phoneUri() => Uri(scheme: 'tel', path: phoneE164);

  // `Uri(queryParameters:)` encode les espaces en `+`, que certains clients
  // mail affichent tels quels dans l'objet.
  static String _encode(Map<String, String> params) => params.entries
      .map(
        (e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
      )
      .join('&');
}

/// Ouvre une URI externe (`tel:`, `mailto:`), injectable pour les tests.
typedef ExternalLauncher = Future<bool> Function(Uri uri);

Future<bool> _defaultLauncher(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Ouvre l'application de téléphone ou de messagerie ; en cas d'échec (aucune
/// application, simulateur, refus), **copie la coordonnée** et le dit.
///
/// Pas de `canLaunchUrl` : sous Android 11+ il répond `false` sans
/// déclaration `<queries>` et le bouton paraît mort (voir `AndroidManifest`).
/// On tente l'ouverture et on traite l'échec.
Future<void> openSupportChannel(
  BuildContext context,
  Uri uri, {
  required String fallbackValue,
  ExternalLauncher launcher = _defaultLauncher,
}) async {
  var ok = false;
  try {
    ok = await launcher(uri);
  } catch (e) {
    logDebug('Support : ouverture de $uri impossible : $e');
  }
  if (ok || !context.mounted) return;
  await Clipboard.setData(ClipboardData(text: fallbackValue));
  if (!context.mounted) return;
  context.showSnack(
    'Impossible d\'ouvrir l\'application. $fallbackValue a été copié.',
    duration: const Duration(seconds: 5),
  );
}
