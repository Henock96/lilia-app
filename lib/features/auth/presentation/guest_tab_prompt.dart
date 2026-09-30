import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import 'package:lilia_app/common_widgets/photo_hero_sheet.dart';
import 'package:lilia_app/core/support/support_contact.dart';
import 'package:lilia_app/features/user/presentation/pages/about_page.dart';
import 'package:lilia_app/routing/pending_destination.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';

/// Un bénéfice **réel** d'un compte : chaque ligne doit correspondre à une
/// fonctionnalité présente dans l'application (voir `_invitationPour`).
class GuestBenefit {
  const GuestBenefit(this.icon, this.text);

  final IconData icon;
  final String text;
}

/// Onglet réservé aux comptes (« Commandes », « Profil ») tapé par un
/// visiteur (P3-18, enrichi par l'UI Refresh).
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
/// connexion **comme** l'inscription ramènent sur l'onglet demandé (`from`).
/// La coque affiche cette invitation **à la place** de l'écran de l'onglet,
/// sans y naviguer : aucun écran authentifié n'est construit.
class GuestTabPrompt extends StatelessWidget {
  const GuestTabPrompt({
    super.key,
    required this.location,
    required this.title,
    required this.message,
    required this.image,
    required this.benefits,
    this.imageAlignment = Alignment.center,
    this.launcher,
  });

  final String location;
  final String title;
  final String message;

  /// Photo décorative (`assets/onboarding/…`).
  final String image;
  final Alignment imageAlignment;
  final List<GuestBenefit> benefits;

  /// Injectable pour les tests ; `launchUrl` sinon.
  final ExternalLauncher? launcher;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: PhotoHeroSheet(
          image: image,
          alignment: imageAlignment,
          photoFraction: 0.32,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              LiliaSpacing.lg,
              LiliaSpacing.lg,
              LiliaSpacing.lg,
              LiliaSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: LiliaSpacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  // Inter pour les phrases, Oswald (condensé) pour les titres.
                  style: GoogleFonts.inter(
                    textStyle: theme.textTheme.bodyLarge,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: LiliaSpacing.lg),
                for (final b in benefits)
                  Padding(
                    padding: const EdgeInsets.only(bottom: LiliaSpacing.sm + 4),
                    child: Row(
                      children: [
                        Icon(b.icon, size: 22, color: cs.primary),
                        const SizedBox(width: LiliaSpacing.sm + 4),
                        Expanded(
                          child: Text(
                            b.text,
                            style: GoogleFonts.inter(
                              textStyle: theme.textTheme.bodyLarge,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: LiliaSpacing.md),
                ElevatedButton(
                  key: const Key('guest_tab_sign_in'),
                  onPressed: () => context.go(signInLocationFor(location)),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Se connecter'),
                ),
                const SizedBox(height: LiliaSpacing.sm + 4),
                OutlinedButton(
                  key: const Key('guest_tab_sign_up'),
                  onPressed: () => context.go(signUpLocationFor(location)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Créer un compte'),
                ),
                const SizedBox(height: LiliaSpacing.xl),
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
                  leading: Icon(
                    Iconsax.info_circle,
                    color: cs.onSurfaceVariant,
                  ),
                  title: const Text('À propos de Lilia Food'),
                  trailing: const Icon(Icons.chevron_right),
                  // `Navigator.push` et non la route `/profile/about` : elle
                  // est sous `/profile`, donc réservée aux comptes par
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
