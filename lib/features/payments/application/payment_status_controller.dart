import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:lilia_app/features/payments/data/payment_service.dart';
import 'package:lilia_app/features/payments/domain/payment_failure.dart';
import 'package:lilia_app/core/log.dart';

part 'payment_status_controller.g.dart';

/// État de l'attente de paiement, du point de vue de l'écran.
enum PaymentWaitPhase {
  /// Le prestataire traite ; le client doit valider sur son téléphone.
  waiting,

  /// Paiement confirmé.
  succeeded,

  /// Paiement refusé, expiré, ou abandonné.
  failed,

  /// Ni le prestataire ni le serveur n'ont tranché dans le temps imparti.
  ///
  /// **Ce n'est pas un échec.** Le paiement peut aboutir après coup, confirmé
  /// par le webhook : dire au client que c'est raté serait faux et l'inviterait
  /// à payer une seconde fois.
  undetermined,
}

class PaymentWaitState {
  const PaymentWaitState({
    required this.phase,
    required this.elapsed,
    this.outcome,
    this.failureCode,
  });

  final PaymentWaitPhase phase;

  /// Temps écoulé depuis le début de l'attente — alimente le chronomètre.
  final Duration elapsed;

  /// Issue métier, dérivée du statut serveur et du code d'échec.
  ///
  /// L'état ne transporte volontairement **aucun texte** : le message affiché
  /// est produit par `mapPaymentFailure`, à l'affichage. Faire voyager une
  /// chaîne ici, c'était laisser passer celle de l'opérateur.
  final PaymentOutcome? outcome;

  /// Code d'échec du prestataire — **pour les journaux et le mapper**, jamais
  /// pour l'écran.
  final String? failureCode;

  PaymentWaitState copyWith({
    PaymentWaitPhase? phase,
    Duration? elapsed,
    PaymentOutcome? outcome,
    String? failureCode,
  }) =>
      PaymentWaitState(
        phase: phase ?? this.phase,
        elapsed: elapsed ?? this.elapsed,
        outcome: outcome ?? this.outcome,
        failureCode: failureCode ?? this.failureCode,
      );
}

/// Suit un paiement jusqu'à son issue.
///
/// **Deux sources concourantes, et c'est voulu** :
///  · l'interrogation périodique de `GET /payments/:id/status` ;
///  · le push FCM `payment_confirmed` / `payment_failed`, qui arrive
///    généralement avant l'interrogation suivante.
///
/// La première qui tranche gagne ; le serveur étant la seule autorité, les deux
/// disent la même chose. Le polling seul suffirait, mais il ferait attendre le
/// client jusqu'à trois secondes de plus sur une 4G lente.
///
/// **Cadence** : 3 s pendant la première minute (le client compose son code),
/// puis 5 s. Au-delà de trois minutes on s'arrête sur `undetermined` — continuer
/// consommerait sa data sans rien apprendre, et le webhook tranchera de son côté.
@riverpod
class PaymentStatusController extends _$PaymentStatusController {
  Timer? _timer;
  DateTime? _startedAt;

  /// Plus d'interrogation **automatique** : issue tranchée, abandon après
  /// trois minutes, ou écran fermé.
  bool _stopped = false;

  /// L'écran a disparu : plus rien du tout, pas même une vérification
  /// demandée.
  bool _disposed = false;

  /// Une vérification manuelle est en cours (C-04).
  bool _checking = false;

  /// Horloge injectable : l'abandon à trois minutes n'est pas testable sur une
  /// horloge réelle.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  static const _fastInterval = Duration(seconds: 3);
  static const _slowInterval = Duration(seconds: 5);
  static const _fastPhase = Duration(seconds: 60);
  static const _giveUpAfter = Duration(minutes: 3);

  @override
  PaymentWaitState build(String paymentId) {
    _startedAt = now();

    ref.onDispose(() {
      _disposed = true;
      _stopped = true;
      _timer?.cancel();
    });

    // Premier contrôle après le délai conseillé par le serveur : interroger
    // immédiatement ne renverrait que PENDING.
    _schedule(_fastInterval);

    return const PaymentWaitState(
      phase: PaymentWaitPhase.waiting,
      elapsed: Duration.zero,
    );
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    if (_stopped) return;
    _timer = Timer(delay, _poll);
  }

  Future<void> _poll() async {
    if (_stopped) return;

    final elapsed = now().difference(_startedAt!);

    if (elapsed >= _giveUpAfter) {
      _finish(
        const PaymentWaitState(
          phase: PaymentWaitPhase.undetermined,
          elapsed: _giveUpAfter,
        ),
      );
      return;
    }

    try {
      final status = await ref
          .read(paymentServiceProvider)
          .checkPaymentStatus(paymentId);

      if (_stopped) return;

      if (status.isTerminal) {
        // Le détail technique part dans les journaux, jamais dans l'état.
        if (status.status != PaymentStatus.success) {
          logDebug(
            '💰 Paiement ${status.paymentId} terminé — statut ${status.status}, '
            'code ${status.failureCode ?? "n/a"}, '
            'message prestataire « ${status.failureMessage ?? "n/a"} »',
          );
        }
        _finish(
          PaymentWaitState(
            phase: status.status == PaymentStatus.success
                ? PaymentWaitPhase.succeeded
                : PaymentWaitPhase.failed,
            elapsed: elapsed,
            outcome: outcomeOf(
              status: status.status,
              failureCode: status.failureCode,
            ),
            failureCode: status.failureCode,
          ),
        );
        return;
      }

      state = state.copyWith(elapsed: elapsed);
    } catch (e) {
      // Une interrogation qui échoue ne change rien à l'état du paiement : on
      // réessaie. Couper ici sur une coupure réseau ferait croire à un échec.
      logDebug('⏳ Interrogation du statut échouée : $e');
      state = state.copyWith(elapsed: elapsed);
    }

    _schedule(elapsed < _fastPhase ? _fastInterval : _slowInterval);
  }

  void _finish(PaymentWaitState finalState) {
    _stopped = true;
    _timer?.cancel();
    state = finalState;
  }

  /// Prise en compte d'un push FCM concernant ce paiement.
  ///
  /// Le push ne fait pas autorité à lui seul : il **déclenche une vérification
  /// immédiate** plutôt que de fixer l'état. Un payload de notification n'est
  /// pas une source financière — seul le serveur l'est.
  void onPushReceived() {
    if (state.phase == PaymentWaitPhase.undetermined) {
      // C-04 : le push qui arrive après l'abandon est précisément celui qui
      // apporte l'issue. Il était ignoré (`_stopped`).
      unawaited(_checkOnce());
      return;
    }
    if (_stopped) return;
    _schedule(Duration.zero);
  }

  /// Interrogation manuelle (bouton « Vérifier maintenant »).
  Future<void> refreshNow() async {
    if (state.phase == PaymentWaitPhase.undetermined) {
      await _checkOnce();
      return;
    }
    if (_stopped) return;
    _timer?.cancel();
    await _poll();
  }

  /// Une vérification, une seule, après l'abandon de l'interrogation
  /// automatique (C-04, audit du 09/10/2026).
  ///
  /// Après trois minutes, l'écran passait en `undetermined` et `_stopped`
  /// neutralisait **tout** : « Vérifier maintenant » et le push FCM ne
  /// faisaient plus rien. Un client qui validait sur son téléphone à la
  /// quatrième minute restait devant « Paiement toujours en cours » sans
  /// moyen de le voir aboutir.
  ///
  /// `GET /payments/:id/status` interroge le prestataire tant que le
  /// paiement est `PENDING` : c'est bien une vérification, pas une lecture.
  /// Toujours `PENDING` : on reste en `undetermined`, sans relancer de
  /// cadence — le webhook tranchera de son côté.
  Future<void> _checkOnce() async {
    if (_disposed || _checking) return;
    _checking = true;
    try {
      final status = await ref
          .read(paymentServiceProvider)
          .checkPaymentStatus(paymentId);
      if (_disposed || !status.isTerminal) return;
      state = PaymentWaitState(
        phase: status.status == PaymentStatus.success
            ? PaymentWaitPhase.succeeded
            : PaymentWaitPhase.failed,
        elapsed: state.elapsed,
        outcome: outcomeOf(
          status: status.status,
          failureCode: status.failureCode,
        ),
        failureCode: status.failureCode,
      );
    } catch (e) {
      logDebug('⏳ Vérification manuelle du statut échouée : $e');
    } finally {
      _checking = false;
    }
  }
}

/// Dernière tentative d'encaissement d'une commande, ou `null`.
///
/// Sert à une seule chose, mais elle est importante : savoir si un paiement est
/// **déjà en cours** avant de proposer « Payer maintenant ». Sans cette
/// information, l'écran de commande offrait une reprise pendant qu'une demande
/// attendait sur le téléphone du client — le geste exact qui invite au double
/// paiement.
///
/// Lecture pure, non rafraîchie automatiquement : l'écran d'attente s'occupe du
/// suivi actif. Ici, on veut l'état au moment où le client regarde sa commande.
@riverpod
Future<PaymentStatusResponse?> orderPayment(Ref ref, String orderId) {
  return ref.read(paymentServiceProvider).getPaymentForOrder(orderId);
}
