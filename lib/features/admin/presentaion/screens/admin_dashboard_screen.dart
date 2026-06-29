import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../models/group_stats.dart';
import '../../providers/admin_provider.dart';
import '../../../../core/helpers/error_helper.dart';

class AdminDashboardScreen extends ConsumerWidget {
  final bool inShell;
  const AdminDashboardScreen({super.key, this.inShell = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final statsAsync = ref.watch(dashboardProvider);
    final auth = ref.watch(authStateProvider);
    final isSuperAdmin = auth.role == 'super_admin';

    final body = RefreshIndicator(
      onRefresh: () async => ref.invalidate(dashboardProvider),
      child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        statsAsync.when(
          data: (groups) {
            if (groups.isEmpty) return const SizedBox.shrink();
            final totals = groups.length == 1
                ? groups.first
                : groups.fold(groups.first, (a, b) => a.merge(b));
            return _StatsSection(
              groups: groups,
              totals: totals,
              isSuperAdmin: isSuperAdmin,
              onSettle: isSuperAdmin && groups.isNotEmpty
                  ? () => _showSettlementDialog(context, ref, groups)
                  : null,
            );
          },
          error: (e, __) => Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('تعذر تحميل الإحصائيات',
                    style: TextStyle(color: scheme.error, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => ref.invalidate(dashboardProvider),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
          loading: () => const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
        const SizedBox(height: 24),
        // Quick actions
        Text('إجراءات سريعة', style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold, color: scheme.onSurface,
        )),
        const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.person_add,
                  label: 'حجز لعميل',
                  color: Colors.amber,
                  onTap: () => context.push('/admin/create-booking'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAction(
                  icon: Icons.account_balance_wallet,
                  label: 'شحن محفظة',
                  color: Colors.green,
                  onTap: () => context.push('/admin/deposit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAction(
                  icon: Icons.qr_code_scanner,
                  label: 'مسح QR',
                  color: Colors.blue,
                  onTap: () => context.push('/admin/scan-qr'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.schedule,
                  label: 'الأوقات المتاحة',
                  color: Colors.green,
                  onTap: () => context.push('/available-slots'),
                ),
              ),
              Expanded(child: const SizedBox()),
              Expanded(child: const SizedBox()),
            ],
          ),
        const SizedBox(height: 24),
        // Menu items
        Text('القائمة', style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold, color: scheme.onSurface,
        )),
        const SizedBox(height: 12),
        _MenuItem(
          icon: Icons.pending_actions,
          title: 'حجوزات معلقة',
          subtitle: 'عرض وتأكيد الحجوزات المعلقة',
          color: Colors.orange,
          onTap: () => context.push('/admin/pending'),
        ),
        _MenuItem(
          icon: Icons.stadium_outlined,
          title: 'إدارة الملاعب',
          subtitle: 'إضافة وتعديل الملاعب',
          color: scheme.primary,
          onTap: () => context.push('/admin/facilities'),
        ),
        _MenuItem(
          icon: Icons.campaign_outlined,
          title: 'الإعلانات',
          subtitle: 'إدارة الإعلانات الممولة',
          color: Colors.purple,
          onTap: () => context.push('/admin/ads'),
        ),
        _MenuItem(
          icon: Icons.search,
          title: 'بحث بالجوال',
          subtitle: 'البحث في الحجوزات برقم الجوال',
          color: Colors.teal,
          onTap: () => context.push('/admin/search-bookings'),
        ),
        _MenuItem(
          icon: Icons.bar_chart,
          title: 'التقارير',
          subtitle: 'تقارير الإيرادات والحجوزات',
          color: Colors.deepOrange,
          onTap: () => context.push('/admin/reports'),
        ),
        _MenuItem(
          icon: Icons.settings,
          title: 'إعدادات المجموعة',
          subtitle: 'أوقات العمل، العربون، مدة العقد',
          color: Colors.blueGrey,
          onTap: () => context.push('/admin/settings'),
        ),
      ],
    ),
    );
    if (inShell) return body;
    return Scaffold(appBar: AppBar(title: const Text('لوحة الإدارة')), body: body);
  }
}

class _StatsSection extends StatelessWidget {
  final List<GroupStats> groups;
  final GroupStats totals;
  final bool isSuperAdmin;
  final VoidCallback? onSettle;

  const _StatsSection({
    required this.groups,
    required this.totals,
    required this.isSuperAdmin,
    this.onSettle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('إحصائيات', style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold, color: scheme.onSurface,
        )),
        const SizedBox(height: 12),
        // Today's stats (most important)
        _StatCard(
          title: 'حجوزات اليوم',
          value: '${totals.todayConfirmed} مؤكدة / ${totals.todayPending} معلقة / ${totals.todayPendingApproval} شبه مؤكدة',
          icon: Icons.today,
          color: Colors.blue,
          onTap: () => context.push('/admin/today-bookings', extra: totals.groupId),
        ),
        const SizedBox(height: 12),
        // Total + developer due row
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'إجمالي الحجوزات',
                value: totals.totalBookings.toString(),
                icon: Icons.book_online,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: isSuperAdmin
                  ? _StatCard(
                      title: 'المستحق للمطور',
                      value: '${totals.developerDue.toStringAsFixed(0)} ر.س',
                      icon: Icons.payments,
                      color: Colors.red,
                      onTap: onSettle,
                    )
                  : _StatCard(
                      title: 'عدد الحجوزات المستحقة للمطور',
                      value: totals.developerDueCount.toString(),
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Confirmed / Pending / Pending Approval
        Row(
          children: [
            Expanded(child: _MiniStatCard(
              title: 'مؤكدة',
              value: totals.confirmedBookings.toString(),
              icon: Icons.check_circle,
              color: Colors.green,
            )),
            const SizedBox(width: 8),
            Expanded(child: _MiniStatCard(
              title: 'معلقة',
              value: totals.pendingBookings.toString(),
              icon: Icons.pending,
              color: Colors.orange,
            )),
            const SizedBox(width: 8),
            Expanded(child: _MiniStatCard(
              title: 'شبه مؤكدة',
              value: totals.pendingApprovalBookings.toString(),
              icon: Icons.schedule,
              color: Colors.blue,
            )),
          ],
        ),
        const SizedBox(height: 12),
        // Revenue / deposits
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'الإيرادات',
                value: '${totals.totalRevenue.toStringAsFixed(0)} ر.س',
                icon: Icons.trending_up,
                color: Colors.teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'الإيداعات',
                value: '${totals.totalDeposits.toStringAsFixed(0)} ر.س',
                icon: Icons.account_balance,
                color: Colors.indigo,
              ),
            ),
          ],
        ),
        // Per-group breakdown for super_admin
        if (groups.length > 1) ...[
          const SizedBox(height: 16),
          Text('حسب المجموعة', style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant,
          )),
          const SizedBox(height: 8),
          ...groups.map((g) => _GroupRow(stats: g)),
        ],
      ],
    );
  }
}

class _GroupRow extends StatelessWidget {
  final GroupStats stats;
  const _GroupRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(stats.groupName, style: TextStyle(
                fontWeight: FontWeight.w600, color: scheme.onSurface,
              )),
            ),
            Text('${stats.todayConfirmed}/${stats.todayPending}/${stats.todayPendingApproval}', style: TextStyle(
              fontSize: 13, color: scheme.onSurfaceVariant,
            )),
          ],
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(title, style: TextStyle(
              fontSize: 12, color: scheme.onSurfaceVariant,
            ), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: scheme.onSurface,
            )),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(
                      fontSize: 13, color: scheme.onSurfaceVariant,
                    )),
                    const SizedBox(height: 2),
                    Text(value, style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: scheme.onSurface,
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(
                fontWeight: FontWeight.w600, color: scheme.onSurface,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600,
                    )),
                    Text(subtitle, style: TextStyle(
                      fontSize: 13, color: scheme.onSurfaceVariant,
                    )),
                  ],
                ),
              ),
              Icon(Icons.chevron_left, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

void _showSettlementDialog(BuildContext context, WidgetRef ref, List<GroupStats> groups) {
  String? selectedGroupId;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('تسوية حجوزات المطور'),
      content: groups.length > 1
          ? DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'المجموعة',
              ),
              items: groups.map((g) => DropdownMenuItem(
                value: g.groupId,
                child: Text(g.groupName),
              )).toList(),
              onChanged: (v) => selectedGroupId = v,
            )
          : const Text('سيتم تسوية جميع الحجوزات المستحقة للمطور'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () async {
            final gId = selectedGroupId ?? (groups.length == 1 ? groups.first.groupId : null);
            if (gId == null) return;

            Navigator.of(ctx).pop();
            final result = await ref.read(adminActionProvider.notifier).recordSettlement(
              facilityGroupId: gId,
              amount: 0,
              notes: 'تسوية مطور',
            );
            if (context.mounted) {
              result.when(
                success: (_) => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تسوية الحجوزات')),
                ),
                failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(translateError(e)),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              );
            }
          },
          child: const Text('تسوية'),
        ),
      ],
    ),
  );
}
