import 'package:app_platform_core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../models/announcement.dart';
import '../../providers/announcement_provider.dart';
import '../../providers/local_notification_provider.dart';

String _formatDate(String iso) {
  final dt = DateTime.parse(iso);
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
  if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
  if (diff.inDays < 7) return 'منذ ${diff.inDays} ي';
  return '${dt.day}/${dt.month}/${dt.year}';
}

class AnnouncementsScreen extends ConsumerWidget {
  final bool inShell;
  const AnnouncementsScreen({super.key, this.inShell = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(announcementsProvider);
    final localNotifications = ref.watch(localNotificationsProvider);
    final auth = ref.watch(authStateProvider);
    final isAdmin = auth.role == 'facility_admin' || auth.role == 'super_admin';

    final serverEmpty = state.data == null || state.data!.isEmpty;
    final showLocal = localNotifications.isNotEmpty;

    Widget content;
    if (state.status == LoadStatus.loading && serverEmpty) {
      content = const Center(child: CircularProgressIndicator());
    } else if (state.status == LoadStatus.error && serverEmpty && !showLocal) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: scheme.error),
            const SizedBox(height: 8),
            Text('فشل تحميل الإشعارات', style: TextStyle(color: scheme.error)),
          ],
        ),
      );
    } else if (serverEmpty && !showLocal) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none, size: 64, color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('لا توجد إشعارات', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16)),
          ],
        ),
      );
    } else {
      final bottomInset = MediaQuery.of(context).padding.bottom;

      final items = <Widget>[];

      if (showLocal) {
        items.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.notifications_outlined, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'إشعارات التطبيق',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
        items.addAll(localNotifications.map((n) => _LocalNotificationCard(notification: n)));
      }

      if (serverEmpty && showLocal) {
        // only local — skip divider
      } else if (showLocal && !serverEmpty) {
        items.add(const Divider(height: 32));
      }

      if (state.data != null) {
        items.addAll(state.data!.map((a) => _AnnouncementCard(announcement: a)));
      }

      content = ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
        children: items,
      );
    }

    if (inShell) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: content,
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => context.push('/admin/create-announcement'),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _LocalNotificationCard extends ConsumerWidget {
  final LocalNotification notification;
  const _LocalNotificationCard({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isUnread = !notification.isRead;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => ref.read(localNotificationsProvider.notifier).remove(notification.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: isUnread
            ? scheme.secondaryContainer.withValues(alpha: 0.25)
            : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            ref.read(localNotificationsProvider.notifier).markAsRead(notification.id);
            _showDetail(context, notification);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isUnread)
                      Container(
                        width: 8, height: 8,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: scheme.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Icon(notification.type == 'welcome' ? Icons.waving_hand_outlined : Icons.check_circle_outline, size: 18, color: scheme.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notification.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      _formatDate(notification.createdAt.toIso8601String()),
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  notification.body,
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, LocalNotification n) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(n.type == 'welcome' ? Icons.waving_hand_outlined : Icons.check_circle_outline, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(n.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(n.createdAt.toIso8601String()),
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const Divider(height: 24),
            Text(n.body, style: const TextStyle(fontSize: 15, height: 1.5)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementCard extends ConsumerWidget {
  final Announcement announcement;
  const _AnnouncementCard({required this.announcement});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isUnread = !announcement.isRead;
    final auth = ref.watch(authStateProvider);
    final isAdmin = auth.role == 'facility_admin' || auth.role == 'super_admin';
    final isSender = announcement.senderId == auth.userId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isUnread ? scheme.primaryContainer.withValues(alpha: 0.3) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (isUnread) {
            ref.read(announcementActionProvider.notifier).markRead([announcement.id]);
          }
          _showDetail(context, announcement, ref);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isUnread)
                    Container(
                      width: 8, height: 8,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Icon(Icons.campaign_outlined, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      announcement.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    _formatDate(announcement.createdAt),
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                  if (isAdmin || isSender) ...[
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      iconSize: 20,
                      onSelected: (v) {
                        if (v == 'delete') _confirmDelete(context, ref);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'delete', child: Text('حذف')),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                announcement.body,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      announcement.senderName.isNotEmpty ? 'من: ${announcement.senderName}' : '',
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                    ),
                  ),
                  if (isAdmin && announcement.readCount > 0)
                    Text(
                      'مقروء من ${announcement.readCount}',
                      style: TextStyle(fontSize: 11, color: scheme.primary.withValues(alpha: 0.7)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الإشعار'),
        content: const Text('هل أنت متأكد من حذف هذا الإشعار؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(announcementActionProvider.notifier).deleteAnnouncement(announcement.id);
            },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, Announcement a, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.campaign, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(a.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              a.senderName.isNotEmpty ? 'من: ${a.senderName}' : '',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(a.createdAt),
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const Divider(height: 24),
            Text(a.body, style: const TextStyle(fontSize: 15, height: 1.5)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
