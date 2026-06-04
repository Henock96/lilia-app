/// Formatage centralisé des montants en Francs CFA pour l'app cliente.
///
/// Affiche le terme courant au Congo (« FCFA ») avec séparateur de milliers
/// (espace fine insécable, style français) : `150000` → « 150 000 FCFA ».
///
/// Indépendant des données de locale `intl` (groupement manuel) → aucun risque
/// d'erreur « locale data not loaded » au runtime.
String formatPrice(num amount) {
  final rounded = amount.round();
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(' '); // espace fine insécable (groupement FR)
    }
    buffer.write(digits[i]);
  }
  return '${rounded < 0 ? '-' : ''}$buffer FCFA';
}

/// Variante sans suffixe devise — utile quand l'unité est affichée à part.
String formatAmount(num amount) {
  final rounded = amount.round();
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return '${rounded < 0 ? '-' : ''}$buffer';
}
