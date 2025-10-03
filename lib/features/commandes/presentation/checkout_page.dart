// lib/features/checkout/presentation/checkout_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/common_widgets/build_loading_state.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/commandes/data/checkout_controller.dart';
import 'package:lilia_app/features/payments/presentation/payment_page.dart';
import 'package:lilia_app/features/user/application/adresse_controller.dart';
import 'package:lilia_app/features/user/application/profile_controller.dart';
import 'package:lilia_app/features/user/data/adresse_repository.dart';
import 'package:lilia_app/models/adresse.dart';

import '../../../routing/app_route_enum.dart';
// Pour la navigation après commande

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _formKey =
      GlobalKey<
        FormState
      >(); // Ajout de la clé de formulaire pour la validation
  // Déclarations des contrôleurs de texte pour les nouvelles adresses/téléphones
  final TextEditingController _newAddressRueController =
      TextEditingController();

  // État pour l'adresse sélectionnée (par défaut ou nouvelle)
  Adresse? _selectedAddress;
  bool _useNewAddress =
      false; // Pour basculer entre adresses existantes et nouvelle adresse

  // État pour la méthode de paiement sélectionnée
  String _selectedPaymentMethod =
      'CASH_ON_DELIVERY'; // Correspond à votre backend

  // Frais de livraison (fixé pour l'UI, le backend recalcule)
  final double _deliveryFee =
      500.0; // Correspond à DELIVERY_FEE de votre backend

  @override
  void dispose() {
    _newAddressRueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch les fournisseurs de données
    final cartAsync = ref.watch(cartControllerProvider);
    final addressesAsync = ref.watch(adresseControllerProvider);
    final userProfileAsync = ref.watch(userProfileProvider);
    final checkoutState = ref.watch(checkoutControllerProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            context.goNamed(AppRoutes.cart.routeName);
          },
        ),
        title: const Text(
          'Finaliser votre commande',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        // Permet de rafraîchir les données en tirant vers le bas
        onRefresh: () async {
          ref.invalidate(cartControllerProvider);
          ref.invalidate(userProfileProvider);
        },
        child: cartAsync.when(
          data: (cart) {
            // Calcul du sous-total côté client pour l'affichage
            final double subTotal = cart!.items.fold(0.0, (sum, item) {
              return sum + (item.variant.prix * item.quantite);
            });
            final double total = subTotal + _deliveryFee;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Form(
                    // Enveloppe le contenu dans un Form pour la validation
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section Adresse de Livraison
                        _buildSectionTitle('Adresse de livraison:'),
                        addressesAsync.when(
                          data: (addresses) {
                            // Initialise _selectedAddress si c'est la première fois et qu'il y a des adresses
                            if (_selectedAddress == null &&
                                addresses.isNotEmpty &&
                                !_useNewAddress) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(() {
                                    _selectedAddress = addresses.first;
                                  });
                                }
                              });
                            }

                            // Si aucune adresse existe et que l'utilisateur n'est pas déjà en train d'en ajouter une,
                            // force l'affichage du formulaire de nouvelle adresse.
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
                                if (addresses.isNotEmpty &&
                                    !_useNewAddress) ...[
                                  // Affiche le Dropdown si des adresses existent et qu'on n'est pas en mode "nouvelle adresse"
                                  DropdownButtonFormField<Adresse>(
                                    initialValue:
                                        _selectedAddress, // Utilise _selectedAddress directement
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          8.0,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                    ),
                                    hint: const Text(
                                      'Selectionnez une adresse existante',
                                    ),
                                    items: addresses.map((adresse) {
                                      return DropdownMenuItem(
                                        value: adresse,
                                        child: Text(
                                          adresse.toString(),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (Adresse? newValue) {
                                      setState(() {
                                        _selectedAddress = newValue;
                                        _useNewAddress =
                                            false; // Désactive la saisie de nouvelle adresse
                                      });
                                    },
                                    validator: (value) {
                                      if (value == null && !_useNewAddress) {
                                        return 'Veillez choisir une adresse svp!';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _useNewAddress = !_useNewAddress;
                                        if (_useNewAddress) {
                                          _selectedAddress =
                                              null; // Désélectionne l'adresse existante
                                        }
                                      });
                                    },
                                    child: Text(
                                      _useNewAddress
                                          ? 'Utiliser une adresse existante'
                                          : 'Ajouter une nouvelle adresse',
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (_useNewAddress) ...[
                                  // Affiche les champs de nouvelle adresse si _useNewAddress est true
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: TextFormField(
                                      controller: _newAddressRueController,
                                      decoration: _inputDecoration(
                                        'Rue, Avenue',
                                      ),
                                      validator: (value) =>
                                          value!.isEmpty ? 'Required' : null,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ],
                            );
                          },
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (err, stack) =>
                              Text('Error loading addresses: $err'),
                        ),
                        const SizedBox(height: 20),
                        // Section Méthode de Paiement
                        _buildSectionTitle('Mode de Paiement'),
                        _buildPaymentMethodSection(),
                        const SizedBox(height: 40),
                        // Section Résumé de la Commande
                        _buildSectionTitle('Sommaire de la commande'),
                        const SizedBox(height: 10),
                        Column(
                          children: cart.items.map((item) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.quantite}x ${item.product.nom} (${item.variant.label})',
                                      style: const TextStyle(fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${(item.quantite * item.variant.prix).toStringAsFixed(0)} FCFA',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const Divider(height: 20),
                        _buildSummaryRow('Sous-total', subTotal),
                        _buildSummaryRow('Prix de livraison', _deliveryFee),
                        _buildSummaryRow('Total', total, isTotal: true),
                        const SizedBox(height: 20),
                        //const Spacer(),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: ElevatedButton(
                      onPressed: checkoutState.isLoading
                          ? null
                          : () => _handleCheckout(context, total),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: checkoutState.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _selectedPaymentMethod == 'MTN_MOMO'
                                  ? 'Continuer vers le paiement'
                                  : 'Passer la commande',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const BuildLoadingState(),
          error: (err, stack) => BuildErrorState(err),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        children: [
          // Option 1: Cash à la livraison
          RadioListTile<String>(
            title: Row(
              children: [
                Icon(Icons.money, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Payer en Cash à la livraison',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            subtitle: const Text('Payez en espèces au livreur'),
            value: 'CASH_ON_DELIVERY',
            groupValue: _selectedPaymentMethod,
            onChanged: (String? value) {
              setState(() => _selectedPaymentMethod = value!);
            },
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),

          const Divider(),

          // Option 2: MTN Mobile Money
          RadioListTile<String>(
            title: Row(
              children: [
                Icon(Icons.phone_android, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Text(
                  'MTN Mobile Money',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            subtitle: const Text('Paiement sécurisé via MTN MoMo'),
            value: 'MTN_MOMO',
            groupValue: _selectedPaymentMethod,
            onChanged: (String? value) {
              setState(() => _selectedPaymentMethod = value!);
            },
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),

          // Badge "Mode Test" si applicable
          if (_selectedPaymentMethod == 'MTN_MOMO')
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Mode Test: Les paiements sont simulés',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 🔥 NOUVELLE MÉTHODE: Gérer le checkout selon la méthode de paiement
  Future<void> _handleCheckout(BuildContext context, double total) async {
    if (!_formKey.currentState!.validate()) return;

    // Étape 1: Préparer l'adresse
    String? finalAddressId = await _prepareAddress(context);
    if (finalAddressId == null) return;

    // Étape 2: Vérifier la méthode de paiement
    if (_selectedPaymentMethod == 'MTN_MOMO') {
      // Pour MTN MoMo: Créer la commande d'abord, puis aller vers le paiement
      await _handleMtnMomoPayment(context, finalAddressId, total);
    } else {
      // Pour Cash: Créer la commande directement
      await _handleCashOnDelivery(context, finalAddressId);
    }
  }

  // 🔥 NOUVELLE MÉTHODE: Préparer l'adresse (extraite de votre code)
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur lors de la création de l\'adresse: ${e.toString()}',
            ),
          ),
        );
        return null;
      }
    } else if (_selectedAddress != null) {
      finalAddressId = _selectedAddress!.id;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Veuillez sélectionner ou ajouter une adresse de livraison.',
          ),
        ),
      );
      return null;
    }

    return finalAddressId;
  }

  // 🔥 NOUVELLE MÉTHODE: Gérer le paiement MTN MoMo
  Future<void> _handleMtnMomoPayment(
    BuildContext context,
    String addressId,
    double total,
  ) async {
    try {
      // Étape 1: Créer la commande
      final order = await ref
          .read(checkoutControllerProvider.notifier)
          .placeOrder(
            adresseId: addressId,
            paymentMethod: _selectedPaymentMethod,
          );

      // Étape 2: Naviguer vers la page de paiement avec l'orderId
      if (!context.mounted) return;

      final paymentResult = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) =>
              PaymentPage(orderId: order.id, amount: total, currency: 'FCFA'),
        ),
      );

      // Étape 3: Gérer le résultat du paiement
      if (paymentResult == true) {
        // Paiement réussi
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commande et paiement réussis!'),
            backgroundColor: Colors.green,
          ),
        );

        // Vider le panier
        ref.read(cartControllerProvider.notifier).clearCart();

        // Naviguer vers la page de succès
        context.goNamed(AppRoutes.orderSuccess.routeName);
      } else {
        // Paiement échoué ou annulé
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Paiement annulé. Votre commande est enregistrée mais non payée.',
            ),
            action: SnackBarAction(
              label: 'Voir mes commandes',
              onPressed: () {
                context.goNamed(AppRoutes.orderSuccess.routeName);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
    }
  }

  // 🔥 NOUVELLE MÉTHODE: Gérer le paiement en cash
  Future<void> _handleCashOnDelivery(
    BuildContext context,
    String addressId,
  ) async {
    try {
      await ref
          .read(checkoutControllerProvider.notifier)
          .placeOrder(
            adresseId: addressId,
            paymentMethod: _selectedPaymentMethod,
          );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commande passée avec succès!')),
      );

      ref.read(cartControllerProvider.notifier).clearCart();
      context.goNamed(AppRoutes.orderSuccess.routeName);
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de la commande: ${e.toString()}')),
      );
    }
  }

  // Helper pour les titres de section
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Helper pour les décorations des champs de texte
  InputDecoration _inputDecoration(String labelText) {
    return InputDecoration(
      labelText: labelText,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: Colors.teal, width: 2.0),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  // Helper pour les lignes de résumé (subtotal, delivery, total)
  Widget _buildSummaryRow(String label, double value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${value.toStringAsFixed(0)} FCFA',
            style: TextStyle(
              fontSize: 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.black : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
