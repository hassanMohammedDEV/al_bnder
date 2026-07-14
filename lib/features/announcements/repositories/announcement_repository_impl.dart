import 'package:app_platform_core/core.dart';
import 'package:app_platform_network/network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/api_client_provider.dart';
import '../models/announcement.dart';
import 'announcement_repository.dart';

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepositoryImpl(apiClient: ref.read(apiClientProvider));
});

class AnnouncementRepositoryImpl implements AnnouncementRepository {
  final ApiClient _apiClient;

  AnnouncementRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient; // ignore: prefer_initializing_formals

  @override
  Future<Result<List<Announcement>>> getMyAnnouncements() {
    return _apiClient.post('rpc/get_my_announcements', parser: (json) {
      final data = json as Map<String, dynamic>;
      final list = data['data'] as List;
      return list.map((e) => Announcement.fromMap(e)).toList();
    });
  }

  @override
  Future<Result<int>> getUnreadCount() {
    return _apiClient.post('rpc/get_unread_announcement_count', parser: (json) {
      final data = json as Map<String, dynamic>;
      return (data['data'] as Map<String, dynamic>)['count'] as int;
    });
  }

  @override
  Future<Result<void>> createAnnouncement({required String title, required String body}) {
    return _apiClient.post('rpc/create_announcement', body: {
      'p_title': title,
      'p_body': body,
    }, parser: (_) {});
  }

  @override
  Future<Result<void>> markRead(List<String> announcementIds) {
    return _apiClient.post('rpc/mark_announcements_read', body: {
      'p_announcement_ids': announcementIds,
    }, parser: (_) {});
  }

  @override
  Future<Result<void>> deleteAnnouncement(String id) {
    return _apiClient.post('rpc/delete_announcement', body: {
      'p_announcement_id': id,
    }, parser: (_) {});
  }
}
