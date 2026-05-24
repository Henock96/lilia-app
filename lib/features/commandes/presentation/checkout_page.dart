import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/common_widgets/build_loading_state.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/cart/application/draft_orders_provider.dart';
import 'package:lilia_app/features/commandes/data/checkout_controller.dart';
import 'package:lilia_app/features/commandes/presentation/delivery_options_page.dart';
import 'package:lilia_app/features/home/data/remote/restaurant_controller.dart';
import 'package:lilia_app/features/user/application/adresse_controller.dart';
import 'package:lilia_app/features/user/application/profile_controller.dart';
import 'package:lilia_app/routing/app_route_enum.dart';
import 'package:lilia_app/services/analytics_service.dart';

import '../../../constants/app_constants.dart';
import '../../../models/cart.dart';
import '../../../models/promo_validation_result.dart';
import '../data/promo_repository.dart';

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

  bool _analyticsLogged = false;
  PromoValidationResult? _promoResult;
  bool _promoLoading = false;
  String? _promoError;
  bool _useLoyaltyPoints = false;
  String _selectedPaymentMethod = 'MTN_MOMO';
  String? _idempotencyKey;

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

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
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

          final double subTotal = cart.totalPrice;
          final double deliveryFee =
              _promoResult?.newDeliveryFee ?? options.deliveryFee;
          final double serviceFee = (subTotal * AppConstants.serviceFeeRate)
              .roundToDouble();
          final double discountAmount = _promoResult?.discountAmount ?? 0;
          final int userPoints = userProfileAsync.value?.loyaltyPoints ?? 0;
          final double loyaltyDiscount = userPoints * 5.0;
          final double total =
              subTotal +
              deliveryFee +
              serviceFee -
              discountAmount -
              (_useLoyaltyPoints ? loyaltyDiscount : 0);
          final String restaurantId = cart.items.first.product.restaurantId;

          // Analytics: début du checkout (une seule fois)
          if (!_analyticsLogged) {
            _analyticsLogged = true;
            AnalyticsService.logBeginCheckout(
              total: total,
              isDelivery: options.isDelivery,
            );
          }

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
                  if (userPoints >= 100) ...[
                    _buildSectionTitle('Points de fidelite'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
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
                          'Reduction de ${loyaltyDiscount.toStringAsFixed(0)} FCFA',
                          style: TextStyle(color: Colors.amber[800]),
                        ),
                        secondary: const Icon(Icons.stars, color: Colors.amber),
                        activeThumbColor: Colors.amber[700],
                      ),
                    ),
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
                  ),
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
                          : () => _showPaymentInstructions(
                              context,
                              total,
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
                        '${((menuInfo?.prix ?? 0) * quantite).toStringAsFixed(0)} FCFA',
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
                '${serviceFee.toStringAsFixed(0)} FCFA',
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
                '${total.toStringAsFixed(0)} FCFA',
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
            '${originalDeliveryFee.toStringAsFixed(0)} FCFA',
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
      '${deliveryFee.toStringAsFixed(0)} FCFA',
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Commande enregistree pour plus tard'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Depiler checkout et delivery-options du tab panier
      // pour que le retour au tab panier affiche le CartScreen
      Navigator.of(context).popUntil((route) => route.isFirst);

      // Naviguer vers l'ecran des brouillons (tab profil)
      context.goNamed(AppRoutes.draftOrders.routeName);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showPaymentInstructions(
    BuildContext context,
    double total,
    DeliveryOptions options,
    String restaurantId,
  ) async {
    if (!_formKey.currentState!.validate()) {
      // Montrer un feedback si le formulaire n'est pas valide
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez remplir le numero de telephone'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

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

    if (!context.mounted) return;

    final isMtn = _selectedPaymentMethod == 'MTN_MOMO';
    final paymentPhoneNumber = isMtn
        ? AppConstants.mtnMomoPaymentNumber
        : AppConstants.airtelMoneyPaymentNumber;
    final methodLabel = isMtn ? 'MTN Mobile Money' : 'Airtel Money';
    final dialogIsDark = Theme.of(context).brightness == Brightness.dark;
    final rawMethodColor = isMtn ? Colors.amber.shade700 : Colors.red.shade600;
    final methodColor = dialogIsDark
        ? Color.lerp(rawMethodColor, Colors.white, 0.45)!
        : rawMethodColor;

    if (!context.mounted) return;

    showDialog(
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
              const Text(
                'Instructions de paiement',
                style: TextStyle(fontSize: 18),
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
                // Numéro de paiement
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
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
                      IconButton(
                        icon: Icon(Icons.copy, color: methodColor),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: paymentPhoneNumber),
                          );
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
                    color: isDark
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.green.shade50,
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
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final checkout = await ref
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
                      );

                  // Reset key so a new order gets a new key
                  _idempotencyKey = null;

                  // Analytics: commande réussie
                  AnalyticsService.logOrderCreated(
                    orderId: checkout.id,
                    total: total,
                    paymentMethod: _selectedPaymentMethod,
                    isDelivery: options.isDelivery,
                    restaurantId: restaurantId,
                    itemCount: checkout.items.length,
                  );

                  if (!context.mounted) return;
                  Navigator.of(dialogContext).pop();
                  ref.read(cartControllerProvider.notifier).clearCart();
                  context.goNamed(AppRoutes.orderSuccess.routeName);
                } catch (e) {
                  // Analytics: commande échouée
                  AnalyticsService.logOrderFailed(
                    errorMessage: e.toString(),
                    paymentMethod: _selectedPaymentMethod,
                    isDelivery: options.isDelivery,
                  );

                  if (!context.mounted) return;
                  Navigator.of(dialogContext).pop();
                  _showOrderError(context, e);
                }
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

    showDialog(
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
