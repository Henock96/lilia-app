import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../utils/currency.dart';
import '../../../utils/snackbar.dart';
import '../data/claims_repository.dart';
import '../domain/claim.dart';
import 'claims_providers.dart';

/// Une demande et son fil avec le service client (F3-06).
class ClaimDetailPage extends ConsumerStatefulWidget {
  const ClaimDetailPage({super.key, required this.claimId});

  final String claimId;

  @override
  ConsumerState<ClaimDetailPage> createState() => _ClaimDetailPageState();
}

class _ClaimDetailPageState extends ConsumerState<ClaimDetailPage> {
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(claimsRepositoryProvider)
          .postMessage(widget.claimId, text);
      _message.clear();
      ref.invalidate(claimDetailProvider(widget.claimId));
    } catch (e) {
      if (mounted) context.showErrorSnack('$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(claimDetailProvider(widget.claimId));
    return Scaffold(
      appBar: AppBar(title: const Text('Ma demande')),
      body: switch (state) {
        AsyncValue(hasError: true, hasValue: false, :final error?) => Center(
          child: Text('$error'),
        ),
        AsyncValue(:final value?) => _body(value),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _body(ClaimDetail claim) {
    final time = DateFormat('d MMM, HH:mm', 'fr_FR');
    final ownRefunds = claim.refunds.where((r) => r.fromThisClaim);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${claimReasonLabel(claim.reason)} — commande #${claim.orderRef}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${claim.restaurantName} · '
                '${claimStatusLabel(claim.status, claim.outcome)}',
              ),
              for (final i in claim.items) Text('• ${i.quantity} × ${i.label}'),
              const SizedBox(height: 12),
              // L'issue, en tête : c'est ce que le client vient chercher.
              for (final r in ownRefunds)
                _Banner(
                  color: Colors.green,
                  text: switch (r.status) {
                    'COMPLETED' =>
                      '${formatPrice(r.amountXaf)} vous ont été remboursés sur votre Mobile Money.',
                    'REJECTED' =>
                      'Le remboursement n’a pas pu aboutir : le service client vous recontacte.',
                    _ =>
                      '${formatPrice(r.amountXaf)} sont en cours de remboursement sur votre Mobile Money.',
                  },
                ),
              if (claim.voucher case final v?)
                _Banner(
                  color: Colors.orange,
                  text:
                      'Avoir de ${formatPrice(v.amountXaf)}, valable jusqu’au '
                      '${DateFormat('d MMMM', 'fr_FR').format(v.expiresAt)} : '
                      '${v.code}',
                  action: TextButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copier le code'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: v.code));
                      if (mounted) context.showSuccessSnack('Code copié.');
                    },
                  ),
                ),
              for (final m in claim.messages)
                Align(
                  alignment: m.mine
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 320),
                    decoration: BoxDecoration(
                      color: m.mine
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${m.authorLabel} · ${time.format(m.createdAt)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        Text(m.body),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (!claim.isClosed)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('claim-message'),
                      controller: _message,
                      maxLength: 2000,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Écrire au service client…',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('claim-send'),
                    icon: const Icon(Icons.send),
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.text, this.action});

  final MaterialColor color;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.shade50,
      border: Border.all(color: color.shade200),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(text), ?action],
    ),
  );
}
