/// Formatage centralisé des montants en Francs CFA pour l'app cliente.
///
/// Affiche le code devise standard du projet (« XAF », pas « FCFA » — aligné
/// sur l'admin et le backend) avec séparateur de milliers (espace, style
/// français) : `150000` → « 150 000 XAF ».
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
  return '${rounded < 0 ? '-' : ''}$buffer XAF';
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
