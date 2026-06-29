import 'package:app_platform_core/core.dart';

import '../models/announcement.dart';

abstract class AnnouncementRepository {
  Future<Result<List<Announcement>>> getMyAnnouncements();
  Future<Result<int>> getUnreadCount();
  Future<Result<void>> createAnnouncement({required String title, required String body});
  Future<Result<void>> markRead(List<String> announcementIds);
}
