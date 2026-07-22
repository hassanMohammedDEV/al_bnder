import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../admin/repositories/admin_repository_impl.dart';
import '../../../auth/providers/auth_provider.dart';

final todayBookingsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final authGroupId = ref.watch(authStateProvider).facilityGroupId;
  if (authGroupId == null || authGroupId.isEmpty) {
    throw Exception('loading');
  }
  final result = await ref.read(adminRepositoryProvider).getTodayBookings(authGroupId);
  return result.when(
    success: (data) => data.where((b) => b['status'] == 'confirmed').toList(),
    failure: (e) => throw e,
  );
});

class DailyReportScreen extends ConsumerWidget {
  final bool inShell;
  const DailyReportScreen({super.key, this.inShell = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final bookingsAsync = ref.watch(todayBookingsProvider);

    Widget body = RefreshIndicator(
      onRefresh: () async => ref.invalidate(todayBookingsProvider),
      child: bookingsAsync.when(
        data: (bookings) {
          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_available, size: 64, color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text('لا توجد حجوزات اليوم', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16)),
                ],
              ),
            );
          }

          final rows = <_BookingRow>[];
          for (final b in bookings) {
            final userName = (b['user_name'] as String?) ?? (b['guest_name'] as String?) ?? '—';
            final totalPrice = (b['total_price'] as num?)?.toDouble() ?? 0;
            final paidAmount = (b['paid_amount'] as num?)?.toDouble() ?? 0;
            final remaining = totalPrice - paidAmount;
            final instances = (b['instances'] as List?) ?? [];
            final first = instances.isNotEmpty ? instances.first : null;
            rows.add(_BookingRow(
              name: userName,
              startTime: first?['start_at'] as String? ?? '',
              endTime: first?['end_at'] as String? ?? '',
              paid: paidAmount,
              remaining: remaining,
            ));
          }

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
            itemCount: rows.length + 1,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              if (i == 0) return _buildHeader(scheme);
              final r = rows[i - 1];
              return _buildRow(r, i, scheme);
            },
          );
        },
        error: (e, _) {
          final authGroupId = ref.read(authStateProvider).facilityGroupId;
          if (authGroupId == null || authGroupId.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            children: [
              SizedBox(height: MediaQuery.of(context).size.height / 3),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: scheme.error),
                    const SizedBox(height: 8),
                    Text('فشل تحميل البيانات', style: TextStyle(color: scheme.error)),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );

    if (inShell) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('حجوزات اليوم')),
      body: body,
    );
  }

  Widget _buildHeader(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(width: 28, child: Text('#', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          Expanded(flex: 4, child: Text('الاسم', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          Expanded(flex: 3, child: Text('الوقت', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          Expanded(flex: 2, child: Text('المدفوع', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13), textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text('المتبقي', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildRow(_BookingRow r, int idx, ColorScheme scheme) {
    final timeStr = _formatTimeRange(r.startTime, r.endTime);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('$idx', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            flex: 4,
            child: Text(r.name, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 3,
            child: Text(timeStr, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            flex: 2,
            child: Text(              r.paid.toStringAsFixed(0), style: const TextStyle(fontSize: 13), textAlign: TextAlign.center),
          ),
          Expanded(
            flex: 2,
            child: Text(
              r.remaining.toStringAsFixed(0),
              style: TextStyle(fontSize: 13, color: r.remaining > 0 ? scheme.error : scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeRange(String start, String end) {
    if (start.isEmpty) return '—';
    try {
      final s = DateTime.parse(start).toLocal();
      final e = DateTime.parse(end).toLocal();
      final fmt = DateFormat('hh:mm');
      return '${fmt.format(s)} - ${fmt.format(e)}';
    } catch (_) {
      return '—';
    }
  }
}

class _BookingRow {
  final String name;
  final String startTime;
  final String endTime;
  final double paid;
  final double remaining;

  const _BookingRow({
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.paid,
    required this.remaining,
  });
}
