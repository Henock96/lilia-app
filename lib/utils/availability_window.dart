/// Fenêtre horaire de vente d'un produit — **portage fidèle de la règle du
/// serveur**.
///
/// ## Pourquoi ce fichier existe
///
/// La règle vit côté backend (`product-availability.ts`) et le serveur publie
/// son verdict sur chaque produit sous `availableNow`. C'est lui qu'il faut
/// lire ; ce fichier n'est qu'un **repli**, pour les réponses antérieures au
/// champ.
///
/// L'application recopiait pourtant cette règle en Dart, avec deux erreurs :
///
/// ```dart
/// final now = DateTime.now();                        // fuseau de l'appareil
/// return current.compareTo(availableFrom!) >= 0 &&
///        current.compareTo(availableUntil!) <= 0;    // ✗
/// ```
///
/// 1. **Les fenêtres à cheval sur minuit étaient toujours fausses.** Pour
///    « 22:00 → 02:00 », à 23:00 : `"23:00" <= "02:00"` ne tient pas. Un bar de
///    nuit n'était jamais commandable, et personne ne pouvait le voir sans
///    ouvrir l'application à 23 h.
/// 2. **L'heure était celle de l'appareil**, pas celle de Brazzaville. Un
///    téléphone mal réglé, ou un client en déplacement, obtenait un verdict
///    différent de celui du serveur — qui, lui, décide au checkout.
///
/// C'est exactement la divergence que le correctif SQL d'août avait supprimée
/// côté serveur (17 combinaisons sur 49), réapparue côté client.
///
/// ⚠️ **Ne jamais faire diverger ce fichier de `product-availability.ts`.** Le
/// tableau de cas de `test/models/availability_window_test.dart` est le jumeau
/// de `availability-window-contract.spec.ts` côté backend : toute ligne ajoutée
/// d'un côté doit l'être de l'autre.
library;

class AvailabilityWindow {
  const AvailabilityWindow._();

  /// Brazzaville = UTC+1 toute l'année (pas d'heure d'été en Afrique centrale).
  ///
  /// La constante est nommée plutôt qu'écrite en dur : c'est la même valeur que
  /// `LOCAL_UTC_OFFSET_HOURS` côté serveur.
  static const Duration brazzavilleOffset = Duration(hours: 1);

  /// Heure locale de Brazzaville au format « HH:mm ».
  ///
  /// Le format à largeur fixe se compare lexicographiquement comme il se
  /// compare chronologiquement — c'est ce qui permet au serveur d'exprimer la
  /// règle en SQL, et à ce portage de rester une simple comparaison de chaînes.
  static String localHHmm([DateTime? now]) {
    final utc = (now ?? DateTime.now()).toUtc().add(brazzavilleOffset);
    final hh = utc.hour.toString().padLeft(2, '0');
    final mm = utc.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// L'heure courante est-elle dans la fenêtre `from → until` ?
  ///
  /// Une fenêtre dont l'heure de fin **précède** l'heure de début traverse
  /// minuit (« 22:00 → 02:00 ») : la comparaison s'inverse alors, et c'est
  /// précisément la branche qui manquait.
  ///
  /// Bornes incluses des deux côtés, comme côté serveur.
  static bool contains({String? from, String? until, DateTime? now}) {
    if (from == null && until == null) return true;

    final current = localHHmm(now);

    if (from != null && until != null) {
      return from.compareTo(until) <= 0
          // Fenêtre classique : on est entre les deux bornes.
          ? current.compareTo(from) >= 0 && current.compareTo(until) <= 0
          // Fenêtre de nuit : après l'ouverture OU avant la fermeture.
          : current.compareTo(from) >= 0 || current.compareTo(until) <= 0;
    }
    if (from != null) return current.compareTo(from) >= 0;
    return current.compareTo(until!) <= 0;
  }
}
