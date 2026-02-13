import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/common_widgets/build_loading_state.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/commandes/data/checkout_controller.dart';
import 'package:lilia_app/features/commandes/presentation/delivery_options_page.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_controller.dart';
import 'package:lilia_app/features/user/application/adresse_controller.dart';
import 'package:lilia_app/features/user/application/profile_controller.dart';
import 'package:lilia_app/routing/app_route_enum.dart';

import '../../../models/cart.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  final DeliveryOptions? deliveryOptions;

  const CheckoutPage({super.key, this.deliveryOptions});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Récupérer les options de livraison
    final options = widget.deliveryOptions;

    // Si pas d'options, rediriger vers la page de choix
    if (options == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.goNamed(AppRoutes.deliveryOptions.routeName);
      });
      return const Scaffold(body: BuildLoadingState());
    }

    final cartAsync = ref.watch(cartControllerProvider);
    final checkoutState = ref.watch(checkoutControllerProvider);
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.goNamed(AppRoutes.deliveryOptions.routeName),
        ),
        title: const Text(
          'Confirmer la commande',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: cartAsync.when(
        data: (cart) {
          if (cart == null || cart.items.isEmpty) {
            return const Center(child: Text('Votre panier est vide'));
          }

          final double subTotal = cart.totalPrice;
          final double deliveryFee = options.deliveryFee;
          final double total = subTotal + deliveryFee;
          final String restaurantId = cart.items.first.product.restaurantId;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // === RÉCAPITULATIF MODE DE LIVRAISON ===
                  _buildDeliveryRecap(options),
                  const SizedBox(height: 24),

                  // === SECTION TÉLÉPHONE ===
                  _buildSectionTitle('Numero de telephone'),
                  const SizedBox(height: 8),
                  userProfileAsync.when(
                    data: (user) => _buildPhoneSection(user.phone),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => _buildPhoneSection(null),
                  ),
                  const SizedBox(height: 24),

                  // === SECTION INSTRUCTIONS ===
                  _buildSectionTitle('Instructions (Facultatif)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _noteController,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: InputDecoration(
                      hintText: 'Ex: Sonnez a la porte, appelez-moi...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // === SECTION RÉSUMÉ ===
                  _buildSectionTitle('Resume de la commande'),
                  const SizedBox(height: 12),
                  _buildOrderSummary(cart, subTotal, deliveryFee, total, options),
                  const SizedBox(height: 24),

                  // === SECTION PAIEMENT ===
                  _buildSectionTitle('Mode de paiement'),
                  const SizedBox(height: 8),
                  _buildPaymentSection(),
                  const SizedBox(height: 32),

                  // === BOUTON DE VALIDATION ===
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: checkoutState.isLoading
                          ? null
                          : () => _showPaymentInstructions(context, total, options, restaurantId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: checkoutState.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Valider et payer',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const BuildLoadingState(),
        error: (err, stack) => BuildErrorState(
          err,
          onRetry: () => ref.invalidate(cartControllerProvider),
        ),
      ),
    );
  }

  Widget _buildDeliveryRecap(DeliveryOptions options) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: options.isDelivery
            ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
            : Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: options.isDelivery
              ? Theme.of(context).primaryColor.withValues(alpha: 0.3)
              : Colors.green.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              options.isDelivery ? Icons.delivery_dining : Icons.store,
              color: options.isDelivery
                  ? Theme.of(context).primaryColor
                  : Colors.green,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  options.isDelivery ? 'Livraison a domicile' : 'Retrait au restaurant',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (options.isDelivery && options.quartier != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Quartier: ${options.quartier!.nom}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
                if (options.isDelivery && options.address != null) ...[
                  Text(
                    options.address!.rue,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
                if (options.isDelivery && options.newAddressRue != null) ...[
                  Text(
                    options.newAddressRue!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.goNamed(AppRoutes.deliveryOptions.routeName),
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildPhoneSection(String? existingPhone) {
    if (existingPhone != null &&
        existingPhone.isNotEmpty &&
        _phoneController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _phoneController.text = existingPhone;
        }
      });
    }

    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: 'Numero de telephone',
        hintText: 'Ex: 06 XXX XX XX',
        prefixIcon: const Icon(Icons.phone),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez entrer votre numero de telephone';
        }
        if (value.length < 9) {
          return 'Numero de telephone invalide';
        }
        return null;
      },
    );
  }

  Widget _buildPaymentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(12),
        color: Colors.orange.shade50,
      ),
      child: Row(
        children: [
          Icon(Icons.phone_android, color: Colors.orange.shade700, size: 32),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MTN Mobile Money',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Paiement securise',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(
    Cart cart,
    double subTotal,
    double deliveryFee,
    double total,
    DeliveryOptions options,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Menus groupés
          ...cart.menuGroups.entries.map((entry) {
            final groupItems = entry.value;
            final menuInfo = groupItems.first.menu;
            final quantite = groupItems.first.quantite;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${quantite}x ${menuInfo?.nom ?? "Menu"}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${((menuInfo?.prix ?? 0) * quantite).toStringAsFixed(0)} FCFA',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  ...groupItems.map((item) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 2),
                    child: Text(
                      '- ${item.product.nom}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  )),
                ],
              ),
            );
          }),
          // Items individuels
          ...cart.individualItems.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${item.quantite}x ${item.product.nom}',
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${(item.quantite * item.variant.prix).toStringAsFixed(0)} FCFA',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 24),
          _buildSummaryRow('Sous-total', subTotal),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Frais de livraison', style: TextStyle(fontSize: 15)),
              Text(
                options.isDelivery
                    ? '${deliveryFee.toStringAsFixed(0)} FCFA'
                    : 'Gratuit',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: !options.isDelivery ? Colors.green : null,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '${total.toStringAsFixed(0)} FCFA',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 15)),
        Text(
          '${value.toStringAsFixed(0)} FCFA',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Future<void> _showPaymentInstructions(
    BuildContext context,
    double total,
    DeliveryOptions options,
    String restaurantId,
  ) async {
    if (!_formKey.currentState!.validate()) return;

    // Préparer l'adresse si c'est une livraison
    String? finalAddressId;
    if (options.isDelivery) {
      if (options.newAddressRue != null) {
        // Créer une nouvelle adresse
        try {
          final newAddress = await ref
              .read(adresseControllerProvider.notifier)
              .createAdresse(
                rue: options.newAddressRue!,
                quartierId: options.quartier?.id,
              );
          finalAddressId = newAddress.id;
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: ${e.toString()}')),
          );
          return;
        }
      } else if (options.address != null) {
        finalAddressId = options.address!.id;
      }
    }

    if (!context.mounted) return;

    // Récupérer le numéro de téléphone du restaurant
    String paymentPhoneNumber = 'Non disponible';
    try {
      final restaurant = await ref.read(
        restaurantControllerProvider(restaurantId).future,
      );
      paymentPhoneNumber = restaurant.phoneNumber ?? 'Non disponible';
    } catch (_) {
      // En cas d'erreur, on continue avec le numéro par défaut
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.payment, color: Colors.orange.shade700, size: 24),
              const SizedBox(width: 8),
              const Text('Instructions de paiement', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pour valider votre commande, effectuez le paiement via MTN Mobile Money:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                // Numéro de paiement
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Numero MTN MoMo',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            paymentPhoneNumber,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, color: Colors.orange),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: paymentPhoneNumber));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Numero copie!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Montant
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Text('Montant: ', style: TextStyle(fontSize: 14)),
                      Text(
                        '${total.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Instructions
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Etapes:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      SizedBox(height: 8),
                      Text('1. Composez *105#', style: TextStyle(fontSize: 13)),
                      Text('2. Choisir "Envoi d\'argent"', style: TextStyle(fontSize: 13)),
                      Text('3. Choisir "Abonne Mobile Money"', style: TextStyle(fontSize: 13)),
                      Text('4. Entrer le numero ci-dessus', style: TextStyle(fontSize: 13)),
                      Text('5. Entrer le montant', style: TextStyle(fontSize: 13)),
                      Text('6. Confirmer avec votre code PIN', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ref.read(checkoutControllerProvider.notifier).placeOrder(
                    adresseId: finalAddressId,
                    paymentMethod: 'MTN_MOMO',
                    isDelivery: options.isDelivery,
                    note: _noteController.text.trim().isEmpty
                        ? null
                        : _noteController.text.trim(),
                  );

                  if (!context.mounted) return;
                  Navigator.of(dialogContext).pop();
                  ref.read(cartControllerProvider.notifier).clearCart();
                  context.goNamed(AppRoutes.orderSuccess.routeName);
                } catch (e) {
                  if (!context.mounted) return;
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'J\'ai paye',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
