import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/payments/domain/payment_failure.dart';
import 'package:lilia_app/utils/order_reference.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lilia_app/common_widgets/app_animations.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/features/commandes/domain/order_error_presentation.dart';
import 'package:lilia_app/common_widgets/build_loading_state.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/cart/application/draft_orders_provider.dart';
import 'package:lilia_app/features/commandes/data/checkout_controller.dart';
import 'package:lilia_app/features/commandes/data/checkout_quote_provider.dart';
import 'package:lilia_app/models/checkout_quote.dart';
import 'package:lilia_app/utils/congo_phone.dart';
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
import 'package:lilia_app/common_widgets/lilia_badge.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';
import 'package:lilia_app/utils/currency.dart';
import 'package:lilia_app/utils/snackbar.dart';
import 'package:lilia_app/features/commandes/presentation/widgets/checkout_order_summary.dart';
import 'package:lilia_app/features/commandes/presentation/widgets/payment_instructions_dialog.dart';
import 'package:lilia_app/features/commandes/presentation/widgets/checkout_submit_bar.dart';

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

  /// Vrai du premier tap sur « Valider et payer » jusqu'à la sortie du tunnel.
  ///
  /// ## Pourquoi `checkoutState.isLoading` ne suffisait pas
  ///
  /// Le bouton n'était grisé que par l'état de `CheckoutController`, qui ne
  /// couvre **qu'une** des trois étapes du tunnel :
  ///
  /// ```text
  /// ① createAdresse()          isLoading == false  → bouton ACTIF
  /// ② placeOrder()             isLoading == true   → bouton grisé
  ///    └─ state = AsyncData    isLoading == false
  /// ③ _createPaymentWithRetry() (jusqu'à 2 essais + 2 s) → bouton ACTIF
  /// ```
  ///
  /// Fenêtre ① : un aller-retour complet (~800 ms depuis Brazzaville) pendant
  /// lequel rien à l'écran n'indique qu'il se passe quelque chose. Deux taps
  /// créaient **deux adresses identiques** dans le carnet du client.
  ///
  /// Fenêtre ③ : `_idempotencyKey` vient d'être remise à zéro, un second tap
  /// repart donc avec une clé neuve, sans aucune protection d'idempotence
  /// côté serveur. Le panier ayant été vidé dans la transaction de checkout,
  /// cette seconde commande échoue en « panier vide » — et le client voit un
  /// dialogue d'échec **pendant qu'un paiement légitime se prépare**. C'est le
  /// message exact qui invite à payer une deuxième fois.
  ///
  /// ⚠️ La garde est posée **avant le premier `await`**, et pas seulement sur
  /// l'apparence du bouton : le grisage ne prend effet qu'à la frame suivante,
  /// et deux taps peuvent tomber dans la même. Même raisonnement que
  /// `SignInController._executer`.
  bool _envoiEnCours = false;
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

    // Filet de sécurité, plus une redirection.
    //
    // Le refus appartient désormais au `redirect` de la route `checkout`
    // (`app_router.dart`) : sans `DeliveryOptions` dans l'`extra`, cette page
    // n'est jamais construite. La version précédente naviguait ici même, dans
    // un `addPostFrameCallback` — donc après avoir affiché une frame de page de
    // paiement vide (R-04), et en concurrence avec le routeur.
    if (options == null) {
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
          //
          // ⚠️ **Pas de barème, pas de total.** Ce `??
          // PlatformSettings.fallback` affichait une commission de 8 % pendant
          // que la production en facturait 15 : le client validait 22 600 FCFA
          // et l'écran de paiement lui en réclamait 24 000. Deux fenêtres,
          // toutes deux ordinaires — `/platform-settings` injoignable, et les
          // premières frames de chaque checkout. On préfère désormais ne rien
          // afficher et le dire.
          final settings = settingsAsync.value;
          if (settings == null) {
            return _TarifsIndisponibles(
              // ⚠️ `isLoading` seul ne suffit pas : Riverpod 3 **relance**
      // automatiquement un provider en échec, avec un backoff. Entre deux
      // tentatives il repasse donc en chargement tout en portant son erreur,
      // et un écran qui ne regarde que `isLoading` affiche un indicateur
      // perpétuel au lieu de dire ce qui ne va pas. Dès qu'un échec est
      // connu, on l'annonce — la relance continue derrière.
      enChargement: settingsAsync.isLoading && !settingsAsync.hasError,
              onRetry: () => ref.invalidate(platformSettingsProvider),
            );
          }
          // ── Fenêtre de maintenance ─────────────────────────────────
          //
          // `maintenanceMode` et `maintenanceMessage` étaient servis par
          // `/platform-settings`, parsés par `PlatformSettings`… et lus par
          // personne. L'administrateur pouvait déclarer une interruption ; le
          // client la découvrait au refus du checkout, sans explication.
          //
          // C'est ici qu'elle se dit, et pas ailleurs : le mode maintenance
          // n'interdit pas de consulter le catalogue, il interdit de
          // commander. Un verrou global fermerait aussi la découverte, et
          // ferait dépendre l'ouverture de l'application d'un appel réseau.
          if (settings.maintenanceMode) {
            return _MaintenanceEnCours(message: settings.maintenanceMessage);
          }

          final estimate = CheckoutEstimate.compute(
            subTotal: cart.totalPrice,
            deliveryFee: _promoResult?.newDeliveryFee ?? options.deliveryFee,
            promoDiscount: _promoResult?.discountAmount ?? 0,
            loyaltyPoints: userProfileAsync.value?.loyaltyPoints ?? 0,
            useLoyaltyPoints: _useLoyaltyPoints,
            settings: settings,
            // D-4 — taux de la boutique annoncé par le panier.
            serviceFeePercent: cart.serviceFeePercent,
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
            serviceFeePercent: cart.serviceFeePercent,
          ).loyaltyDiscount;
          // F3-11 — devis serveur : le calcul du checkout lui-même, offre
          // boutique comprise. Il fait foi dès qu'il est là ; l'estimation
          // locale ne couvre que son chargement (ou une précommande dont le
          // créneau n'est pas encore choisi, que le serveur refuserait).
          final quote = _quoteFor(options, cart.isPreorderCart);
          final double subTotal = quote?.subTotal ?? estimate.subTotal;
          final double deliveryFee = quote?.deliveryFee ?? estimate.deliveryFee;
          final double serviceFee = quote?.serviceFee ?? estimate.serviceFee;
          final double loyaltyDiscount =
              quote?.loyaltyDiscount ?? estimate.loyaltyDiscount;
          final double total = quote?.total ?? estimate.total;
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

          final bool sending = _envoiEnCours || checkoutState.isLoading;
          final bool slotMissing = cart.isPreorderCart && _scheduledFor == null;

          // P3-15 : le défilement porte le formulaire, la barre du bas porte
          // l'action et le total — toujours visibles, au-dessus du clavier
          // (`resizeToAvoidBottomInset`) et de la zone de geste (`SafeArea`).
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
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
                        _buildSectionTitle('Numéro de téléphone'),
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
                          _buildSectionTitle('Points de fidélité'),
                          const SizedBox(height: 8),
                          // Surface du thème et non `Colors.amber[50]` : en sombre,
                          // le titre clair sur ce fond pâle devenait illisible.
                          Material(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: LiliaRadius.mdAll,
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.warningText
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: SwitchListTile(
                              value: _useLoyaltyPoints,
                              onChanged: (v) =>
                                  setState(() => _useLoyaltyPoints = v),
                              title: const Text(
                                'Utiliser mes points',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                'Réduction de ${formatPrice(potentialLoyaltyDiscount)}',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .warningText,
                                ),
                              ),
                              secondary: Icon(
                                Icons.stars,
                                color: Theme.of(context)
                                    .colorScheme
                                    .warningText,
                              ),
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
                        _buildSectionTitle('Résumé de la commande'),
                        const SizedBox(height: 12),
                        CheckoutOrderSummary(
                          cart: cart,
                          isDelivery: options.isDelivery,
                          subTotal: subTotal,
                          deliveryFee: deliveryFee,
                          originalDeliveryFee: options.deliveryFee,
                          deliverySubsidy:
                              widget.deliveryOptions?.deliverySubsidy ?? 0,
                          serviceFee: serviceFee,
                          promo: _promoResult,
                          loyaltyDiscount: _useLoyaltyPoints
                              ? loyaltyDiscount
                              : 0,
                          total: total,
                          isEstimate: quote == null,
                          vendorOffer: quote?.vendorOffer,
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

                        // === BOUTON ENREGISTRER POUR PLUS TARD ===
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _envoiEnCours || checkoutState.isLoading
                                ? null
                                : () => _saveDraft(cart, restaurantId),
                            icon: const Icon(
                              Icons.bookmark_border_rounded,
                              size: 20,
                            ),
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
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Garde le panier sur ce téléphone, sans passer '
                          'commande. Vous le retrouverez dans Profil › '
                          'Paniers enregistrés.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              CheckoutSubmitBar(
                total: total,
                isEstimate: quote == null,
                // L'indicateur suit la garde, et non le seul
                // `CheckoutController` : sinon il s'éteignait pendant la
                // création de l'adresse et pendant l'ouverture du paiement,
                // laissant croire que rien ne se passait.
                isSending: sending,
                disabledReason: slotMissing
                    ? 'Choisissez un créneau pour continuer.'
                    : null,
                onPressed: sending || slotMissing
                    ? null
                    : () => _startPaymentFlow(context, options, restaurantId),
              ),
            ],
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
            : cs.successText.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: options.isDelivery
              ? cs.primary.withValues(alpha: 0.3)
              : cs.successText.withValues(alpha: 0.3),
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
              color: options.isDelivery ? cs.primary : cs.successText,
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
                const LiliaBadge(
                  label: 'Requis',
                  variant: LiliaBadgeVariant.warning,
                  icon: Icons.error_outline,
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
    final cs = Theme.of(context).colorScheme;
    // Titre et icône en `warningText`, texte courant en `onSurface` : le
    // titre était orange sur voile orange (≈ 2.2:1), en 12 px.
    return Container(
      padding: const EdgeInsets.all(LiliaSpacing.sp3),
      decoration: BoxDecoration(
        color: cs.warningText.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(color: cs.warningText.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: cs.warningText, size: 20),
          const SizedBox(width: LiliaSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Commande sur commande',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: cs.warningText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Le vendeur peut annuler jusqu\'à la veille (J-1). En cas d\'annulation, le remboursement se fait sous 48 heures.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: cs.onSurface,
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
        labelText: 'Numéro de téléphone',
        hintText: 'Ex: 06 XXX XX XX',
        prefixIcon: const Icon(Icons.phone),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Veuillez entrer votre numéro de téléphone';
        }
        // C-03 : ce numéro paie quand le champ Mobile Money est vide. Une
        // longueur ≥ 9 laissait passer « 123456789 », refusé ensuite par le
        // serveur… après la création de la commande.
        if (!isCongoMobilePhone(value)) return congoPhoneErrorMessage;
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
    final cs = Theme.of(context).colorScheme;
    // Code promo déjà appliqué : afficher un récap avec bouton supprimer
    if (_promoResult != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        // Voile « succès » du thème : `Colors.green.shade50` restait un
        // rectangle pâle en mode sombre.
        decoration: BoxDecoration(
          color: cs.successText.withValues(alpha: 0.1),
          borderRadius: LiliaRadius.mdAll,
          border: Border.all(color: cs.successText.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: cs.successText, size: 24),
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
                      color: cs.successText,
                    ),
                  ),
                  if (_promoResult!.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _promoResult!.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    _promoResult!.discountLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: cs.successText,
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
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.onPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Appliquer',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
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
            quartierId: widget.deliveryOptions?.quartier?.id,
          );

      if (!mounted) return;
      setState(() {
        _promoResult = result;
        _promoLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _promoError = userFacingErrorMessage(e);
        _promoLoading = false;
      });
    }
  }

  /// Dernier devis serveur affiché — renvoyé au checkout (offre vue).
  CheckoutQuote? _lastQuote;

  /// Devis du panier pour les options courantes ; `null` tant qu'il n'est pas
  /// là (ou s'il échoue : le checkout dira alors pourquoi, avec son message).
  CheckoutQuote? _quoteFor(DeliveryOptions options, bool isPreorderCart) {
    if (isPreorderCart && _scheduledFor == null) {
      _lastQuote = null;
      return null;
    }
    final usesNewAddress = options.newAddressRue != null;
    final async = ref.watch(
      checkoutQuoteProvider(
        isDelivery: options.isDelivery,
        adresseId: usesNewAddress ? null : options.address?.id,
        quartierId: options.quartier?.id ?? options.address?.quartierId,
        promoCode: _promoResult?.code,
        useLoyaltyPoints: _useLoyaltyPoints,
        scheduledFor: _scheduledFor,
      ),
    );
    _lastQuote = async.hasValue && !async.hasError ? async.value : null;
    return _lastQuote;
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

      // Un brouillon est **local** : il ne crée aucune commande serveur. Le
      // dire, sinon le client croit avoir commandé (constaté en QA 03/10).
      context.showSnack(
        'Panier enregistré sur ce téléphone. Aucune commande n’a été passée.',
      );

      // Depiler checkout et delivery-options du tab panier
      // pour que le retour au tab panier affiche le CartScreen
      Navigator.of(context).popUntil((route) => route.isFirst);

      // Naviguer vers l'ecran des brouillons (tab profil)
      context.goNamed(AppRoutes.draftOrders.routeName);
    } catch (e) {
      if (!mounted) return;
      context.showErrorSnack(userFacingErrorMessage(e));
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
  /// Point d'entrée **unique et gardé** du tunnel de paiement.
  ///
  /// Voir [_envoiEnCours] pour ce que la garde couvre et pourquoi elle ne peut
  /// pas être portée par l'état d'un contrôleur.
  Future<void> _startPaymentFlow(
    BuildContext context,
    DeliveryOptions options,
    String restaurantId,
  ) async {
    if (_envoiEnCours) return;
    setState(() => _envoiEnCours = true);
    try {
      await _deroulerTunnelPaiement(context, options, restaurantId);
    } finally {
      // `mounted` : le tunnel se termine le plus souvent par une navigation,
      // et cet écran a déjà disparu.
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  Future<void> _deroulerTunnelPaiement(
    BuildContext context,
    DeliveryOptions options,
    String restaurantId,
  ) async {
    if (!_formKey.currentState!.validate()) {
      if (context.mounted) {
        context.showErrorSnack('Veuillez remplir le numéro de téléphone');
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
                : normalizeCongoPhone(_phoneController.text),
            promoCode: _promoResult?.code,
            idempotencyKey: _getOrCreateIdempotencyKey(),
            useLoyaltyPoints: _useLoyaltyPoints,
            scheduledFor: _scheduledFor,
            // F3-11 — l'offre affichée par le devis. Sans devis chargé, on
            // n'affirme rien : le serveur applique ce qu'il trouve.
            seenVendorOffer: _lastQuote == null
                ? null
                : (id: _lastQuote!.vendorOffer?.id),
          );
    } catch (e) {
      // F3-11 — l'offre a changé depuis le récapitulatif (terminée, budget
      // épuisé, mise en pause) : rien n'a été encaissé. On recalcule le devis
      // et on laisse le client valider le nouveau total.
      if (e is ApiException && e.code == 'VENDOR_OFFER_CHANGED') {
        ref.invalidate(checkoutQuoteProvider);
        if (context.mounted) context.showErrorSnack(e.message);
        return;
      }
      // Catégorie d'échec seulement : `e.toString()` transportait le message du
      // serveur, donc du texte libre susceptible de contenir un numéro ou une
      // référence de transaction.
      AnalyticsService.trackOrderFailed(
        paymentMethod: _selectedPaymentMethod,
        failureKind: 'checkout_rejected',
      );
      // 426 : le serveur applique un seuil de version que notre barème en
      // cache (jusqu'à 5 min) ignore encore. 503 : une maintenance vient
      // d'être déclarée. Dans les deux cas, relire les réglages fait
      // apparaître tout de suite le dialogue de mise à jour ou l'écran de
      // maintenance, au lieu d'un refus que rien n'explique au prochain essai.
      if (e is ApiException && (e.statusCode == 426 || e.statusCode == 503)) {
        ref.invalidate(platformSettingsProvider);
      }
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
      // D-3 : refus métier attendu, pas une panne — ni Sentry ni « Réessayer ».
      if (isOrderItemsUnavailable(e)) {
        if (context.mounted) _signalerRupture(context, e);
        return;
      }
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

    if (!context.mounted) return;
    await _poursuivreSelonLeRail(context, checkout, payment);
  }

  /// Suite du parcours selon le rail d'encaissement **du serveur**.
  ///
  /// ⚠️ Point de passage UNIQUE après un `POST /payments` réussi (C-01, audit
  /// du 09/10/2026). La relance de `_showPaymentRecoveryDialog` appelait
  /// directement la modale de virement manuel : sous pawaPay, elle affichait
  /// un numéro destinataire **vide** pendant que la demande USSD partait
  /// réellement sur le téléphone, et « J'ai payé » menait à « Commande
  /// passée » sans aucune interrogation du statut.
  ///
  /// Le mode vient du backend : basculer de pawaPay au virement manuel (ou
  /// l'inverse) ne doit pas demander une release sur les stores.
  Future<void> _poursuivreSelonLeRail(
    BuildContext context,
    Checkout checkout,
    PaymentResponse payment,
  ) async {
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
      ref.read(cartControllerProvider.notifier).clearCartEnArrierePlan();
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

    // Mode manuel : instructions de virement, telles que renvoyées par le
    // serveur. Sans destinataire, il n'y a rien à virer : on ne montre pas
    // une consigne « Entrez le numéro ci-dessus » au-dessus d'un vide.
    if ((payment.instructions?.phone ?? '').trim().isEmpty) {
      await _showPaymentRecoveryDialog(context, checkout);
      return;
    }
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
        // ⚠️ Ne rejouer que ce qui peut réussir au second essai.
        //
        // Le `catch` ne discriminait rien : un 426 (version trop ancienne),
        // un 400 (refus de l'opérateur, plafond de tentatives atteint) ou un
        // 403 repartaient à l'identique, pour un refus certain — deux
        // secondes d'écran figé ajoutées au pire moment du parcours, avant
        // d'afficher un message que le serveur avait déjà donné.
        //
        // Aucun risque financier n'était en jeu (le serveur réutilise sa
        // ligne `PENDING`), seulement du temps perdu. Mais deux secondes
        // pendant lesquelles rien ne bouge, juste après « Valider et payer »,
        // sont exactement celles où un client tape à nouveau.
        if (attempt == 0 && _rejouable(e)) {
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }
        break;
      }
    }
    throw lastError!;
  }

  /// Cet échec peut-il avoir une autre issue au second essai ?
  ///
  /// Oui pour le transport et pour un serveur en peine — y compris le 502
  /// `PAYMENT_PROVIDER_UNAVAILABLE`, où la ligne reste `PENDING` avec son
  /// identifiant prestataire : le rejeu rejoue la **même** demande.
  /// Non pour un refus, qui est une décision et ne changera pas en deux
  /// secondes.
  static bool _rejouable(Object erreur) {
    if (erreur is! ApiException) return true; // inconnu : on laisse sa chance
    return switch (erreur.kind) {
      ApiErrorKind.network || ApiErrorKind.timeout || ApiErrorKind.server =>
        true,
      ApiErrorKind.client ||
      ApiErrorKind.unauthorized ||
      ApiErrorKind.unknown => false,
    };
  }

  /// Numéro qui paiera.
  ///
  /// Distinct du téléphone de contact quand le client en a saisi un : on paie
  /// souvent depuis un autre appareil que celui qu'on donne au livreur.
  ///
  /// Normalisé (C-03) : la saisie « 06 123 45 67 » partait brute, et un
  /// serveur antérieur à la PR backend #146 la refusait en 400 — après la
  /// création de la commande.
  String _paymentPhone() {
    final momo = _momoPhoneController.text.trim();
    return normalizeCongoPhone(momo.isNotEmpty ? momo : _phoneController.text);
  }

  /// Écran de reprise : la commande existe, le paiement n'a pas pu être
  /// enregistré. On ne laisse pas le client devant des instructions de paiement
  /// qui ne mènent nulle part.
  /// D-3 : un article est devenu indisponible entre la commande et le
  /// paiement. Rien n'a été débité et réessayer redonnerait le même refus : on
  /// dit lequel (message du serveur) et on mène aux commandes, où le client
  /// peut annuler celle-ci et la repasser.
  void _signalerRupture(BuildContext context, Object erreur) {
    ref.read(cartControllerProvider.notifier).clearCartEnArrierePlan();
    context.showErrorSnack(paymentStartErrorMessage(erreur));
    context.goNamed(AppRoutes.commandes.routeName);
  }

  Future<void> _showPaymentRecoveryDialog(
    BuildContext context,
    Checkout checkout,
  ) async {
    final cs = Theme.of(context).colorScheme;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      // C-07 : `barrierDismissible: false` ne bloque pas le retour Android.
      // Fermée par mégarde, cette boîte laissait le client sur le checkout
      // d'une commande déjà créée, panier plein, prêt à la repasser.
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
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
                'Votre commande ${refCommande(checkout.id)} '
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
                ref.read(cartControllerProvider.notifier).clearCartEnArrierePlan();
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
                  // Même aiguillage que le chemin nominal (C-01).
                  await _poursuivreSelonLeRail(context, checkout, payment);
                } catch (e) {
                  if (!context.mounted) return;
                  if (isOrderItemsUnavailable(e)) {
                    _signalerRupture(context, e);
                    return;
                  }
                  await _showPaymentRecoveryDialog(context, checkout);
                }
              },
              child: const Text('Réessayer'),
            ),
          ],
        ),
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

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      // C-07 : le retour Android ne doit pas escamoter les instructions.
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: PaymentInstructionsDialog(
          isMtn: isMtn,
          methodLabel: methodLabel,
          paymentPhoneNumber: paymentPhoneNumber,
          amountDue: amountDue,
          reference: reference,
          onLater: () {
            Navigator.of(dialogContext).pop();
            ref.read(cartControllerProvider.notifier).clearCartEnArrierePlan();
            context.goNamed(AppRoutes.commandes.routeName);
          },
          onPaid: () {
            Navigator.of(dialogContext).pop();
            ref.read(cartControllerProvider.notifier).clearCartEnArrierePlan();
            context.goNamed(AppRoutes.orderSuccess.routeName);
          },
        ),
      ),
    );
  }

  void _showOrderError(BuildContext context, Object error) {
    // Titre, message et icône d'après la nature de l'échec — dont l'issue
    // inconnue d'un délai dépassé (P3-05). Jamais `error.toString()`.
    final presentation = OrderErrorPresentation.from(error);
    final title = presentation.title;
    final message = presentation.message;
    final icon = presentation.icon;
    final iconColor = presentation.kind == OrderErrorKind.outcomeUnknown
        ? Theme.of(context).colorScheme.warningText
        : Theme.of(context).colorScheme.error;

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

/// Le barème n'a pas pu être lu : on ne fabrique pas de total.
///
/// Cet écran remplace un `?? PlatformSettings.fallback` qui affichait
/// tranquillement une commission de 8 % pendant que le serveur en facturait
/// 15. Montrer un montant qu'on ne peut pas garantir coûte plus cher que de ne
/// rien montrer : le client le découvre à l'écran de paiement, au moment où il
/// s'apprête à payer.
/// Interruption de service annoncée par le serveur.
///
/// Le message vient de l'administrateur (`maintenanceMessage`) : il sait ce
/// qui se passe et jusqu'à quand. On n'en invente pas un à sa place, et on se
/// contente d'un repli neutre s'il n'a rien écrit.
class _MaintenanceEnCours extends StatelessWidget {
  const _MaintenanceEnCours({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction_outlined, size: 56, color: cs.tertiary),
            const SizedBox(height: 16),
            Text(
              'Commandes momentanément suspendues',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message?.trim().isNotEmpty == true
                  ? message!.trim()
                  : 'Nous effectuons une maintenance. Votre panier est '
                        'conservé : réessayez dans quelques minutes.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarifsIndisponibles extends StatelessWidget {
  const _TarifsIndisponibles({
    required this.enChargement,
    required this.onRetry,
  });

  /// Distingue « ça arrive » de « ça a échoué ». Sans cette nuance, une
  /// seconde de réseau lent afficherait un message d'erreur.
  final bool enChargement;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (enChargement) return const BuildLoadingState();

    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 56, color: cs.outline),
            const SizedBox(height: 16),
            Text(
              'Frais indisponibles',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Nous n’avons pas pu récupérer les frais actuels. Pour ne pas '
              'vous annoncer un montant qui changerait au paiement, la '
              'commande est mise en attente.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
