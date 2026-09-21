import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `StateProvider` vit dans `legacy` depuis Riverpod 3 — même import que
// `notification_providers.dart`.
import 'package:flutter_riverpod/legacy.dart';
import 'package:lilia_app/constants/app_size.dart';

import '../../../routing/app_route_enum.dart';
import '../../../routing/auth_route_link.dart';
import '../application/sign_in_controller.dart';
import 'auth_screen_shell.dart';
import 'signin_page.dart' show AuthButtonSpinner, GoogleSignInButton;

/// Écran d'inscription.
///
/// ⚠️ **Plus aucun dialogue modal de chargement.** Il en existait un, ouvert
/// depuis un `ref.listen` et refermé via un `BuildContext` mémorisé dans un
/// champ (`_progressIndicatorContext`). Ce champ n'est affecté qu'au moment où
/// le `builder` du dialogue s'exécute — à la frame suivante. Un échec plus
/// rapide que cette frame trouvait donc `null` au moment de refermer, et le
/// dialogue `barrierDismissible: false` restait **définitivement** ouvert :
/// écran figé, application inutilisable jusqu'au redémarrage (B-03).
///
/// Le chargement est désormais porté par `signInControllerProvider`, comme sur
/// l'écran de connexion : un seul état, aucune branche ne peut le laisser
/// allumé.
class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScreenShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Header(),
          gapH32,
          const _SignUpForm(),
          gapH12,
          const _OrDivider(),
          gapH12,
          // Le code de parrainage saisi sur CET écran doit suivre si le
          // client choisit finalement Google — sinon un filleul perdait son
          // parrain en silence.
          GoogleSignInButton(
            label: "S'inscrire avec Google",
            referralCode: () => ProviderScope.containerOf(
              context,
              listen: false,
            ).read(signupReferralCodeProvider),
          ),
          gapH12,
          const _SignInNavigation(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // La flèche de retour occupe désormais le haut de l'écran : elle
        // remplace cette marge au lieu de s'y ajouter, sinon l'en-tête
        // descendrait et le dernier bouton sortirait de l'écran.
        gapH8,
        Icon(Icons.fastfood, size: 80, color: theme.colorScheme.primary),
        gapH16,
        Text(
          'Rejoignez Lilia Food',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        gapH8,
        Text(
          'Creez votre compte en quelques etapes',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _SignUpForm extends ConsumerStatefulWidget {
  const _SignUpForm();

  @override
  ConsumerState<_SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends ConsumerState<_SignUpForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _referralController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      await ref
          .read(signInControllerProvider.notifier)
          .signUpWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            referralCode: _referralController.text.trim().isEmpty
                ? null
                : _referralController.text.trim().toUpperCase(),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final etat = ref.watch(signInControllerProvider);
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nom complet',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Veuillez entrer votre nom' : null,
          ),
          gapH12,
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Numéro de téléphone',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.phone,
            validator: (v) => (v == null || v.isEmpty)
                ? 'Veuillez entrer votre numero'
                : null,
          ),
          gapH12,
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Veuillez entrer votre email';
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                return 'Email invalide';
              }
              return null;
            },
          ),
          gapH12,
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Mot de Passe',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: 'Masquer le mot de passe',
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Veuillez entrer un mot de passe';
              }
              if (v.length < 6) return 'Au moins 6 caracteres';
              return null;
            },
          ),
          gapH12,
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirmer le mot de passe',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirmez votre mot de passe';
              if (v != _passwordController.text) {
                return 'Les mots de passe ne correspondent pas';
              }
              return null;
            },
          ),
          gapH12,
          // Code de parrainage (optionnel)
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.card_giftcard,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _referralController,
                    // Publié à chaque frappe : le bouton Google est un widget
                    // frère, il ne voit pas ce contrôleur.
                    onChanged: (value) {
                      final code = value.trim().toUpperCase();
                      ref.read(signupReferralCodeProvider.notifier).state =
                          code.isEmpty ? null : code;
                    },
                    decoration: InputDecoration(
                      labelText: 'Code de parrainage (optionnel)',
                      border: InputBorder.none,
                      labelStyle: TextStyle(
                        color: theme.colorScheme.primary.withValues(alpha: 0.7),
                      ),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+200 pts',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          gapH32,
          ElevatedButton(
            key: const Key('signup_submit'),
            onPressed: etat.isLoading ? null : _signUp,
            child: etat.isRunning(AuthOperation.emailSignUp)
                ? const AuthButtonSpinner()
                : const Text("S'inscrire"),
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sizes.p8),
          child: Text(
            'OU',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

/// Code de parrainage saisi sur l'écran d'inscription.
///
/// Il vit dans un provider parce que **deux widgets frères** en ont besoin :
/// `_SignUpForm`, qui le saisit, et le bouton Google, qui doit le transmettre
/// si l'utilisateur choisit finalement Google. Sans ce partage, taper son code
/// puis cliquer « S'inscrire avec Google » perdait le parrain en silence.
final signupReferralCodeProvider = StateProvider<String?>((ref) => null);

class _SignInNavigation extends StatelessWidget {
  const _SignInNavigation();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Vous avez déjà un compte ?',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
          ),
        ),
        TextButton(
          onPressed: () => goToAuthRoute(context, AppRoutes.signIn),
          child: Text(
            "Se connecter",
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
