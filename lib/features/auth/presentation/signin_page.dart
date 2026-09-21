import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/constants/app_size.dart';
import 'package:lilia_app/routing/app_route_enum.dart';
import 'package:lilia_app/routing/auth_route_link.dart';

import 'package:lilia_app/features/auth/application/password_controller.dart';
import 'package:lilia_app/features/auth/application/sign_in_controller.dart';
import 'package:lilia_app/utils/snackbar.dart';
import 'package:lilia_app/features/auth/presentation/auth_screen_shell.dart';
import 'package:lilia_app/features/auth/presentation/phone_collection_sheet.dart';

/// Écran de connexion.
///
/// ⚠️ **Aucun `ref.listen` d'erreur ici.** Les messages d'échec
/// d'authentification sont affichés par `AuthFailureAnnouncerScope`, monté
/// au-dessus du routeur. Deux raisons :
///
/// 1. un `ref.listen` posé sur un écran meurt avec lui — c'est précisément ce
///    qui rendait invisible l'échec de `/users/sync` à l'inscription (B-02) ;
/// 2. cet écran interpolait `'${state.error}'`, ce qui affichait au client
///    `Exception: …` et `GoogleSignInException(code …canceled…)`.
class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScreenShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Header(),
          gapH32,
          const _SignInForm(),
          gapH24,
          const _OrDivider(),
          gapH24,
          const GoogleSignInButton(label: 'Se connecter avec Google'),
          gapH32,
          const _SignUpNavigation(),
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
      await ref
          .read(signInControllerProvider.notifier)
          .signInWithEmail(
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
    final etat = ref.watch(signInControllerProvider);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const Key('signin_email'),
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer votre email';
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                return 'Veuillez entrer un email valide';
              }
              return null;
            },
          ),
          gapH20,
          TextFormField(
            key: const Key('signin_password'),
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Mot de Passe',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                // Le libellé suit l'action que le bouton déclenche : il
                // annonçait « Masquer » y compris quand le mot de passe
                // l'était déjà.
                tooltip: _obscurePassword
                    ? 'Afficher le mot de passe'
                    : 'Masquer le mot de passe',
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: _togglePasswordVisibility,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer votre mot de passe';
              }
              return null;
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => showPasswordResetDialog(
                context,
                ref,
                emailInitial: _emailController.text.trim(),
              ),
              child: const Text('Mot de passe oublié ?'),
            ),
          ),
          gapH16,
          ElevatedButton(
            key: const Key('signin_submit'),
            // Grisé dès qu'une opération tourne — y compris celle du bouton
            // Google, qui appelle `disconnect()` et annulerait celle-ci.
            onPressed: etat.isLoading ? null : _signIn,
            child: etat.isRunning(AuthOperation.emailSignIn)
                ? const AuthButtonSpinner()
                : const Text('Se connecter'),
          ),
        ],
      ),
    );
  }
}

/// Demande l'adresse puis envoie le lien de réinitialisation.
///
/// Trois défauts corrigés d'un coup :
/// - le `TextEditingController` du dialogue n'était jamais `dispose()` ;
/// - l'échec s'affichait en `Erreur: ${e.toString()}`, soit
///   `[firebase_auth/user-not-found] There is no user record…` — en anglais ;
/// - le contrôleur posait l'erreur dans son état **et** la relançait, ce qui
///   produisait deux messages pour un seul échec.
Future<void> showPasswordResetDialog(
  BuildContext context,
  WidgetRef ref, {
  String emailInitial = '',
}) async {
  final controller = TextEditingController(text: emailInitial);
  try {
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Réinitialiser le mot de passe'),
        content: TextField(
          key: const Key('reset_email_field'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Entrez votre email'),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              final saisie = controller.text.trim();
              if (saisie.isNotEmpty) Navigator.of(dialogContext).pop(saisie);
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty) return;

    final echec = await ref
        .read(passwordControllerProvider.notifier)
        .sendPasswordResetEmailTo(email);

    if (!context.mounted) return;
    if (echec == null) {
      // Formulation neutre volontairement : confirmer l'envoi « à cette
      // adresse » révélerait qu'un compte y existe.
      context.showSuccessSnack(
        'Si un compte existe pour cette adresse, un e-mail vient d’être envoyé.',
      );
    } else {
      context.showErrorSnack(echec.message);
    }
  } finally {
    controller.dispose();
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
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

/// Bouton Google, partagé par la connexion et l'inscription.
///
/// Il existe en un seul exemplaire parce que les deux écrans en avaient chacun
/// une copie, et qu'elles avaient déjà divergé : celle de l'inscription ne
/// proposait pas la saisie du numéro de téléphone (M-02), si bien qu'un client
/// arrivé par « S'inscrire avec Google » n'en avait jamais.
///
/// Corrige aussi M-01 : la version précédente ne lisait aucun état, donc
/// n'affichait pas d'indicateur et laissait passer les doubles taps — deux
/// flux Google concurrents, dont chacun appelait `disconnect()`.
class GoogleSignInButton extends ConsumerWidget {
  const GoogleSignInButton({super.key, required this.label, this.referralCode});

  final String label;

  /// Transmis à la **création** du compte seulement. Saisi sur l'écran
  /// d'inscription, il doit suivre si le client choisit finalement Google.
  final String? Function()? referralCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final etat = ref.watch(signInControllerProvider);
    final enCours = etat.isRunning(AuthOperation.google);

    return OutlinedButton.icon(
      key: const Key('signin_google'),
      onPressed: etat.isLoading ? null : () => _connecter(context, ref),
      icon: enCours
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Image.asset('assets/images/google_logo.png', height: 24.0),
      label: Text(label, style: TextStyle(color: cs.onSurface)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.4)),
      ),
    );
  }

  Future<void> _connecter(BuildContext context, WidgetRef ref) async {
    final echec = await ref
        .read(signInControllerProvider.notifier)
        .signInWithGoogle(referralCode: referralCode?.call());

    // `null` = succès. Sur échec, le message est déjà annoncé ailleurs — y
    // compris « pas de message » quand le client a simplement annulé.
    if (echec != null || !context.mounted) return;

    // Le jeton Google ne porte pas toujours de numéro : on le demande une fois,
    // et seulement s'il manque. Le bottom-sheet est passable.
    await maybePromptPhoneNumber(context, ref);
  }
}

/// Indicateur dimensionné pour tenir dans un bouton sans le faire grandir.
///
/// Sa couleur vient du thème (`onPrimary`), jamais de `Colors.white` : en
/// thème sombre l'action est un orange clair sur lequel le blanc tombe à
/// 2,84:1.
class AuthButtonSpinner extends StatelessWidget {
  const AuthButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      width: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }
}

class _SignUpNavigation extends StatelessWidget {
  const _SignUpNavigation();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Vous n'avez pas de compte ?",
          style: TextStyle(color: cs.onSurface, fontSize: 14),
        ),
        TextButton(
          onPressed: () => goToAuthRoute(context, AppRoutes.signUp),
          child: Text(
            "S'inscrire",
            style: TextStyle(
              color: cs.primary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
