import 'package:lilia_app/features/home/data/remote/menu_repo.dart';
import 'package:lilia_app/models/menu.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'menu_controller.g.dart';

/// Provider pour récupérer les menus actifs d'un restaurant
@riverpod
Future<List<MenuDuJour>> activeMenus(Ref ref, String? restaurantId) async {
  final repository = ref.watch(menuRepositoryProvider);
  return repository.getActiveMenus(restaurantId: restaurantId);
}

/// Provider pour récupérer un menu spécifique par son ID
@riverpod
Future<MenuDuJour> menuDetails(Ref ref, String menuId) async {
  final repository = ref.watch(menuRepositoryProvider);
  return repository.getMenuById(menuId);
}

/// Provider pour récupérer tous les menus (avec filtres)
@riverpod
Future<List<MenuDuJour>> allMenus(
  Ref ref, {
  String? restaurantId,
  bool? isActive,
  bool includeExpired = false,
}) async {
  final repository = ref.watch(menuRepositoryProvider);
  return repository.getAllMenus(
    restaurantId: restaurantId,
    isActive: isActive,
    includeExpired: includeExpired,
  );
}
