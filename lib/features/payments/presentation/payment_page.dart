import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/features/payments/data/payment_service.dart';

class PaymentPage extends ConsumerStatefulWidget {
  final String orderId;
  final double amount;
  final String currency;

  const PaymentPage({
    super.key,
    required this.orderId,
    required this.amount,
    this.currency = 'XAF',
  });

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final paymentService = ref.read(paymentServiceProvider);

      // Formater le numéro
      final formattedPhone = paymentService.formatPhoneNumber(
        _phoneController.text,
      );

      debugPrint('📱 Processing payment with phone: $formattedPhone');

      // 1. Créer le paiement
      final paymentResponse = await paymentService.createPayment(
        orderId: widget.orderId,
        amount: widget.amount,
        phoneNumber: formattedPhone,
        currency: widget.currency,
      );

      debugPrint('✅ Payment created: ${paymentResponse.paymentId}');

      // 2. Afficher un dialogue de chargement
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PaymentLoadingDialog(
          paymentId: paymentResponse.paymentId,
          phoneNumber: formattedPhone,
        ),
      );

      // 3. Attendre la confirmation
      final status = await paymentService.waitForPaymentCompletion(
        paymentId: paymentResponse.paymentId,
      );

      // 4. Fermer le dialogue de chargement
      if (mounted) {
        Navigator.of(context).pop();
      }

      // 5. Afficher le résultat
      if (status.status == PaymentStatus.success) {
        _showSuccessDialog();
      } else {
        _showErrorDialog(status.reason ?? 'Le paiement a échoué');
      }
    } catch (e) {
      debugPrint('❌ Payment error: $e');

      if (mounted) {
        // Fermer le dialogue de chargement si ouvert
        Navigator.of(context).popUntil((route) => route.isFirst);

        setState(() {
          _errorMessage = 'Erreur: $e';
          _isProcessing = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Paiement réussi !'),
          ],
        ),
        content: Text(
          'Votre paiement de ${widget.amount} ${widget.currency} a été effectué avec succès.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Fermer le dialogue
              Navigator.of(
                context,
              ).pop(true); // Retourner à la page précédente avec succès
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text('Paiement échoué'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Réessayer'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(false);
            },
            child: Text('Annuler'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paymentService = ref.watch(paymentServiceProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Paiement MTN Mobile Money')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Résumé de la commande
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Résumé',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Commande:', style: TextStyle(fontSize: 16)),
                          Text(
                            widget.orderId.substring(0, 8) + '...',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Montant:', style: TextStyle(fontSize: 16)),
                          Text(
                            '${widget.amount} ${widget.currency}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Numéro de téléphone
              Text(
                'Numéro MTN Mobile Money',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Ex: 670000000',
                  prefixText: '+242',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                  helperText: 'Entrez votre numéro MTN Mobile Money',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer votre numéro';
                  }
                  if (!paymentService.validatePhoneNumber(value)) {
                    return 'Numéro invalide';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Message d'erreur
              if (_errorMessage != null)
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 16),

              // Instructions
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Comment ça marche ?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '1. Entrez votre numéro MTN Mobile Money\n'
                        '2. Cliquez sur "Payer"\n'
                        '3. Vous recevrez un SMS sur votre téléphone\n'
                        '4. Composez le code USSD pour confirmer',
                        style: TextStyle(color: Colors.blue.shade900),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Bouton de paiement
              ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.orange,
                ),
                child: _isProcessing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Traitement...'),
                        ],
                      )
                    : Text(
                        'Payer ${widget.amount} ${widget.currency}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== 3. Dialogue de chargement =====
class PaymentLoadingDialog extends ConsumerStatefulWidget {
  final String paymentId;
  final String phoneNumber;

  const PaymentLoadingDialog({
    super.key,
    required this.paymentId,
    required this.phoneNumber,
  });

  @override
  ConsumerState<PaymentLoadingDialog> createState() =>
      _PaymentLoadingDialogState();
}

class _PaymentLoadingDialogState extends ConsumerState<PaymentLoadingDialog> {
  int _secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    // Compter les secondes
    Future.doWhile(() async {
      await Future.delayed(Duration(seconds: 1));
      if (mounted) {
        setState(() => _secondsElapsed++);
        return true;
      }
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Empêcher la fermeture
      child: AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text(
              'Paiement en cours...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'Un SMS a été envoyé au\n${widget.phoneNumber}',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              'Veuillez composer le code USSD\npour confirmer le paiement',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 16),
            Text(
              'Temps écoulé: ${_secondsElapsed}s',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
