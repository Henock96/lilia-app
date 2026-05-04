import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:lilia_app/features/auth/controller/auth_controller.dart';
import 'package:lilia_app/features/user/application/profile_controller.dart';
import 'package:lilia_app/features/user/edit_profile_page.dart';
import 'package:lilia_app/routing/app_route_enum.dart';

import '../../common_widgets/build_error_state.dart';
import 'presentation/pages/about_page.dart';

class UserPage extends ConsumerWidget {
  const UserPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProfileProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Mon Profil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: userState.when(
        data: (user) {
          return SafeArea(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(userProfileProvider.future),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Section Profil Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
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
                            GestureDetector(
                              onTap: () {
                                ref
                                    .read(profileControllerProvider.notifier)
                                    .updateProfilePicture();
                              },
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.2),
                                        width: 4,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 55,
                                      backgroundColor: Colors.grey[200],
                                      backgroundImage: user.imageUrl != null
                                          ? NetworkImage(user.imageUrl!)
                                          : null,
                                      child: user.imageUrl == null
                                          ? Icon(
                                              Iconsax.user,
                                              size: 50,
                                              color: Colors.grey[400],
                                            )
                                          : null,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                    ),
                                    child: const Icon(
                                      Iconsax.camera,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              user.nom ?? 'Nom',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Iconsax.sms,
                                  size: 16,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  user.email ?? 'Email non disponible',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Carte Points de fidélité
                      _LoyaltyCard(ref: ref),

                      const SizedBox(height: 16),

                      // Carte Parrainage
                      _ReferralCard(ref: ref),

                      const SizedBox(height: 20),

                      // Section Menu Principal
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
                            _ProfileMenuItem(
                              icon: Iconsax.heart,
                              iconColor: Colors.red[400]!,
                              title: 'Mes Favoris',
                              subtitle: 'Vos restaurants préférés',
                              onTap: () =>
                                  context.goNamed(AppRoutes.favoris.routeName),
                              showTopBorder: false,
                            ),
                            _ProfileMenuItem(
                              icon: Iconsax.document_text,
                              iconColor: Colors.amber[700]!,
                              title: 'Commandes en attente',
                              subtitle: 'Commandes enregistrees pour plus tard',
                              onTap: () => context.goNamed(
                                AppRoutes.draftOrders.routeName,
                              ),
                            ),
                            _ProfileMenuItem(
                              icon: Iconsax.location,
                              iconColor: Colors.blue[400]!,
                              title: 'Adresses de livraison',
                              subtitle: 'Gérer vos adresses',
                              onTap: () =>
                                  context.goNamed(AppRoutes.address.routeName),
                            ),
                            _ProfileMenuItem(
                              icon: Iconsax.user_edit,
                              iconColor: Colors.orange[400]!,
                              title: 'Modifier le profil',
                              subtitle: 'Nom, téléphone',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const EditProfilePage(),
                                  ),
                                );
                              },
                            ),
                            _ProfileMenuItem(
                              icon: Iconsax.lock,
                              iconColor: Colors.purple[400]!,
                              title: 'Mot de passe',
                              subtitle: 'Changer votre mot de passe',
                              onTap: () => context.goNamed(
                                AppRoutes.changePassword.routeName,
                              ),
                              showBottomBorder: false,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Section Informations
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
                        child: _ProfileMenuItem(
                          icon: Iconsax.info_circle,
                          iconColor: Colors.teal[400]!,
                          title: 'À propos de Lilia Food',
                          subtitle: 'Version, conditions d\'utilisation',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AboutPage(),
                              ),
                            );
                          },
                          showTopBorder: false,
                          showBottomBorder: false,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Bouton Déconnexion
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            _showLogoutConfirmationDialog(context, ref);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Iconsax.logout,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Se déconnecter',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => BuildErrorState(
          error,
          onRetry: () => ref.invalidate(userProfileProvider),
        ),
      ),
    );
  }

  void _showLogoutConfirmationDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Iconsax.logout,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('Se déconnecter ?'),
            ],
          ),
          content: const Text(
            'Êtes-vous sûr de vouloir vous déconnecter de votre compte ?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Déconnecter'),
              onPressed: () async {
                Navigator.of(context).pop();
                await ref.read(authControllerProvider.notifier).signOut();
              },
            ),
          ],
        );
      },
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showTopBorder;
  final bool showBottomBorder;

  const _ProfileMenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
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
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
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

class _LoyaltyCard extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _LoyaltyCard({required this.ref});

  @override
  ConsumerState<_LoyaltyCard> createState() => _LoyaltyCardState();
}

class _LoyaltyCardState extends ConsumerState<_LoyaltyCard> {
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    final transactionsAsync = ref.watch(loyaltyTransactionsProvider);

    return userAsync.when(
      data: (user) => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF8C00), Color(0xFFFFB347)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.stars, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Points de fidelite',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => setState(() => _showHistory = !_showHistory),
                  child: Text(
                    _showHistory ? 'Masquer' : 'Historique',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${user.loyaltyPoints}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'points',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      '= 1 pt par 100 FCFA',
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Valeur: ${(user.loyaltyPoints * 5)} FCFA de reduction (min. 100 pts)',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            if (_showHistory) ...[
              const SizedBox(height: 12),
              const Divider(color: Colors.white30),
              const SizedBox(height: 8),
              transactionsAsync.when(
                data: (transactions) => transactions.isEmpty
                    ? const Text(
                        'Aucune transaction',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      )
                    : Column(
                        children: transactions
                            .take(10)
                            .map(
                              (t) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        t.reason,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${t.points > 0 ? "+" : ""}${t.points} pts',
                                      style: TextStyle(
                                        color: t.points > 0
                                            ? Colors.white
                                            : Colors.white70,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                error: (_, _) => const Text(
                  'Erreur chargement',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ],
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _ReferralCard extends ConsumerWidget {
  final WidgetRef ref;
  const _ReferralCard({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(referralStatsProvider);

    return statsAsync.when(
      data: (stats) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.card_giftcard, color: Colors.purple, size: 22),
                SizedBox(width: 8),
                Text(
                  'Parrainage',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Mon code de parrainage',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: stats.referralCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Code copie !'),
                    backgroundColor: Colors.purple,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.purple.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      stats.referralCode,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: Colors.purple,
                      ),
                    ),
                    const Icon(Icons.copy, color: Colors.purple, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatBadge(
                  label: 'Parraines',
                  value: '${stats.totalReferrals}',
                ),
                const SizedBox(width: 12),
                _StatBadge(
                  label: 'Recompenses',
                  value: '${stats.rewardedReferrals}',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Parrainez un ami: +500 pts pour vous, +200 pts pour lui a sa 1ere commande',
                style: TextStyle(fontSize: 11, color: Colors.purple),
              ),
            ),
          ],
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  const _StatBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.purple,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
