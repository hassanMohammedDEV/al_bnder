import 'package:app_platform_core/core.dart';

import '../models/facility_ad.dart';

abstract class AdsRepository {
  Future<Result<List<FacilityAd>>> getAds(String facilityGroupId);
  Future<Result<List<FacilityAd>>> getAllActiveAds();
  Future<Result<void>> createAd({
    required String facilityGroupId,
    required String title,
    String? description,
    String? imageUrl,
    String? linkUrl,
    String? startsAt,
    String? endsAt,
    int sortOrder = 0,
  });
  Future<Result<void>> updateAd({
    required String adId,
    required String title,
    String? description,
    String? imageUrl,
    String? linkUrl,
    String? startsAt,
    String? endsAt,
    int? sortOrder,
  });
  Future<Result<void>> toggleActive(String adId, bool isActive);
  Future<Result<void>> deleteAd(String adId);
  Future<Result<void>> updateSortOrder(String adId, int sortOrder);
}
