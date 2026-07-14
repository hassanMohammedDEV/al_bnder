import 'package:app_platform_core/core.dart';
import 'package:app_platform_network/network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/api_client_provider.dart';
import '../models/player_ad.dart';
import 'player_ad_repository.dart';

final playerAdRepositoryProvider = Provider<PlayerAdRepository>((ref) {
  return PlayerAdRepositoryImpl(apiClient: ref.read(apiClientProvider));
});

class PlayerAdRepositoryImpl implements PlayerAdRepository {
  final ApiClient _apiClient;

  PlayerAdRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient; // ignore: prefer_initializing_formals

  @override
  Future<Result<List<PlayerAd>>> getPlayerAds(String facilityGroupId) {
    return _apiClient.post('rpc/get_player_ads', body: {
      'p_facility_group_id': facilityGroupId,
    }, parser: (json) {
      final data = json as Map<String, dynamic>;
      final list = data['data'] as List;
      return list.map((e) => PlayerAd.fromMap(e)).toList();
    });
  }

  @override
  Future<Result<void>> createPlayerAd(Map<String, dynamic> data) {
    return _apiClient.post('rpc/create_player_ad', body: data, parser: (_) {});
  }

  @override
  Future<Result<void>> createOfficialPlayerAd(Map<String, dynamic> data) {
    return _apiClient.post('rpc/create_official_player_ad', body: data, parser: (_) {});
  }

  @override
  Future<Result<void>> deletePlayerAd(String id) {
    return _apiClient.post('rpc/delete_player_ad', body: {
      'p_ad_id': id,
    }, parser: (_) {});
  }

  @override
  Future<Result<void>> updatePlayerAd(String adId, Map<String, dynamic> data) {
    return _apiClient.post('rpc/update_player_ad', body: {
      'p_ad_id': adId,
      ...data,
    }, parser: (_) {});
  }

  @override
  Future<Result<void>> reportPlayerAd(String adId, String reason) {
    return _apiClient.post('rpc/report_player_ad', body: {
      'p_ad_id': adId,
      'p_reason': reason,
    }, parser: (_) {});
  }

  @override
  Future<Result<List<PlayerAd>>> getReportedAds(String facilityGroupId) {
    return _apiClient.post('rpc/get_reported_player_ads', body: {
      'p_facility_group_id': facilityGroupId,
    }, parser: (json) {
      final data = json as Map<String, dynamic>;
      final list = data['data'] as List;
      return list.map((e) => PlayerAd.fromMap(e)).toList();
    });
  }

  @override
  Future<Result<void>> dismissReport(String adId) {
    return _apiClient.post('rpc/dismiss_player_ad_report', body: {
      'p_ad_id': adId,
    }, parser: (_) {});
  }

  @override
  Future<Result<bool>> checkBanned(String facilityGroupId) {
    return _apiClient.post('rpc/check_player_ad_banned', body: {
      'p_facility_group_id': facilityGroupId,
    }, parser: (json) {
      final data = json as Map<String, dynamic>;
      return data['data'] as bool;
    });
  }

  @override
  Future<Result<void>> banUser(String userId, String facilityGroupId, String reason) {
    return _apiClient.post('rpc/ban_user_from_player_ads', body: {
      'p_user_id': userId,
      'p_facility_group_id': facilityGroupId,
      'p_reason': reason,
    }, parser: (_) {});
  }

  @override
  Future<Result<void>> unbanUser(String userId, String facilityGroupId) {
    return _apiClient.post('rpc/unban_user_from_player_ads', body: {
      'p_user_id': userId,
      'p_facility_group_id': facilityGroupId,
    }, parser: (_) {});
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getBannedUsers(String facilityGroupId, String search) {
    return _apiClient.post('rpc/get_banned_users', body: {
      'p_facility_group_id': facilityGroupId,
      'p_search': search,
    }, parser: (json) {
      final data = json as Map<String, dynamic>;
      final list = data['data'] as List;
      return list.cast<Map<String, dynamic>>();
    });
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> searchUsersToBan(String facilityGroupId, String search) {
    return _apiClient.post('rpc/search_users_to_ban', body: {
      'p_facility_group_id': facilityGroupId,
      'p_search': search,
    }, parser: (json) {
      final data = json as Map<String, dynamic>;
      final list = data['data'] as List;
      return list.cast<Map<String, dynamic>>();
    });
  }
}
