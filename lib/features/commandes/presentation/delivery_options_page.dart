import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/common_widgets/build_loading_state.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_controller.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:lilia_app/features/address/presentation/pages/location_picker_page.dart';
import 'package:lilia_app/features/quartiers/application/quartiers_controller.dart';
import 'package:lilia_app/features/user/application/adresse_controller.dart';
import 'package:lilia_app/models/adresse.dart';
import 'package:lilia_app/models/quartier.dart';
import 'package:lilia_app/features/settings/data/platform_settings_service.dart';
import 'package:lilia_app/models/restaurant.dart';
import 'package:lilia_app/models/vendor_type.dart';
import 'package:lilia_app/routing/app_route_enum.dart';
import 'package:lilia_app/utils/currency.dart';
import 'package:lilia_app/utils/snackbar.dart';

class DeliveryOptionsPage extends ConsumerStatefulWidget {
  const DeliveryOptionsPage({super.key});

  @override
  ConsumerState<DeliveryOptionsPage> createState() =>
      _DeliveryOptionsPageState();
}

class _DeliveryOptionsPageState extends ConsumerState<DeliveryOptionsPage> {
  bool _isDelivery = true;
  Quartier? _selectedQuartier;
  Adresse? _selectedAddress;
  bool _useNewAddress = false;
  final TextEditingController _newAddressController = TextEditingController();

  /// Position posée sur la carte pour la nouvelle adresse saisie ici.
  /// `null` = le client ne l'a pas fait ; la commande retombera sur le
  /// centroïde du quartier, en `APPROXIMATE`.
  PickedLocation? _newAddressLocation;

  double? _calculatedDeliveryFee;

  /// Dernier devis serveur (F3-02) : il porte la part offerte par le vendeur
  /// et le seuil de livraison offerte, qu'on explique sans rien recalculer.
  DeliveryFeeResult? _quote;

  /// Mode plateforme et devis injoignable : le prix est inconnu. On ne le
  /// remplace pas par le tarif du vendeur, qui ne s'applique plus.
  bool _deliveryFeeUnavailable = false;

  /// Sous-total du panier, transmis au devis pour le seul seuil « livraison
  /// offerte dès X ».
  int? _subTotal;

  /// Identifiant de l'adresse dont on rattache le quartier, le temps de
  /// l'aller-retour serveur. `null` = aucune complétion en cours.
  ///
  /// Porté par l'identifiant et non par un booléen : la liste peut contenir
  /// plusieurs adresses sans quartier, et un drapeau global ferait tourner
  /// l'indicateur sur toutes.
  String? _completionEnCours;

  /// Vrai quand les frais affichés sont un repli local et non la réponse de
  /// `/quartiers/delivery-fee` : le montant final peut différer.
  bool _deliveryFeeIsEstimate = false;
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
          tooltip: 'Retour',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed(AppRoutes.cart.routeName),
        ),
        title: const Text(
          'Mode de livraison',
          style: TextStyle(fontWeight: FontWeight.bold),
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
          // LIL-131 : on charge le restaurant pour adapter l'UI au vendorType
          // (HOME_COOK n'a pas d'adresse physique → retrait masqué ; BAKERY,
          // HOME_COOK et BEVERAGE_SHOP affichent un badge en tête).
          final restaurantAsync = ref.watch(
            restaurantControllerProvider(_restaurantId!),
          );
          final restaurant = restaurantAsync.value;
          // Si HOME_COOK, on force le mode livraison (le retrait n'a pas de sens).
          if (restaurant?.vendorType == VendorType.HOME_COOK && !_isDelivery) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _isDelivery = true;
                  _calculatedDeliveryFee = null;
                  _quote = null;
                });
              }
            });
          }

          // F3-09 — le sous-total du panier, options comprises : prix
          // unitaire serveur × quantité, un menu compté une fois à son prix.
          // L'ancienne somme `variant.prix × quantite` sur TOUTES les lignes
          // ignorait les suppléments et comptait un menu produit par produit.
          final double subTotal = cart.totalPrice;
          _subTotal = subTotal.round();

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bannière vendor type (visible pour non-RESTAURANT)
                  if (restaurant != null &&
                      restaurant.vendorType != VendorType.RESTAURANT) ...[
                    _VendorBanner(restaurant: restaurant),
                    const SizedBox(height: 16),
                  ],
                  // === SECTION MODE DE LIVRAISON ===
                  _buildSectionTitle(
                    'Comment souhaitez-vous recevoir votre commande ?',
                  ),
                  const SizedBox(height: 12),
                  _buildDeliveryModeSection(restaurant),
                  const SizedBox(height: 24),

                  // === SECTION QUARTIER (seulement si livraison) ===
                  if (_isDelivery) ...[
                    _buildSectionTitle('Sélectionnez votre quartier'),
                    const SizedBox(height: 12),
                    quartiersAsync.when(
                      data: (quartiers) => _buildQuartierSection(quartiers),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Text('Erreur: $err'),
                    ),
                    const SizedBox(height: 24),

                    // === SECTION ADRESSE ===
                    _buildSectionTitle('Adresse de livraison'),
                    const SizedBox(height: 12),
                    addressesAsync.when(
                      data: (addresses) => _buildAddressSection(addresses),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
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
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        disabledBackgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
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
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildDeliveryModeSection(Restaurant? restaurant) {
    final cs = Theme.of(context).colorScheme;
    // LIL-131 : HOME_COOK n'a pas d'adresse physique pour le retrait ;
    // l'option n'a pas de sens — on la masque entièrement.
    final hidePickup = restaurant?.vendorType == VendorType.HOME_COOK;
    // Libellé adapté au type de vendeur (boulangerie, vendeur maison…).
    final pickupTitle = restaurant != null
        ? 'Retrait ${restaurant.vendorType.pickupLocationLabel}'
        : 'Retrait sur place';

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      // `groupValue`/`onChanged` sur RadioListTile sont dépréciés depuis
      // Flutter 3.32 : c'est désormais l'ancêtre RadioGroup qui porte l'état du
      // groupe. Les frais de livraison suivent le mode : inconnus (null, à
      // recalculer selon le quartier) en livraison, nuls au retrait.
      child: RadioGroup<bool>(
        groupValue: _isDelivery,
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _isDelivery = value;
            _calculatedDeliveryFee = value ? null : 0;
            _quote = null;
            _deliveryFeeUnavailable = false;
          });
        },
        child: Column(
          children: [
            // Option Livraison
            RadioListTile<bool>(
              value: true,
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
                      ? cs.primary.withValues(alpha: 0.1)
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.delivery_dining,
                  color: _isDelivery ? cs.primary : cs.outline,
                  size: 28,
                ),
              ),
              activeColor: cs.primary,
            ),
            if (!hidePickup) ...[
              Divider(height: 1, color: cs.outline),
              // Option Retrait
              RadioListTile<bool>(
                value: false,
                title: Text(
                  pickupTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600),
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
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.store,
                    color: !_isDelivery ? Colors.green : cs.outline,
                    size: 28,
                  ),
                ),
                activeColor: cs.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuartierSection(List<Quartier> quartiers) {
    final cs = Theme.of(context).colorScheme;
    final selectedQuartierFromList = _selectedQuartier != null
        ? quartiers.where((q) => q.id == _selectedQuartier!.id).firstOrNull
        : null;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<Quartier>(
        initialValue: selectedQuartierFromList,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.location_on_outlined),
          hintText: 'Choisissez votre quartier',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        items: quartiers.map((quartier) {
          return DropdownMenuItem(value: quartier, child: Text(quartier.nom));
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
    // Présélectionner l'adresse par défaut du client.
    //
    // Aucune ne l'était : le client devait rouvrir la même adresse à chaque
    // commande, et un tap oublié bloquait le bouton « Continuer » sans dire
    // pourquoi. On ne choisit que si rien n'est encore sélectionné — écraser
    // un choix déjà fait serait pire que de ne rien présélectionner.
    if (_selectedAddress == null && !_useNewAddress) {
      final preferred = addresses.where((a) => a.isDefault).firstOrNull;
      if (preferred != null) {
        // Hors phase de construction : `setState` pendant un `build` lève.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _selectedAddress != null || _useNewAddress) return;
          setState(() {
            _selectedAddress = preferred;
            if (preferred.quartier != null &&
                preferred.quartierId != _selectedQuartier?.id) {
              _selectedQuartier = preferred.quartier;
              _calculateDeliveryFee();
            }
          });
        });
      }
    }

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
          Builder(
            builder: (context) {
              final cs = Theme.of(context).colorScheme;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: cs.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Aucune adresse enregistrée. Ajoutez une nouvelle adresse.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              );
            },
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
          icon: Icon(_useNewAddress ? Icons.list : Icons.add, size: 18),
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
              hintText: 'Ex: Rue Bayonne, près du marché',
              prefixIcon: const Icon(Icons.edit_location_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Même geste que dans « Mes adresses » : la position se pose sur une
          // carte. Sans elle, la commande partira avec le centroïde du
          // quartier — c'est livrable, mais le livreur devra appeler, et on le
          // dit ici plutôt que de le laisser découvrir.
          OutlinedButton.icon(
            onPressed: _pickNewAddressLocation,
            icon: Icon(
              _newAddressLocation == null
                  ? Icons.map_outlined
                  : Icons.check_circle,
              size: 18,
              color: _newAddressLocation == null ? null : Colors.green,
            ),
            label: Text(
              _newAddressLocation == null
                  ? 'Placer sur la carte (recommandé)'
                  : 'Position enregistrée — modifier',
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ],
      ],
    );
  }

  /// Rattache le quartier sélectionné à une adresse qui n'en a pas.
  ///
  /// L'écriture part au serveur (`PATCH /adresses/:id`) et non dans l'état
  /// local : la correction doit survivre à cette commande. C'est précisément ce
  /// qui distingue « compléter l'adresse » de « choisir un quartier pour
  /// aujourd'hui » — la seconde laisserait les dix-neuf autres commandes
  /// suivantes repartir sans destination.
  Future<void> _attacherQuartier(Adresse adresse) async {
    final quartier = _selectedQuartier;
    if (quartier == null || _completionEnCours != null) return;

    setState(() => _completionEnCours = adresse.id);
    try {
      final misAJour = await ref
          .read(adresseControllerProvider.notifier)
          .updateAdresse(adresse.id, quartierId: quartier.id);

      if (!mounted) return;
      setState(() {
        _completionEnCours = null;
        // Si c'est l'adresse en cours de sélection, on la remplace par la
        // version renvoyée par le serveur : sans cela, la carte continuerait
        // d'afficher « Quartier non défini » jusqu'au prochain chargement.
        if (_selectedAddress?.id == adresse.id) _selectedAddress = misAJour;
      });
      context.showSuccessSnack('Adresse complétée : ${quartier.nom}');
      // Les frais peuvent dépendre du quartier (mode ZONE_BASED).
      _calculateDeliveryFee();
    } catch (e) {
      if (!mounted) return;
      setState(() => _completionEnCours = null);
      context.showErrorSnack(
        "Impossible de compléter l'adresse. Réessayez.",
      );
    }
  }

  Widget _buildAddressCard(Adresse adresse) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _selectedAddress?.id == adresse.id;
    final matchesQuartier =
        _selectedQuartier != null &&
        adresse.quartierId == _selectedQuartier!.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAddress = adresse;
          // Si l'adresse a un quartier différent, mettre à jour le quartier sélectionné
          if (adresse.quartier != null &&
              adresse.quartierId != _selectedQuartier?.id) {
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
            color: isSelected ? cs.primary : cs.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? cs.primary.withValues(alpha: 0.05) : cs.surface,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primary.withValues(alpha: 0.1)
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.home_outlined,
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
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
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
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
                              color: cs.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ] else ...[
                        Icon(
                          Icons.location_off,
                          size: 14,
                          color: cs.error,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Quartier non défini',
                            style: TextStyle(fontSize: 12, color: cs.error),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // ── Adresse sans quartier : on propose de la compléter ──
                  //
                  // Vingt adresses de production (juillet 2025 → mars 2026)
                  // n'ont aucun quartier : elles précèdent la règle qui le rend
                  // obligatoire. Sans lui, `DeliveryDestinationService` n'a pas
                  // de niveau 2 — ni position posée, ni centroïde — et la
                  // commande part en `UNKNOWN`, c'est-à-dire **sans
                  // destination** pour le livreur.
                  //
                  // La carte se contentait de l'annoncer. L'annonce est juste,
                  // mais elle laisse le client devant un problème qu'il n'a pas
                  // les moyens de résoudre depuis cet écran : il faudrait
                  // quitter le tunnel de commande, aller dans « Mes adresses »,
                  // modifier, revenir. Personne ne le fait.
                  //
                  // Le quartier est pourtant **déjà choisi** juste au-dessus.
                  // Un tap le rattache à l'adresse — et la répare pour toutes
                  // les commandes suivantes, pas seulement celle-ci. C'est la
                  // différence entre signaler une donnée manquante et permettre
                  // de la fournir.
                  if (adresse.quartier == null) ...[
                    const SizedBox(height: 6),
                    if (_selectedQuartier != null)
                      _CompleterQuartierBouton(
                        quartier: _selectedQuartier!,
                        enCours: _completionEnCours == adresse.id,
                        onPressed: () => _attacherQuartier(adresse),
                      )
                    else
                      Text(
                        'Choisissez votre quartier ci-dessus pour compléter '
                        'cette adresse.',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],

                  // Fiabilité de la position.
                  //
                  // « Mes adresses » l'affichait, cet écran-ci non — alors que
                  // c'est ici que le client choisit où sa commande sera livrée.
                  // L'information arrivait donc partout sauf au moment où elle
                  // sert : mieux vaut apprendre que le livreur devra appeler
                  // avant de payer qu'en l'ayant au bout du fil.
                  //
                  // ⚠️ Le texte dépend du quartier, et c'est le correctif.
                  // Il annonçait « le livreur sera guidé au quartier » quel
                  // que soit l'état de l'adresse — y compris quand elle n'a
                  // PAS de quartier, cas où `DeliveryDestinationService` n'a
                  // ni position ni centroïde et rend `UNKNOWN`. On promettait
                  // donc un guidage qui n'existe pas, sur la seule adresse
                  // pour laquelle il n'existe pas.
                  if (!adresse.hasPosition) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.gps_off, size: 13, color: cs.error),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            adresse.quartierId == null
                                ? 'Non située et sans quartier — le livreur '
                                      'n’aurait aucun repère. Complétez '
                                      'l’adresse ci-dessus.'
                                : 'Non située — le livreur sera guidé au '
                                      'quartier et devra vous appeler',
                            style: TextStyle(fontSize: 11, color: cs.error),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: cs.primary, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryFeeSummary(double subTotal) {
    final cs = Theme.of(context).colorScheme;
    final deliveryFee = _isDelivery ? (_calculatedDeliveryFee ?? 0) : 0.0;
    // Taux servi par `/platform-settings` — plus de 8 % en dur : le taux est
    // modifiable par l'admin et le serveur facture le sien.
    //
    // ⚠️ Le repli `?? PlatformSettings.fallback` a disparu : il affichait 8 %
    // là où la production facture 15 %, donc un total inférieur de plusieurs
    // centaines de francs à celui que le client allait payer. Sans barème, ce
    // bloc n'annonce plus de total — et `_canContinue` refuse d'avancer.
    final baremeAsync = ref.watch(platformSettingsProvider);
    final settings = baremeAsync.value;
    if (settings == null) {
      return _BaremeIndisponible(
        // ⚠️ `isLoading` seul ne suffit pas : Riverpod 3 **relance**
      // automatiquement un provider en échec, avec un backoff. Entre deux
      // tentatives il repasse donc en chargement tout en portant son erreur,
      // et un écran qui ne regarde que `isLoading` affiche un indicateur
      // perpétuel au lieu de dire ce qui ne va pas. Dès qu'un échec est
      // connu, on l'annonce — la relance continue derrière.
      enChargement: baremeAsync.isLoading && !baremeAsync.hasError,
        onRetry: () => ref.invalidate(platformSettingsProvider),
      );
    }
    final serviceFee = (subTotal * settings.serviceFeeRate).roundToDouble();
    final total = subTotal + deliveryFee + serviceFee;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sous-total', style: TextStyle(fontSize: 15)),
              Text(
                formatPrice(subTotal),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // `Flexible` + `mainAxisSize.min` : sans eux, cette ligne
              // débordait de 24 px — la largeur exacte de l'indicateur de
              // calcul (16) et de son décalage (8) — pendant tout le temps où
              // les frais se calculent, c'est-à-dire juste après que le client
              // a choisi son quartier. Les deux `Row` imbriqués prenaient leur
              // largeur intrinsèque et personne ne cédait de place.
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Flexible(
                      child: Text(
                        'Frais de livraison',
                        style: TextStyle(fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_isDelivery && _deliveryFeeUnavailable)
                    TextButton(
                      onPressed: _calculateDeliveryFee,
                      child: const Text('Prix indisponible — réessayer'),
                    )
                  else
                  Text(
                    _isDelivery
                        ? (_calculatedDeliveryFee != null
                              ? formatPrice(_calculatedDeliveryFee!)
                              : 'Selectionnez un quartier')
                        : 'Gratuit',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: !_isDelivery ? Colors.green : null,
                    ),
                  ),
                  // Le calcul de zone a échoué : on affiche un repli, le
                  // montant final peut différer. Le dire plutôt que de laisser
                  // croire à un montant confirmé.
                  if (_isDelivery && (_quote?.vendorSubsidy ?? 0) > 0)
                    Text(
                      'dont ${formatPrice(_quote!.vendorSubsidy)} offerts par le vendeur',
                      style: const TextStyle(fontSize: 11, color: Colors.green),
                    ),
                  if (_isDelivery &&
                      _quote?.freeDeliveryThreshold != null &&
                      (_quote?.vendorSubsidy ?? 0) == 0 &&
                      subTotal < _quote!.freeDeliveryThreshold!)
                    Text(
                      'Offerte dès ${formatPrice(_quote!.freeDeliveryThreshold!)}',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  if (_isDelivery && _deliveryFeeIsEstimate)
                    Text(
                      'Estimation — montant confirme a la commande',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Frais de service', style: TextStyle(fontSize: 15)),
              Text(
                formatPrice(serviceFee),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
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
                formatPrice(total),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickNewAddressLocation() async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          quartier: _selectedQuartier,
          initialPosition: _newAddressLocation == null
              ? null
              : LatLng(
                  _newAddressLocation!.latitude,
                  _newAddressLocation!.longitude,
                ),
          initialLandmark: _newAddressLocation?.landmark,
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _newAddressLocation = picked);
    }
  }

  Future<void> _calculateDeliveryFee() async {
    if (_restaurantId == null || _selectedQuartier == null) return;

    setState(() {
      _isCalculatingFee = true;
      _deliveryFeeUnavailable = false;
    });

    try {
      final result = await ref.read(
        deliveryFeeProvider(
          restaurantId: _restaurantId!,
          quartierId: _selectedQuartier!.id,
          subTotal: _subTotal,
        ).future,
      );
      if (!mounted) return;
      setState(() {
        _calculatedDeliveryFee = result.fee;
        _quote = result;
        _deliveryFeeIsEstimate = false;
        _isCalculatingFee = false;
      });
    } catch (e) {
      if (!mounted) return;
      // F3-02 — en mode plateforme, le tarif du vendeur ne s'applique plus :
      // s'en servir comme repli annoncerait un prix que le checkout ne
      // facturera pas. Le prix est inconnu, on le dit et on propose de
      // réessayer.
      if (ref.read(platformSettingsProvider).value?.isPlatformDeliveryPricing ??
          false) {
        setState(() {
          _calculatedDeliveryFee = null;
          _quote = null;
          _deliveryFeeUnavailable = true;
          _isCalculatingFee = false;
        });
        return;
      }
      // Le calcul de zone a échoué (réseau instable — le cas nominal à
      // Brazzaville). On retombe sur les frais fixes du vendeur, et à défaut
      // sur le défaut serveur — l'ancienne valeur en dur de 500 FCFA était
      // 500 FCFA sous le défaut backend, écart invisible pour le client.
      final vendorFee = ref
          .read(restaurantControllerProvider(_restaurantId!))
          .value
          ?.fixedDeliveryFee;
      setState(() {
        _calculatedDeliveryFee = vendorFee ?? kDefaultDeliveryFee;
        _deliveryFeeIsEstimate = true;
        _isCalculatingFee = false;
      });
    }
  }

  bool _canContinue() {
    // Sans barème, l'écran suivant refusera de composer un total : autant ne
    // pas y emmener le client. Même règle des deux côtés, une seule source.
    final bareme = ref.read(platformSettingsProvider).value;
    if (bareme == null) return false;
    // Fenêtre de maintenance déclarée par l'administrateur : le checkout
    // l'annonce et refuse. Emmener le client jusque-là ne lui apprendrait
    // rien de plus, une étape plus tard.
    if (bareme.maintenanceMode) return false;

    if (!_isDelivery) return true; // Retrait, pas besoin d'adresse

    // Mode plateforme : pas de devis, pas de prix — on n'emmène pas le client
    // valider un total inconnu.
    if (bareme.isPlatformDeliveryPricing && _calculatedDeliveryFee == null) {
      return false;
    }

    // Pour la livraison, il faut un quartier et une adresse
    if (_selectedQuartier == null) return false;

    if (_useNewAddress) {
      // Une adresse créée ici naît avec `options.quartier.id`
      // (`checkout_page` → `createAdresse(quartierId: …)`) : les deux sources
      // coïncident par construction.
      return _newAddressController.text.trim().isNotEmpty;
    }

    // ⚠️ L'adresse doit porter le quartier — pas seulement la liste déroulante.
    //
    // Ce sont **deux** porteurs pour une même donnée, et ils alimentent des
    // consommateurs différents :
    //
    // ```text
    // liste déroulante ──→ /quartiers/delivery-fee ──→ frais AFFICHÉS
    // adresse.quartierId ─→ DeliveryDestinationService ─→ frais FACTURÉS
    //                                                  └→ destination livreur
    // ```
    //
    // Taper une adresse qui a un quartier les synchronise
    // (`_buildAddressCard`). Une adresse qui n'en a pas ne le peut pas : chez
    // un vendeur `ZONE_BASED`, le client valide le tarif de la zone choisie
    // pendant que le serveur facture `restaurant.fixedDeliveryFee`. Et la
    // commande part en `DESTINATION_UNKNOWN` — ni position posée, ni centroïde
    // de quartier : le livreur n'a **aucun** point de chute.
    //
    // On bloque plutôt qu'on avertit, parce que la réparation est à un tap
    // juste au-dessus (« Utiliser <quartier> »), avec le quartier déjà choisi,
    // et qu'elle répare l'adresse pour toutes les commandes suivantes.
    final adresse = _selectedAddress;
    return adresse != null && adresse.quartierId != null;
  }

  void _continueToCheckout() {
    // Passer les données à la page de confirmation
    context.goNamed(
      AppRoutes.checkout.routeName,
      extra: DeliveryOptions(
        isDelivery: _isDelivery,
        quartier: _selectedQuartier,
        address: _selectedAddress,
        newAddressRue: _useNewAddress
            ? _newAddressController.text.trim()
            : null,
        newAddressLocation: _useNewAddress ? _newAddressLocation : null,
        deliveryFee: _isDelivery
            ? (_calculatedDeliveryFee ?? kDefaultDeliveryFee)
            : 0,
        deliverySubsidy: _isDelivery ? (_quote?.vendorSubsidy ?? 0) : 0,
      ),
    );
  }
}

/// LIL-131 : bandeau "type de vendeur" affiché en tête du checkout pour les
/// vendeurs non-RESTAURANT (boulangerie, fait maison, boissons…). Donne au
/// client une attente claire sur ce qu'il va recevoir.
class _VendorBanner extends StatelessWidget {
  final Restaurant restaurant;
  const _VendorBanner({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final v = restaurant.vendorType;
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.12),
            cs.primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Text(v.emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  restaurant.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
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

  /// Position posée sur la carte pour [newAddressRue]. `null` si le client a
  /// sauté l'étape : l'adresse sera créée sans coordonnées et le serveur
  /// retombera sur le centroïde du quartier.
  final PickedLocation? newAddressLocation;
  final double deliveryFee;

  /// F3-02 — part de la livraison offerte par le vendeur, déjà déduite de
  /// [deliveryFee]. Affichée, jamais recalculée.
  final double deliverySubsidy;

  DeliveryOptions({
    required this.isDelivery,
    this.quartier,
    this.address,
    this.newAddressRue,
    this.newAddressLocation,
    required this.deliveryFee,
    this.deliverySubsidy = 0,
  });
}

/// Bouton « compléter cette adresse avec le quartier sélectionné ».
///
/// Extrait en widget plutôt qu'inline : il porte trois états (repos, envoi en
/// cours, désactivé) et un libellé qui nomme le quartier. Écrit dans la carte,
/// il aurait rallongé une méthode qui construit déjà quatre blocs.
///
/// Le libellé dit ce qui va être écrit — « Utiliser Poto-Poto » — et non
/// « Compléter ». Un bouton qui ne nomme pas son effet oblige à l'essayer pour
/// le découvrir, sur une action qui modifie une donnée enregistrée.
class _CompleterQuartierBouton extends StatelessWidget {
  const _CompleterQuartierBouton({
    required this.quartier,
    required this.enCours,
    required this.onPressed,
  });

  final Quartier quartier;
  final bool enCours;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: enCours ? null : onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: cs.primary,
        ),
        icon: enCours
            ? SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              )
            : const Icon(Icons.add_location_alt_outlined, size: 15),
        label: Text(
          enCours ? 'Enregistrement…' : 'Utiliser ${quartier.nom}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Le barème de frais n'a pas pu être lu — voir `platform_settings_service.dart`.
///
/// Pendant du `_TarifsIndisponibles` du checkout, au même motif : cet écran
/// annonce lui aussi un total, et un total faux se découvre au paiement.
class _BaremeIndisponible extends StatelessWidget {
  const _BaremeIndisponible({
    required this.enChargement,
    required this.onRetry,
  });

  final bool enChargement;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: enChargement
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : Column(
              children: [
                Text(
                  'Frais indisponibles',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Impossible de récupérer les frais actuels. Le total sera '
                  'affiché dès qu’ils seront connus.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Réessayer'),
                ),
              ],
            ),
    );
  }
}
