import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/core/update/app_update_model.dart';
import 'package:lilia_app/core/update/app_update_service.dart';
import 'package:lilia_app/features/settings/data/platform_settings_service.dart';
import 'package:lilia_app/theme/lilia_tokens.dart';

/// Dialogues de mise à jour — obligatoire (non fermable) et facultative.
///
/// ## Un dialogue qui suit l'état, pas une photo de l'état (UPD-004)
///
/// Les deux dialogues **observent** `appUpdateInfoProvider` et se referment
/// d'eux-mêmes quand l'exigence qu'ils représentent disparaît :
///
/// * l'obligatoire, quand l'administrateur lève le blocage ;
/// * la facultative, quand un blocage est posé (l'appelant affiche alors
///   l'obligatoire) ou quand plus rien n'est proposé.
///
/// Auparavant, un dialogue obligatoire affiché restait à l'écran jusqu'au
/// redémarrage de l'app, même blocage levé.
///
/// Le dialogue obligatoire relit en plus les réglages **au retour dans
/// l'application** : c'est le moment où l'utilisateur revient du store sans
/// avoir pu mettre à jour, ou après qu'on lui a dit « c'est réglé ».
class AppUpdateDialog {
  static Future<void> showMandatory(BuildContext context, AppUpdateInfo info) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: _AppUpdateDialogBody(initialInfo: info, mandatory: true),
      ),
    );
  }

  static Future<void> showOptional(BuildContext context, AppUpdateInfo info) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _AppUpdateDialogBody(initialInfo: info, mandatory: false),
    );
  }
}

class _AppUpdateDialogBody extends ConsumerStatefulWidget {
  const _AppUpdateDialogBody({
    required this.initialInfo,
    required this.mandatory,
  });

  final AppUpdateInfo initialInfo;
  final bool mandatory;

  @override
  ConsumerState<_AppUpdateDialogBody> createState() =>
      _AppUpdateDialogBodyState();
}

class _AppUpdateDialogBodyState extends ConsumerState<_AppUpdateDialogBody> {
  AppLifecycleListener? _lifecycle;
  bool _opening = false;
  bool _openFailed = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    if (widget.mandatory) {
      _lifecycle = AppLifecycleListener(
        onResume: () => ref.invalidate(platformSettingsProvider),
      );
    }
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  /// Ce dialogue représente-t-il encore l'exigence courante ?
  bool _stillRelevant(AppUpdateInfo info) =>
      widget.mandatory ? info.isMandatory : info.isOptional;

  void _closeSoon() {
    if (_closing) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _openStore(AppUpdateInfo info) async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _openFailed = false;
    });
    final result = await ref.read(appUpdateServiceProvider).openStore(info);
    if (!mounted) return;
    setState(() {
      _opening = false;
      _openFailed = result == StoreOpenResult.failed;
    });
    // Facultative : on ne referme que si le store s'est réellement ouvert.
    // Refermer sur un échec, c'était dire « c'est parti » quand rien ne
    // l'était.
    if (!widget.mandatory && result == StoreOpenResult.opened) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Seules les valeurs *établies* pilotent la fermeture : pendant un
    // rechargement, ou si le réseau tombe, le dialogue reste tel quel. Un
    // blocage ne se lève jamais sur une erreur de lecture.
    final async = ref.watch(appUpdateInfoProvider);
    final latest = async is AsyncData<AppUpdateInfo> ? async.value : null;
    if (latest != null && !_stillRelevant(latest)) _closeSoon();
    final info = latest ?? widget.initialInfo;

    final service = ref.read(appUpdateServiceProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: widget.mandatory ? 8 : 6,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 24,
          vertical: widget.mandatory ? 28 : 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: widget.mandatory ? 72 : 64,
              height: widget.mandatory ? 72 : 64,
              decoration: BoxDecoration(
                color: LiliaColors.orange600.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.mandatory
                    ? Icons.system_update_rounded
                    : Icons.new_releases_rounded,
                size: widget.mandatory ? 38 : 34,
                color: LiliaColors.orange600,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.mandatory
                  ? 'Mise à jour requise'
                  : 'Nouvelle version disponible',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: widget.mandatory ? 20 : 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              info.updateMessage ??
                  (widget.mandatory
                      ? 'Une mise à jour importante de Lilia Food est requise pour continuer à commander vos repas en toute sécurité.'
                      : 'Une nouvelle version de Lilia Food est disponible avec des améliorations de performance et de nouvelles fonctionnalités.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            if (widget.mandatory && info.minSupportedVersion != null) ...[
              const SizedBox(height: 10),
              _VersionChip('Version minimale : v${info.minSupportedVersion}'),
            ],
            if (!widget.mandatory && info.latestAvailableVersion != null) ...[
              const SizedBox(height: 8),
              _VersionChip('Version ${info.latestAvailableVersion}'),
            ],
            if (_openFailed) ...[
              const SizedBox(height: 16),
              _StoreOpenFailure(
                storeName: service.storeName,
                link: service.fallbackLink(info),
              ),
            ],
            const SizedBox(height: 22),
            if (widget.mandatory)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: _UpdateButton(
                  opening: _opening,
                  label: _openFailed ? 'Réessayer' : 'Mettre à jour maintenant',
                  onPressed: () => _openStore(info),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        final versionKey =
                            info.latestAvailableVersion?.toString() ?? 'latest';
                        await service.dismissOptionalUpdate(versionKey);
                        if (mounted) navigator.pop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Plus tard'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _UpdateButton(
                      opening: _opening,
                      label: _openFailed ? 'Réessayer' : 'Mettre à jour',
                      onPressed: () => _openStore(info),
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

class _UpdateButton extends StatelessWidget {
  const _UpdateButton({
    required this.opening,
    required this.label,
    required this.onPressed,
  });

  final bool opening;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      // Désactivé pendant l'ouverture : deux taps rapides lançaient deux
      // intentions vers le store.
      onPressed: opening ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: LiliaColors.orange600,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: opening
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
    );
  }
}

class _VersionChip extends StatelessWidget {
  const _VersionChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Ce qu'on dit quand aucune destination n'a pu s'ouvrir (UPD-002).
///
/// Le dialogue obligatoire reste fermé à la sortie — c'est sa raison d'être —
/// mais il ne laisse plus l'utilisateur sans consigne : il nomme le store, dit
/// quoi y chercher, et propose le lien à copier.
class _StoreOpenFailure extends StatelessWidget {
  const _StoreOpenFailure({required this.storeName, required this.link});

  final String storeName;
  final String link;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('store-open-failure'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            "Impossible d'ouvrir le store.\n"
            'Ouvrez $storeName et cherchez « Lilia Food » pour mettre à jour.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.red.shade900),
          ),
          TextButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              await Clipboard.setData(ClipboardData(text: link));
              messenger?.showSnackBar(
                const SnackBar(content: Text('Lien copié')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copier le lien'),
          ),
        ],
      ),
    );
  }
}
