import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const String _appVersion = '1.0.13';
  static const String _appName = 'Lilia Food';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'À propos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                    Text(
                      'Version $_appVersion',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Commandez vos plats préférés auprès des meilleurs restaurants près de chez vous.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _AboutMenuItem(
                      icon: Iconsax.document_text,
                      iconColor: Colors.blue[400]!,
                      title: "Conditions d'utilisation",
                      onTap: () => _showTextPage(
                        context,
                        title: "Conditions d'utilisation",
                        content: _termsOfUse,
                      ),
                      showTopBorder: false,
                    ),
                    _AboutMenuItem(
                      icon: Iconsax.shield_tick,
                      iconColor: Colors.green[400]!,
                      title: 'Politique de confidentialité',
                      onTap: () => _showTextPage(
                        context,
                        title: 'Politique de confidentialité',
                        content: _privacyPolicy,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Section Contact
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _AboutMenuItem(
                      icon: Iconsax.sms,
                      iconColor: Colors.orange[400]!,
                      title: 'Nous contacter',
                      subtitle: 'contact@liliafood.com',
                      onTap: () {},
                      showTopBorder: false,
                    ),
                    _AboutMenuItem(
                      icon: Iconsax.call,
                      iconColor: Colors.teal[400]!,
                      title: 'Assistance téléphonique',
                      subtitle: '+242 06 745 46 10',
                      onTap: () {},
                      showBottomBorder: false,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Footer
              Text(
                '© 2025 $_appName. Tous droits réservés.',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
              const SizedBox(height: 4),
              Text(
                'Fait avec amour au Congo',
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showTextPage(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _TextDetailPage(title: title, content: content),
      ),
    );
  }
}

// Textes légaux
const String _termsOfUse = '''
Bienvenue sur Lilia Food. En utilisant notre application, vous acceptez les présentes conditions d'utilisation.

1. Objet du service
Lilia Food est une plateforme de commande et de livraison de repas qui met en relation les clients avec les restaurants partenaires.

2. Inscription et compte
Pour utiliser nos services, vous devez créer un compte en fournissant des informations exactes et à jour. Vous êtes responsable de la confidentialité de vos identifiants de connexion.

3. Commandes
Toute commande passée via l'application constitue un engagement d'achat. Les prix affichés incluent les taxes applicables. Les frais de livraison sont indiqués avant la validation de la commande.

4. Paiement
Le paiement s'effectue via les moyens de paiement proposés dans l'application (Mobile Money). Le paiement est dû au moment de la validation de la commande.

5. Livraison
Les délais de livraison sont donnés à titre indicatif. Lilia Food s'efforce de respecter les délais annoncés mais ne peut être tenue responsable des retards indépendants de sa volonté.

6. Annulation
Une commande peut être annulée tant qu'elle n'a pas été confirmée par le restaurant. Au-delà, aucune annulation ne sera possible.

7. Responsabilité
Lilia Food agit en tant qu'intermédiaire entre les clients et les restaurants. La qualité des produits relève de la responsabilité des restaurants partenaires.

8. Données personnelles
Vos données personnelles sont traitées conformément à notre politique de confidentialité.

9. Modification des conditions
Lilia Food se réserve le droit de modifier les présentes conditions à tout moment. Les utilisateurs seront informés de toute modification.

10. Contact
Pour toute question relative aux présentes conditions, vous pouvez nous contacter à contact@liliafood.com.
''';

const String _privacyPolicy = '''
Lilia Food s'engage à protéger la vie privée de ses utilisateurs. Cette politique décrit comment nous collectons, utilisons et protégeons vos données personnelles.

1. Données collectées
Nous collectons les données suivantes :
- Informations d'inscription : nom, adresse email, numéro de téléphone
- Adresses de livraison
- Historique des commandes
- Données de paiement (traitées de manière sécurisée)
- Données de localisation (avec votre consentement)

2. Utilisation des données
Vos données sont utilisées pour :
- Traiter et livrer vos commandes
- Gérer votre compte utilisateur
- Vous envoyer des notifications sur vos commandes
- Améliorer nos services
- Vous proposer des offres personnalisées

3. Partage des données
Vos données peuvent être partagées avec :
- Les restaurants partenaires (pour le traitement des commandes)
- Les livreurs (pour la livraison)
- Les prestataires de paiement (pour le traitement des transactions)

Nous ne vendons jamais vos données personnelles à des tiers.

4. Sécurité
Nous mettons en œuvre des mesures de sécurité appropriées pour protéger vos données contre tout accès non autorisé, modification ou destruction.

5. Conservation
Vos données sont conservées aussi longtemps que votre compte est actif. Vous pouvez demander la suppression de vos données à tout moment.

6. Vos droits
Vous disposez des droits suivants :
- Accéder à vos données personnelles
- Rectifier vos données
- Supprimer votre compte et vos données
- Retirer votre consentement

7. Notifications push
Nous utilisons Firebase Cloud Messaging pour vous envoyer des notifications relatives à vos commandes et aux nouveaux menus. Vous pouvez désactiver les notifications dans les paramètres de votre appareil.

8. Contact
Pour toute question relative à vos données personnelles, contactez-nous à contact@liliafood.com.
''';

class _TextDetailPage extends StatelessWidget {
  final String title;
  final String content;

  const _TextDetailPage({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutMenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool showTopBorder;
  final bool showBottomBorder;

  const _AboutMenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.showTopBorder = true,
    this.showBottomBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: showBottomBorder
              ? Border(bottom: BorderSide(color: Colors.grey[200]!))
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
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Iconsax.arrow_right_3, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }
}
