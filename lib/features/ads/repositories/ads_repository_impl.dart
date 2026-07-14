import 'package:app_platform_core/core.dart';
import 'package:app_platform_network/network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/api_client_provider.dart';
import '../models/facility_ad.dart';
import 'ads_repository.dart';

final adsRepositoryProvider = Provider<AdsRepository>((ref) {
  return AdsRepositoryImpl(apiClient: ref.read(apiClientProvider));
});

class AdsRepositoryImpl implements AdsRepository {
  final ApiClient _apiClient;

  AdsRepositoryImpl({required this._apiClient});

  @override
  Future<Result<List<FacilityAd>>> getAllActiveAds() {
    return _apiClient.post('rpc/get_all_active_advertisements', parser: (json) {
      final data = json as Map<String, dynamic>;
      final list = data['data'] as List;
      return list.map((e) => FacilityAd.fromMap(e)).toList();
    });
  }

  @override
  Future<Result<List<FacilityAd>>> getAds(String facilityGroupId) {
    return _apiClient.post('rpc/get_advertisements', body: {
      'p_facility_group_id': facilityGroupId,
    }, parser: (json) {
      final data = json as Map<String, dynamic>;
      final list = data['data'] as List;
      return list.map((e) => FacilityAd.fromMap(e)).toList();
    });
  }

  @override
  Future<Result<void>> createAd({
    required String facilityGroupId,
    required String title,
    String? description,
    String? imageUrl,
    String? linkUrl,
    String? startsAt,
    String? endsAt,
    int sortOrder = 0,
  }) {
    return _apiClient.post('rpc/create_advertisement', body: {
      'p_facility_group_id': facilityGroupId,
      'p_title': title,
      'p_description': ?description,
      'p_image_url': ?imageUrl,
      'p_link_url': ?linkUrl,
      'p_starts_at': ?startsAt,
      'p_ends_at': ?endsAt,
      'p_sort_order': sortOrder,
    }, parser: (_) {});
  }

  @override
  Future<Result<void>> updateAd({
    required String adId,
    required String title,
    String? description,
    String? imageUrl,
    String? linkUrl,
    String? startsAt,
    String? endsAt,
    int? sortOrder,
  }) {
    return _apiClient.post('rpc/update_advertisement', body: {
      'p_ad_id': adId,
      'p_title': title,
      'p_description': ?description,
      'p_image_url': ?imageUrl,
      'p_link_url': ?linkUrl,
      'p_starts_at': ?startsAt,
      'p_ends_at': ?endsAt,
      'p_sort_order': ?sortOrder,
    }, parser: (_) {});
  }

  @override
  Future<Result<void>> updateSortOrder(String adId, int sortOrder) {
    return _apiClient.post('rpc/update_ad_sort_order', body: {
      'p_ad_id': adId,
      'p_sort_order': sortOrder,
    }, parser: (_) {});
  }

  @override
  Future<Result<void>> toggleActive(String adId, bool isActive) {
    return _apiClient.post('rpc/toggle_advertisement_active', body: {
      'p_ad_id': adId,
      'p_is_active': isActive,
    }, parser: (_) {});
  }

  @override
  Future<Result<void>> deleteAd(String adId) {
    return _apiClient.post('rpc/delete_advertisement', body: {
      'p_ad_id': adId,
    }, parser: (_) {});
  }
}
