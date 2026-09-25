import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../models/order_item.dart';
import '../../../routing/app_route_enum.dart';
import '../../../utils/snackbar.dart';
import '../../commandes/data/order_controller.dart';
import '../data/claims_repository.dart';
import '../domain/claim.dart';
import 'claims_providers.dart';

/// « Un problème avec ma commande ? » (F3-06) — commande livrée, 24 h.
class ClaimFormPage extends ConsumerStatefulWidget {
  const ClaimFormPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<ClaimFormPage> createState() => _ClaimFormPageState();
}

class _ClaimFormPageState extends ConsumerState<ClaimFormPage> {
  static const _maxPhotos = 3;

  ClaimReason? _reason;
  final Map<String, int> _items = {};
  final _note = TextEditingController();
  final List<String> _photos = [];
  bool _uploading = false;
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  ClaimDraft? get _draft => _reason == null
      ? null
      : ClaimDraft(
          reason: _reason!,
          items: _items,
          note: _note.text,
          photoUrls: _photos,
        );

  Future<void> _addPhoto() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
    );
    if (image == null) return;
    setState(() => _uploading = true);
    try {
      final url = await ref.read(claimsRepositoryProvider).uploadPhoto(image);
      if (mounted) setState(() => _photos.add(url));
    } catch (e) {
      if (mounted) context.showErrorSnack('Photo non envoyée : $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    final draft = _draft;
    if (draft == null || !draft.isComplete) return;
    setState(() => _sending = true);
    try {
      final claim = await ref
          .read(claimsRepositoryProvider)
          .open(widget.orderId, draft);
      ref.invalidate(myClaimsProvider);
      if (!mounted) return;
      context.showSuccessSnack(
        'Demande envoyée. Le service client vous répond dans « Mes demandes ».',
      );
      _openClaim(claim.id);
    } on ApiException catch (e) {
      // Une demande est déjà ouverte : on y mène plutôt que d'en ouvrir une autre.
      final existing = e.details?['claimId'];
      if (e.code == 'CLAIM_ALREADY_OPEN' && existing is String) {
        if (mounted) _openClaim(existing);
        return;
      }
      if (mounted) context.showErrorSnack(e.message);
    } catch (e) {
      if (mounted) context.showErrorSnack('$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openClaim(String claimId) => context.pushReplacementNamed(
    AppRoutes.claimDetail.routeName,
    pathParameters: {'claimId': claimId},
  );

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));
    final draft = _draft;
    return Scaffold(
      appBar: AppBar(title: const Text('Un problème avec ma commande ?')),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (order) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Possible jusqu’à 24 h après la livraison. Le service client '
              'vous répond dans « Mes demandes ».',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            RadioGroup<ClaimReason>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
              child: Column(
                children: [
                  for (final r in ClaimReason.values)
                    RadioListTile<ClaimReason>(
                      key: Key('claim-reason-${r.wire}'),
                      value: r,
                      title: Text(r.question),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            if (_reason != null) ...[
              const SizedBox(height: 8),
              Text(
                _reason!.needsItems
                    ? 'Quels articles ?'
                    : 'Articles concernés (facultatif)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              for (final item in order.items) _itemTile(item),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Racontez-nous (facultatif)',
                border: OutlineInputBorder(),
              ),
            ),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final url in _photos)
                  InputChip(
                    label: const Text('Photo jointe'),
                    onDeleted: () => setState(() => _photos.remove(url)),
                  ),
                if (_photos.length < _maxPhotos)
                  ActionChip(
                    avatar: _uploading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text('Ajouter une photo'),
                    onPressed: _uploading ? null : _addPhoto,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('claim-submit'),
              onPressed:
                  draft != null && draft.isComplete && !_sending && !_uploading
                  ? _submit
                  : null,
              child: Text(_sending ? 'Envoi…' : 'Envoyer ma demande'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemTile(OrderItem item) {
    final qty = _items[item.id] ?? 0;
    return CheckboxListTile(
      key: Key('claim-item-${item.id}'),
      contentPadding: EdgeInsets.zero,
      value: qty > 0,
      title: Text(item.product.nom),
      onChanged: (checked) =>
          setState(() => _items[item.id] = checked == true ? 1 : 0),
      secondary: qty > 0 && item.quantite > 1
          ? DropdownButton<int>(
              value: qty,
              items: [
                for (var n = 1; n <= item.quantite; n++)
                  DropdownMenuItem(
                    value: n,
                    child: Text('$n / ${item.quantite}'),
                  ),
              ],
              onChanged: (n) => setState(() => _items[item.id] = n ?? 1),
            )
          : null,
    );
  }
}
