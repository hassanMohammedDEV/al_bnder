import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../admin/models/group_stats.dart';
import '../../../admin/providers/admin_provider.dart';
import '../../../facilities/providers/facility_provider.dart';

class SettlementScreen extends ConsumerWidget {
  const SettlementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final groupsAsync = ref.watch(facilityGroupsProvider);
    final statsAsync = ref.watch(dashboardProvider);
    final groups = groupsAsync.data ?? [];
    final statsMap = <String, GroupStats>{};
    if (statsAsync.hasValue) {
      for (final s in statsAsync.value!) {
        statsMap[s.groupId] = s;
      }
    }

    if (groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups, size: 48, color: scheme.onSurfaceVariant.withAlpha(80)),
            const SizedBox(height: 12),
            Text('لا توجد مجموعات', style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    final settled = groups.where((g) {
      final stats = statsMap[g.id];
      return stats == null || stats.developerDue <= 0;
    }).toList();
    final unsettled = groups.where((g) {
      final stats = statsMap[g.id];
      return stats != null && stats.developerDue > 0;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(dashboardProvider),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (unsettled.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.payments, size: 18, color: Colors.red.shade600),
                const SizedBox(width: 8),
                Text('مستحق التسوية', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface,
                )),
              ],
            ),
            const SizedBox(height: 12),
            ...unsettled.map((g) => _GroupSettlementCard(
              group: g,
              stats: statsMap[g.id]!,
              scheme: scheme,
              onSettle: () => _confirmAndSettle(context, ref, g.id, g.name, statsMap[g.id]!),
            )),
            const SizedBox(height: 24),
          ],
          if (settled.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.check_circle, size: 18, color: Colors.green.shade600),
                const SizedBox(width: 8),
                Text('تمت التسوية', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface,
                )),
              ],
            ),
            const SizedBox(height: 12),
            ...settled.map((g) => _GroupSettlementCard(
              group: g,
              stats: statsMap[g.id],
              scheme: scheme,
              onSettle: null,
            )),
          ],
          if (unsettled.isEmpty && settled.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, size: 48, color: scheme.onSurfaceVariant.withAlpha(80)),
                    const SizedBox(height: 12),
                    Text('لا توجد بيانات', style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmAndSettle(
    BuildContext context, WidgetRef ref, String groupId, String groupName, GroupStats stats,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسوية حجوزات المطور'),
        content: Text(
          'سيتم تسوية جميع الحجوزات المستحقة للمطور لمجموعة "$groupName".\n\n'
          'المبلغ المستحق: ${stats.developerDue.toStringAsFixed(0)} ر.ي\n'
          'عدد الحجوزات: ${stats.developerDueCount}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('تسوية'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final result = await ref.read(adminActionProvider.notifier).recordSettlement(
      facilityGroupId: groupId,
      amount: stats.developerDue,
      notes: 'تسوية مطور - $groupName',
    );
    if (context.mounted) {
      result.when(
        success: (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم تسوية حجوزات "$groupName"')),
          );
          ref.invalidate(dashboardProvider);
        },
        failure: (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل التسوية: $e')),
          );
        },
      );
    }
  }
}

class _GroupSettlementCard extends StatelessWidget {
  final dynamic group;
  final GroupStats? stats;
  final ColorScheme scheme;
  final VoidCallback? onSettle;

  const _GroupSettlementCard({
    required this.group,
    required this.stats,
    required this.scheme,
    this.onSettle,
  });

  @override
  Widget build(BuildContext context) {
    final due = stats?.developerDue ?? 0;
    final count = stats?.developerDueCount ?? 0;
    final isSettled = due <= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: isSettled ? Colors.green.withAlpha(25) : Colors.red.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSettled ? Icons.check_circle : Icons.payments,
                color: isSettled ? Colors.green : Colors.red,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${group.name}', style: TextStyle(
                    fontWeight: FontWeight.w600, color: scheme.onSurface,
                  )),
                  const SizedBox(height: 4),
                  Text(
                    isSettled
                        ? 'تمت التسوية'
                        : '$count حجوزات — ${due.toStringAsFixed(0)} ر.ي مستحق',
                    style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (onSettle != null)
              FilledButton.tonalIcon(
                onPressed: onSettle,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('تصفير'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.withAlpha(30),
                  foregroundColor: Colors.red.shade700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
