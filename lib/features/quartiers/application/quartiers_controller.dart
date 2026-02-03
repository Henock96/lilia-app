import 'package:lilia_app/features/quartiers/data/quartiers_repository.dart';
import 'package:lilia_app/models/quartier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'quartiers_controller.g.dart';

/// Provider pour la liste des quartiers (avec cache)
@Riverpod(keepAlive: true)
Future<List<Quartier>> quartiersList(Ref ref) async {
  final repository = ref.watch(quartiersRepositoryProvider.notifier);
  return repository.getAllQuartiers();
}

/// Provider pour calculer les frais de livraison
@riverpod
Future<DeliveryFeeResult> deliveryFee(
  Ref ref, {
  required String restaurantId,
  required String quartierId,
}) async {
  final repository = ref.watch(quartiersRepositoryProvider.notifier);
  return repository.calculateDeliveryFee(
    restaurantId: restaurantId,
    quartierId: quartierId,
  );
}
