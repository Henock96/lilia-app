import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:lilia_app/features/auth/controller/auth_controller.dart';
import 'package:lilia_app/features/user/application/profile_controller.dart';
import 'package:lilia_app/features/user/edit_profile_page.dart';

import '../../common_widgets/build_error_state.dart';

class UserPage extends ConsumerWidget {
  const UserPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Profil', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: userState.when(
        data: (user) {
          if (user == null) {
            return const Center(
              child: Text('Utilisateur non connecté. Veuillez vous connecter.'),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(userProfileProvider.future),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      ref.read(profileControllerProvider.notifier).updateProfilePicture();
                    },
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: user.imageUrl != null ? NetworkImage(user.imageUrl!) : null,
                          child: user.imageUrl == null ? const Icon(Iconsax.user, size: 50) : null,
                        ),
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.black87,
                          child: Icon(Icons.add_a_photo, color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    user.nom ?? 'Nom',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.email ?? 'Email non disponible',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 32),
                  ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: const Text('Ajouter une adresse de livraison'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('Modifier vos informations'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfilePage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.password),
                    title: const Text("Changer votre mot de passe"),
                  ),
                  const Spacer(),
                  ListTile(
                    title: const Text("A propos de Lilia Food"),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text('Se déconnecter'),
                      onPressed: () async {
                        await ref.read(authControllerProvider.notifier).signOut();
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => BuildErrorState(error),
      ),
    );
  }
}
