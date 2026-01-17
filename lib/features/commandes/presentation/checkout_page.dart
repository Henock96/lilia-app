import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/common_widgets/build_loading_state.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/commandes/data/checkout_controller.dart';
import 'package:lilia_app/features/payments/presentation/payment_page.dart';
import 'package:lilia_app/features/user/application/adresse_controller.dart';
import 'package:lilia_app/features/user/application/profile_controller.dart';
import 'package:lilia_app/models/adresse.dart';
import 'package:lilia_app/routing/app_route_enum.dart';

import '../../../models/cart.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _newAddressRueController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  Adresse? _selectedAddress;
  bool _useNewAddress = false;
  bool _isDelivery = true; // true = livraison, false = point de retrait

  // Numéro MTN Mobile Money pour le paiement
  final String _paymentPhoneNumber = '+242 06 745 46 10';

  final double _deliveryFee = 500.0;

  @override
  void dispose() {
    _newAddressRueController.dispose();
    _noteController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartControllerProvider);
    final addressesAsync = ref.watch(adresseControllerProvider);
    final checkoutState = ref.watch(checkoutControllerProvider);
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.goNamed(AppRoutes.cart.routeName),
        ),
        title: const Text(
          'Finaliser votre commande',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: cartAsync.when(
        data: (cart) {
          final double subTotal = cart!.items.fold(0.0, (sum, item) {
            return sum + (item.variant.prix * item.quantite);
          });
          // Calcul du total selon le mode de livraison
          final double total = _isDelivery ? subTotal + _deliveryFee : subTotal;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // === SECTION TÉLÉPHONE ===
                  _buildSectionTitle('Numéro de téléphone'),
                  const SizedBox(height: 8),
                  userProfileAsync.when(
                    data: (user) => _buildPhoneSection(user.phone),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => _buildPhoneSection(null),
                  ),
                  const SizedBox(height: 24),

                  // === SECTION MODE DE LIVRAISON ===
                  _buildSectionTitle('Mode de réception'),
                  const SizedBox(height: 8),
                  _buildDeliveryModeSection(),
                  const SizedBox(height: 24),

                  // === SECTION ADRESSE (seulement si livraison) ===
                  if (_isDelivery) ...[
                    _buildSectionTitle('Adresse de livraison'),
                    addressesAsync.when(
                      data: (addresses) => _buildAddressSection(addresses),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Text('Erreur: $err'),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // === SECTION INSTRUCTIONS ===
                  _buildSectionTitle('Instructions pour la commande (Facultatif)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _noteController,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: InputDecoration(
                      hintText: 'Ex: Sonnez à la porte, appelez-moi à l\'arrivée...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // === SECTION RÉSUMÉ ===
                  _buildSectionTitle('Résumé de la commande'),
                  const SizedBox(height: 12),
                  _buildOrderSummary(cart, subTotal, total),
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
                          : () => _showPaymentInstructions(context, total),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: checkoutState.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                        'Valider et payer la commande',
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
        error: (err, stack) => BuildErrorState(err),
      ),
    );
  }

  // === SECTIONS DE L'INTERFACE ===

  Widget _buildPhoneSection(String? existingPhone) {
    // Pré-remplir le champ si le numéro existe et que le controller est vide
    if (existingPhone != null && existingPhone.isNotEmpty && _phoneController.text.isEmpty) {
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
        labelText: 'Numéro de téléphone',
        hintText: 'Ex: 06 XXX XX XX',
        prefixIcon: const Icon(Icons.phone),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez entrer votre numéro de téléphone';
        }
        if (value.length < 9) {
          return 'Numéro de téléphone invalide';
        }
        return null;
      },
    );
  }

  Widget _buildDeliveryModeSection() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Option Livraison
          RadioListTile<bool>(
            value: true,
            groupValue: _isDelivery,
            onChanged: (value) {
              setState(() {
                _isDelivery = value!;
              });
            },
            title: const Text(
              'Livraison à domicile',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Frais de livraison: ${_deliveryFee.toStringAsFixed(0)} FCFA',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            secondary: Icon(
              Icons.delivery_dining,
              color: _isDelivery ? Theme.of(context).primaryColor : Colors.grey,
            ),
            activeColor: Theme.of(context).primaryColor,
          ),
          Divider(height: 1, color: Colors.grey.shade300),
          // Option Point de retrait
          RadioListTile<bool>(
            value: false,
            groupValue: _isDelivery,
            onChanged: (value) {
              setState(() {
                _isDelivery = value!;
              });
            },
            title: const Text(
              'Retrait au restaurant',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Pas de frais supplémentaires',
              style: TextStyle(color: Colors.green[600], fontSize: 13),
            ),
            secondary: Icon(
              Icons.store,
              color: !_isDelivery ? Theme.of(context).primaryColor : Colors.grey,
            ),
            activeColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection(List<Adresse> addresses) {
    if (_selectedAddress == null && addresses.isNotEmpty && !_useNewAddress) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedAddress = addresses.first);
        }
      });
    }

    if (addresses.isEmpty && !_useNewAddress) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _useNewAddress = true);
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (addresses.isNotEmpty && !_useNewAddress) ...[
          DropdownButtonFormField<Adresse>(
            value: _selectedAddress,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            hint: const Text('Sélectionnez une adresse'),
            items: addresses.map((adresse) {
              return DropdownMenuItem(
                value: adresse,
                child: Text(
                  adresse.toString(),
                  style: const TextStyle(fontSize: 14),
                ),
              );
            }).toList(),
            onChanged: (Adresse? newValue) {
              setState(() {
                _selectedAddress = newValue;
                _useNewAddress = false;
              });
            },
            validator: (value) {
              if (value == null && !_useNewAddress) {
                return 'Veuillez choisir une adresse';
              }
              return null;
            },
          ),
        ],
        if (addresses.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _useNewAddress = !_useNewAddress;
                  if (_useNewAddress) {
                    _selectedAddress = null;
                  }
                });
              },
              icon: Icon(
                _useNewAddress ? Icons.arrow_back : Icons.add,
                size: 18,
              ),
              label: Text(
                _useNewAddress
                    ? 'Utiliser une adresse existante'
                    : 'Ajouter une nouvelle adresse',
              ),
            ),
          ),
        if (_useNewAddress) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _newAddressRueController,
            decoration: InputDecoration(
              labelText: 'Adresse complète: Rue, Quartier, Ville',
              hintText: 'Rue, Quartier, Ville',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            validator: (value) {
              if (_useNewAddress && (value == null || value.isEmpty)) {
                return 'Veuillez entrer une adresse complète.';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(8),
        color: Colors.orange.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_android, color: Colors.orange.shade700, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'MTN Mobile Money',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Paiement sécurisé via MTN Mobile Money',
            style: TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Le paiement est obligatoire pour valider votre commande',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(Cart cart, double subTotal, double total) {
    return Column(
      children: [
        ...cart.items.map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${item.quantite}x ${item.product.nom} (${item.variant.label})',
                    style: const TextStyle(fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(item.quantite * item.variant.prix).toStringAsFixed(0)} FCFA',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        const Divider(height: 24, thickness: 1),
        _buildSummaryRow('Sous-total', subTotal),
        const SizedBox(height: 8),
        // Afficher les frais de livraison seulement si livraison à domicile
        if (_isDelivery)
          _buildSummaryRow('Frais de livraison', _deliveryFee)
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Frais de livraison',
                style: TextStyle(fontSize: 16),
              ),
              Text(
                'Gratuit (Retrait)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[600],
                ),
              ),
            ],
          ),
        const Divider(height: 24, thickness: 1),
        _buildSummaryRow('Total à payer', total, isTotal: true),
      ],
    );
  }

  Widget _buildSummaryRow(String label, double value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '${value.toStringAsFixed(0)} FCFA',
          style: TextStyle(
            fontSize: isTotal ? 20 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: isTotal ? Colors.orange : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  // === DIALOGUE D'INSTRUCTIONS DE PAIEMENT ===

  Future<void> _showPaymentInstructions(BuildContext context, double total) async {
    if (!_formKey.currentState!.validate()) return;

    // Préparer l'adresse seulement si livraison à domicile
    String? finalAddressId;
    if (_isDelivery) {
      finalAddressId = await _prepareAddress(context);
      if (finalAddressId == null) return;
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
              Icon(Icons.payment, color: Colors.orange.shade700, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Instructions de paiement',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isDelivery
                      ? 'Pour valider votre commande et bénéficier de la livraison, veuillez effectuer le paiement via MTN Mobile Money au numéro suivant :'
                      : 'Pour valider votre commande (retrait au restaurant), veuillez effectuer le paiement via MTN Mobile Money au numéro suivant :',
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),
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
                            'Numéro MTN MoMo',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _paymentPhoneNumber,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, color: Colors.orange),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: _paymentPhoneNumber),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Numéro copié !'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        tooltip: 'Copier le numéro',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Montant à payer : ',
                        style: TextStyle(fontSize: 13),
                      ),
                      Text(
                        '${total.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        '📝 Étapes à suivre :',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('1. Composez *105#', style: TextStyle(fontSize: 13)),
                      Text('2. Choisir"Envoi d\'argent"', style: TextStyle(fontSize: 13)),
                      Text('3. Ensuite "Abonne Mobile Money"', style: TextStyle(fontSize: 13)),
                      Text('4. Entrer le numéro ci-dessus', style: TextStyle(fontSize: 13)),
                      Text('5. Entrer le montant', style: TextStyle(fontSize: 13)),
                      Text('6. Confirmer avec votre code PIN', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Une fois le paiement effectué, votre commande sera automatiquement validée et mise en préparation.',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.black87,
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
                //Navigator.of(dialogContext).pop();
                // Créer la commande avec la note
                final order = await ref.read(checkoutControllerProvider.notifier).placeOrder(
                  adresseId: finalAddressId ?? "Pas d'adresses",
                  paymentMethod: 'MTN_MOMO',
                  note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
                );
                //_proceedToPayment(context, total);

                if (!context.mounted) return;
                ref.read(cartControllerProvider.notifier).clearCart();
                context.goNamed(AppRoutes.orderSuccess.routeName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
              ),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: const Text(
                  'J\'ai effectué le paiement',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // === TRAITEMENT DU PAIEMENT ===

  /*Future<void> _proceedToPayment(BuildContext context, double total) async {
    String? finalAddressId = await _prepareAddress(context);
    if (finalAddressId == null) return;

    try {
      // Créer la commande avec la note
      final order = await ref.read(checkoutControllerProvider.notifier).placeOrder(
        adresseId: finalAddressId,
        paymentMethod: 'MTN_MOMO',
        note: _noteController.text.trim().isEmpty ? "null" : _noteController.text.trim(),
      );

      if (!context.mounted) return;

      // Naviguer vers la page de paiement
      final paymentResult = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentPage(
            orderId: order.id,
            amount: total,
            currency: 'XAF',
          ),
        ),
      );

      if (!context.mounted) return;

      if (paymentResult == true) {
        // Paiement confirmé
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Paiement confirmé ! Votre commande est en préparation.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        ref.read(cartControllerProvider.notifier).clearCart();
        context.goNamed(AppRoutes.orderSuccess.routeName);
      } else {
        // Paiement non confirmé
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '⚠️ Paiement en attente. Votre commande sera validée après confirmation du paiement.',
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Voir ma commande',
              onPressed: () => context.goNamed(AppRoutes.orderSuccess.routeName),
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
*/
  Future<String?> _prepareAddress(BuildContext context) async {
    String? finalAddressId;

    if (_useNewAddress) {
      try {
        final newAddress = await ref
            .read(adresseControllerProvider.notifier)
            .createAdresse(rue: _newAddressRueController.text);
        finalAddressId = newAddress.id;
        ref.invalidate(adresseControllerProvider);
      } catch (e) {
        if (!context.mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
        return null;
      }
    } else if (_selectedAddress != null) {
      finalAddressId = _selectedAddress!.id;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une adresse de livraison.'),
        ),
      );
      return null;
    }

    return finalAddressId;
  }
}