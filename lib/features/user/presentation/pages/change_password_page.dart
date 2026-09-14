import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/features/auth/application/password_controller.dart';
import 'package:lilia_app/features/auth/presentation/signin_page.dart'
    show AuthButtonSpinner;
import 'package:lilia_app/utils/snackbar.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Le chargement vient du contrôleur, plus d'un `bool` local : un `catch`
  /// qui oubliait son `finally` laissait le bouton désactivé pour toujours.
  ///
  /// L'échec est **rendu**, pas relancé : `PasswordController` traduit la
  /// `FirebaseAuthException` en message français. L'écran affichait auparavant
  /// `Erreur: ${e.toString()}`, c'est-à-dire
  /// `[firebase_auth/weak-password] Password should be at least 6 characters`.
  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final echec = await ref
        .read(passwordControllerProvider.notifier)
        .updatePassword(_newPasswordController.text);

    if (!mounted) return;
    if (echec != null) {
      context.showErrorSnack(echec.message);
      return;
    }
    context.showSuccessSnack('Mot de passe mis à jour.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final enCours = ref.watch(passwordControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Changer le mot de passe')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _newPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Nouveau mot de passe',
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty || value.length < 6) {
                    return 'Le mot de passe doit contenir au moins 6 caractères.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirmer le nouveau mot de passe',
                ),
                obscureText: true,
                validator: (value) {
                  if (value != _newPasswordController.text) {
                    return 'Les mots de passe ne correspondent pas.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                key: const Key('change_password_submit'),
                onPressed: enCours ? null : _changePassword,
                child: enCours
                    ? const AuthButtonSpinner()
                    : const Text('Changer le mot de passe'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
