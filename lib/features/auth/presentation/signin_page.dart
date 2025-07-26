import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/constants/app_size.dart';
import 'package:lilia_app/routing/app_route_enum.dart';

import '../controller/auth_controller.dart';

class SignInPage extends ConsumerWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authControllerProvider, (prev, state) {
      if (state.hasError && !state.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${state.error}'),
            backgroundColor: Colors.red,
          ),
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
              const _Header(),
              gapH32,
              const _SignInForm(),
              gapH24,
              const _OrDivider(),
              gapH24,
              const _SocialLogins(),
              gapH32,
              const _SignUpNavigation(),
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
        Icon(
          Icons.fastfood,
          size: 80,
          color: theme.colorScheme.primary,
        ),
        gapH16,
        Text(
          'Bienvenue sur Lilia Food',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        gapH8,
        Text(
          'Connectez-vous à votre compte',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _SignInForm extends ConsumerStatefulWidget {
  const _SignInForm();

  @override
  ConsumerState<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends ConsumerState<_SignInForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      await ref.read(authControllerProvider.notifier).sigInInUserWithEmailAndPassword(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(

            controller: _emailController,
            decoration: InputDecoration(
              errorStyle: TextStyle(color: Theme.of(context).textTheme.titleLarge!.color),
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Veuillez entrer votre email';
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'Veuillez entrer un email valide';
              return null;
            },
          ),
          gapH20,
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Mot de Passe',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: _togglePasswordVisibility,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Veuillez entrer votre mot de passe';
              return null;
            },
          ),
          gapH32,
          ElevatedButton(
            onPressed: state.isLoading ? null : _signIn,
            child: state.isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : const Text('Se connecter'),
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

class _SocialLogins extends ConsumerWidget {
  const _SocialLogins();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () async {
        await ref.read(authControllerProvider.notifier).signInWithGoogle();
      },
      icon: Image.asset('assets/images/google_logo.png', height: 24.0), // Assurez-vous d'avoir ce logo
      label: const Text('Se connecter avec Google', style: TextStyle(color: Colors.black87),),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        side: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}

class _SignUpNavigation extends StatelessWidget {
  const _SignUpNavigation();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Vous n'avez pas de compte ?",
          style: theme.textTheme.bodyLarge,
        ),
        TextButton(
          onPressed: () => context.goNamed(AppRoutes.signUp.routeName),
          child: const Text("S'inscrire",style: TextStyle(color: Colors.black87, fontSize: 15),),
        ),
      ],
    );
  }
}
