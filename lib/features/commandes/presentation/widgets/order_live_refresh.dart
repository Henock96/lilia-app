import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/features/commandes/data/delivery_tracking_repository.dart';
import 'package:lilia_app/features/commandes/data/order_controller.dart';
import 'package:lilia_app/features/payments/application/payment_status_controller.dart';
import 'package:lilia_app/models/order.dart';

/// La commande vit encore : il y a quelque chose à voir changer.
bool orderNeedsLiveRefresh(OrderStatus status) => switch (status) {
  OrderStatus.livrer ||
  OrderStatus.annuler ||
  OrderStatus.echecLivraison ||
  OrderStatus.unknow => false,
  _ => true,
};

/// Garde la fiche commande à jour sans geste du client (22/11/2026).
///
/// Deux défauts constatés en démo :
///
/// 1. **La fiche restait figée sans notification** : acceptation par la
///    boutique, paiement, départ du livreur n'apparaissaient qu'en tirant
///    l'écran. Les push sont le chemin rapide, pas une garantie — et sur
///    iPhone ils n'arrivent pas encore. La commande est donc relue toutes les
///    [interval], tant qu'elle n'est pas terminée et que l'application est au
///    premier plan.
/// 2. **Le code de remise n'apparaissait jamais** si la fiche était ouverte
///    avant la création de la course : le suivi recevait un 404 (pas encore de
///    `Delivery`, elle naît au passage `PRET`) et s'arrêtait. À chaque
///    changement de statut, le suivi et le paiement sont relus : le code
///    arrive dès que le livreur récupère le repas (`EN_TRANSIT`).
///
/// Invisible : ne rend rien.
class OrderLiveRefresh extends ConsumerStatefulWidget {
  const OrderLiveRefresh({
    super.key,
    required this.orderId,
    required this.status,
    this.interval = const Duration(seconds: 20),
  });

  final String orderId;
  final OrderStatus status;
  final Duration interval;

  @override
  ConsumerState<OrderLiveRefresh> createState() => _OrderLiveRefreshState();
}

class _OrderLiveRefreshState extends ConsumerState<OrderLiveRefresh>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _auPremierPlan = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _armer();
  }

  @override
  void didUpdateWidget(OrderLiveRefresh old) {
    super.didUpdateWidget(old);
    if (old.status != widget.status) {
      // La commande a bougé : ce qui en dépend se relit (course, code de
      // remise, paiement). Le suivi qui s'était arrêté sur un 404 repart.
      //
      // Après la frame : `didUpdateWidget` s'exécute pendant la
      // reconstruction de la fiche, et invalider à ce moment marque d'autres
      // widgets « à reconstruire » en pleine construction.
      final orderId = widget.orderId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.invalidate(driverLocationControllerProvider(orderId));
        ref.invalidate(orderPaymentProvider(orderId));
      });
    }
    if (old.status != widget.status || old.interval != widget.interval) {
      _armer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final avant = _auPremierPlan;
    _auPremierPlan = state == AppLifecycleState.resumed;
    if (_auPremierPlan && !avant) {
      // Retour au premier plan : relire tout de suite, pas dans 20 s.
      _relire();
    }
    _armer();
  }

  void _armer() {
    _timer?.cancel();
    _timer = null;
    if (!_auPremierPlan || !orderNeedsLiveRefresh(widget.status)) return;
    _timer = Timer.periodic(widget.interval, (_) => _relire());
  }

  void _relire() {
    if (!mounted || !orderNeedsLiveRefresh(widget.status)) return;
    ref.invalidate(orderDetailProvider(widget.orderId));
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
