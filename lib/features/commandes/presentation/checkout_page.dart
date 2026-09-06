import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/common_widgets/app_animations.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/common_widgets/build_loading_state.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/cart/application/draft_orders_provider.dart';
import 'package:lilia_app/features/commandes/data/checkout_controller.dart';
import 'package:lilia_app/features/commandes/presentation/delivery_options_page.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_controller.dart';
import 'package:lilia_app/features/payments/data/payment_service.dart';
import 'package:lilia_app/features/payments/presentation/payment_pending_args.dart';
import 'package:lilia_app/features/user/application/adresse_controller.dart';
import 'package:lilia_app/features/user/application/profile_controller.dart';
import 'package:lilia_app/routing/app_route_enum.dart';
import 'package:lilia_app/features/commandes/domain/checkout_estimate.dart';
import 'package:lilia_app/features/settings/data/platform_settings_service.dart';
import 'package:lilia_app/services/analytics_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../models/cart.dart';
import '../../../models/checkout.dart';
import '../../../models/promo_validation_result.dart';
import '../../../models/restaurant.dart';
import '../../../models/vendor_type.dart';
import '../data/promo_repository.dart';
import 'package:lilia_app/utils/currency.dart';
import 'package:lilia_app/utils/snackbar.dart';

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
  final TextEditingController _promoController = TextEditingController();

  PromoValidationResult? _promoResult;
  bool _promoLoading = false;
  String? _promoError;
  bool _useLoyaltyPoints = false;
  String _selectedPaymentMethod = 'MTN_MOMO';

  /// Numéro Mobile Money qui paiera, distinct du téléphone de contact.
  ///
  /// Le même champ servait aux deux. Or on paie souvent depuis un autre
  /// téléphone que celui qu'on donne au livreur (numéro de la maison, du
  /// conjoint) — et avec un prestataire qui envoie réellement une demande, se
  /// tromper de numéro n'est plus une coquille sur un papier, c'est un paiement
  /// qui n'arrive pas.
  final TextEditingController _momoPhoneController = TextEditingController();
  String? _idempotencyKey;
  // LIL-122 : date/heure choisies pour les commandes preorder (madeToOrder).
  // Null tant que le client n'a pas ouvert le picker.
  DateTime? _scheduledFor;

  String _getOrCreateIdempotencyKey() {
    _idempotencyKey ??= _generateUuidV4();
    return _idempotencyKey!;
  }

  String _generateUuidV4() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  void dispose() {
    _noteController.dispose();
    _phoneController.dispose();
    _momoPhoneController.dispose();
    _promoController.dispose();
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
    final settingsAsync = ref.watch(platformSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          tooltip: 'Retour',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed(AppRoutes.deliveryOptions.routeName),
        ),
        title: const Text(
          'Confirmer la commande',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: cartAsync.when(
        data: (cart) {
          if (cart == null || cart.items.isEmpty) {
            return const Center(child: Text('Votre panier est vide'));
          }

          // Estimation affichée avant commande. Le montant réellement dû est
          // celui de la commande créée par le serveur (`order.total`), repris
          // tel quel dans la modale de paiement : ce bloc ne sert qu'à donner
          // au client un ordre de grandeur cohérent.
          //
          // Les paramètres viennent de `/platform-settings` et non plus de
          // constantes en dur : le jour où l'admin passe la commission de 8 à
          // 10 %, l'estimation suit sans release mobile.
          final settings = settingsAsync.value ?? PlatformSettings.fallback;
          final estimate = CheckoutEstimate.compute(
            subTotal: cart.totalPrice,
            deliveryFee: _promoResult?.newDeliveryFee ?? options.deliveryFee,
            promoDiscount: _promoResult?.discountAmount ?? 0,
            loyaltyPoints: userProfileAsync.value?.loyaltyPoints ?? 0,
            useLoyaltyPoints: _useLoyaltyPoints,
            settings: settings,
          );
          final int userPoints = userProfileAsync.value?.loyaltyPoints ?? 0;
          // Réduction réellement applicable si le client active ses points —
          // affichée avant l'activation du switch. On montrait auparavant la
          // valeur brute du solde, qui pouvait dépasser le montant dû.
          final double potentialLoyaltyDiscount = CheckoutEstimate.compute(
            subTotal: cart.totalPrice,
            deliveryFee: _promoResult?.newDeliveryFee ?? options.deliveryFee,
            promoDiscount: _promoResult?.discountAmount ?? 0,
            loyaltyPoints: userPoints,
            useLoyaltyPoints: true,
            settings: settings,
          ).loyaltyDiscount;
          final double subTotal = estimate.subTotal;
          final double deliveryFee = estimate.deliveryFee;
          final double serviceFee = estimate.serviceFee;
          final double discountAmount = estimate.promoDiscount;
          final double loyaltyDiscount = estimate.loyaltyDiscount;
          final double total = estimate.total;
          final String restaurantId = cart.items.first.product.restaurantId;

          // ⚠️ Plus aucun `begin_checkout` ici.
          //
          // Il était émis depuis `build`, protégé par un simple booléen
          // d'instance : suffisant contre les reconstructions, inopérant dès
          // que l'écran est quitté puis rouvert — ce qui arrive à chaque
          // correction d'adresse. Il est désormais émis sur le bouton
          // « Passer la commande » du panier, où le web émet le sien.

          // LIL-131 : on watch le restaurant pour le bandeau vendor + adapter
          // les libellés (ex: "Préparée par boulangerie X").
          final restaurantAsync = ref.watch(
            restaurantControllerProvider(restaurantId),
          );
          final restaurant = restaurantAsync.value;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bandeau vendor (non-RESTAURANT uniquement)
                  if (restaurant != null &&
                      restaurant.vendorType != VendorType.RESTAURANT) ...[
                    _CheckoutVendorBanner(restaurant: restaurant),
                    const SizedBox(height: 16),
                  ],
                  // === RÉCAPITULATIF MODE DE LIVRAISON ===
                  _buildDeliveryRecap(options),
                  const SizedBox(height: 24),

                  // === SECTION TÉLÉPHONE ===
                  _buildSectionTitle('Numero de telephone'),
                  const SizedBox(height: 8),
                  userProfileAsync.when(
                    data: (user) => _buildPhoneSection(user.phone),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
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

                  // === SECTION CODE PROMO ===
                  _buildSectionTitle('Code promo'),
                  const SizedBox(height: 8),
                  _buildPromoSection(
                    restaurantId: restaurantId,
                    subTotal: subTotal,
                    originalDeliveryFee: options.deliveryFee,
                  ),
                  const SizedBox(height: 24),

                  // === SECTION POINTS DE FIDELITE ===
                  if (userPoints >= settings.loyaltyMinRedemption) ...[
                    _buildSectionTitle('Points de fidelite'),
                    const SizedBox(height: 8),
                    Material(
                      color: Colors.amber[50],
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.amber.withValues(alpha: 0.4),
                        ),
                      ),
                      child: SwitchListTile(
                        value: _useLoyaltyPoints,
                        onChanged: (v) => setState(() => _useLoyaltyPoints = v),
                        title: Text(
                          'Utiliser mes points',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Reduction de ${formatPrice(potentialLoyaltyDiscount)}',
                          style: TextStyle(color: Colors.amber[800]),
                        ),
                        secondary: const Icon(Icons.stars, color: Colors.amber),
                        activeThumbColor: Colors.amber[700],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // === SECTION PREORDER (LIL-122) ===
                  // Visible uniquement si le panier contient des produits
                  // madeToOrder=true. Force le client à choisir un slot.
                  if (cart.isPreorderCart) ...[
                    _buildSectionTitle('Quand voulez-vous récupérer ?'),
                    const SizedBox(height: 8),
                    _buildPreorderSlotPicker(),
                    const SizedBox(height: 24),
                  ],

                  // === SECTION RÉSUMÉ ===
                  _buildSectionTitle('Resume de la commande'),
                  const SizedBox(height: 12),
                  _buildOrderSummary(
                    cart: cart,
                    subTotal: subTotal,
                    deliveryFee: deliveryFee,
                    originalDeliveryFee: options.deliveryFee,
                    serviceFee: serviceFee,
                    discountAmount: discountAmount,
                    loyaltyDiscount: loyaltyDiscount,
                    total: total,
                    options: options,
                  ).fadeSlideIn(),
                  const SizedBox(height: 24),

                  // === SECTION PAIEMENT ===
                  _buildSectionTitle('Mode de paiement'),
                  const SizedBox(height: 8),
                  _buildPaymentSection(),
                  const SizedBox(height: 16),

                  // === DISCLAIMER PREORDER (LIL-122 décision 4b) ===
                  // Avertit le client que le paiement upfront engage mais que
                  // le vendeur peut annuler tard et que le remboursement met
                  // jusqu'à 48h. Pas de blocage, juste de la transparence.
                  if (cart.isPreorderCart) ...[
                    _buildPreorderDisclaimer(),
                    const SizedBox(height: 16),
                  ],

                  // === BOUTON DE VALIDATION ===
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed:
                          checkoutState.isLoading ||
                              (cart.isPreorderCart && _scheduledFor == null)
                          ? null
                          : () => _startPaymentFlow(
                              context,
                              options,
                              restaurantId,
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
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
                  const SizedBox(height: 12),

                  // === BOUTON ENREGISTRER POUR PLUS TARD ===
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: checkoutState.isLoading
                          ? null
                          : () => _saveDraft(cart, restaurantId),
                      icon: const Icon(Icons.bookmark_border_rounded, size: 20),
                      label: const Text(
                        'Enregistrer pour plus tard',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: options.isDelivery
            ? cs.primary.withValues(alpha: 0.1)
            : Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: options.isDelivery
              ? cs.primary.withValues(alpha: 0.3)
              : Colors.green.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              options.isDelivery ? Icons.delivery_dining : Icons.store,
              color: options.isDelivery ? cs.primary : Colors.green,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  options.isDelivery
                      ? 'Livraison a domicile'
                      : 'Retrait au restaurant',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (options.isDelivery && options.quartier != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Quartier: ${options.quartier!.nom}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                  ),
                ],
                if (options.isDelivery && options.address != null) ...[
                  Text(
                    options.address!.rue,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                  ),
                ],
                if (options.isDelivery && options.newAddressRue != null) ...[
                  Text(
                    options.newAddressRue!,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: () =>
                context.goNamed(AppRoutes.deliveryOptions.routeName),
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  // ─── Preorder slot picker (LIL-122) ────────────────────────────────────
  // Affiché si cart.isPreorderCart. Le client choisit date + heure ; on
  // contraint à [now + 24h, now + 7 jours] localement. Le backend a la
  // décision finale sur le lead time exact du vendeur (PreorderValidator).

  Widget _buildPreorderSlotPicker() {
    final scheme = Theme.of(context).colorScheme;
    final hasSlot = _scheduledFor != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasSlot
              ? scheme.primary
              : scheme.primary.withValues(alpha: 0.3),
          width: hasSlot ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Date et heure de retrait',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              if (!hasSlot)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Requis',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Minimum 24h à l\'avance, maximum 7 jours.',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _pickPreorderSlot,
            icon: Icon(hasSlot ? Icons.event_available : Icons.event, size: 18),
            label: Text(
              hasSlot
                  ? _formatScheduledFor(_scheduledFor!)
                  : 'Choisir la date et l\'heure',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: hasSlot ? scheme.primary : scheme.onSurface,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPreorderSlot() async {
    final now = DateTime.now();
    final initialDate = _scheduledFor ?? now.add(const Duration(hours: 24));
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.add(const Duration(hours: 24)),
      lastDate: now.add(const Duration(days: 7)),
      helpText: 'Date de retrait',
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      helpText: 'Heure de retrait',
    );
    if (pickedTime == null) return;
    setState(() {
      _scheduledFor = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  String _formatScheduledFor(DateTime dt) {
    const days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];
    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${days[dt.weekday - 1]} ${dt.day} ${months[dt.month - 1]} à $hh:$mm';
  }

  // ─── Disclaimer preorder (LIL-122 décision 4b) ─────────────────────────

  Widget _buildPreorderDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Commande sur commande',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Le vendeur peut annuler jusqu\'à la veille (J-1). En cas d\'annulation, le remboursement se fait sous 48 heures.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: Colors.orange[900],
                  ),
                ),
              ],
            ),
          ),
        ],
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
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
    return Column(
      children: [
        _buildPaymentOption(
          method: 'MTN_MOMO',
          label: 'MTN Mobile Money',
          color: Colors.amber.shade700,
        ),
        const SizedBox(height: 12),
        _buildPaymentOption(
          method: 'AIRTEL_MONEY',
          label: 'Airtel Money',
          color: Colors.red.shade600,
        ),
        const SizedBox(height: 16),
        _buildMomoPhoneField(),
      ],
    );
  }

  /// Numéro Mobile Money qui recevra la demande de paiement.
  ///
  /// Laissé vide, le téléphone de contact est utilisé — c'est le cas le plus
  /// fréquent, et imposer une seconde saisie identique serait une friction de
  /// plus sur un écran qui en compte déjà.
  Widget _buildMomoPhoneField() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _momoPhoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Numéro Mobile Money (si différent)',
            hintText: _phoneController.text.trim().isEmpty
                ? '06 123 45 67'
                : _phoneController.text.trim(),
            prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            final input = (value ?? '').trim();
            // Champ facultatif : vide = on paie avec le numéro de contact.
            if (input.isEmpty) return null;
            final valid = ref
                .read(paymentServiceProvider)
                .validatePhoneNumber(input);
            return valid ? null : 'Numéro Mobile Money congolais invalide';
          },
        ),
        const SizedBox(height: 6),
        Text(
          'La demande de paiement arrivera sur ce numéro. Laissez vide pour '
          'utiliser votre numéro de contact.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildPaymentOption({
    required String method,
    required String label,
    required Color color,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedPaymentMethod == method;

    // In dark mode use a lighter tint so text stays legible
    final displayColor = isDark && isSelected
        ? Color.lerp(color, Colors.white, 0.45)!
        : color;

    final bgColor = isSelected
        ? (isDark
              ? color.withValues(alpha: 0.18)
              : color.withValues(alpha: 0.08))
        : cs.surfaceContainerHighest;
    final borderColor = isSelected
        ? displayColor.withValues(alpha: isDark ? 0.6 : 0.4)
        : cs.outlineVariant;

    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.phone_android,
              color: isSelected ? displayColor : cs.onSurfaceVariant,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? displayColor : cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Paiement securise',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            isSelected
                ? Icon(Icons.check_circle, color: displayColor)
                : Icon(Icons.circle_outlined, color: cs.outlineVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoSection({
    required String restaurantId,
    required double subTotal,
    required double originalDeliveryFee,
  }) {
    // Code promo déjà appliqué : afficher un récap avec bouton supprimer
    if (_promoResult != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _promoResult!.code,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.green.shade800,
                    ),
                  ),
                  if (_promoResult!.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _promoResult!.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    _promoResult!.discountLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Fermer',
              icon: const Icon(Icons.close, size: 20),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              onPressed: () {
                setState(() {
                  _promoResult = null;
                  _promoError = null;
                  _promoController.clear();
                });
              },
            ),
          ],
        ),
      );
    }

    // Champ de saisie du code promo
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _promoController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Entrer un code promo',
                  prefixIcon: const Icon(Icons.local_offer_outlined, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  errorText: _promoError,
                ),
                onChanged: (_) {
                  if (_promoError != null) {
                    setState(() => _promoError = null);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _promoLoading
                    ? null
                    : () => _applyPromoCode(
                        restaurantId: restaurantId,
                        subTotal: subTotal,
                        deliveryFee: originalDeliveryFee,
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: _promoLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Appliquer',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _applyPromoCode({
    required String restaurantId,
    required double subTotal,
    required double deliveryFee,
  }) async {
    final code = _promoController.text.trim();
    if (code.isEmpty) {
      setState(() => _promoError = 'Veuillez entrer un code promo');
      return;
    }

    setState(() {
      _promoLoading = true;
      _promoError = null;
    });

    try {
      final result = await ref
          .read(promoRepositoryProvider.notifier)
          .validateCode(
            code: code,
            restaurantId: restaurantId,
            subTotal: subTotal,
            deliveryFee: deliveryFee,
          );

      if (!mounted) return;
      setState(() {
        _promoResult = result;
        _promoLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      String message = e.toString();
      if (message.startsWith('Exception: ')) {
        message = message.substring(11);
      }
      setState(() {
        _promoError = message;
        _promoLoading = false;
      });
    }
  }

  Widget _buildOrderSummary({
    required Cart cart,
    required double subTotal,
    required double deliveryFee,
    required double originalDeliveryFee,
    required double serviceFee,
    required double discountAmount,
    required double loyaltyDiscount,
    required double total,
    required DeliveryOptions options,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
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
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formatPrice(((menuInfo?.prix ?? 0) * quantite)),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  ...groupItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(left: 16, top: 2),
                      child: Text(
                        '- ${item.product.nom}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
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
                    formatPrice((item.quantite * item.variant.prix)),
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
              _buildDeliveryFeeLabel(
                isDelivery: options.isDelivery,
                deliveryFee: deliveryFee,
                originalDeliveryFee: originalDeliveryFee,
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
          // Ligne réduction promo
          if (_promoResult != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_offer,
                        size: 16,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Promo ${_promoResult!.code}',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.green,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _promoResult!.discountLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
          // Ligne reduction fidelite
          if (_useLoyaltyPoints && loyaltyDiscount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.stars, size: 16, color: Colors.amber),
                    SizedBox(width: 4),
                    Text(
                      'Points fidelite',
                      style: TextStyle(fontSize: 15, color: Colors.amber),
                    ),
                  ],
                ),
                Text(
                  '- ${loyaltyDiscount.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          ],
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

  Widget _buildDeliveryFeeLabel({
    required bool isDelivery,
    required double deliveryFee,
    required double originalDeliveryFee,
  }) {
    if (!isDelivery) {
      return const Text(
        'Gratuit',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Colors.green,
        ),
      );
    }

    final isFreeDeliveryPromo =
        _promoResult != null &&
        _promoResult!.discountType == DiscountType.freeDelivery;

    if (isFreeDeliveryPromo) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatPrice(originalDeliveryFee),
            style: TextStyle(
              fontSize: 14,
              decoration: TextDecoration.lineThrough,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Gratuit',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.green,
            ),
          ),
        ],
      );
    }

    return Text(
      formatPrice(deliveryFee),
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    );
  }

  Widget _buildSummaryRow(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 15)),
        Text(
          formatPrice(value),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Future<void> _saveDraft(Cart cart, String restaurantId) async {
    try {
      // Recuperer le nom du restaurant
      final restaurant = await ref.read(
        restaurantControllerProvider(restaurantId).future,
      );
      final restaurantName = restaurant.name;

      await ref
          .read(draftOrdersProvider.notifier)
          .saveDraft(cart: cart, restaurantName: restaurantName);

      if (!mounted) return;

      context.showSnack('Commande enregistree pour plus tard');

      // Depiler checkout et delivery-options du tab panier
      // pour que le retour au tab panier affiche le CartScreen
      Navigator.of(context).popUntil((route) => route.isFirst);

      // Naviguer vers l'ecran des brouillons (tab profil)
      context.goNamed(AppRoutes.draftOrders.routeName);
    } catch (e) {
      if (!mounted) return;
      context.showErrorSnack('Erreur: $e');
    }
  }

  /// Tunnel de paiement, en trois temps.
  ///
  /// L'ordre historique était inversé : la modale d'instructions était affichée
  /// **avant** la création de la commande et du paiement, avec un numéro et un
  /// montant calculés côté client. Conséquences : le numéro Airtel affiché
  /// était un placeholder, le montant pouvait diverger de celui facturé, et un
  /// échec de `POST /payments` était avalé — le client payait un virement que
  /// l'admin ne pouvait rattacher à rien.
  ///
  /// Désormais : commande → paiement → instructions issues du serveur.
  Future<void> _startPaymentFlow(
    BuildContext context,
    DeliveryOptions options,
    String restaurantId,
  ) async {
    if (!_formKey.currentState!.validate()) {
      if (context.mounted) {
        context.showErrorSnack('Veuillez remplir le numero de telephone');
      }
      return;
    }

    // Préparer l'adresse si c'est une livraison
    String? finalAddressId;
    if (options.isDelivery) {
      if (options.newAddressRue != null) {
        try {
          final newAddress = await ref
              .read(adresseControllerProvider.notifier)
              .createAdresse(
                rue: options.newAddressRue!,
                quartierId: options.quartier?.id,
                // La position posée sur la carte à l'étape précédente. Sans
                // elle, l'adresse naît sans coordonnées et le serveur
                // retombera sur le centroïde du quartier — jamais sur le GPS
                // du téléphone, qui n'a rien à voir avec la destination.
                latitude: options.newAddressLocation?.latitude,
                longitude: options.newAddressLocation?.longitude,
                landmark: options.newAddressLocation?.landmark,
              );
          finalAddressId = newAddress.id;
        } catch (e) {
          if (!context.mounted) return;
          _showOrderError(
            context,
            Exception(
              'Impossible de sauvegarder l\'adresse de livraison. Veuillez réessayer.',
            ),
          );
          return;
        }
      } else if (options.address != null) {
        finalAddressId = options.address!.id;
      }
    }

    // ─── 1. Créer la commande ────────────────────────────────────────────────
    final Checkout checkout;
    try {
      checkout = await ref
          .read(checkoutControllerProvider.notifier)
          .placeOrder(
            adresseId: finalAddressId,
            paymentMethod: _selectedPaymentMethod,
            isDelivery: options.isDelivery,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            contactPhone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            promoCode: _promoResult?.code,
            idempotencyKey: _getOrCreateIdempotencyKey(),
            useLoyaltyPoints: _useLoyaltyPoints,
            scheduledFor: _scheduledFor,
          );
    } catch (e) {
      // Catégorie d'échec seulement : `e.toString()` transportait le message du
      // serveur, donc du texte libre susceptible de contenir un numéro ou une
      // référence de transaction.
      AnalyticsService.trackOrderFailed(
        paymentMethod: _selectedPaymentMethod,
        failureKind: 'checkout_rejected',
      );
      if (!context.mounted) return;
      _showOrderError(context, e);
      return;
    }

    // Nouvelle clé pour la prochaine commande.
    _idempotencyKey = null;

    // `order_created` — la commande **existe** : le serveur a rendu son
    // identifiant et son montant. Ni le clic sur le bouton, ni l'arrivée sur un
    // écran de confirmation : le checkout échoue régulièrement (panier sous le
    // minimum du vendeur, produit épuisé, vendeur fermé).
    AnalyticsService.trackOrderCreated(
      orderId: checkout.id,
      amount: checkout.total,
      itemCount: checkout.items.length,
    );

    // ─── 2. Créer le paiement — bloquant, car il porte les instructions ──────
    final PaymentResponse payment;
    try {
      payment = await _createPaymentWithRetry(checkout);
    } catch (e, st) {
      // Sans ligne `Payment`, la commande n'apparaît pas dans l'écran admin
      // « Paiements à confirmer » : un virement du client ne serait rattachable
      // à rien. On ne masque plus l'échec derrière un `debugPrint`.
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) => scope.setContexts('checkout', {
          'orderId': checkout.id,
          'paymentMethod': _selectedPaymentMethod,
        }),
      );
      AnalyticsService.trackOrderFailed(
        paymentMethod: _selectedPaymentMethod,
        failureKind: 'payment_open_failed',
      );
      if (!context.mounted) return;
      await _showPaymentRecoveryDialog(context, checkout);
      return;
    }

    // `payment_started` — une tentative d'encaissement existe côté serveur.
    // Unique par `paymentId` : les deux essais de `_createPaymentWithRetry`
    // rendent la **même** ligne `Payment` (le backend réutilise celle qui est
    // PENDING), donc un seul paiement lancé — ce qui est la vérité.
    AnalyticsService.trackPaymentStarted(
      paymentId: payment.paymentId,
      orderId: checkout.id,
      paymentMethod: _selectedPaymentMethod,
      amount: payment.amount > 0 ? payment.amount : checkout.total,
    );

    // ─── 3. Suite du parcours, selon le rail d'encaissement du serveur ───────
    //
    // Le mode vient du backend : basculer de pawaPay au virement manuel (ou
    // l'inverse) ne doit pas demander une release sur les stores.
    if (!context.mounted) return;

    if (payment.isSettled) {
      // Commande intégralement réglée en points de fidélité : rien à payer.
      //
      // Le serveur a marqué l'encaissement `SUCCESS` à la création — c'est bien
      // une confirmation de la source de vérité, pas une supposition d'écran.
      // Sans cet appel, ces commandes apparaîtraient comme des paiements lancés
      // et jamais aboutis.
      AnalyticsService.trackPaymentSuccess(
        paymentId: payment.paymentId,
        orderId: checkout.id,
        paymentMethod: _selectedPaymentMethod,
        amount: payment.amount > 0 ? payment.amount : checkout.total,
      );
      ref.read(cartControllerProvider.notifier).clearCart();
      context.goNamed(AppRoutes.orderSuccess.routeName);
      return;
    }

    if (payment.isInteractive) {
      // Le client valide sur son téléphone : on l'accompagne pendant l'attente.
      // ⚠️ Le panier n'est PAS vidé ici — il ne l'est qu'à la confirmation. Le
      // vider maintenant effacerait la sélection d'un client dont le paiement
      // peut échouer.
      context.goNamed(
        AppRoutes.paymentPending.routeName,
        pathParameters: {'paymentId': payment.paymentId},
        extra: PaymentPendingArgs(
          orderId: checkout.id,
          amount: payment.amount > 0 ? payment.amount : checkout.total,
          method: _selectedPaymentMethod,
        ),
      );
      return;
    }

    // Mode manuel : instructions de virement, telles que renvoyées par le serveur.
    await _showPaymentInstructionsDialog(context, checkout, payment);
  }

  /// Deux tentatives : l'appel est **sûr à rejouer**.
  ///
  /// Le backend réutilise la ligne `Payment` PENDING existante — avec le MÊME
  /// identifiant prestataire — au lieu d'en créer une seconde. Un rejeu ne peut
  /// donc pas produire un second débit : le prestataire répond
  /// `DUPLICATE_IGNORED`.
  ///
  /// Aucun montant n'est transmis : il vient de `order.total`, côté serveur.
  Future<PaymentResponse> _createPaymentWithRetry(Checkout checkout) async {
    final paymentService = ref.read(paymentServiceProvider);
    Object? lastError;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await paymentService.createPayment(
          orderId: checkout.id,
          phoneNumber: _paymentPhone(),
          method: _selectedPaymentMethod,
        );
      } catch (e) {
        lastError = e;
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
    }
    throw lastError!;
  }

  /// Numéro qui paiera.
  ///
  /// Distinct du téléphone de contact quand le client en a saisi un : on paie
  /// souvent depuis un autre appareil que celui qu'on donne au livreur.
  String _paymentPhone() {
    final momo = _momoPhoneController.text.trim();
    return momo.isNotEmpty ? momo : _phoneController.text.trim();
  }

  /// Écran de reprise : la commande existe, le paiement n'a pas pu être
  /// enregistré. On ne laisse pas le client devant des instructions de paiement
  /// qui ne mènent nulle part.
  Future<void> _showPaymentRecoveryDialog(
    BuildContext context,
    Checkout checkout,
  ) async {
    final cs = Theme.of(context).colorScheme;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: cs.tertiary),
            const SizedBox(width: 8),
            const Expanded(child: Text('Commande enregistrée')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Votre commande n°${checkout.id.substring(checkout.id.length - 6).toUpperCase()} '
              'a bien été créée, mais nous n\'avons pas pu préparer les instructions '
              'de paiement.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Ne faites aucun virement pour l\'instant. Réessayez, ou retrouvez '
              'la commande dans « Mes commandes » pour finaliser le paiement.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(cartControllerProvider.notifier).clearCart();
              context.goNamed(AppRoutes.commandes.routeName);
            },
            child: const Text('Voir mes commandes'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                final payment = await _createPaymentWithRetry(checkout);
                if (!context.mounted) return;
                await _showPaymentInstructionsDialog(
                  context,
                  checkout,
                  payment,
                );
              } catch (e) {
                if (!context.mounted) return;
                await _showPaymentRecoveryDialog(context, checkout);
              }
            },
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  /// Modale d'instructions. Numéro, montant et référence viennent **tous** du
  /// backend : rien n'est recalculé ni codé en dur ici.
  Future<void> _showPaymentInstructionsDialog(
    BuildContext context,
    Checkout checkout,
    PaymentResponse payment,
  ) async {
    final isMtn = _selectedPaymentMethod == 'MTN_MOMO';
    final instructions = payment.instructions;

    // Le montant fait autorité côté serveur (`order.total`), pas côté client.
    final amountDue = instructions?.amount ?? checkout.total.toDouble();
    final paymentPhoneNumber = instructions?.phone ?? '';
    final methodLabel =
        instructions?.methodLabel ??
        (isMtn ? 'MTN Mobile Money' : 'Airtel Money');
    final reference = instructions?.reference ?? payment.referenceId;

    final dialogIsDark = Theme.of(context).brightness == Brightness.dark;
    final rawMethodColor = isMtn ? Colors.amber.shade700 : Colors.red.shade600;
    final methodColor = dialogIsDark
        ? Color.lerp(rawMethodColor, Colors.white, 0.45)!
        : rawMethodColor;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final cs = Theme.of(context).colorScheme;
        final isDark = dialogIsDark;
        final cardBg = isDark
            ? methodColor.withValues(alpha: 0.15)
            : methodColor.withValues(alpha: 0.08);
        final cardBorder = methodColor.withValues(alpha: 0.3);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.payment, color: methodColor, size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Instructions de paiement',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pour valider votre commande, effectuez le paiement via $methodLabel:',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                // Numéro de paiement — fourni par le backend
                Semantics(
                  label: 'Numéro $methodLabel : $paymentPhoneNumber',
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Numero $methodLabel',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                paymentPhoneNumber,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.copy, color: methodColor),
                          tooltip: 'Copier le numéro',
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: paymentPhoneNumber),
                            );
                            context.showSnack('Numero copie!');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Montant — celui de la commande créée, pas un recalcul client
                Semantics(
                  label: 'Montant à envoyer : ${formatPrice(amountDue)}',
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Text('Montant: ', style: TextStyle(fontSize: 14)),
                        Text(
                          formatPrice(amountDue),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (reference.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  // Référence : seul moyen fiable pour l'admin de rapprocher un
                  // virement d'une commande. Elle n'était jamais affichée.
                  Semantics(
                    label: 'Référence de paiement : $reference',
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reference a rappeler',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  reference,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.copy, color: methodColor),
                            tooltip: 'Copier la référence',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: reference));
                              context.showSnack('Reference copiee!');
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Instructions USSD
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.blue.withValues(alpha: 0.12)
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Etapes:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (isMtn) ...[
                        const Text(
                          '1. Composez *105#',
                          style: TextStyle(fontSize: 13),
                        ),
                        const Text(
                          '2. Choisir "Envoi d\'argent"',
                          style: TextStyle(fontSize: 13),
                        ),
                        const Text(
                          '3. Choisir "Abonne Mobile Money"',
                          style: TextStyle(fontSize: 13),
                        ),
                        const Text(
                          '4. Entrer le numero ci-dessus',
                          style: TextStyle(fontSize: 13),
                        ),
                        const Text(
                          '5. Entrer le montant',
                          style: TextStyle(fontSize: 13),
                        ),
                        const Text(
                          '6. Confirmer avec votre code PIN',
                          style: TextStyle(fontSize: 13),
                        ),
                      ] else ...[
                        const Text(
                          '1. Composez *555#',
                          style: TextStyle(fontSize: 13),
                        ),
                        const Text(
                          '2. Choisir "Envoyer de l\'argent"',
                          style: TextStyle(fontSize: 13),
                        ),
                        const Text(
                          '3. Entrer le numero ci-dessus',
                          style: TextStyle(fontSize: 13),
                        ),
                        const Text(
                          '4. Entrer le montant',
                          style: TextStyle(fontSize: 13),
                        ),
                        const Text(
                          '5. Confirmer avec votre code PIN',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              // La commande existe déjà : « Plus tard » ne l'annule pas, elle
              // reste payable depuis « Mes commandes » jusqu'à expiration.
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ref.read(cartControllerProvider.notifier).clearCart();
                context.goNamed(AppRoutes.commandes.routeName);
              },
              child: const Text('Plus tard'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ref.read(cartControllerProvider.notifier).clearCart();
                context.goNamed(AppRoutes.orderSuccess.routeName);
              },
              style: ElevatedButton.styleFrom(backgroundColor: methodColor),
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

  void _showOrderError(BuildContext context, Object error) {
    // Nettoyer le message d'erreur
    String message = error.toString();
    if (message.startsWith('Exception: ')) {
      message = message.substring(11);
    }

    // Déterminer l'icône et la couleur selon le type d'erreur
    IconData icon = Icons.error_outline;
    Color iconColor = Colors.red;
    String title = 'Erreur de commande';

    if (message.contains('fermé')) {
      icon = Icons.store;
      iconColor = Colors.orange;
      title = 'Restaurant fermé';
    } else if (message.contains('rupture') || message.contains('stock')) {
      icon = Icons.remove_shopping_cart;
      iconColor = Colors.orange;
      title = 'Produit indisponible';
    } else if (message.contains('minimum') || message.contains('montant')) {
      icon = Icons.monetization_on;
      iconColor = Colors.amber.shade700;
      title = 'Montant insuffisant';
    } else if (message.contains('panier') && message.contains('vide')) {
      icon = Icons.shopping_cart_outlined;
      iconColor = Colors.grey;
      title = 'Panier vide';
    } else if (message.contains('adresse')) {
      icon = Icons.location_off;
      iconColor = Colors.blue;
      title = 'Problème d\'adresse';
    } else if (message.contains('promo') || message.contains('code')) {
      icon = Icons.local_offer;
      iconColor = Colors.purple;
      title = 'Code promo invalide';
    } else if (message.contains('reconnecter') ||
        message.contains('authentif')) {
      icon = Icons.lock_outline;
      iconColor = Colors.red;
      title = 'Session expirée';
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 17))),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }
}

/// LIL-131 : bandeau "type de vendeur" en tête du checkout. Permet au client
/// de vérifier d'un coup d'œil le type de commerçant (boulangerie, fait
/// maison…) avant de valider.
class _CheckoutVendorBanner extends StatelessWidget {
  final Restaurant restaurant;
  const _CheckoutVendorBanner({required this.restaurant});

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
