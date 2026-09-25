/// Réclamation sur une commande livrée (F3-06).
///
/// Le client dit ce qu'il constate — un motif, des articles, une photo. Le
/// montant n'est jamais calculé ici : le service client décide, et l'issue
/// revient dans « Mes demandes ».
library;

/// Motifs proposés — même liste fermée que le serveur (`CLAIM_REASONS`).
enum ClaimReason {
  missingItem('MISSING_ITEM', 'Il manque un article', 'Article manquant'),
  wrongItem('WRONG_ITEM', 'Je n’ai pas reçu le bon article', 'Article erroné'),
  damaged('DAMAGED', 'Un article est abîmé ou renversé', 'Article abîmé'),
  late('LATE', 'La livraison a été très en retard', 'Retard'),
  other('OTHER', 'Autre chose', 'Autre');

  const ClaimReason(this.wire, this.question, this.short);

  final String wire;
  final String question;
  final String short;

  /// Le serveur exige des articles pour ces trois motifs (400 sinon).
  bool get needsItems =>
      this == missingItem || this == wrongItem || this == damaged;
}

/// Libellé court d'un motif, y compris les signalements antérieurs à F3-06.
String claimReasonLabel(String wire) {
  for (final r in ClaimReason.values) {
    if (r.wire == wire) return r.short;
  }
  return switch (wire) {
    'NOT_RECEIVED' => 'Commande non reçue',
    'WRONG_ORDER' => 'Mauvaise commande',
    _ => 'Demande',
  };
}

/// Ce que voit le client : l'issue si elle existe, sinon où en est sa demande.
String claimStatusLabel(String status, String? outcome) {
  switch (outcome) {
    case 'REFUNDED':
      return 'Remboursée';
    case 'VOUCHER':
      return 'Avoir offert';
    case 'REJECTED':
      return 'Réponse donnée';
  }
  return switch (status) {
    'OPEN' => 'Envoyée',
    'IN_PROGRESS' => 'En cours de traitement',
    _ => 'Traitée',
  };
}

String _s(Object? v) => v is String ? v : '';
int _i(Object? v) => v is num ? v.toInt() : 0;
DateTime _d(Object? v) =>
    (v is String ? DateTime.tryParse(v) : null)?.toLocal() ?? DateTime(1970);

class ClaimSummary {
  const ClaimSummary({
    required this.id,
    required this.orderId,
    required this.orderRef,
    required this.status,
    required this.reason,
    required this.summary,
    required this.outcome,
    required this.createdAt,
  });

  final String id;
  final String orderId;
  final String orderRef;
  final String status;
  final String reason;
  final String summary;
  final String? outcome;
  final DateTime createdAt;

  factory ClaimSummary.fromJson(Map<String, dynamic> json) => ClaimSummary(
    id: _s(json['id']),
    orderId: _s(json['orderId']),
    orderRef: _s(json['orderRef']),
    status: _s(json['status']),
    reason: _s(json['reason']),
    summary: _s(json['summary']),
    outcome: json['outcome'] as String?,
    createdAt: _d(json['createdAt']),
  );
}

class ClaimMessage {
  const ClaimMessage({
    required this.id,
    required this.authorLabel,
    required this.mine,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String authorLabel;
  final bool mine;
  final String body;
  final DateTime createdAt;

  factory ClaimMessage.fromJson(Map<String, dynamic> json) => ClaimMessage(
    id: _s(json['id']),
    authorLabel: _s(json['authorLabel']),
    mine: json['mine'] == true,
    body: _s(json['body']),
    createdAt: _d(json['createdAt']),
  );
}

class ClaimRefund {
  const ClaimRefund({
    required this.amountXaf,
    required this.status,
    required this.fromThisClaim,
  });

  final int amountXaf;
  final String status;
  final bool fromThisClaim;

  factory ClaimRefund.fromJson(Map<String, dynamic> json) => ClaimRefund(
    amountXaf: _i(json['amountXaf']),
    status: _s(json['status']),
    fromThisClaim: json['fromThisClaim'] == true,
  );
}

class ClaimVoucher {
  const ClaimVoucher({
    required this.code,
    required this.amountXaf,
    required this.expiresAt,
  });

  final String code;
  final int amountXaf;
  final DateTime expiresAt;
}

class ClaimDetail {
  const ClaimDetail({
    required this.id,
    required this.orderRef,
    required this.status,
    required this.reason,
    required this.outcome,
    required this.restaurantName,
    required this.items,
    required this.messages,
    required this.refunds,
    required this.voucher,
  });

  final String id;
  final String orderRef;
  final String status;
  final String reason;
  final String? outcome;
  final String restaurantName;
  final List<({int quantity, String label})> items;
  final List<ClaimMessage> messages;
  final List<ClaimRefund> refunds;
  final ClaimVoucher? voucher;

  bool get isClosed => status == 'CLOSED';

  factory ClaimDetail.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(Object? v) =>
        v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];
    final order = json['order'];
    final restaurant = order is Map ? order['restaurant'] : null;
    final voucher = json['voucher'];
    return ClaimDetail(
      id: _s(json['id']),
      orderRef: _s(json['orderRef']),
      status: _s(json['status']),
      reason: _s(json['reason']),
      outcome: json['outcome'] as String?,
      restaurantName: restaurant is Map ? _s(restaurant['nom']) : '',
      items: [
        for (final i in list(json['items']))
          (quantity: _i(i['quantity']), label: _s(i['label'])),
      ],
      messages: list(json['messages']).map(ClaimMessage.fromJson).toList(),
      refunds: list(json['refunds']).map(ClaimRefund.fromJson).toList(),
      voucher: voucher is Map<String, dynamic>
          ? ClaimVoucher(
              code: _s(voucher['code']),
              amountXaf: _i(voucher['amountXaf']),
              expiresAt: _d(voucher['expiresAt']),
            )
          : null,
    );
  }
}

/// Ce que le client envoie : un motif, des articles (id → quantité), un mot,
/// des photos déjà téléversées.
class ClaimDraft {
  const ClaimDraft({
    required this.reason,
    this.items = const {},
    this.note,
    this.photoUrls = const [],
  });

  final ClaimReason reason;
  final Map<String, int> items;
  final String? note;
  final List<String> photoUrls;

  bool get isComplete =>
      !reason.needsItems || items.values.any((qty) => qty > 0);

  Map<String, dynamic> toJson() {
    final chosen = items.entries.where((e) => e.value > 0).toList();
    final text = note?.trim();
    return {
      'reason': reason.wire,
      if (chosen.isNotEmpty)
        'items': [
          for (final e in chosen) {'orderItemId': e.key, 'quantity': e.value},
        ],
      if (text != null && text.isNotEmpty) 'note': text,
      if (photoUrls.isNotEmpty) 'photoUrls': photoUrls,
    };
  }
}
