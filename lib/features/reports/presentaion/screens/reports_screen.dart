import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/helpers/error_helper.dart';
import '../../../../presentaion/shared/time_picker_dialog.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../facilities/providers/facility_provider.dart';
import '../../../facilities/providers/selected_group_provider.dart';
import '../../repositories/reports_repository_impl.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  final bool inShell;
  const ReportsScreen({super.key, this.inShell = false});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _walletOps = [];
  Map<String, dynamic>? _analytics;
  var _loading = false;
  var _loaded = false;

  Future<void> _load() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار تاريخ البداية والنهاية')),
      );
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تاريخ النهاية يجب أن يكون بعد تاريخ البداية')),
      );
      return;
    }
    setState(() { _loading = true; _walletOps = []; _analytics = null; });
    final groupId = ref.read(selectedGroupProvider);
    final auth = ref.read(authStateProvider);
    final isAdmin = auth.role == 'facility_admin' || auth.role == 'super_admin';

    final result = await ref.read(reportsRepositoryProvider).searchBookingsByDateRange(
      facilityGroupId: groupId,
      startDate: _startDate!,
      endDate: _endDate!,
    );
    if (!mounted) return;
    result.when(
      success: (data) => setState(() { _bookings = data; _loading = false; _loaded = true; }),
      failure: (e) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(e))));
      },
    );

    if (isAdmin && groupId != null) {
      final opsResult = await ref.read(reportsRepositoryProvider).getWalletOperations(
        facilityGroupId: groupId,
        startDate: _startDate!,
        endDate: _endDate!,
      );
      if (!mounted) return;
      opsResult.when(
        success: (data) => setState(() => _walletOps = data),
        failure: (_) {},
      );

      final analyticsResult = await ref.read(reportsRepositoryProvider).getAnalytics(
        facilityGroupId: groupId,
        startDate: _startDate!,
        endDate: _endDate!,
      );
      if (!mounted) return;
      analyticsResult.when(
        success: (data) => setState(() => _analytics = data),
        failure: (_) {},
      );
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? DateTime.now().subtract(const Duration(days: 30)) : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: isStart ? 'اختر تاريخ البداية' : 'اختر تاريخ النهاية',
      cancelText: 'تراجع',
      confirmText: 'موافق',
    );
    if (date == null) return;
    setState(() {
      if (isStart) {
        _startDate = date;
      } else {
        _endDate = date;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groupsState = ref.watch(facilityGroupsProvider);
    final groups = groupsState.data ?? [];
    final activeGroups = groups.where((g) => g.isActive).toList();
    final selectedGroupId = ref.watch(selectedGroupProvider);
    final selectedGroup = activeGroups.where((g) => g.id == selectedGroupId).firstOrNull;

    if (selectedGroupId == null && activeGroups.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedGroupProvider.notifier).select(activeGroups.first.id);
      });
    }

    final content = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.bar_chart, color: scheme.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('التقارير', style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: scheme.onSurface,
                )),
                Text('تحليل الإيرادات والحجوزات', style: TextStyle(
                  fontSize: 13, color: scheme.onSurfaceVariant,
                )),
                if (selectedGroup != null) ...[
                  const SizedBox(height: 2),
                  Text(selectedGroup.name, style: TextStyle(
                    fontSize: 12, color: scheme.primary, fontWeight: FontWeight.w600,
                  )),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Group selector
        if (groups.length > 1) ...[
          Text('المجموعة', style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant,
          )),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: groups.map((g) => FilterChip(
              label: Text(g.name),
              selected: g.id == selectedGroupId,
              onSelected: g.isActive
                  ? (_) => ref.read(selectedGroupProvider.notifier).select(g.id)
                  : (_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ستتوفر قريباً')),
                      );
                    },
              selectedColor: scheme.primaryContainer,
              checkmarkColor: scheme.primary,
              avatar: g.isActive ? null : Icon(Icons.lock, size: 14, color: scheme.onSurfaceVariant),
            )).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Date range picker
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.date_range, size: 16, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text('الفترة الزمنية', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant,
                  )),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          border: Border.all(color: _startDate != null ? scheme.primary : scheme.outlineVariant),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _startDate != null ? dateLabelWithDay(_startDate!) : 'من',
                          style: TextStyle(
                            color: _startDate != null ? scheme.onSurface : scheme.onSurfaceVariant,
                            fontWeight: _startDate != null ? FontWeight.w600 : FontWeight.normal,
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.arrow_forward, size: 16, color: scheme.onSurfaceVariant),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          border: Border.all(color: _endDate != null ? scheme.primary : scheme.outlineVariant),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _endDate != null ? dateLabelWithDay(_endDate!) : 'إلى',
                          style: TextStyle(
                            color: _endDate != null ? scheme.onSurface : scheme.onSurfaceVariant,
                            fontWeight: _endDate != null ? FontWeight.w600 : FontWeight.normal,
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 44, height: 44,
                    child: IconButton.filled(
                      onPressed: _loading ? null : _load,
                      icon: _loading
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.search, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (!_loaded)
          SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app, size: 40, color: scheme.onSurfaceVariant.withAlpha(80)),
                  const SizedBox(height: 12),
                  Text('اختر تاريخين واضغط بحث', style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),

        if (_loaded && _bookings.isEmpty)
          SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off, size: 48, color: scheme.onSurfaceVariant.withAlpha(100)),
                  const SizedBox(height: 12),
                  Text('لا توجد نتائج للفترة المحددة', style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),

        if (_loaded && _bookings.isNotEmpty) ...[
          const SizedBox(height: 20),
          _ReportSummary(bookings: _bookings),
          const SizedBox(height: 20),
          _FacilityBreakdown(bookings: _bookings),
          const SizedBox(height: 20),
          _DailyBreakdown(bookings: _bookings),
        ],

        if (_analytics != null) ...[
          const SizedBox(height: 20),
          _UtilizationSection(data: _analytics!),
          const SizedBox(height: 20),
          _PeakHoursChart(data: _analytics!),
        ],

        if (_walletOps.isNotEmpty) ...[
          const SizedBox(height: 20),
          _WalletOperationsSection(operations: _walletOps),
        ],
      ],
    );

    if (widget.inShell) return content;
    return Scaffold(appBar: AppBar(title: const Text('التقارير')), body: content);
  }
}

class _ReportSummary extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;
  const _ReportSummary({required this.bookings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    var totalRevenue = 0.0;
    var totalPaid = 0.0;
    var confirmed = 0;
    var pending = 0;
    var pendingApproval = 0;
    var cancelled = 0;

    for (final b in bookings) {
      final price = (b['total_price'] as num?)?.toDouble() ?? 0;
      final paid = (b['paid_amount'] as num?)?.toDouble() ?? 0;
      totalRevenue += price;
      totalPaid += paid;
      switch (b['status'] as String? ?? '') {
        case 'confirmed':
          confirmed++;
          break;
        case 'pending_approval':
          pendingApproval++;
          break;
        case 'pending':
          pending++;
          break;
        case 'cancelled':
          cancelled++;
          break;
      }
    }

    final totalBookings = bookings.length;
    final outstanding = totalRevenue - totalPaid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              width: 4, height: 20,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text('ملخص التقرير', style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.bold, color: scheme.onSurface,
            )),
          ],
        ),
        const SizedBox(height: 14),

        // Key metrics - revenue row
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _MetricCard(
                label: 'إجمالي الإيرادات',
                value: totalRevenue.toStringAsFixed(0),
                unit: 'ر.ي',
                icon: Icons.trending_up,
                color: Colors.teal,
                valueColor: Colors.teal,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _MetricCard(
                label: 'مدفوع',
                value: totalPaid.toStringAsFixed(0),
                unit: 'ر.ي',
                icon: Icons.check_circle,
                color: Colors.green,
                valueColor: Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _MetricCard(
                label: 'متبقي',
                value: outstanding.toStringAsFixed(0),
                unit: 'ر.ي',
                icon: Icons.receipt_long,
                color: outstanding > 0 ? Colors.orange : Colors.green,
                valueColor: outstanding > 0 ? Colors.orange : Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Total bookings + status breakdown
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _MetricCard(
                label: 'إجمالي الحجوزات',
                value: '$totalBookings',
                unit: 'حجز',
                icon: Icons.book_online,
                color: scheme.primary,
                valueColor: scheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: _StatusBreakdown(
                confirmed: confirmed,
                pendingApproval: pendingApproval,
                pending: pending,
                cancelled: cancelled,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusBreakdown extends StatelessWidget {
  final int confirmed;
  final int pendingApproval;
  final int pending;
  final int cancelled;

  const _StatusBreakdown({
    required this.confirmed,
    required this.pendingApproval,
    required this.pending,
    required this.cancelled,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = confirmed + pendingApproval + pending + cancelled;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('حالة الحجوزات', style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant,
          )),
          const SizedBox(height: 10),
          _StatusBar(
            total: total,
            segments: [
              _Segment(label: 'مؤكدة', count: confirmed, color: Colors.green),
              _Segment(label: 'شبه مؤكدة', count: pendingApproval, color: Colors.blue),
              _Segment(label: 'معلقة', count: pending, color: Colors.orange),
              _Segment(label: 'ملغية', count: cancelled, color: scheme.error),
            ],
            scheme: scheme,
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final int total;
  final List<_Segment> segments;
  final ColorScheme scheme;

  const _StatusBar({
    required this.total,
    required this.segments,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final active = segments.where((s) => s.count > 0).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: active.map((s) {
                final fraction = s.count / total;
                return Expanded(
                  flex: (fraction * 100).round().clamp(1, 100),
                  child: Container(color: s.color),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Legend
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: active.map((s) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(
                color: s.color, borderRadius: BorderRadius.circular(2),
              )),
              const SizedBox(width: 4),
              Text('${s.label} ${s.count}', style: TextStyle(
                fontSize: 11, color: scheme.onSurfaceVariant,
              )),
            ],
          )).toList(),
        ),
      ],
    );
  }
}

class _Segment {
  final String label;
  final int count;
  final Color color;
  const _Segment({required this.label, required this.count, required this.color});
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final Color valueColor;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(label, style: TextStyle(
                  fontSize: 11, color: scheme.onSurfaceVariant,
                ), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: valueColor,
              ),
              children: [
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.normal, color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FacilityBreakdown extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;
  const _FacilityBreakdown({required this.bookings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Map<String, _FacilityStat> stats = {};
    var maxRevenue = 0.0;
    for (final b in bookings) {
      final name = b['facility_name'] as String? ?? 'غير معروف';
      final price = (b['total_price'] as num?)?.toDouble() ?? 0;
      final paid = (b['paid_amount'] as num?)?.toDouble() ?? 0;
      final s = stats.putIfAbsent(name, () => _FacilityStat());
      s.count++;
      s.revenue += price;
      s.paid += paid;
      if (s.revenue > maxRevenue) maxRevenue = s.revenue;
    }

    final sorted = stats.entries.toList()
      ..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4, height: 20,
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text('حسب الملعب', style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.bold, color: scheme.onSurface,
            )),
          ],
        ),
        const SizedBox(height: 14),
        ...sorted.map((e) {
          final ratio = maxRevenue > 0 ? e.value.revenue / maxRevenue : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(e.key, style: TextStyle(
                          fontWeight: FontWeight.w600, color: scheme.onSurface,
                        )),
                      ),
                      Text('${e.value.revenue.toStringAsFixed(0)} ر.ي', style: TextStyle(
                        fontWeight: FontWeight.bold, color: scheme.primary,
                      )),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                      backgroundColor: scheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.amber.shade400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('${e.value.count} حجوزات', style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant,
                      )),
                      const Spacer(),
                      Text('مدفوع: ${e.value.paid.toStringAsFixed(0)} ر.ي', style: TextStyle(
                        fontSize: 12, color: Colors.green.shade600,
                      )),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _DailyBreakdown extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;
  const _DailyBreakdown({required this.bookings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Map<String, _DayStat> days = {};
    var maxDayRevenue = 0.0;
    for (final b in bookings) {
      final instances = (b['instances'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final inst in instances) {
        final date = DateTime.parse(inst['start_at'] as String).toLocal();
        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final price = (b['total_price'] as num?)?.toDouble() ?? 0;
        final d = days.putIfAbsent(key, () => _DayStat());
        d.count++;
        d.revenue += price;
        if (d.revenue > maxDayRevenue) maxDayRevenue = d.revenue;
      }
    }

    final sorted = days.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4, height: 20,
              decoration: BoxDecoration(
                color: Colors.indigo,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text('حسب اليوم', style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.bold, color: scheme.onSurface,
            )),
          ],
        ),
        const SizedBox(height: 14),
        ...sorted.map((e) {
          final date = DateTime.parse(e.key);
          final ratio = maxDayRevenue > 0 ? e.value.revenue / maxDayRevenue : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.calendar_today, size: 14, color: Colors.indigo),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Text(dateLabelWithDay(date), style: TextStyle(
                      color: scheme.onSurface, fontWeight: FontWeight.w500,
                    )),
                  ),
                  Expanded(
                    flex: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: scheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.indigo.withAlpha(180),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 60,
                    child: Text('${e.value.count}', style: TextStyle(
                      color: scheme.onSurfaceVariant, fontSize: 13,
                    )),
                  ),
                  Text('${e.value.revenue.toStringAsFixed(0)} ر.ي', style: TextStyle(
                    fontWeight: FontWeight.w600, color: scheme.onSurface,
                  )),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _FacilityStat {
  int count = 0;
  double revenue = 0;
  double paid = 0;
}

class _DayStat {
  int count = 0;
  double revenue = 0;
}

class _WalletOperationsSection extends StatelessWidget {
  final List<Map<String, dynamic>> operations;
  const _WalletOperationsSection({required this.operations});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    var totalDeposits = 0.0;
    var totalDeducts = 0.0;

    for (final op in operations) {
      final amount = (op['amount'] as num?)?.toDouble() ?? 0;
      if (op['type'] == 'deposit') totalDeposits += amount;
      else totalDeducts += amount;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4, height: 20,
              decoration: BoxDecoration(
                color: Colors.teal,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text('عمليات المحافظ', style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.bold, color: scheme.onSurface,
            )),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'إجمالي الإيداع',
                value: totalDeposits.toStringAsFixed(0),
                unit: 'ر.ي',
                icon: Icons.add_circle,
                color: Colors.green,
                valueColor: Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                label: 'إجمالي الخصم',
                value: totalDeducts.toStringAsFixed(0),
                unit: 'ر.ي',
                icon: Icons.remove_circle,
                color: Colors.red,
                valueColor: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...operations.map((op) => _WalletOpTile(op: op, scheme: scheme)),
      ],
    );
  }
}

class _WalletOpTile extends StatelessWidget {
  final Map<String, dynamic> op;
  final ColorScheme scheme;
  const _WalletOpTile({required this.op, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final isDeposit = op['type'] == 'deposit';
    final amount = (op['amount'] as num?)?.toDouble() ?? 0;
    final desc = op['description'] as String? ?? '';
    final userName = op['target_user_name'] as String? ?? '';
    final adminName = op['admin_name'] as String? ?? '';
    final createdAt = op['created_at'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
              color: isDeposit ? Colors.green : scheme.error,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(userName.isNotEmpty ? userName : 'مستخدم',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                  if (adminName.isNotEmpty)
                    Text('بواسطة: $adminName',
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  Text(desc, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  Text(formatDateTime12(DateTime.parse(createdAt)),
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant.withValues(alpha: 0.7))),
                ],
              ),
            ),
            Text(
              '${isDeposit ? '+' : '-'}$amount ر.ي',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDeposit ? Colors.green : scheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UtilizationSection extends StatelessWidget {
  final Map<String, dynamic> data;
  const _UtilizationSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final facilities = (data['facilities'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final overallUtil = (summary['overall_utilization'] as num?)?.toDouble() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 20,
              decoration: BoxDecoration(color: Colors.indigo, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 10),
            Text('نسبة الإشغال', style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.bold, color: scheme.onSurface,
            )),
          ],
        ),
        const SizedBox(height: 14),
        Center(
          child: Column(
            children: [
              Text('${overallUtil.toStringAsFixed(0)}%', style: TextStyle(
                fontSize: 42, fontWeight: FontWeight.bold,
                color: overallUtil > 70 ? Colors.green : (overallUtil > 40 ? Colors.orange : scheme.error),
              )),
              Text('نسبة الإشغال الإجمالية', style: TextStyle(
                fontSize: 13, color: scheme.onSurfaceVariant,
              )),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...facilities.map((f) {
          final util = (f['utilization_percent'] as num?)?.toDouble() ?? 0;
          final name = f['facility_name'] as String? ?? '';
          final booked = (f['booked_hours'] as num?)?.toDouble() ?? 0;
          final available = (f['available_hours'] as num?)?.toDouble() ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(name, style: TextStyle(fontWeight: FontWeight.w500, color: scheme.onSurface))),
                    Text('$booked / $available ساعة', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    const SizedBox(width: 8),
                    Text('${util.toStringAsFixed(0)}%', style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: util > 70 ? Colors.green : (util > 40 ? Colors.orange : scheme.error),
                    )),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: util / 100,
                    minHeight: 10,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                      util > 70 ? Colors.green : (util > 40 ? Colors.orange : scheme.error),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _PeakHoursChart extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PeakHoursChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final peakHours = (data['peak_hours'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (peakHours.isEmpty) return const SizedBox.shrink();

    final maxCount = peakHours.fold<int>(0,
      (p, v) => (v['booking_count'] as int? ?? 0) > p ? (v['booking_count'] as int?)! : p);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 20,
              decoration: BoxDecoration(color: Colors.deepOrange, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 10),
            Text('أوقات الذروة', style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.bold, color: scheme.onSurface,
            )),
          ],
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: peakHours.map((p) {
              final hour = (p['hour'] as int?) ?? 0;
              final count = (p['booking_count'] as int?) ?? 0;
              final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
              final period = hour < 12 ? 'ص' : 'م';
              final height = maxCount > 0 ? (count / maxCount * 140) : 0.0;

              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$count', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Container(
                      width: 28,
                      height: height.clamp(4, 140),
                      decoration: BoxDecoration(
                        color: count == maxCount ? Colors.deepOrange : scheme.primary.withAlpha(180),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('$h $period', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        if (peakHours.isNotEmpty) ...[
          const SizedBox(height: 8),
          Center(
            child: Text('* عدد الحجوزات لكل ساعة في الفترة المحددة',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant.withAlpha(150))),
          ),
        ],
      ],
    );
  }
}
