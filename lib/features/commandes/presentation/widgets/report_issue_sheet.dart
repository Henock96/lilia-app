import 'package:flutter/material.dart';

/// Motifs qu'un client peut signaler — même liste fermée que le serveur
/// (`CUSTOMER_ISSUE_KINDS`, Master Audit v1, F-06).
enum OrderIssueKind {
  notReceived('NOT_RECEIVED', 'Je n’ai pas reçu ma commande'),
  wrongOrder('WRONG_ORDER', 'Commande erronée ou incomplète'),
  late('LATE', 'Ma commande est très en retard'),
  other('OTHER', 'Autre problème');

  const OrderIssueKind(this.wire, this.label);

  final String wire;
  final String label;
}

/// Ce que le client a choisi de signaler.
class OrderIssueReport {
  const OrderIssueReport(this.kind, this.message);

  final OrderIssueKind kind;
  final String? message;
}

/// Feuille de signalement : un motif obligatoire, un message facultatif.
/// Rend `null` si le client renonce.
Future<OrderIssueReport?> showReportIssueSheet(BuildContext context) {
  return showModalBottomSheet<OrderIssueReport>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const ReportIssueSheet(),
  );
}

class ReportIssueSheet extends StatefulWidget {
  const ReportIssueSheet({super.key});

  @override
  State<ReportIssueSheet> createState() => _ReportIssueSheetState();
}

class _ReportIssueSheetState extends State<ReportIssueSheet> {
  OrderIssueKind? _kind;
  final _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Signaler un problème',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          RadioGroup<OrderIssueKind>(
            groupValue: _kind,
            onChanged: (value) => setState(() => _kind = value),
            child: Column(
              children: [
                for (final kind in OrderIssueKind.values)
                  RadioListTile<OrderIssueKind>(
                    key: Key('issue-${kind.wire}'),
                    value: kind,
                    title: Text(kind.label),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
          TextField(
            controller: _message,
            maxLength: 1000,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Précisions (facultatif)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('issue-submit'),
            onPressed: _kind == null
                ? null
                : () => Navigator.of(context).pop(
                    OrderIssueReport(
                      _kind!,
                      _message.text.trim().isEmpty
                          ? null
                          : _message.text.trim(),
                    ),
                  ),
            child: const Text('Envoyer le signalement'),
          ),
        ],
      ),
    );
  }
}
