import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/claims_repository.dart';
import '../domain/claim.dart';

part 'claims_providers.g.dart';

/// « Mes demandes » (F3-06).
@riverpod
Future<List<ClaimSummary>> myClaims(Ref ref) =>
    ref.read(claimsRepositoryProvider).mine();

/// Rafraîchissement du fil : pas de WebSocket client (blueprint §6).
const claimThreadPollInterval = Duration(seconds: 30);

/// Une demande et son fil, relue toutes les 30 s tant que l'écran l'observe.
@riverpod
Future<ClaimDetail> claimDetail(Ref ref, String claimId) async {
  final claim = await ref.read(claimsRepositoryProvider).detail(claimId);
  if (!claim.isClosed) {
    final timer = Timer(claimThreadPollInterval, ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
  return claim;
}
