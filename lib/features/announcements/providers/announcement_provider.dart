import 'package:app_platform_core/core.dart';
import 'package:app_platform_state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/announcement.dart';
import '../repositories/announcement_repository_impl.dart';

final announcementsProvider = NotifierProvider<AnnouncementsNotifier, BaseState<List<Announcement>>>(
  AnnouncementsNotifier.new,
);

final unreadCountProvider = NotifierProvider<UnreadCountNotifier, int>(
  UnreadCountNotifier.new,
);

final announcementActionProvider = NotifierProvider<AnnouncementActionNotifier, ActionStore>(
  AnnouncementActionNotifier.new,
);

class AnnouncementsNotifier extends BaseNotifier<List<Announcement>> {
  @override
  BaseState<List<Announcement>> build() {
    Future.microtask(() => load());
    return const BaseState();
  }

  Future<void> load() async {
    setLoading();
    final result = await ref.read(announcementRepositoryProvider).getMyAnnouncements();
    result.when(
      success: (data) {
        setSuccess(data);
        ref.read(unreadCountProvider.notifier).recompute(data);
      },
      failure: (e) => setError(e),
    );
  }
}

class UnreadCountNotifier extends Notifier<int> {
  @override
  int build() {
    Future.microtask(() => _load());
    return 0;
  }

  void recompute(List<Announcement> announcements) {
    state = announcements.where((a) => !a.isRead).length;
  }

  Future<void> _load() async {
    final result = await ref.read(announcementRepositoryProvider).getUnreadCount();
    result.when(success: (count) => state = count, failure: (_) {});
  }
}

class AnnouncementActionNotifier extends Notifier<ActionStore> {
  @override
  ActionStore build() => ActionStore();

  Future<Result<void>> createAnnouncement({required String title, required String body}) async {
    const key = 'create';
    state = state.start(key);
    final result = await ref.read(announcementRepositoryProvider).createAnnouncement(title: title, body: body);
    result.when(
      success: (_) {
        state = state.success(key);
        ref.read(announcementsProvider.notifier).load();
      },
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

  Future<Result<void>> markRead(List<String> ids) async {
    const key = 'markRead';
    state = state.start(key);
    final result = await ref.read(announcementRepositoryProvider).markRead(ids);
    result.when(
      success: (_) {
        state = state.success(key);
        ref.read(announcementsProvider.notifier).load();
      },
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

  Future<Result<void>> deleteAnnouncement(String id) async {
    const key = 'delete';
    state = state.start(key);
    final result = await ref.read(announcementRepositoryProvider).deleteAnnouncement(id);
    result.when(
      success: (_) {
        state = state.success(key);
        ref.read(announcementsProvider.notifier).load();
      },
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }
}
