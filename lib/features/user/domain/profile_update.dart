import 'package:lilia_app/utils/congo_phone.dart';

/// Corps de `PUT /users/me` depuis l'écran « Modifier le profil ».
///
/// C-08 (audit du 09/10/2026) : le téléphone partait tel que saisi. Vide, il
/// traversait `@IsOptional` (qui ne laisse passer que `null`/`undefined`) et
/// tombait sur `@Matches` : 400. Avec des espaces (« 06 123 45 67 », la forme
/// que l'app suggère partout), même 400 — `UpdateUserDto` ne retire pas les
/// séparateurs. Dans les deux cas le profil n'était plus enregistrable, nom
/// compris.
///
/// Un champ vide n'est donc pas envoyé (le numéro existant est conservé), et
/// un numéro saisi part normalisé.
Map<String, dynamic> profileUpdatePayload({
  required String nom,
  required String phone,
}) =>
    {
      'nom': nom.trim(),
      if (phone.trim().isNotEmpty) 'phone': normalizeCongoPhone(phone),
    };
