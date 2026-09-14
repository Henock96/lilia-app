import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/features/user/application/profile_controller.dart';

/// Affiche le bottom-sheet de collecte du numero si l'utilisateur connecte
/// n'a pas encore de numero. Skippable. A appeler apres une connexion Google.
Future<void> maybePromptPhoneNumber(BuildContext context, WidgetRef ref) async {
  try {
    final profile = await ref.read(userProfileProvider.future);
    final hasPhone = (profile.phone ?? '').trim().isNotEmpty;
    if (hasPhone || !context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => const PhoneCollectionSheet(),
    );
  } catch (_) {
    // Best-effort : ne jamais bloquer le flux de connexion.
  }
}

class PhoneCollectionSheet extends ConsumerStatefulWidget {
  const PhoneCollectionSheet({super.key});

  @override
  ConsumerState<PhoneCollectionSheet> createState() =>
      _PhoneCollectionSheetState();
}

class _PhoneCollectionSheetState extends ConsumerState<PhoneCollectionSheet> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _erreur;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Enregistre le numéro.
  ///
  /// ⚠️ L'échec **doit** se voir. La version précédente lisait le `bool` rendu
  /// par `updateUser`, remettait `_saving` à `false` et s'arrêtait là : le
  /// client voyait l'indicateur tourner puis s'éteindre, sans message et sans
  /// que la feuille se ferme. Rien ne lui disait s'il devait réessayer.
  Future<void> _save() async {
    final phone = _controller.text.trim();
    if (phone.isEmpty) {
      setState(() => _erreur = 'Entrez votre numéro de téléphone.');
      return;
    }

    setState(() {
      _saving = true;
      _erreur = null;
    });

    final echec = await ref
        .read(profileControllerProvider.notifier)
        .updateUser({'phone': phone});

    if (!mounted) return;
    setState(() {
      _saving = false;
      _erreur = echec;
    });

    // On ne referme que sur un succès : sinon le client doit pouvoir corriger
    // et réessayer sans rouvrir la feuille.
    if (echec == null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ajoutez votre numéro',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Pour le suivi de vos commandes et nos messages importants.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('phone_collection_field'),
            controller: _controller,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Numéro de téléphone',
              prefixIcon: const Icon(Icons.phone_outlined),
              errorText: _erreur,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('phone_collection_save'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enregistrer'),
          ),
          TextButton(
            key: const Key('phone_collection_skip'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Plus tard'),
          ),
        ],
      ),
    );
  }
}
