import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/routing/app_route_enum.dart';

class OrderSuccessPage extends ConsumerStatefulWidget {
  const OrderSuccessPage({super.key});

  @override
  ConsumerState<OrderSuccessPage> createState() => _OrderSuccessPageState();
}

class _OrderSuccessPageState extends ConsumerState<OrderSuccessPage> {
  @override
  void initState() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref.read(cartControllerProvider.notifier).clearCart();
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: cs.primary,
                  size: 100,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Commande passée avec succès !',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Merci pour votre confiance. Vous pouvez suivre l\'état de votre commande dans la section "Mes Commandes".',
                  style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: () {
                    context.goNamed(AppRoutes.commandes.routeName);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Voir mes commandes',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    context.goNamed(AppRoutes.home.routeName);
                  },
                  child: Text(
                    'Retour à l\'écran d\'accueil',
                    style: TextStyle(color: cs.primary, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
