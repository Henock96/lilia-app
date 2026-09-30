import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import 'package:lilia_app/core/support/support_contact.dart';
import 'package:lilia_app/features/user/presentation/pages/about_page.dart';
import 'package:lilia_app/routing/pending_destination.dart';

/// Onglet réservé aux comptes (« Commandes », « Profil ») tapé par un
/// visiteur (P3-18).
///
/// ## Ce qu'elle remplace
///
/// Le tap menait à la connexion **en plein écran, hors de la coque** : plus
/// de barre d'onglets, aucun mot sur ce que l'onglet contient, et — le
/// support et « À propos » vivant sous `/profile` — aucun moyen de joindre
/// l'assistance sans créer de compte.
///
/// ## Ce qu'elle ne change pas
///
/// La règle d'accès : `/commandes` et `/profile` restent réservés
/// (`protected_locations.dart`), le garde du routeur est intact, et la
/// connexion ramène sur l'onglet demandé (`from`). La coque affiche cette
/// invitation **à la place** de l'écran de l'onglet, sans y naviguer : aucun
/// écran authentifié n'est construit.
class GuestTabPrompt extends StatelessWidget {
  const GuestTabPrompt({
    super.key,
    required this.location,
    required this.title,
    required this.message,
    required this.icon,
    this.launcher,
  });

  final String location;
  final String title;
  final String message;
  final IconData icon;

  /// Injectable pour les tests ; `launchUrl` sinon.
  final ExternalLauncher? launcher;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Icon(icon, size: 56, color: cs.primary),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              key: const Key('guest_tab_sign_in'),
              onPressed: () => context.go(signInLocationFor(location)),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Se connecter ou créer un compte',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Besoin d\'aide ?',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Iconsax.sms, color: cs.onSurfaceVariant),
              title: const Text('Écrire au support'),
              subtitle: const Text(SupportContact.email),
              onTap: () => _open(
                context,
                SupportContact.emailUri(),
                SupportContact.email,
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Iconsax.call, color: cs.onSurfaceVariant),
              title: const Text('Appeler le support'),
              subtitle: const Text(SupportContact.phoneDisplay),
              onTap: () => _open(
                context,
                SupportContact.phoneUri(),
                SupportContact.phoneDisplay,
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Iconsax.info_circle, color: cs.onSurfaceVariant),
              title: const Text('À propos de Lilia Food'),
              trailing: const Icon(Icons.chevron_right),
              // `Navigator.push` et non la route `/profile/about` : elle est
              // sous `/profile`, donc réservée aux comptes par
              // `protected_locations`. La page est statique (version,
              // contacts) ; l'ouvrir ici n'expose rien.
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AboutPage(launcher: launcher),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, Uri uri, String fallback) {
    final l = launcher;
    return l == null
        ? openSupportChannel(context, uri, fallbackValue: fallback)
        : openSupportChannel(
            context,
            uri,
            fallbackValue: fallback,
            launcher: l,
          );
  }
}
