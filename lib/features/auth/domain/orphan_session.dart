import '../../../core/network/api_exception.dart';

/// Refus du serveur qui disent « ce compte n'existe pas (ou plus) chez nous »,
/// alors que Firebase garde la session du téléphone.
///
/// Le code est lu en priorité ; le texte ne sert qu'aux serveurs antérieurs
/// au code (même message, mot pour mot, depuis août 2026).
enum AccountRefusal { notSynced, revoked }

AccountRefusal? accountRefusalOf(Object error) {
  if (error is! ApiException || error.statusCode != 403) return null;
  switch (error.code) {
    case 'ACCOUNT_NOT_SYNCED':
      return AccountRefusal.notSynced;
    case 'ACCOUNT_REVOKED':
      return AccountRefusal.revoked;
  }
  if (error.message.startsWith('Compte non synchronisé')) {
    return AccountRefusal.notSynced;
  }
  return null;
}
