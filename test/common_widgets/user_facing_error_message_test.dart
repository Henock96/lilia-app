import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilia_app/common_widgets/build_error_state.dart';
import 'package:lilia_app/core/network/api_exception.dart';

/// Ce que lit le client quand un chargement échoue : jamais un nom de classe
/// Dart, jamais une trace.
void main() {
  test('ApiException : son message, rédigé pour le client', () {
    expect(
      userFacingErrorMessage(const ApiException('Vendeur introuvable.')),
      'Vendeur introuvable.',
    );
  });

  test('coupure réseau : une phrase, pas SocketException', () {
    final m = userFacingErrorMessage(
      const SocketException('Failed host lookup: lilia-backend.onrender.com'),
    );
    expect(m, 'Connexion impossible. Vérifiez votre accès à internet.');
    expect(m, isNot(contains('onrender')));
  });

  test('délai dépassé', () {
    expect(
      userFacingErrorMessage(TimeoutException('x')),
      contains('trop de temps'),
    );
  });

  test('Exception("texte client") : le texte, sans préfixe', () {
    expect(
      userFacingErrorMessage(Exception("Erreur lors du téléchargement.")),
      'Erreur lors du téléchargement.',
    );
  });

  test('erreur de programmation : message générique', () {
    expect(
      userFacingErrorMessage(TypeError()),
      'Une erreur inattendue est survenue. Réessayez dans un instant.',
    );
  });
}
