import 'package:lilia_app/core/network/api_client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../models/banner.dart';

part 'banner_repo.g.dart';

class BannerRepository {
  final ApiClient _api;

  BannerRepository(this._api);

  Future<List<AppBanner>> getActiveBanners({String? restaurantId}) async {
    final res = await _api.getJson(
      '/banners',
      query: {'restaurantId': ?restaurantId},
    );
    final data = (res.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return data
        .map((json) => AppBanner.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

@Riverpod(keepAlive: true)
BannerRepository bannerRepository(Ref ref) {
  return BannerRepository(ref.watch(apiClientProvider));
}
