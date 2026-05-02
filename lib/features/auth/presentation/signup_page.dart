import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/constants/app_size.dart';

import '../../../routing/app_route_enum.dart';
import '../controller/auth_controller.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  BuildContext? _progressIndicatorContext;

  @override
  void dispose() {
    if (_progressIndicatorContext != null && _progressIndicatorContext!.mounted) {
      Navigator.of(_progressIndicatorContext!).pop();
      _progressIndicatorContext = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (prev, state) async {
      if (state.isLoading) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            _progressIndicatorContext = ctx;
            return const Center(child: CircularProgressIndicator());
          },
        );
        return;
      }
      if (_progressIndicatorContext != null && _progressIndicatorContext!.mounted) {
        Navigator.of(_progressIndicatorContext!).pop();
        _progressIndicatorContext = null;
      }
      if (state.hasError && !state.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${state.error}'), backgroundColor: Colors.red),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: Sizes.p24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(),
              gapH32,
              _SignUpForm(),
              gapH12,
              _OrDivider(),
              gapH12,
              _SocialLogins(),
              gapH12,
              _SignInNavigation(),
            ],
          ),
        ),
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
        gapH64,
        Icon(Icons.fastfood, size: 80, color: theme.colorScheme.primary),
        gapH16,
        Text('Rejoignez Lilia Food', textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        gapH8,
        Text('Creez votre compte en quelques etapes', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
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
      await ref.read(authControllerProvider.notifier).createUserWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
        _phoneController.text.trim(),
        referralCode: _referralController.text.trim().isEmpty ? null : _referralController.text.trim().toUpperCase(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nom complet', prefixIcon: Icon(Icons.person_outline)),
            validator: (v) => (v == null || v.isEmpty) ? 'Veuillez entrer votre nom' : null,
          ),
          gapH12,
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: 'Numero de telephone', prefixIcon: Icon(Icons.phone_outlined)),
            keyboardType: TextInputType.phone,
            validator: (v) => (v == null || v.isEmpty) ? 'Veuillez entrer votre numero' : null,
          ),
          gapH12,
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Veuillez entrer votre email';
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) return 'Email invalide';
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
                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Veuillez entrer un mot de passe';
              if (v.length < 6) return 'Au moins 6 caracteres';
              return null;
            },
          ),
          gapH12,
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirmer le mot de passe', prefixIcon: Icon(Icons.lock_outline)),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirmez votre mot de passe';
              if (v != _passwordController.text) return 'Les mots de passe ne correspondent pas';
              return null;
            },
          ),
          gapH12,
          // Code de parrainage (optionnel)
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.card_giftcard, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _referralController,
                    decoration: InputDecoration(
                      labelText: 'Code de parrainage (optionnel)',
                      border: InputBorder.none,
                      labelStyle: TextStyle(color: theme.colorScheme.primary.withValues(alpha: 0.7)),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('+200 pts', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                ),
              ],
            ),
          ),
          gapH32,
          ElevatedButton(
            onPressed: state.isLoading ? null : _signUp,
            child: state.isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
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
          child: Text('OU', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _SocialLogins extends ConsumerWidget {
  const _SocialLogins();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () async {
        await ref.read(authControllerProvider.notifier).signInWithGoogle();
      },
      icon: Image.asset('assets/images/google_logo.png', height: 24.0),
      label: const Text("S'inscrire avec Google", style: TextStyle(color: Colors.black87)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        side: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}

class _SignInNavigation extends StatelessWidget {
  const _SignInNavigation();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Vous avez deja un compte ?', style: TextStyle(color: Colors.black87, fontSize: 14)),
        TextButton(
          onPressed: () => context.goNamed(AppRoutes.signIn.routeName),
          child: const Text("Se connecter", style: TextStyle(color: Colors.black87, fontSize: 12)),
        ),
      ],
    );
  }
}
