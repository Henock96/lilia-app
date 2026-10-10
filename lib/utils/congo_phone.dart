/// Numéro mobile congolais, tel que le serveur l'accepte.
///
/// Miroir de `IsCongoMobilePhone` (`lilia-backend`,
/// `common/validation/congo-phone.decorator.ts`) : séparateurs retirés
/// (`espace . - ( )`), puis `^(\+?242)?0?[456]\d{7}$`.
///
/// Les invites de l'app montrent elles-mêmes des espaces (« 06 123 45 67 ») ;
/// la saisie partait pourtant **brute** vers `POST /payments` et
/// `PUT /users/me`. Le paiement l'accepte depuis la PR backend #146, le profil
/// non (`UpdateUserDto` n'a pas de `Transform`) : on normalise donc ici, avant
/// tout envoi, sans dépendre du déploiement d'un serveur (C-03, C-08, C-33 —
/// audit du 09/10/2026).
library;

final RegExp _separateurs = RegExp(r'[\s.\-()]');
final RegExp _mobileCongo = RegExp(r'^(\+?242)?0?[456]\d{7}$');

/// La saisie sans ses séparateurs. Ne valide rien.
String normalizeCongoPhone(String input) =>
    input.trim().replaceAll(_separateurs, '');

/// La saisie est-elle un mobile congolais accepté par le serveur ?
bool isCongoMobilePhone(String input) =>
    _mobileCongo.hasMatch(normalizeCongoPhone(input));

/// Message d'erreur commun aux formulaires — celui du serveur.
const congoPhoneErrorMessage =
    'Numéro de téléphone congolais invalide (ex : 06 123 45 67)';
