import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/lilia_tokens.dart';
import '../../data/delivery_review_repository.dart';

/// Notation du livreur, présentée en bottom sheet à la fin d'une livraison.
///
/// Une feuille plutôt qu'un écran : la notation est un geste court, et sortir
/// le client de sa commande pour trois étoiles serait disproportionné. Elle
/// s'ouvre depuis le détail de commande quand la livraison est `LIVRER` et
/// qu'aucune note n'existe encore.
class RateDriverSheet extends ConsumerStatefulWidget {
  const RateDriverSheet({
    super.key,
    required this.deliveryId,
    this.driverName,
  });

  final String deliveryId;
  final String? driverName;

  /// Ouvre la feuille. Renvoie `true` si une note a été enregistrée.
  static Future<bool?> show(
    BuildContext context, {
    required String deliveryId,
    String? driverName,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: RateDriverSheet(
          deliveryId: deliveryId,
          driverName: driverName,
        ),
      ),
    );
  }

  @override
  ConsumerState<RateDriverSheet> createState() => _RateDriverSheetState();
}

class _RateDriverSheetState extends ConsumerState<RateDriverSheet> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating < 1) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(deliveryReviewRepositoryProvider).rateDriver(
            deliveryId: widget.deliveryId,
            rating: _rating,
            comment: _commentController.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      // Le backend refuse notamment une seconde note (409) : on affiche son
      // message plutôt qu'une erreur générique.
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = isDark ? LiliaSemantics.dark : LiliaSemantics.light;
    final who = widget.driverName?.trim();

    return Container(
      decoration: BoxDecoration(
        color: t.bgElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: t.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            who != null && who.isNotEmpty
                ? 'Comment s\'est passée la livraison avec $who ?'
                : 'Comment s\'est passée votre livraison ?',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // Sélection 1 à 5 étoiles.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final value = i + 1;
              final filled = value <= _rating;
              return IconButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() => _rating = value),
                iconSize: 38,
                icon: Icon(
                  filled ? Icons.star_rounded : Icons.star_border_rounded,
                  color: filled ? Colors.amber : t.border,
                ),
                tooltip: '$value étoile${value > 1 ? 's' : ''}',
              );
            }),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _commentController,
            enabled: !_submitting,
            maxLines: 3,
            maxLength: 1000,
            decoration: InputDecoration(
              hintText: 'Un commentaire ? (optionnel)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: t.danger, fontSize: 13),
            ),
          ],

          const SizedBox(height: 12),
          FilledButton(
            onPressed: _rating >= 1 && !_submitting ? _submit : null,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Envoyer ma note'),
          ),
        ],
      ),
    );
  }
}
