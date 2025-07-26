import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/features/auth/controller/auth_controller.dart';
import 'package:lilia_app/features/user/application/profile_controller.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pré-remplir les champs avec les données de l'utilisateur actuel
    final user = ref.read(userProfileProvider).value;
    if (user != null) {
      _nameController.text = user.nom ?? '';
      //_addressController.text = user.adresse!.rue ?? '';
      _phoneController.text = user.phone ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    //_addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final success = await ref.read(profileControllerProvider.notifier).updateUser({
        'nom': _nameController.text,
        //'adresses': _addressController.text,
        'phone': _phoneController.text,
      });

      if (!mounted) return; // Vérifie si le widget est toujours monté

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour avec succès!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // Retourne à la page précédente
      } else {
        // En cas d'erreur, affiche le message d'erreur du provider
        final error = ref.read(profileControllerProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour: ${error ?? "Une erreur inconnue est survenue."}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final user = ref.watch(authControllerProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le Profil'),
      ),
      body: user == null
          ? const Center(child: Text("Utilisateur non trouvé."))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom complet',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer votre nom';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Numéro de téléphone',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: profileState.isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: profileState.isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Enregistrer les modifications'),
                      ),
                    ),
                     if (profileState.hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Erreur: ${profileState.error}',
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
