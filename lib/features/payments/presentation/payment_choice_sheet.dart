import 'package:flutter/material.dart';
import 'package:lilia_app/utils/currency.dart';

/// Opérateur et numéro d'une tentative de paiement.
typedef PaymentChoice = ({String phone, String method});

/// Demande l'opérateur et le numéro Mobile Money, juste avant `POST /payments`.
///
/// L'opérateur ne se choisit plus sur « Confirmer la commande » : en
/// « accepter puis payer », le client ne paie qu'une fois la boutique d'accord,
/// parfois longtemps après. La question se pose donc au moment où elle sert —
/// au checkout quand le paiement suit la commande, sur la fiche commande sinon.
/// Une seule feuille pour les deux chemins : deux copies divergeraient.
///
/// `null` : feuille fermée sans choix. La commande, elle, existe toujours.
Future<PaymentChoice?> showPaymentChoiceSheet(
  BuildContext context, {
  required num amount,
  required String initialMethod,
  required bool Function(String input) isValidPhone,
  String initialPhone = '',
}) {
  return showModalBottomSheet<PaymentChoice>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PaymentChoiceSheet(
      amount: amount,
      initialMethod: initialMethod,
      initialPhone: initialPhone,
      isValidPhone: isValidPhone,
    ),
  );
}

class _PaymentChoiceSheet extends StatefulWidget {
  const _PaymentChoiceSheet({
    required this.amount,
    required this.initialMethod,
    required this.initialPhone,
    required this.isValidPhone,
  });

  final num amount;
  final String initialMethod;
  final String initialPhone;
  final bool Function(String input) isValidPhone;

  @override
  State<_PaymentChoiceSheet> createState() => _PaymentChoiceSheetState();
}

class _PaymentChoiceSheetState extends State<_PaymentChoiceSheet> {
  final _formKey = GlobalKey<FormState>();

  /// Libéré par [dispose], au démontage de la feuille.
  ///
  /// ⚠️ Pas dans un `finally` autour de `showModalBottomSheet` : la `Future`
  /// se résout dès le `pop`, pendant que la feuille, encore en animation de
  /// fermeture, se redessine avec ce contrôleur — « used after being
  /// disposed ».
  late final TextEditingController _phone = TextEditingController(
    text: widget.initialPhone,
  );
  late String _method = widget.initialMethod;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop((phone: _phone.text.trim(), method: _method));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Payer ${formatPrice(widget.amount)}',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'MTN_MOMO', label: Text('MTN MoMo')),
                ButtonSegment(value: 'AIRTEL_MONEY', label: Text('Airtel Money')),
              ],
              selected: {_method},
              onSelectionChanged: (selection) =>
                  setState(() => _method = selection.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              autofocus: widget.initialPhone.isEmpty,
              decoration: const InputDecoration(
                labelText: 'Numéro Mobile Money',
                hintText: '06 123 45 67',
                helperText: 'La demande de paiement arrivera sur ce numéro.',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final input = (value ?? '').trim();
                if (input.isEmpty) return 'Numéro requis';
                return widget.isValidPhone(input)
                    ? null
                    : 'Numéro congolais invalide';
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Envoyer la demande de paiement'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
