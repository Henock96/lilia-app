import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/routing/app_route_enum.dart';

import '../controller/auth_controller.dart';



class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  //Fonction pour basculer la visibilité du mot de passe
  void _toogglePasswordVisibility(){
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  BuildContext? _progressIndicatorContext;
  // add dispose methode to the state of the widget
  @override
  void dispose() {
    // dispose controllers
    _emailController.dispose();
    _passwordController.dispose();

    // close loading dialog when closing page
    if (_progressIndicatorContext != null &&
        _progressIndicatorContext!.mounted) {
      Navigator.of(_progressIndicatorContext!).pop();
      _progressIndicatorContext = null;
    }
    super.dispose();
  }

  Future<void> _signIn() async {
    final auth = ref.read(authControllerProvider.notifier);

    await auth.sigInInUserWithEmailAndPassword(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (prev, state) async {
      if (state.isLoading) {
        await showDialog(
          context: context,
          builder: (ctx) {
            _progressIndicatorContext = ctx;
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
        );
        return;
      }// close circular progress indicator after rebuild to guarantee that the
      // context is still valid
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        if (_progressIndicatorContext != null &&
            _progressIndicatorContext!.mounted) {
          Navigator.of(_progressIndicatorContext!).pop();
          _progressIndicatorContext = null;
        }
      });

      if (state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Erreur: ${state.error}'),
          ),
        );
      }
    });
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Bienvenue sur Lilia App',
              style: TextStyle(fontSize: 24),
            ),
            const Text('Connectez-vous à votre compte'),
            const SizedBox(
              height: 5,
            ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Email',
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Mot de Passe',
              ),
              obscureText: true,
            ),
            const SizedBox(
              height: 20,
            ),
            SizedBox(
              width: MediaQuery.sizeOf(context).width * 0.5,
              child: ElevatedButton(
                onPressed: _signIn,
                child: const Text('Se connecter'),
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Vous n'avez pas de compte ?"),
                const SizedBox(
                  width: 10,
                ),
                TextButton(
                  onPressed: () {
                    context.goNamed(AppRoutes.signUp.name);
                  },
                  child: const Text("S'inscrire"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}