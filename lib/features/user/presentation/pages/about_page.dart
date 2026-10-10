import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:lilia_app/core/support/legal_links.dart';
import 'package:lilia_app/core/support/support_contact.dart';

/// Version **du binaire installé**, lue par `package_info_plus`.
///
/// Elle était codée en dur (`'1.3.3'`) quand le `pubspec` disait `1.3.5+39` :
/// le support ne savait pas quelle version le client utilisait (P3-08).
String aboutVersionLabel(PackageInfo info) => info.buildNumber.isEmpty
    ? 'Version ${info.version}'
    : 'Version ${info.version} (${info.buildNumber})';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key, this.launcher});

  /// Injectable pour les tests ; `launchUrl` sinon.
  final ExternalLauncher? launcher;

  static const String _appName = 'Lilia Food';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('À propos'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Header avec logo et version
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        Iconsax.shop,
                        size: 50,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _appName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snap) => Text(
                        snap.hasData ? aboutVersionLabel(snap.data!) : ' ',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Commandez vos plats préférés auprès des meilleurs restaurants près de chez vous.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Section Informations légales
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  children: [
                    _AboutMenuItem(
                      icon: Iconsax.document_text,
                      iconColor: Colors.blue[400]!,
                      title: "Conditions d'utilisation",
                      // C-10 : la version publiée, pas une copie embarquée.
                      onTap: () => _open(
                        context,
                        LegalLinks.termsOfUse,
                        LegalLinks.termsOfUse.toString(),
                      ),
                      showTopBorder: false,
                    ),
                    _AboutMenuItem(
                      icon: Iconsax.shield_tick,
                      iconColor: Colors.green[400]!,
                      title: 'Politique de confidentialité',
                      onTap: () => _open(
                        context,
                        LegalLinks.privacyPolicy,
                        LegalLinks.privacyPolicy.toString(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Section Contact
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  children: [
                    _AboutMenuItem(
                      icon: Iconsax.sms,
                      iconColor: Colors.orange[400]!,
                      title: 'Nous contacter',
                      subtitle: SupportContact.email,
                      semanticHint: 'Écrire un e-mail au support',
                      onTap: () => _open(
                        context,
                        SupportContact.emailUri(),
                        SupportContact.email,
                      ),
                      showTopBorder: false,
                    ),
                    _AboutMenuItem(
                      icon: Iconsax.call,
                      iconColor: Colors.teal[400]!,
                      title: 'Assistance téléphonique',
                      subtitle: SupportContact.phoneDisplay,
                      semanticHint: 'Appeler le support',
                      onTap: () => _open(
                        context,
                        SupportContact.phoneUri(),
                        SupportContact.phoneDisplay,
                      ),
                      showBottomBorder: false,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Footer
              Text(
                '© 2026 $_appName. Tous droits réservés.',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Fait avec amour par DreesisLab',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              // Attribution exigée par la licence du plan Free OpenWeather
              // (ODbL), en plus du panneau météo de l'accueil.
              TextButton(
                onPressed: () => _open(
                  context,
                  Uri.parse('https://openweathermap.org/'),
                  'https://openweathermap.org/',
                ),
                child: const Text(
                  'Weather data provided by OpenWeather',
                  style: TextStyle(fontSize: 12),
                ),
              ),

              const SizedBox(height: 24),
            ],
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

class _AboutMenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? semanticHint;
  final VoidCallback onTap;
  final bool showTopBorder;
  final bool showBottomBorder;

  const _AboutMenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.semanticHint,
    this.showTopBorder = true,
    this.showBottomBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      hint: semanticHint,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: showBottomBorder
                ? Border(
                    bottom: BorderSide(
                      color: cs.outline.withValues(alpha: 0.2),
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        // `onSurfaceVariant` : `grey[500]` = 2,6:1 sur blanc.
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Iconsax.arrow_right_3, color: cs.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
