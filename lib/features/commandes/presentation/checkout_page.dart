// lib/features/checkout/presentation/checkout_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/commandes/data/checkout_controller.dart';
import 'package:lilia_app/features/user/application/adresse_controller.dart';
import 'package:lilia_app/features/user/application/profile_controller.dart';
import 'package:lilia_app/models/adresse.dart';

import '../../../routing/app_route_enum.dart';
 // Pour la navigation après commande

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _formKey = GlobalKey<FormState>(); // Ajout de la clé de formulaire pour la validation
  // Déclarations des contrôleurs de texte pour les nouvelles adresses/téléphones
  final TextEditingController _newAddressRueController = TextEditingController();
  final TextEditingController _newAddressVilleController = TextEditingController();
  final TextEditingController _newAddressCountryController = TextEditingController();
  final TextEditingController _newAddressComplementController = TextEditingController();
  final TextEditingController _newPhoneNumberController = TextEditingController();

  // État pour l'adresse sélectionnée (par défaut ou nouvelle)
  Adresse? _selectedAddress;
  bool _useNewAddress = false; // Pour basculer entre adresses existantes et nouvelle adresse

  // État pour la méthode de paiement sélectionnée
  String _selectedPaymentMethod = 'CASH_ON_DELIVERY'; // Correspond à votre backend

  // Frais de livraison (fixé pour l'UI, le backend recalcule)
  final double _deliveryFee = 500.0; // Correspond à DELIVERY_FEE de votre backend

  @override
  void dispose() {
    _newAddressRueController.dispose();
    _newAddressVilleController.dispose();
    _newAddressCountryController.dispose();
    _newAddressComplementController.dispose();
    _newPhoneNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch les fournisseurs de données
    final cartAsync = ref.watch(cartControllerProvider);
    final addressesAsync = ref.watch(userAdressesProvider);
    final userProfileAsync = ref.watch(userProfileProvider);
    final checkoutState = ref.watch(checkoutControllerProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
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
      body: RefreshIndicator( // Permet de rafraîchir les données en tirant vers le bas
        onRefresh: () async {
          ref.invalidate(cartControllerProvider);
          ref.invalidate(userProfileProvider);
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
              padding: const EdgeInsets.all(16.0),
              child: Form( // Enveloppe le contenu dans un Form pour la validation
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Adresse de Livraison
                    _buildSectionTitle('Adresse :'),
                    addressesAsync.when(
                      data: (addresses) {
                        // Initialise _selectedAddress si c'est la première fois et qu'il y a des adresses
                        if (_selectedAddress == null && addresses.isNotEmpty && !_useNewAddress) {
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
                            if (addresses.isNotEmpty && !_useNewAddress) ...[ // Affiche le Dropdown si des adresses existent et qu'on n'est pas en mode "nouvelle adresse"
                              DropdownButtonFormField<Adresse>(
                                value: _selectedAddress, // Utilise _selectedAddress directement
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                hint: const Text('Select an existing address'),
                                items: addresses.map((adresse) {
                                  return DropdownMenuItem(
                                    value: adresse,
                                    child: Text(adresse.toString()),
                                  );
                                }).toList(),
                                onChanged: (Adresse? newValue) {
                                  setState(() {
                                    _selectedAddress = newValue;
                                    _useNewAddress = false; // Désactive la saisie de nouvelle adresse
                                  });
                                },
                                validator: (value) {
                                  if (value == null && !_useNewAddress) {
                                    return 'Please select an address';
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
                                      _selectedAddress = null; // Désélectionne l'adresse existante
                                    }
                                  });
                                },
                                child: Text(
                                  _useNewAddress ? 'Utiliser une adresse existante' : 'Ajouter une nouvelle adresse',
                                  style: const TextStyle(color: Colors.teal),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_useNewAddress) ...[ // Affiche les champs de nouvelle adresse si _useNewAddress est true
                              TextFormField(
                                controller: _newAddressRueController,
                                decoration: _inputDecoration('Avenue/Rue/Appartement No.'),
                                validator: (value) => value!.isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _newAddressVilleController,
                                decoration: _inputDecoration('Ville'),
                                validator: (value) => value!.isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _newAddressCountryController,
                                decoration: _inputDecoration('Pays'),
                                validator: (value) => value!.isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _newAddressComplementController,
                                decoration: _inputDecoration('Complement (Optional)'),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Text('Error loading addresses: $err'),
                    ),
                    const SizedBox(height: 20),

                    // Section Numéro de Téléphone
                   /* _buildSectionTitle('Phone Number'),
                    userProfileAsync.when(
                      data: (userProfile) {
                        // Pré-remplir si existant et le champ est vide
                        if (userProfile.phone != null && userProfile.phone!.isNotEmpty && _newPhoneNumberController.text.isEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              _newPhoneNumberController.text = userProfile.phone!;
                            }
                          });
                        }
                        return TextFormField(
                          controller: _newPhoneNumberController,
                          keyboardType: TextInputType.phone,
                          decoration: _inputDecoration('Enter Phone Number'),
                          validator: (value) => value!.isEmpty ? 'Required' : null,
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Text('Error loading phone number: $err'),
                    ),
                    const SizedBox(height: 20),*/

                    // Section Méthode de Paiement
                    _buildSectionTitle('Mode de Paiement'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: const Text('Payez en Cash'),
                            value: 'CASH_ON_DELIVERY',
                            groupValue: _selectedPaymentMethod,
                            onChanged: (String? value) {
                              setState(() {
                                _selectedPaymentMethod = value!;
                              });
                            },
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          // Ajoutez d'autres méthodes de paiement ici si nécessaire
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section Résumé de la Commande
                    _buildSectionTitle('Sommaire de la commande'),
                    Column(
                      children: cart.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.quantite}x ${item.product.nom} (${item.variant.label})',
                                  style: const TextStyle(fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${(item.quantite * item.variant.prix).toStringAsFixed(2)} FCFA',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const Divider(height: 30),
                    _buildSummaryRow('Sous-total', subTotal),
                    _buildSummaryRow('Prix de livraison', _deliveryFee),
                    _buildSummaryRow('Total', total, isTotal: true),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: ${err.toString()}')),
        ),
      ),
      // Bouton "Place Order" en bas de l'écran
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: checkoutState.isLoading ? null : () async {
            if (_formKey.currentState!.validate()) { // Valide le formulaire
              String? finalAddressId;
              String? finalNewAddressRue;
              String? finalNewAddressVille;
              String? finalNewAddressCountry;
              String? finalNewAddressComplement;
              String? finalPhoneNumber;

              if (_useNewAddress) {
                finalNewAddressRue = _newAddressRueController.text;
                finalNewAddressVille = _newAddressVilleController.text;
                finalNewAddressCountry = _newAddressCountryController.text;
                finalNewAddressComplement = _newAddressComplementController.text.isEmpty ? null : _newAddressComplementController.text;

                // IMPORTANT: Votre backend createOrderFromCart ne gère pas la création d'adresse à la volée.
                // Vous devez soit:
                // 1. Créer l'adresse via un autre endpoint API (par exemple, /addresses) AVANT d'appeler placeOrder,
                //    puis utiliser l'ID de l'adresse nouvellement créée.
                // 2. Modifier votre fonction createOrderFromCart côté backend pour qu'elle accepte
                //    les détails d'une nouvelle adresse et la crée elle-même.
                // Pour l'instant, je vais afficher un message d'erreur et empêcher la commande.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Creating new addresses is not yet supported via this flow. Please select an existing address or implement address creation first.')),
                );
                return; // Empêche la commande si nouvelle adresse n'est pas gérée
              } else if (_selectedAddress != null) {
                finalAddressId = _selectedAddress!.id;
              } else {
                // Ce cas devrait être géré par le validator du DropdownButtonFormField,
                // mais une vérification supplémentaire est toujours bonne.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select or add a delivery address.')),
                );
                return;
              }

              /*finalPhoneNumber = _newPhoneNumberController.text.isEmpty ? null : _newPhoneNumberController.text;
              if (finalPhoneNumber == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your phone number.')),
                );
                return;
              }*/

              try {
                await ref.read(checkoutControllerProvider.notifier).placeOrder(
                  adresseId: finalAddressId, // Doit être non-null ici grâce aux vérifications
                  paymentMethod: _selectedPaymentMethod,
                  newPhoneNumber: finalPhoneNumber,
                  // Les détails de la nouvelle adresse ne sont pas passés ici car non gérés par votre backend createOrderFromCart
                );
                // Succès: naviguer vers une page de confirmation ou l'historique des commandes
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Order placed successfully!')),
                );
                context.goNamed(AppRoutes.orderSuccess.routeName); // Naviguer vers la page de succès
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to place order: ${e.toString()}')),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            minimumSize: const Size(double.infinity, 50),
          ),
          child: checkoutState.isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
            'Place Order - ',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      ),
    );
  }

  // Helper pour les titres de section
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
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
            '${value.toStringAsFixed(2)} FCFA',
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
