/// Libellé du badge ouvert / fermé (F3-03).
///
/// Une boutique en pause a une heure de réouverture connue : « Fermé » seul
/// laissait croire à une fermeture pour la journée. Heure de Brazzaville
/// (UTC+1, sans heure d'été), quel que soit le fuseau du téléphone.
String openingLabel(bool isOpen, DateTime? pausedUntil, {DateTime? now}) {
  if (isOpen) return 'Ouvert';
  final current = now ?? DateTime.now();
  if (pausedUntil == null || !pausedUntil.isAfter(current)) return 'Fermé';
  DateTime bzv(DateTime d) => d.toUtc().add(const Duration(hours: 1));
  final t = bzv(pausedUntil);
  final n = bzv(current);
  String two(int v) => v.toString().padLeft(2, '0');
  final hour = '${two(t.hour)}h${two(t.minute)}';
  final sameDay = t.year == n.year && t.month == n.month && t.day == n.day;
  return sameDay
      ? 'Rouvre à $hour'
      : 'Rouvre le ${two(t.day)}/${two(t.month)} à $hour';
}
