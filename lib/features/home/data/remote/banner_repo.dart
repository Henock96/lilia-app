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
      query: {if (restaurantId != null) 'restaurantId': restaurantId},
    );
    final List<dynamic> data = (res.data as Map<String, dynamic>)['data'];
    return data.map((json) => AppBanner.fromJson(json)).toList();
  }
}

@Riverpod(keepAlive: true)
BannerRepository bannerRepository(Ref ref) {
  return BannerRepository(ref.watch(apiClientProvider));
}
