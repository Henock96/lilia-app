import 'package:flutter/material.dart';
import 'package:lilia_app/constants/app_size.dart';

/// Primary button based on [ElevatedButton].
/// Useful for CTAs in the app.
/// @param text - text to display on the button.
/// @param isLoading - if true, a loading indicator will be displayed instead of
/// the text.
/// @param onPressed - callback to be called when the button is pressed.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.text,
    this.isLoading = false,
    this.onPressed,
  });
  final String text;
  final bool isLoading;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    // Hauteur MINIMALE (V-2, audit du 09/10/2026) : une hauteur fixe de 48
    // rognait verticalement un libellé en `titleLarge` (« Aller à la page
    // d'accueil » sur la 404), et davantage avec le texte agrandi.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: Sizes.p48),
      child: ElevatedButton(
        onPressed: onPressed,
        child: isLoading
            ? const CircularProgressIndicator()
            : Text(
                text,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge!.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
      ),
    );
  }
}
