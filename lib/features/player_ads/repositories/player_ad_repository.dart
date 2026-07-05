import 'package:app_platform_core/core.dart';
import '../models/player_ad.dart';

abstract class PlayerAdRepository {
  Future<Result<List<PlayerAd>>> getPlayerAds(String facilityGroupId);
  Future<Result<void>> createPlayerAd(Map<String, dynamic> data);
  Future<Result<void>> createOfficialPlayerAd(Map<String, dynamic> data);
  Future<Result<void>> deletePlayerAd(String id);
  Future<Result<void>> updatePlayerAd(String adId, Map<String, dynamic> data);
  Future<Result<void>> reportPlayerAd(String adId, String reason);
  Future<Result<List<PlayerAd>>> getReportedAds(String facilityGroupId);
  Future<Result<void>> dismissReport(String adId);
  Future<Result<bool>> checkBanned(String facilityGroupId);
  Future<Result<void>> banUser(String userId, String facilityGroupId, String reason);
  Future<Result<void>> unbanUser(String userId, String facilityGroupId);
  Future<Result<List<Map<String, dynamic>>>> getBannedUsers(String facilityGroupId, String search);
  Future<Result<List<Map<String, dynamic>>>> searchUsersToBan(String facilityGroupId, String search);
}
