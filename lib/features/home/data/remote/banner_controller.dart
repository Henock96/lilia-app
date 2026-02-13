import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../models/banner.dart';
import 'banner_repo.dart';

part 'banner_controller.g.dart';

@riverpod
Future<List<AppBanner>> bannersList(Ref ref) async {
  final repository = ref.watch(bannerRepositoryProvider);
  return repository.getActiveBanners();
}
