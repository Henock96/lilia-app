import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/core/update/app_version.dart';

/// `AppVersion.current` doit dire la même chose que `pubspec.yaml`.
///
/// ## Pourquoi ce test existe
///
/// La version de l'application est un numéro qu'on incrémente à chaque
/// publication, et qui vivait recopié à trois endroits : `pubspec.yaml`, la
/// balise de release Sentry dans `main.dart`, et `AppVersion.current`. Les
/// deux derniers sont désormais un seul — mais rien n'empêchait encore de
/// monter `pubspec.yaml` en oubliant le code Dart.
///
/// Les conséquences ne sont pas cosmétiques :
///
///  * **Sentry** attribue les erreurs à la mauvaise version, et répond donc
///    faux à la seule question qu'on lui pose après une publication ;
///  * **la mise à jour** se compare à `AppVersion.current`. Une version figée
///    trop bas déclenche une invitation à mettre à jour chez des clients déjà
///    à jour ; figée trop haut, elle rend le seuil obligatoire inopérant au
///    moment précis où on en a besoin.
///
/// Une constante qu'on doit penser à changer finit par ne pas l'être. Ce test
/// est ce qui remplace cette discipline.
void main() {
  test('AppVersion.current est alignée sur pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    final match = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(
      match,
      isNotNull,
      reason: 'Aucune ligne `version:` trouvée dans pubspec.yaml.',
    );

    final declared = match!.group(1)!;
    final parsed = AppVersion.tryParse(declared);

    expect(
      parsed,
      isNotNull,
      reason:
          'La version « $declared » de pubspec.yaml n\'est pas au format '
          'major.minor.patch+build attendu par AppVersion.',
    );

    expect(
      AppVersion.current,
      equals(parsed),
      reason:
          'pubspec.yaml déclare « $declared » mais AppVersion.current vaut '
          '« ${AppVersion.current} ». Mettez à jour '
          '`lib/core/update/app_version.dart` — sans quoi Sentry étiquettera '
          'les erreurs avec la mauvaise version et le seuil de mise à jour '
          'obligatoire se comparera à un numéro faux.',
    );
  });
}
