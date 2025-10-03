import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/features/user/application/adresse_controller.dart';

class AddressPage extends ConsumerStatefulWidget {
  const AddressPage({super.key});

  @override
  ConsumerState<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends ConsumerState<AddressPage> {
  final _formKey = GlobalKey<FormState>();
  final _rueController = TextEditingController();
  final _villeController = TextEditingController(text: 'Brazzaville');
  final _paysController = TextEditingController(text: 'Congo');

  @override
  void dispose() {
    _rueController.dispose();
    _villeController.dispose();
    _paysController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        await ref
            .read(adresseControllerProvider.notifier)
            .createAdresse(
              rue: _rueController.text,
              ville: _villeController.text,
              pays: _paysController.text,
            );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adresse ajoutée avec succès')),
        );
        _rueController.clear();
        ref.invalidate(adresseControllerProvider);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'ajout de l\'adresse: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(adresseControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Adresses'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mes Adresses : ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: addressesAsync.when(
                data: (addresses) {
                  if (addresses.isEmpty) {
                    return const Center(
                      child: Text('Aucune adresse enregistrée.'),
                    );
                  }
                  return ListView.builder(
                    itemCount: addresses.length,
                    itemBuilder: (context, index) {
                      final address = addresses[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ListTile(
                          title: Text(address.rue),
                          subtitle: Text(
                            '${address.ville}, ${address.country}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Confirmer la suppression'),
                                  content: const Text(
                                    'Voulez-vous vraiment supprimer cette adresse ?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Annuler'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text('Supprimer'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                try {
                                  await ref
                                      .read(adresseControllerProvider.notifier)
                                      .deleteAdresse(address.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Adresse supprimée avec succès',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Erreur lors de la suppression: $e',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Erreur: $err')),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Ajouter une nouvelle adresse :',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _rueController,
                    decoration: const InputDecoration(
                      labelText: 'Rue/ Avenue...',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer une rue';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _villeController,
                    decoration: const InputDecoration(labelText: 'Ville'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer une ville';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _paysController,
                    decoration: const InputDecoration(labelText: 'Pays'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer un pays';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: _submitForm,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10.0, left: 10.0),
                        child: const Text('Ajouter cette nouvelle adresse'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
