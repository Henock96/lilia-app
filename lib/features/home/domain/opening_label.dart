/// Libellé d'ouverture d'une boutique — **le seul** formatage ouvert / fermé /
/// réouverture de l'application (F3-03, UI Refresh).
///
/// L'application ne décide jamais de l'ouverture : elle met en forme ce que le
/// serveur a servi.
///
/// | Entrée | Libellé |
/// |---|---|
/// | `isOpen == true` | « Ouvert » |
/// | `isOpen == null` | « Horaires indisponibles » — inconnu n'est pas ouvert |
/// | fermé, réouverture connue aujourd'hui | « Fermé — ouvre à 10h00 » |
/// | … demain | « Fermé — demain à 10h00 » |
/// | … plus tard | « Fermé — le 02/10 à 10h00 » |
/// | fermé, réouverture inconnue | « Fermé » — jamais une heure inventée |
///
/// ## `nextOpeningAt` avant `pausedUntil`
///
/// Le serveur calcule `nextOpeningAt` avec `decideOpening` **pause comprise** :
/// une pause qui finit à 23h00 chez un vendeur qui ferme à 22h00 donne « demain
/// à 10h00 », là où `pausedUntil` aurait annoncé 23h00 — une heure fausse.
/// Quand le serveur l'a servi ([nextOpeningServed]), c'est donc lui qui fait
/// foi, y compris quand il vaut `null` (fermé à la main, rien sous 8 jours).
/// `pausedUntil` n'est lu que face à un serveur antérieur, qui ne le sert pas.
///
/// Heure de Brazzaville (UTC+1, sans heure d'été), quel que soit le fuseau du
/// téléphone.
String openingLabel(
  bool? isOpen,
  DateTime? pausedUntil, {
  DateTime? nextOpeningAt,
  bool nextOpeningServed = false,
  DateTime? now,
}) {
  if (isOpen == true) return 'Ouvert';
  if (isOpen == null) return 'Horaires indisponibles';

  final current = now ?? DateTime.now();
  final reopening = nextOpeningServed ? nextOpeningAt : pausedUntil;
  if (reopening == null || !reopening.isAfter(current)) return 'Fermé';
  return 'Fermé — ${reopeningWhen(reopening, now: current)}';
}

/// « ouvre à 10h00 », « demain à 10h00 » ou « le 02/10 à 10h00 », heure de
/// Brazzaville.
String reopeningWhen(DateTime at, {DateTime? now}) {
  DateTime bzv(DateTime d) => d.toUtc().add(const Duration(hours: 1));
  final t = bzv(at);
  final n = bzv(now ?? DateTime.now());
  String two(int v) => v.toString().padLeft(2, '0');
  final hour = '${two(t.hour)}h${two(t.minute)}';
  final day = DateTime.utc(t.year, t.month, t.day);
  final today = DateTime.utc(n.year, n.month, n.day);
  final days = day.difference(today).inDays;
  if (days == 0) return 'ouvre à $hour';
  if (days == 1) return 'demain à $hour';
  return 'le ${two(t.day)}/${two(t.month)} à $hour';
}
