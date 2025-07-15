import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/common_widgets/primary_button.dart';
import 'package:lilia_app/constants/app_size.dart';
import 'package:lilia_app/routing/app_route_enum.dart';
/// Placeholder widget showing a message and CTA to go back to the home screen.
class EmptyPlaceholderWidget extends StatelessWidget {
  const EmptyPlaceholderWidget({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Sizes.p16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              message,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            gapH32,
            PrimaryButton(
              onPressed: () => context.goNamed(AppRoutes.home.routeName),
              text: "Aller à la page d'accueil",
            )
          ],
        ),
      ),
    );
  }
}