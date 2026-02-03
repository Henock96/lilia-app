import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/common_widgets/build_loading_state.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/quartiers/application/quartiers_controller.dart';
import 'package:lilia_app/features/user/application/adresse_controller.dart';
import 'package:lilia_app/models/adresse.dart';
import 'package:lilia_app/models/quartier.dart';
import 'package:lilia_app/routing/app_route_enum.dart';

class DeliveryOptionsPage extends ConsumerStatefulWidget {
  const DeliveryOptionsPage({super.key});

  @override
  ConsumerState<DeliveryOptionsPage> createState() => _DeliveryOptionsPageState();
}

class _DeliveryOptionsPageState extends ConsumerState<DeliveryOptionsPage> {
  bool _isDelivery = true;
  Quartier? _selectedQuartier;
  Adresse? _selectedAddress;
  bool _useNewAddress = false;
  final TextEditingController _newAddressController = TextEditingController();

  double? _calculatedDeliveryFee;
  bool _isCalculatingFee = false;
  String? _restaurantId;

  @override
  void initState() {
    super.initState();
    // Ajouter un listener pour mettre à jour le bouton quand le texte change
    _newAddressController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    // Forcer la mise à jour de l'UI quand le texte change
    setState(() {});
  }

  @override
  void dispose() {
    _newAddressController.removeListener(_onTextChanged);
    _newAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartControllerProvider);
    final quartiersAsync = ref.watch(quartiersListProvider);
    final addressesAsync = ref.watch(adresseControllerProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.goNamed(AppRoutes.cart.routeName),
        ),
        title: const Text(
          'Mode de livraison',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: cartAsync.when(
        data: (cart) {
          if (cart == null || cart.items.isEmpty) {
            return const Center(child: Text('Votre panier est vide'));
          }

          // Récupérer le restaurantId du premier item
          _restaurantId = cart.items.first.product.restaurantId;

          final double subTotal = cart.items.fold(0.0, (sum, item) {
            return sum + (item.variant.prix * item.quantite);
          });

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // === SECTION MODE DE LIVRAISON ===
                _buildSectionTitle('Comment souhaitez-vous recevoir votre commande ?'),
                const SizedBox(height: 12),
                _buildDeliveryModeSection(),
                const SizedBox(height: 24),

                // === SECTION QUARTIER (seulement si livraison) ===
                if (_isDelivery) ...[
                  _buildSectionTitle('Sélectionnez votre quartier'),
                  const SizedBox(height: 12),
                  quartiersAsync.when(
                    data: (quartiers) => _buildQuartierSection(quartiers),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Text('Erreur: $err'),
                  ),
                  const SizedBox(height: 24),

                  // === SECTION ADRESSE ===
                  _buildSectionTitle('Adresse de livraison'),
                  const SizedBox(height: 12),
                  addressesAsync.when(
                    data: (addresses) => _buildAddressSection(addresses),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Text('Erreur: $err'),
                  ),
                  const SizedBox(height: 24),
                ],

                // === SECTION RÉSUMÉ DES FRAIS ===
                _buildDeliveryFeeSummary(subTotal),
                const SizedBox(height: 32),

                // === BOUTON CONTINUER ===
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _canContinue() ? _continueToCheckout : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Continuer',
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

  Widget _buildDeliveryModeSection() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
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
                _calculatedDeliveryFee = null;
              });
            },
            title: const Text(
              'Livraison a domicile',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Recevez votre commande chez vous',
              style: TextStyle(fontSize: 13),
            ),
            secondary: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isDelivery
                    ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.delivery_dining,
                color: _isDelivery ? Theme.of(context).primaryColor : Colors.grey,
                size: 28,
              ),
            ),
            activeColor: Theme.of(context).primaryColor,
          ),
          Divider(height: 1, color: Colors.grey.shade300),
          // Option Retrait
          RadioListTile<bool>(
            value: false,
            groupValue: _isDelivery,
            onChanged: (value) {
              setState(() {
                _isDelivery = value!;
                _calculatedDeliveryFee = 0;
              });
            },
            title: const Text(
              'Retrait au restaurant',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Pas de frais supplementaires',
              style: TextStyle(fontSize: 13, color: Colors.green[600]),
            ),
            secondary: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: !_isDelivery
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.store,
                color: !_isDelivery ? Colors.green : Colors.grey,
                size: 28,
              ),
            ),
            activeColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildQuartierSection(List<Quartier> quartiers) {
    // Trouver le quartier correspondant dans la liste (par ID) pour éviter les problèmes d'égalité d'objet
    final selectedQuartierFromList = _selectedQuartier != null
        ? quartiers.where((q) => q.id == _selectedQuartier!.id).firstOrNull
        : null;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<Quartier>(
        value: selectedQuartierFromList,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.location_on_outlined),
          hintText: 'Choisissez votre quartier',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        items: quartiers.map((quartier) {
          return DropdownMenuItem(
            value: quartier,
            child: Text(quartier.nom),
          );
        }).toList(),
        onChanged: (Quartier? value) {
          setState(() {
            _selectedQuartier = value;
            // Réinitialiser l'adresse sélectionnée si elle n'a pas ce quartier
            if (_selectedAddress != null &&
                _selectedAddress!.quartierId != value?.id) {
              _selectedAddress = null;
            }
          });
          if (value != null) {
            _calculateDeliveryFee();
          }
        },
      ),
    );
  }

  Widget _buildAddressSection(List<Adresse> addresses) {
    // Afficher TOUTES les adresses, pas de filtre restrictif
    // Mais trier pour mettre en premier celles qui correspondent au quartier sélectionné
    final sortedAddresses = List<Adresse>.from(addresses);
    if (_selectedQuartier != null) {
      sortedAddresses.sort((a, b) {
        final aMatches = a.quartierId == _selectedQuartier!.id ? 0 : 1;
        final bMatches = b.quartierId == _selectedQuartier!.id ? 0 : 1;
        return aMatches.compareTo(bMatches);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Afficher les adresses existantes si disponibles et pas en mode nouvelle adresse
        if (sortedAddresses.isNotEmpty && !_useNewAddress) ...[
          // Liste des adresses sous forme de cartes cliquables
          ...sortedAddresses.map((adresse) => _buildAddressCard(adresse)),
        ],

        // Message si aucune adresse enregistrée
        if (addresses.isEmpty && !_useNewAddress) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Aucune adresse enregistrée. Ajoutez une nouvelle adresse.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Bouton pour ajouter nouvelle adresse
        TextButton.icon(
          onPressed: () {
            setState(() {
              _useNewAddress = !_useNewAddress;
              if (_useNewAddress) {
                _selectedAddress = null;
              }
            });
          },
          icon: Icon(
            _useNewAddress ? Icons.list : Icons.add,
            size: 18,
          ),
          label: Text(
            _useNewAddress
                ? 'Utiliser une adresse existante (${addresses.length})'
                : 'Ajouter une nouvelle adresse',
          ),
        ),

        // Champ pour nouvelle adresse
        if (_useNewAddress) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _newAddressController,
            decoration: InputDecoration(
              labelText: 'Nouvelle adresse',
              hintText: 'Ex: 123 Rue de la Paix',
              prefixIcon: const Icon(Icons.edit_location_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAddressCard(Adresse adresse) {
    final isSelected = _selectedAddress?.id == adresse.id;
    final matchesQuartier = _selectedQuartier != null &&
        adresse.quartierId == _selectedQuartier!.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAddress = adresse;
          // Si l'adresse a un quartier différent, mettre à jour le quartier sélectionné
          if (adresse.quartier != null && adresse.quartierId != _selectedQuartier?.id) {
            _selectedQuartier = adresse.quartier;
            _calculateDeliveryFee();
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? Theme.of(context).primaryColor.withValues(alpha: 0.05)
              : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.home_outlined,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade600,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    adresse.rue,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (adresse.quartier != null) ...[
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: matchesQuartier ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          adresse.quartier!.nom,
                          style: TextStyle(
                            fontSize: 12,
                            color: matchesQuartier
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                        if (!matchesQuartier && _selectedQuartier != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(autre quartier)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ] else ...[
                        Icon(
                          Icons.location_off,
                          size: 14,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Quartier non défini',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryFeeSummary(double subTotal) {
    final deliveryFee = _isDelivery ? (_calculatedDeliveryFee ?? 0) : 0.0;
    final total = subTotal + deliveryFee;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sous-total', style: TextStyle(fontSize: 15)),
              Text(
                '${subTotal.toStringAsFixed(0)} FCFA',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('Frais de livraison', style: TextStyle(fontSize: 15)),
                  if (_isCalculatingFee)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
              Text(
                _isDelivery
                    ? (_calculatedDeliveryFee != null
                        ? '${_calculatedDeliveryFee!.toStringAsFixed(0)} FCFA'
                        : 'Selectionnez un quartier')
                    : 'Gratuit',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: !_isDelivery ? Colors.green : null,
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

  Future<void> _calculateDeliveryFee() async {
    if (_restaurantId == null || _selectedQuartier == null) return;

    setState(() {
      _isCalculatingFee = true;
    });

    try {
      final result = await ref.read(
        deliveryFeeProvider(
          restaurantId: _restaurantId!,
          quartierId: _selectedQuartier!.id,
        ).future,
      );
      setState(() {
        _calculatedDeliveryFee = result.fee;
        _isCalculatingFee = false;
      });
    } catch (e) {
      setState(() {
        _calculatedDeliveryFee = 500; // Valeur par défaut en cas d'erreur
        _isCalculatingFee = false;
      });
    }
  }

  bool _canContinue() {
    if (!_isDelivery) return true; // Retrait, pas besoin d'adresse

    // Pour la livraison, il faut un quartier et une adresse
    if (_selectedQuartier == null) return false;

    if (_useNewAddress) {
      return _newAddressController.text.trim().isNotEmpty;
    } else {
      return _selectedAddress != null;
    }
  }

  void _continueToCheckout() {
    // Passer les données à la page de confirmation
    context.goNamed(
      AppRoutes.checkout.routeName,
      extra: DeliveryOptions(
        isDelivery: _isDelivery,
        quartier: _selectedQuartier,
        address: _selectedAddress,
        newAddressRue: _useNewAddress ? _newAddressController.text.trim() : null,
        deliveryFee: _isDelivery ? (_calculatedDeliveryFee ?? 500) : 0,
      ),
    );
  }
}

/// Classe pour passer les options de livraison entre les pages
class DeliveryOptions {
  final bool isDelivery;
  final Quartier? quartier;
  final Adresse? address;
  final String? newAddressRue;
  final double deliveryFee;

  DeliveryOptions({
    required this.isDelivery,
    this.quartier,
    this.address,
    this.newAddressRue,
    required this.deliveryFee,
  });
}
