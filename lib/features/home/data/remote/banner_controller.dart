import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../models/banner.dart';
import 'package:lilia_app/utils/provider_cache.dart';

import 'banner_repo.dart';

part 'banner_controller.g.dart';

@riverpod
Future<List<AppBanner>> bannersList(Ref ref) async {
  // Une bannière ne périme pas en trente secondes : la recharger à chaque
  // retour sur l'accueil coûtait un appel pour une image déjà affichée.
  cachePendant(ref, kCatalogCacheTtl);

  final repository = ref.watch(bannerRepositoryProvider);
  return repository.getActiveBanners();
}
