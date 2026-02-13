import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lilia_app/constants/app_constants.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../models/banner.dart';

part 'banner_repo.g.dart';

class BannerRepository {
  Future<List<AppBanner>> getActiveBanners({String? restaurantId}) async {
    try {
      String url = '${AppConstants.baseUrl}/banners';
      if (restaurantId != null) {
        url += '?restaurantId=$restaurantId';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body)["data"];
        return data.map((json) => AppBanner.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load banners: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }
}

@Riverpod(keepAlive: true)
BannerRepository bannerRepository(Ref ref) {
  return BannerRepository();
}
