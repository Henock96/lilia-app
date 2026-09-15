import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/features/user/application/adresse_controller.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:lilia_app/features/address/presentation/pages/location_picker_page.dart';
import 'package:lilia_app/features/quartiers/application/quartiers_controller.dart';
import 'package:lilia_app/models/adresse.dart';
import 'package:lilia_app/models/location_precision.dart';
import 'package:lilia_app/models/quartier.dart';
import 'package:lilia_app/utils/snackbar.dart';

class AddressPage extends ConsumerStatefulWidget {
  const AddressPage({super.key});

  @override
  ConsumerState<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends ConsumerState<AddressPage> {
  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(adresseControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Adresses'),
        centerTitle: true,
        elevation: 0,
      ),
      body: addressesAsync.when(
        data: (addresses) {
          if (addresses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.location, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune adresse enregistrée',
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ajoutez une adresse de livraison',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(adresseControllerProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: addresses.length,
              itemBuilder: (context, index) {
                return _AddressCard(
                  address: addresses[index],
                  onDelete: () =>
                      _showDeleteConfirmation(context, addresses[index]),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => BuildErrorState(
          err,
          onRetry: () => ref.invalidate(adresseControllerProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAddressSheet(context),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Iconsax.add),
        label: const Text(
          'Nouvelle adresse',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _showAddAddressSheet(BuildContext context) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddAddressSheet(),
    );
    if (created == true && context.mounted) {
      context.showSuccessSnack('Adresse ajoutée avec succès');
    }
  }


  void _showDeleteConfirmation(BuildContext context, Adresse address) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
              const SizedBox(width: 8),
              const Text('Supprimer ?'),
            ],
          ),
          content: Text(
            'Voulez-vous vraiment supprimer l\'adresse "${address.rue}" ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await ref
                      .read(adresseControllerProvider.notifier)
                      .deleteAdresse(address.id);
                  if (!context.mounted) return;
                  context.showSuccessSnack('Adresse supprimée');
                } catch (e) {
                  if (!context.mounted) return;
                  context.showErrorSnack('Erreur: $e');
                }
              },
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }
}

class _AddressCard extends ConsumerWidget {
  final Adresse address;
  final VoidCallback onDelete;

  const _AddressCard({required this.address, required this.onDelete});

  /// Désigne cette adresse comme adresse par défaut.
  Future<void> _setDefault(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(adresseControllerProvider.notifier)
          .setDefault(address.id);
      if (context.mounted) {
        context.showSuccessSnack('Adresse principale mise à jour');
      }
    } catch (e) {
      if (context.mounted) context.showErrorSnack('Erreur: $e');
    }
  }

  /// Modifie le libellé et la rue.
  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditAddressSheet(address: address),
    );
    if (saved == true && context.mounted) {
      context.showSuccessSnack('Adresse modifiée');
    }
  }

  /// Rattrapage des adresses créées avant l'existence de la position.
  ///
  /// Elles restent livrables via le centroïde de leur quartier, mais un point
  /// posé vaut mieux : plutôt que d'obliger le client à recréer son adresse,
  /// on lui propose de la situer.
  Future<void> _locate(BuildContext context, WidgetRef ref) async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          quartier: address.quartier,
          // Recadrer sur la position déjà connue plutôt que de repartir de la
          // vue générale : corriger un point de quelques dizaines de mètres
          // obligeait sinon à retrouver son quartier à la main.
          initialPosition: address.hasPosition
              ? LatLng(address.latitude!, address.longitude!)
              : null,
          initialLandmark: address.landmark,
          title: address.hasPosition
              ? 'Corriger « ${address.displayLabel} »'
              : 'Situer « ${address.displayLabel} »',
        ),
      ),
    );
    if (picked == null || !context.mounted) return;

    try {
      await ref
          .read(adresseControllerProvider.notifier)
          .updatePosition(
            address.id,
            latitude: picked.latitude,
            longitude: picked.longitude,
            landmark: picked.landmark,
          );
      if (context.mounted) context.showSuccessSnack('Position enregistrée');
    } catch (e) {
      // Le `\$` était échappé : le client lisait littéralement « Erreur: $e ».
      if (context.mounted) context.showErrorSnack('Erreur: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final cs = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icone
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: address.isDefault
                    ? cs.primary.withValues(alpha: 0.1)
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Iconsax.location,
                color: address.isDefault ? cs.primary : cs.onSurfaceVariant,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          address.displayLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (address.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Principale',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  // La rue reste affichée sous le libellé quand le client en a
                  // donné un : « Maison » situe dans la liste, « Rue Bayonne »
                  // est ce que le livreur lira.
                  if (address.displayLabel != address.rue) ...[
                    const SizedBox(height: 2),
                    Text(
                      address.rue,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Iconsax.building_3,
                        size: 14,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        address.ville,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (address.hasQuartier) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Iconsax.map, size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          address.quartier!.nom,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  _PrecisionChip(
                    precision: address.locationPrecision,
                    onLocate: () => _locate(context, ref),
                  ),
                ],
              ),
            ),

            // Actions. La suppression était la seule offerte : corriger une
            // faute de frappe imposait de supprimer puis recréer, ce qui
            // faisait aussi perdre la position posée sur la carte.
            PopupMenuButton<String>(
              tooltip: 'Actions sur cette adresse',
              icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _edit(context, ref);
                  case 'locate':
                    _locate(context, ref);
                  case 'default':
                    _setDefault(context, ref);
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined, size: 20),
                    title: Text('Modifier'),
                  ),
                ),
                PopupMenuItem(
                  value: 'locate',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.map_outlined, size: 20),
                    title: Text(
                      address.hasPosition
                          ? 'Corriger la position'
                          : 'Placer sur la carte',
                    ),
                  ),
                ),
                if (!address.isDefault)
                  const PopupMenuItem(
                    value: 'default',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.star_outline, size: 20),
                      title: Text('Définir comme principale'),
                    ),
                  ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Iconsax.trash,
                      size: 20,
                      color: Colors.red[400],
                    ),
                    title: Text(
                      'Supprimer',
                      style: TextStyle(color: Colors.red[400]),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Formulaire de création d'adresse.
///
/// Trois changements de fond par rapport à la version précédente, qui ne
/// comptait que trois champs texte (rue / ville / pays) :
///
/// 1. **le quartier est obligatoire** — c'est lui qui porte les frais de zone
///    et, à défaut de position posée, le centroïde de repli. Sans lui une
///    adresse n'est situable par rien ;
/// 2. **la position se pose sur une carte**, et c'est elle qui guidera le
///    livreur — plus le GPS du téléphone au moment de payer ;
/// 3. **« Congo » a disparu** : toutes les livraisons y sont, le champ ne
///    portait aucune information et faisait un pas de plus à remplir.
class _AddAddressSheet extends ConsumerStatefulWidget {
  const _AddAddressSheet();

  @override
  ConsumerState<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends ConsumerState<_AddAddressSheet> {
  final _formKey = GlobalKey<FormState>();
  final _rueController = TextEditingController();
  final _labelController = TextEditingController();

  Quartier? _quartier;
  PickedLocation? _position;
  bool _saving = false;

  @override
  void dispose() {
    _rueController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          quartier: _quartier,
          initialPosition: _position == null
              ? null
              : LatLng(_position!.latitude, _position!.longitude),
          initialLandmark: _position?.landmark,
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _position = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_quartier == null) {
      context.showErrorSnack('Choisissez votre quartier');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(adresseControllerProvider.notifier)
          .createAdresse(
            rue: _rueController.text.trim(),
            quartierId: _quartier!.id,
            latitude: _position?.latitude,
            longitude: _position?.longitude,
            landmark: _position?.landmark,
            label: _labelController.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showErrorSnack('Erreur: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final quartiersAsync = ref.watch(quartiersListProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Iconsax.location_add,
                        color: cs.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Nouvelle adresse',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Libellé : le modèle, le dépôt et le DTO backend le portaient
                // déjà tous les trois, seul le formulaire ne le proposait pas.
                // Trois adresses au même quartier sont indiscernables sans lui.
                TextFormField(
                  controller: _labelController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 50,
                  decoration: InputDecoration(
                    labelText: 'Nom de l\'adresse (facultatif)',
                    hintText: 'Ex : Maison, Bureau',
                    counterText: '',
                    prefixIcon: const Icon(Iconsax.tag),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _rueController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Rue / Avenue / Repère',
                    hintText: 'Ex : Rue Bayonne, près du marché',
                    prefixIcon: const Icon(Iconsax.routing),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Veuillez entrer une rue ou un repère'
                      : null,
                ),
                const SizedBox(height: 16),

                quartiersAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => Text(
                    'Quartiers indisponibles — réessayez',
                    style: TextStyle(color: cs.error, fontSize: 13),
                  ),
                  data: (quartiers) => DropdownButtonFormField<Quartier>(
                    initialValue: _quartier,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Quartier',
                      prefixIcon: const Icon(Iconsax.building_3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: quartiers
                        .map(
                          (q) => DropdownMenuItem(value: q, child: Text(q.nom)),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _quartier = value),
                    validator: (value) =>
                        value == null ? 'Choisissez votre quartier' : null,
                  ),
                ),
                const SizedBox(height: 16),

                _LocationTile(
                  position: _position,
                  onTap: _pickLocation,
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Ajouter cette adresse',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne « position sur la carte ».
///
/// Elle indique explicitement ce qui se passera si le client ne la remplit
/// pas — livraison guidée au quartier, donc appel du livreur — au lieu de
/// laisser croire que tout est en ordre. C'est une information qu'il vaut
/// mieux donner avant la commande qu'après.
class _LocationTile extends StatelessWidget {
  const _LocationTile({required this.position, required this.onTap});

  final PickedLocation? position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final done = position != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: done
                ? Colors.green.withValues(alpha: 0.5)
                : cs.outline.withValues(alpha: 0.4),
          ),
          color: done ? Colors.green.withValues(alpha: 0.05) : null,
        ),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle : Icons.map_outlined,
              color: done ? Colors.green : cs.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    done ? 'Position enregistrée' : 'Placer sur la carte',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    done
                        ? (position!.landmark ?? 'Le livreur ira à ce point')
                        : 'Sans position, le livreur sera guidé au quartier '
                              'et devra vous appeler',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// État de la position d'une adresse, dit sans détour.
///
/// Le client doit savoir **avant** de commander si le livreur pourra le
/// trouver. Une adresse sans position reste utilisable — le serveur retombe
/// sur le centroïde du quartier — mais le livreur devra appeler, et il vaut
/// mieux l'annoncer que le découvrir à la porte.
class _PrecisionChip extends StatelessWidget {
  const _PrecisionChip({required this.precision, required this.onLocate});

  final LocationPrecision precision;
  final VoidCallback onLocate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (precision == LocationPrecision.exact) {
      return Row(
        children: [
          const Icon(Icons.gps_fixed, size: 13, color: Colors.green),
          const SizedBox(width: 4),
          Text(
            'Position enregistrée',
            style: TextStyle(fontSize: 12, color: Colors.green.shade700),
          ),
        ],
      );
    }

    // `approximate` et `unknown` appellent la même action côté client : poser
    // le point. On ne distingue donc pas les deux ici — ce serait une nuance
    // sans conséquence pratique pour lui.
    return InkWell(
      onTap: onLocate,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gps_off, size: 13, color: cs.error),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Non située — appuyez pour la placer sur la carte',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modification d'une adresse existante.
///
/// Une adresse enregistrée était **définitive** : le contrôleur n'exposait que
/// `createAdresse`, `updatePosition` et `deleteAdresse`. Corriger une faute de
/// frappe dans le nom de rue, ou changer un quartier choisi trop vite,
/// obligeait à supprimer puis recréer — ce qui faisait aussi perdre la
/// position déjà posée sur la carte, et le badge d'adresse principale.
///
/// La position n'est délibérément **pas** modifiable ici : elle se pose sur une
/// carte, pas dans un champ texte. L'action « Corriger la position » du menu
/// ouvre l'écran fait pour ça.
class _EditAddressSheet extends ConsumerStatefulWidget {
  const _EditAddressSheet({required this.address});

  final Adresse address;

  @override
  ConsumerState<_EditAddressSheet> createState() => _EditAddressSheetState();
}

class _EditAddressSheetState extends ConsumerState<_EditAddressSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _rueController;
  late final TextEditingController _labelController;

  Quartier? _quartier;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rueController = TextEditingController(text: widget.address.rue);
    _labelController = TextEditingController(text: widget.address.label ?? '');
    _quartier = widget.address.quartier;
  }

  @override
  void dispose() {
    _rueController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(adresseControllerProvider.notifier)
          .updateAdresse(
            widget.address.id,
            rue: _rueController.text.trim(),
            quartierId: _quartier?.id,
            // Chaîne vide transmise volontairement : c'est ainsi qu'on efface
            // un libellé dont on ne veut plus.
            label: _labelController.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showErrorSnack('Erreur: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final quartiersAsync = ref.watch(quartiersListProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.edit_outlined,
                        color: cs.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Modifier l\'adresse',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _labelController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 50,
                  decoration: InputDecoration(
                    labelText: 'Nom de l\'adresse (facultatif)',
                    hintText: 'Ex : Maison, Bureau',
                    counterText: '',
                    prefixIcon: const Icon(Iconsax.tag),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _rueController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Rue / Avenue / Repère',
                    prefixIcon: const Icon(Iconsax.routing),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Veuillez entrer une rue ou un repère'
                      : null,
                ),
                const SizedBox(height: 16),

                quartiersAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => Text(
                    'Quartiers indisponibles — réessayez',
                    style: TextStyle(color: cs.error, fontSize: 13),
                  ),
                  data: (quartiers) {
                    // L'objet quartier de l'adresse et celui de la liste sont
                    // deux instances distinctes : sans cette résolution par
                    // identifiant, le menu s'ouvrirait vide alors qu'un
                    // quartier est bien enregistré.
                    final selected = _quartier == null
                        ? null
                        : quartiers
                              .where((q) => q.id == _quartier!.id)
                              .firstOrNull;
                    return DropdownButtonFormField<Quartier>(
                      initialValue: selected,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Quartier',
                        prefixIcon: const Icon(Iconsax.building_3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: quartiers
                          .map(
                            (q) => DropdownMenuItem(value: q, child: Text(q.nom)),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _quartier = value),
                      validator: (value) =>
                          value == null ? 'Choisissez votre quartier' : null,
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Le quartier porte les frais de zone : le changer change ce
                // que coûtera la prochaine livraison. Le dire ici évite la
                // surprise au checkout.
                Text(
                  'Le quartier détermine les frais de livraison.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Enregistrer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
