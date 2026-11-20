import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:lilia_app/core/network/api_exception.dart';
import 'package:lilia_app/features/cart/application/cart_controller.dart';
import 'package:lilia_app/features/reservations/data/reservation_repository.dart';
import 'package:lilia_app/features/reservations/presentation/reservation_providers.dart';
import 'package:lilia_app/models/cart.dart';
import 'package:lilia_app/routing/app_route_enum.dart';
import 'package:lilia_app/utils/availability_window.dart';
import 'package:lilia_app/utils/currency.dart';
import 'package:lilia_app/utils/snackbar.dart';

/// Brazzaville = UTC+1 toute l'année : les heures s'affichent là-bas, quel que
/// soit le fuseau du téléphone.
DateTime _bzv(DateTime instant) =>
    instant.toUtc().add(AvailabilityWindow.brazzavilleOffset);

String _hour(DateTime instant) => DateFormat('HH:mm').format(_bzv(instant));

String _dayLong(DateTime instant) =>
    _capitalize(DateFormat('EEEE d MMMM', 'fr_FR').format(_bzv(instant)));

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

String _errorText(Object e) => e is ApiException ? e.message : '$e';

/// Jours civils proposés, de `firstDate` à `lastDate` (bornes serveur).
List<DateTime> reservationDays(ReservationAvailability bounds, {int max = 14}) {
  final first = DateTime.tryParse(bounds.firstDate);
  final last = DateTime.tryParse(bounds.lastDate);
  if (first == null || last == null) return const [];
  final days = <DateTime>[];
  var d = DateTime.utc(first.year, first.month, first.day);
  final end = DateTime.utc(last.year, last.month, last.day);
  while (!d.isAfter(end) && days.length < max) {
    days.add(d);
    d = d.add(const Duration(days: 1));
  }
  return days;
}

String _isoDay(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Où en est le panier par rapport à ce restaurant (D-3) : la précommande
/// d'une réservation, c'est le panier serveur du client.
enum ReservationCartState { empty, otherVendor, ready }

ReservationCartState reservationCartState(Cart? cart, String restaurantId) {
  final items = cart?.items ?? const <CartItem>[];
  if (items.isEmpty) return ReservationCartState.empty;
  if (items.any((i) => i.product.restaurantId != restaurantId)) {
    return ReservationCartState.otherVendor;
  }
  return ReservationCartState.ready;
}

/// Lot 4 (4D, D-3) — « Réserver une table » : précommande (le panier de ce
/// restaurant), couverts, jour, créneau, récapitulatif, envoi.
class ReservationBookingPage extends ConsumerStatefulWidget {
  const ReservationBookingPage({
    super.key,
    required this.restaurantId,
    this.restaurantName,
  });

  final String restaurantId;
  final String? restaurantName;

  @override
  ConsumerState<ReservationBookingPage> createState() =>
      _ReservationBookingPageState();
}

class _ReservationBookingPageState
    extends ConsumerState<ReservationBookingPage> {
  int _partySize = 2;
  DateTime? _day;
  ReservationSlot? _slot;
  final _note = TextEditingController();
  final _phone = TextEditingController();
  bool _sending = false;

  /// Même clé pour toutes les tentatives d'un même envoi ; oubliée dès que le
  /// client change sa demande (sinon le serveur rendrait l'ancienne).
  String? _key;

  void _changed(VoidCallback update) => setState(() {
    update();
    _key = null;
  });

  @override
  void dispose() {
    _note.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final day = _day;
    final slot = _slot;
    if (day == null || slot == null || _sending) return;
    setState(() => _sending = true);
    final key = _key ??= newReservationKey();
    try {
      final phone = _phone.text.trim();
      final note = _note.text.trim();
      final created = await ref
          .read(reservationRepositoryProvider)
          .create(
            restaurantId: widget.restaurantId,
            date: _isoDay(day),
            time: slot.time,
            partySize: _partySize,
            idempotencyKey: key,
            contactPhone: phone.isEmpty ? null : phone,
            note: note.isEmpty ? null : note,
          );
      // Le serveur a vidé le panier : il est devenu la précommande.
      await ref.read(cartControllerProvider.notifier).refresh();
      ref.invalidate(myReservationsProvider);
      if (!mounted) return;
      context.showSnack('Demande envoyée au restaurant.');
      context.goNamed(
        AppRoutes.reservationDetail.routeName,
        pathParameters: {'reservationId': created.id},
      );
    } on ApiException catch (e) {
      if (e.code == ReservationErrorCodes.slotUnavailable ||
          e.code == ReservationErrorCodes.capacityTaken) {
        if (mounted) setState(() => _slot = null);
        ref.invalidate(reservationSlotsProvider);
      }
      if (e.code == ReservationErrorCodes.cartChanged ||
          e.code == ReservationErrorCodes.cartEmpty ||
          e.code == ReservationErrorCodes.cartOtherVendor) {
        await ref.read(cartControllerProvider.notifier).refresh();
      }
      if (mounted) context.showErrorSnack(e.message);
    } catch (e) {
      if (mounted) context.showErrorSnack(_errorText(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _emptyCart() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider le panier ?'),
        content: const Text(
          'Votre panier contient des plats d’un autre établissement. Pour '
          'réserver ici, il faut le vider puis choisir les plats de ce '
          'restaurant.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Garder mon panier'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Vider'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(cartControllerProvider.notifier).clearCart();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider);
    final bounds = ref.watch(reservationBoundsProvider(widget.restaurantId));
    final cartState = reservationCartState(cart.value, widget.restaurantId);
    final slot = _slot;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.restaurantName == null
              ? 'Réserver une table'
              : 'Réserver — ${widget.restaurantName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: switch (bounds) {
        AsyncValue(hasError: true, hasValue: false, :final error?) => _Message(
          text:
              error is ApiException &&
                  error.code == ReservationErrorCodes.notBookable
              ? 'Ce restaurant ne prend pas de réservation pour le moment.'
              : _errorText(error),
          onRetry: () =>
              ref.invalidate(reservationBoundsProvider(widget.restaurantId)),
        ),
        AsyncValue(:final value?) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _PreorderSection(
              state: cartState,
              cart: cart.value,
              onChooseDishes: () => context.pop(),
              onEmptyCart: _emptyCart,
            ),
            if (cartState == ReservationCartState.ready) ...[
              const SizedBox(height: 20),
              _PartySizePicker(
                value: _partySize,
                max: value.maxPartySize,
                onChanged: (v) => _changed(() {
                  _partySize = v;
                  _slot = null;
                }),
              ),
              const SizedBox(height: 16),
              Text('Jour', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _DayPicker(
                days: reservationDays(value),
                selected: _day,
                onSelected: (d) => _changed(() {
                  _day = d;
                  _slot = null;
                }),
              ),
              if (_day case final day?) ...[
                const SizedBox(height: 16),
                Text('Heure', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                _SlotPicker(
                  restaurantId: widget.restaurantId,
                  date: _isoDay(day),
                  partySize: _partySize,
                  selected: _slot,
                  onSelected: (s) => _changed(() => _slot = s),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone de contact (facultatif)',
                  helperText: 'Par défaut, celui de votre compte.',
                ),
                onChanged: (_) => _key = null,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLength: 280,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Note pour le restaurant (facultatif)',
                ),
                onChanged: (_) => _key = null,
              ),
              const SizedBox(height: 8),
              const _HowItWorks(),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('reservation-send'),
                onPressed: _day != null && slot != null && !_sending
                    ? _send
                    : null,
                child: _sending
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        slot == null
                            ? 'Choisissez un créneau'
                            : 'Envoyer la demande · ${slot.time}',
                      ),
              ),
            ],
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _PreorderSection extends StatelessWidget {
  const _PreorderSection({
    required this.state,
    required this.cart,
    required this.onChooseDishes,
    required this.onEmptyCart,
  });

  final ReservationCartState state;
  final Cart? cart;
  final VoidCallback onChooseDishes;
  final VoidCallback onEmptyCart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Votre précommande', style: text.titleMedium),
            const SizedBox(height: 8),
            switch (state) {
              ReservationCartState.empty => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'On réserve avec sa précommande : ajoutez d’abord les '
                    'plats de ce restaurant à votre panier.',
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: onChooseDishes,
                    child: const Text('Choisir mes plats'),
                  ),
                ],
              ),
              ReservationCartState.otherVendor => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Votre panier contient des plats d’un autre '
                    'établissement.',
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: onEmptyCart,
                    child: const Text('Vider le panier'),
                  ),
                ],
              ),
              ReservationCartState.ready => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final i in cart?.items ?? const <CartItem>[])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${i.quantite} × ${i.product.nom}'),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'En envoyant la demande, ces plats quittent votre panier '
                    'et deviennent votre précommande.',
                    style: text.bodySmall,
                  ),
                  TextButton(
                    onPressed: onChooseDishes,
                    child: const Text('Modifier mes plats'),
                  ),
                ],
              ),
            },
          ],
        ),
      ),
    );
  }
}

class _PartySizePicker extends StatelessWidget {
  const _PartySizePicker({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          'Nombre de personnes',
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
      IconButton(
        tooltip: 'Une personne de moins',
        onPressed: value > 1 ? () => onChanged(value - 1) : null,
        icon: const Icon(Icons.remove_circle_outline),
      ),
      Text('$value', style: Theme.of(context).textTheme.titleMedium),
      IconButton(
        tooltip: 'Une personne de plus',
        onPressed: value < max ? () => onChanged(value + 1) : null,
        icon: const Icon(Icons.add_circle_outline),
      ),
    ],
  );
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({
    required this.days,
    required this.selected,
    required this.onSelected,
  });

  final List<DateTime> days;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: days.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, i) {
        final d = days[i];
        return ChoiceChip(
          label: Text(DateFormat('EEE d MMM', 'fr_FR').format(d)),
          selected: selected == d,
          onSelected: (_) => onSelected(d),
        );
      },
    ),
  );
}

class _SlotPicker extends ConsumerWidget {
  const _SlotPicker({
    required this.restaurantId,
    required this.date,
    required this.partySize,
    required this.selected,
    required this.onSelected,
  });

  final String restaurantId;
  final String date;
  final int partySize;
  final ReservationSlot? selected;
  final ValueChanged<ReservationSlot> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(
      reservationSlotsProvider(restaurantId, date, partySize),
    );
    return switch (slots) {
      AsyncValue(hasError: true, hasValue: false, :final error?) => Text(
        _errorText(error),
      ),
      AsyncValue(:final value?) when value.slots.isEmpty => const Text(
        'Plus de table libre ce jour-là pour ce nombre de personnes.',
      ),
      AsyncValue(:final value?) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in value.slots)
            ChoiceChip(
              label: Text(s.time),
              selected: selected?.time == s.time,
              onSelected: (_) => onSelected(s),
            ),
        ],
      ),
      _ => const LinearProgressIndicator(),
    };
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) => Text(
    'Le restaurant accepte ou refuse votre demande. Une fois acceptée, vous '
    'payez la précommande pour confirmer la table. À votre arrivée, un code '
    's’affiche quand votre commande est prête : montrez-le au restaurant.',
    style: Theme.of(context).textTheme.bodySmall,
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ],
      ),
    ),
  );
}

/// « Mes réservations » : à venir d'abord, puis l'historique.
class MyReservationsPage extends ConsumerWidget {
  const MyReservationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myReservationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mes réservations')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myReservationsProvider.future),
        child: switch (state) {
          AsyncValue(hasError: true, hasValue: false, :final error?) =>
            ListView(
              children: [
                _Message(
                  text: _errorText(error),
                  onRetry: () => ref.invalidate(myReservationsProvider),
                ),
              ],
            ),
          AsyncValue(:final value?) when value.isEmpty => ListView(
            children: const [
              _Message(
                text:
                    'Aucune réservation. Les restaurants qui en prennent '
                    'affichent « Réserver une table » sur leur fiche.',
              ),
            ],
          ),
          AsyncValue(:final value?) => ListView(
            children: [
              for (final r in [
                ...value.where((r) => r.isActive),
                ...value.where((r) => !r.isActive),
              ])
                ListTile(
                  leading: const Icon(Icons.table_restaurant_outlined),
                  title: Text(r.restaurantName),
                  subtitle: Text(
                    '${_dayLong(r.arrivalAt)} à ${_hour(r.arrivalAt)} · '
                    '${r.partySize} pers.\n'
                    '${clientReservationStatusLabel(r.status)}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushNamed(
                    AppRoutes.reservationDetail.routeName,
                    pathParameters: {'reservationId': r.id},
                  ),
                ),
            ],
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

/// Fiche d'une réservation : suivi, paiement par la commande liée, code
/// d'arrivée (D-2), annulation selon la politique servie par le serveur.
class ClientReservationPage extends ConsumerStatefulWidget {
  const ClientReservationPage({super.key, required this.reservationId});

  final String reservationId;

  @override
  ConsumerState<ClientReservationPage> createState() =>
      _ClientReservationPageState();
}

class _ClientReservationPageState extends ConsumerState<ClientReservationPage> {
  bool _busy = false;

  Future<void> _cancel(ClientReservation r) async {
    final freeUntil = r.cancellationPolicy?.freeUntil;
    final late = freeUntil != null && DateTime.now().isAfter(freeUntil);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la réservation ?'),
        content: Text(
          r.payment == null
              ? 'Votre demande sera retirée ; rien n’a été payé.'
              : late
              ? 'L’annulation est tardive : elle reste remboursée, mais le '
                    'restaurant en est prévenu.'
              : 'Votre précommande vous sera intégralement remboursée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Garder'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Annuler la réservation'),
          ),
        ],
      ),
    );
    if (ok != true || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(reservationRepositoryProvider).cancel(r.id);
      if (mounted) context.showSnack('Réservation annulée.');
    } catch (e) {
      if (mounted) context.showErrorSnack(_errorText(e));
    } finally {
      ref.invalidate(clientReservationProvider(widget.reservationId));
      ref.invalidate(myReservationsProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Payer et suivre la préparation passent par la commande liée : écran de
  /// paiement, attente pawaPay et code d'arrivée existent déjà.
  void _openOrder(String orderId) => context.goNamed(
    AppRoutes.orderDetail.routeName,
    pathParameters: {'orderId': orderId},
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clientReservationProvider(widget.reservationId));
    return Scaffold(
      appBar: AppBar(title: const Text('Ma réservation')),
      body: switch (state) {
        AsyncValue(hasError: true, hasValue: false, :final error?) => _Message(
          text: _errorText(error),
          onRetry: () =>
              ref.invalidate(clientReservationProvider(widget.reservationId)),
        ),
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () => ref.refresh(
            clientReservationProvider(widget.reservationId).future,
          ),
          child: ClientReservationView(
            r: value,
            busy: _busy,
            onCancel: () => _cancel(value),
            onOpenOrder: _openOrder,
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Contenu de la fiche, sans état : testable seul.
class ClientReservationView extends StatelessWidget {
  const ClientReservationView({
    super.key,
    required this.r,
    required this.busy,
    required this.onCancel,
    required this.onOpenOrder,
  });

  final ClientReservation r;
  final bool busy;
  final VoidCallback onCancel;
  final void Function(String orderId) onOpenOrder;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final payment = r.payment;
    final policy = r.cancellationPolicy;
    final reason = r.declineReason ?? r.cancelReason;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(r.restaurantName, style: text.titleLarge),
        const SizedBox(height: 4),
        Text(
          clientReservationStatusLabel(r.status),
          style: text.titleMedium?.copyWith(color: cs.primary),
        ),
        const SizedBox(height: 8),
        Text(statusExplanation(r)),
        if (reason != null) ...[
          const SizedBox(height: 4),
          Text(clientReservationReasonLabel(reason)),
        ],
        const Divider(height: 32),
        _Line(
          icon: Icons.event,
          text: '${_dayLong(r.arrivalAt)} à ${_hour(r.arrivalAt)}',
        ),
        _Line(
          icon: Icons.group_outlined,
          text: '${r.partySize} personne${r.partySize > 1 ? 's' : ''}',
        ),
        if (r.spaceLabel.isNotEmpty)
          _Line(icon: Icons.table_restaurant_outlined, text: r.spaceLabel),
        const Divider(height: 32),
        Text('Précommande', style: text.titleSmall),
        for (final i in r.items)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${i.quantity} × ${i.name}'
              '${i.variantLabel != null ? ' (${i.variantLabel})' : ''}'
              '${i.options.isEmpty ? '' : ' + ${i.options.join(', ')}'}',
            ),
          ),
        if (payment != null) ...[
          const SizedBox(height: 8),
          _Amount('Plats', payment.subTotal),
          _Amount('Frais de service', payment.serviceFee),
          _Amount('Total', payment.total, bold: true),
          if (payment.priceChanged && payment.indicativeSubTotal != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Le prix des plats a changé depuis votre demande '
                '(${formatPrice(payment.indicativeSubTotal!)} annoncés). '
                'Vérifiez le total avant de payer.',
                style: TextStyle(color: cs.error),
              ),
            ),
        ],
        if (policy != null) ...[
          const Divider(height: 32),
          Text('Annulation', style: text.titleSmall),
          const SizedBox(height: 4),
          if (policy.freeUntil case final freeUntil?)
            Text(
              'Annulation sans frais jusqu’au ${_dayLong(freeUntil)} '
              'à ${_hour(freeUntil)}. Au-delà, elle reste remboursée mais '
              'elle est signalée au restaurant.',
            ),
          if (!policy.noShowRefundable)
            const Text(
              'Si vous ne venez pas sans avoir annulé, la précommande n’est '
              'pas remboursée.',
            ),
        ],
        const SizedBox(height: 24),
        if (busy) const LinearProgressIndicator(),
        if (payment != null && r.canPay)
          FilledButton(
            key: const Key('reservation-pay'),
            onPressed: busy ? null : () => onOpenOrder(payment.orderId),
            child: Text('Payer ${formatPrice(payment.total)}'),
          ),
        if (payment != null && r.status == 'CONFIRMED')
          FilledButton.tonal(
            key: const Key('reservation-open-order'),
            onPressed: () => onOpenOrder(payment.orderId),
            child: const Text('Ma commande et mon code d’arrivée'),
          ),
        if (r.canCancel) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('reservation-cancel'),
            onPressed: busy ? null : onCancel,
            child: const Text('Annuler la réservation'),
          ),
        ],
      ],
    );
  }

  static String statusExplanation(ClientReservation r) => switch (r.status) {
    'PENDING' =>
      r.responseDeadlineAt == null
          ? 'Le restaurant va accepter ou refuser votre demande.'
          : 'Le restaurant répond avant ${_hour(r.responseDeadlineAt!)}. '
                'Sans réponse, la demande expire.',
    'AWAITING_PAYMENT' =>
      r.paymentDeadlineAt == null
          ? 'Payez votre précommande pour confirmer la table.'
          : 'Payez votre précommande avant ${_hour(r.paymentDeadlineAt!)} '
                'pour confirmer la table.',
    'CONFIRMED' =>
      'Votre table est réservée. À votre arrivée, le restaurant prépare '
          'votre commande ; quand elle est prête, votre code d’arrivée '
          's’affiche sur la commande : montrez-le au restaurant.',
    'HONORED' => 'Merci de votre visite !',
    'EXPIRED' =>
      'Le restaurant n’a pas répondu à temps, ou le paiement n’a pas été '
          'fait dans le délai.',
    _ => '',
  };
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _Amount extends StatelessWidget {
  const _Amount(this.label, this.value, {this.bold = false});

  final String label;
  final int value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.w700) : null;
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(formatPrice(value), style: style),
      ],
    );
  }
}

/// Entrée « Réserver une table » de la fiche vendeur (D-1 : seulement si le
/// serveur dit le restaurant réservable).
class ReserveTableCard extends StatelessWidget {
  const ReserveTableCard({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: OutlinedButton.icon(
      key: const Key('reserve-table'),
      onPressed: onPressed,
      icon: const Icon(Icons.table_restaurant_outlined),
      label: const Text('Réserver une table'),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    ),
  );
}

/// Commande liée à une réservation (F-6) : elle n'est pas un simple retrait.
class ReservationOrderBanner extends StatelessWidget {
  const ReservationOrderBanner({super.key, required this.reservationId});

  final String reservationId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.secondaryContainer,
      child: ListTile(
        leading: Icon(
          Icons.table_restaurant_outlined,
          color: cs.onSecondaryContainer,
        ),
        title: Text(
          'Précommande de votre réservation',
          style: TextStyle(color: cs.onSecondaryContainer),
        ),
        subtitle: Text(
          'Table, horaire et annulation : voir la réservation.',
          style: TextStyle(color: cs.onSecondaryContainer),
        ),
        trailing: Icon(Icons.chevron_right, color: cs.onSecondaryContainer),
        onTap: () => context.goNamed(
          AppRoutes.reservationDetail.routeName,
          pathParameters: {'reservationId': reservationId},
        ),
      ),
    );
  }
}
