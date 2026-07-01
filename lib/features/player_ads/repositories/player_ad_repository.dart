import 'package:app_platform_core/core.dart';
import '../models/player_ad.dart';

abstract class PlayerAdRepository {
  Future<Result<List<PlayerAd>>> getPlayerAds(String facilityGroupId);
  Future<Result<void>> createPlayerAd(Map<String, dynamic> data);
  Future<Result<void>> deletePlayerAd(String id);
  Future<Result<void>> updatePlayerAd(String adId, Map<String, dynamic> data);
  Future<Result<void>> reportPlayerAd(String adId, String reason);
  Future<Result<List<PlayerAd>>> getReportedAds(String facilityGroupId);
  Future<Result<void>> dismissReport(String adId);
}
