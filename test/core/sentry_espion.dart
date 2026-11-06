import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Branche un vrai Sentry qui n'envoie rien : `beforeSend` retient l'événement
/// puis le jette.
Future<List<SentryEvent>> espionnerSentry() async {
  final evenements = <SentryEvent>[];
  await Sentry.init((options) {
    options.dsn = 'https://cle@exemple.ingest.sentry.io/1';
    options.beforeSend = (event, hint) {
      evenements.add(event);
      return null;
    };
  });
  addTearDown(Sentry.close);
  return evenements;
}

/// `captureException` n'est pas attendu par l'appelant : on le laisse aboutir.
Future<void> laisserPartirSentry() =>
    Future<void>.delayed(const Duration(milliseconds: 50));
