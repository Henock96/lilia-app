import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lilia_app/core/update/app_update_dialog.dart';
import 'package:lilia_app/core/update/app_update_model.dart';
import 'package:lilia_app/core/update/app_update_service.dart';

/// Présente les dialogues de mise à jour depuis l'écran qui l'adopte.
///
/// ## Cycle de vie (UPD-004)
///
/// Remplace `_updateDialogShown`, un booléen de `HomeScreen` posé une fois
/// pour toute la vie de l'écran — qui est gardé en vie (`keepAlive`), donc
/// pour toute la session :
///
/// * une invitation **facultative** affichée empêchait ensuite tout blocage
///   publié dans la même session ;
/// * rien ne se réévaluait à la fermeture d'un dialogue ;
/// * un blocage levé laissait le dialogue obligatoire à l'écran jusqu'au
///   redémarrage (corrigé dans le dialogue lui-même, qui suit l'état).
///
/// Désormais : un seul dialogue à la fois, et à chaque fermeture — par
/// l'utilisateur ou parce que le dialogue est devenu caduc — l'état courant
/// est réévalué. Une facultative refermée parce qu'un blocage vient d'être
/// posé laisse ainsi place à l'obligatoire.
///
/// Mixin plutôt que widget enveloppe : l'écran d'accueil garde sa structure,
/// et le comportement se teste sur un hôte minimal.
mixin AppUpdateGate<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// Dialogue actuellement à l'écran, `null` sinon.
  UpdateRequirement? _dialogShowing;

  /// Version déjà proposée (facultative) pendant cette session : fermée d'un
  /// tap à côté, l'invitation ne revient pas à chaque relecture des réglages ;
  /// une **nouvelle** version, si.
  String? _optionalOfferedFor;

  @override
  void initState() {
    super.initState();
    // `fireImmediately` : si l'état est déjà connu, on l'applique tout de
    // suite au lieu d'attendre le prochain changement.
    ref.listenManual<AsyncValue<AppUpdateInfo>>(appUpdateInfoProvider, (
      _,
      next,
    ) {
      // Seules les valeurs établies comptent : un rechargement ou une erreur
      // réseau ne doivent ni ouvrir ni fermer un dialogue.
      if (next is AsyncData<AppUpdateInfo>) _onUpdateInfo(next.value);
    }, fireImmediately: true);
  }

  Future<void> _onUpdateInfo(AppUpdateInfo info) async {
    if (!mounted || _dialogShowing != null) return;

    if (info.isMandatory) {
      await _showUpdateDialog(UpdateRequirement.mandatory, info);
    } else if (info.isOptional) {
      final versionKey = info.latestAvailableVersion?.toString() ?? 'latest';
      if (_optionalOfferedFor == versionKey) return;
      final service = ref.read(appUpdateServiceProvider);
      if (!await service.shouldPromptOptionalUpdate(versionKey)) return;
      if (!mounted || _dialogShowing != null) return;
      _optionalOfferedFor = versionKey;
      await _showUpdateDialog(UpdateRequirement.optional, info);
    }
  }

  Future<void> _showUpdateDialog(
    UpdateRequirement kind,
    AppUpdateInfo info,
  ) async {
    _dialogShowing = kind;
    // `showDialog` ne peut pas être appelé pendant un build : le premier
    // déclenchement (`fireImmediately`) a lieu dans `initState`.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      _dialogShowing = null;
      return;
    }
    try {
      if (kind == UpdateRequirement.mandatory) {
        await AppUpdateDialog.showMandatory(context, info);
      } else {
        await AppUpdateDialog.showOptional(context, info);
      }
    } finally {
      _dialogShowing = null;
    }
    if (!mounted) return;
    final current = ref.read(appUpdateInfoProvider);
    if (current is AsyncData<AppUpdateInfo>) {
      await _onUpdateInfo(current.value);
    }
  }
}
