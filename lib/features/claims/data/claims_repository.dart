import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lilia_app/core/network/api_client.dart';
import 'package:lilia_app/utils/api_response.dart';
import 'package:lilia_app/utils/image_compressor.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/claim.dart';

part 'claims_repository.g.dart';

/// Réclamations du client (F3-06) — `/orders/:id/claims`, `/me/claims`,
/// `/claims/:id`.
@Riverpod(keepAlive: true)
ClaimsRepository claimsRepository(Ref ref) =>
    ClaimsRepository(ref.read(apiClientProvider));

class ClaimsRepository {
  ClaimsRepository(this._api);

  final ApiClient _api;

  Future<ClaimDetail> open(String orderId, ClaimDraft draft) async {
    final res = await _api.postJson(
      '/orders/$orderId/claims',
      body: draft.toJson(),
    );
    return ClaimDetail.fromJson(ApiResponse.mapOf(res.data));
  }

  Future<List<ClaimSummary>> mine() async {
    final res = await _api.getJson('/me/claims', query: {'limit': 50});
    return ApiResponse.listOf(
      res.data,
    ).whereType<Map<String, dynamic>>().map(ClaimSummary.fromJson).toList();
  }

  Future<ClaimDetail> detail(String id) async {
    final res = await _api.getJson('/claims/$id');
    return ClaimDetail.fromJson(ApiResponse.mapOf(res.data));
  }

  Future<void> postMessage(String id, String body) =>
      _api.postJson('/claims/$id/messages', body: {'body': body});

  /// Photo jointe : téléversée par le **serveur** (`POST /upload/image`,
  /// dossier `claims`), qui seul connaît les identifiants Cloudinary — et dont
  /// l'URL est la seule que `POST /orders/:id/claims` accepte.
  Future<String> uploadPhoto(XFile image) async {
    final bytes = await ImageCompressor.compress(await image.readAsBytes());
    final res = await _api.postJson(
      '/upload/image?folder=claims',
      body: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: image.name,
          contentType: DioMediaType('image', 'jpeg'),
        ),
      }),
    );
    final map = ApiResponse.mapOf(res.data);
    final url = map['url'];
    if (url is! String) throw StateError('Réponse d’envoi sans URL.');
    return url;
  }
}
