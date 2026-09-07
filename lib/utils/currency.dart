/// Formatage centralisé des montants en francs CFA.
///
/// ## Pourquoi « FCFA » et non « XAF »
///
/// Ce fichier écrivait « XAF », avec un commentaire affirmant l'alignement sur
/// l'admin et le backend. Vérification faite, les deux surfaces que voit le
/// **même acheteur** se contredisaient :
///
/// | Surface | Rendu |
/// |---|---|
/// | site client (`Intl.NumberFormat('fr-FR', { currency: 'XAF' })`) | `2 500 FCFA` |
/// | cette application | `2 500 XAF` |
/// | SMS et push du backend | `… FCFA` |
///
/// On retient **FCFA** : c'est ce qui est déjà affiché à tous les utilisateurs
/// du site, ce que le backend écrit dans les messages qu'un client lit
/// réellement, et l'usage courant à Brazzaville. « XAF » reste le code ISO,
/// employé dans les back-offices et les messages de validation — deux publics
/// différents, deux vocabulaires assumés.
///
/// ## Le séparateur de milliers
///
/// **U+202F**, espace fine insécable, exactement ce que produit `Intl` en
/// `fr-FR`. Le commentaire d'origine annonçait « espace fine insécable » et
/// écrivait une espace ordinaire (U+0020) : deux caractères différents pour
/// deux plateformes qui prétendaient afficher la même chose.
///
/// Indépendant des données de locale `intl` (groupement manuel) → aucun risque
/// d'erreur « locale data not loaded » au runtime.
library;

/// Espace fine insécable — le séparateur de milliers du français, et celui
/// qu'`Intl.NumberFormat('fr-FR')` produit côté web.
const String _thinNbsp = ' ';

/// Devise telle qu'elle s'écrit pour un client. Voir la note ci-dessus.
const String kCurrencyLabel = 'FCFA';

String _group(num amount) {
  final rounded = amount.round();
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(_thinNbsp);
    }
    buffer.write(digits[i]);
  }
  return '${rounded < 0 ? '-' : ''}$buffer';
}

/// `150000` → « 150 000 FCFA ».
///
/// ⚠️ **Toujours passer par ici pour afficher un montant.** Cinq écrans
/// interpolaient directement un `double` (`'${variant.prix} FCFA'`,
/// `toStringAsFixed(1)`), ce qui produisait « 2500.0 FCFA » — dans le panier et
/// les brouillons, c'est-à-dire précisément là où le client vérifie ce qu'il va
/// payer. Le franc CFA n'a pas de sous-unité : une décimale y est toujours un
/// bug d'affichage.
String formatPrice(num amount) => '${_group(amount)} $kCurrencyLabel';

/// Variante sans suffixe devise — utile quand l'unité est affichée à part.
String formatAmount(num amount) => _group(amount);
