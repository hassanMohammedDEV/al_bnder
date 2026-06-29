import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../presentaion/shared/time_picker_dialog.dart';
import '../../repositories/admin_repository_impl.dart';
import '../../../../core/helpers/error_helper.dart';

class AdminTodayBookingsScreen extends ConsumerStatefulWidget {
  final String facilityGroupId;
  const AdminTodayBookingsScreen({super.key, required this.facilityGroupId});

  @override
  ConsumerState<AdminTodayBookingsScreen> createState() => _AdminTodayBookingsScreenState();
}

class _AdminTodayBookingsScreenState extends ConsumerState<AdminTodayBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ref.read(adminRepositoryProvider).getTodayBookings(widget.facilityGroupId);
    if (!mounted) return;
    result.when(
      success: (data) => setState(() { _all = data; _loading = false; }),
      failure: (e) => setState(() => _loading = false),
    );
  }

  List<Map<String, dynamic>> _byStatus(String status) =>
      _all.where((b) => b['status'] == status).toList();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('حجوزات اليوم'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'مؤكدة (${_byStatus('confirmed').length})'),
            Tab(text: 'معلقة (${_byStatus('pending').length})'),
            Tab(text: 'شبه مؤكدة (${_byStatus('pending_approval').length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _list(scheme, _byStatus('confirmed'), Colors.green),
                  _list(scheme, _byStatus('pending'), Colors.orange),
                  _list(scheme, _byStatus('pending_approval'), Colors.blue),
                ],
              ),
            ),
    );
  }

  Widget _list(ColorScheme scheme, List<Map<String, dynamic>> items, Color color) {
    if (items.isEmpty) {
      return Center(child: Text('لا توجد حجوزات', style: TextStyle(color: scheme.onSurfaceVariant)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final b = items[i];
        final id = b['id'] as String;
        final status = b['status'] as String? ?? '';
        final instances = (b['instances'] as List?) ?? [];
        final bookingDate = instances.isNotEmpty
            ? DateTime.parse(instances.first['start_at'] as String).toLocal()
            : null;
        final canCancel = status != 'cancelled' && (bookingDate == null || DateTime.now().isBefore(bookingDate));
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(b['status'] == 'pending_approval' ? 'شبه مؤكد' : b['status'] == 'pending' ? 'معلق' : 'مؤكد',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                      ),
                    ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${(b['total_price'] as num?)?.toStringAsFixed(0) ?? '0'} ر.س',
                        style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurface),
                      ),
                      if (b['paid_amount'] != null && (b['paid_amount'] as num) > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          (b['paid_amount'] as num) >= (b['total_price'] as num)
                              ? 'مدفوع بالكامل'
                              : 'عربون: ${(b['paid_amount'] as num).toStringAsFixed(0)} ر.س',
                          style: TextStyle(fontSize: 11,
                            color: (b['paid_amount'] as num) >= (b['total_price'] as num)
                                ? Colors.green : scheme.primary,
                            fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('المستخدم: ${b['user_name'] as String? ?? ''}', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                Text('الجوال: ${b['user_phone'] as String? ?? ''}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                if (bookingDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('التاريخ: ${dateLabelWithDay(bookingDate)}',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ),
                if (instances.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'الوقت: ${instances.map((inst) {
                        final dt = DateTime.parse(inst['start_at'] as String).toLocal();
                        final dt2 = DateTime.parse(inst['end_at'] as String).toLocal();
                        return '${format12(dt.hour)} - ${format12(dt2.hour)}';
                      }).join(', ')}',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ),
                if (canCancel) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('إلغاء الحجز'),
                      style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
                      onPressed: () => _cancelBooking(context, id),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _cancelBooking(BuildContext context, String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الإلغاء'),
        content: const Text('هل أنت متأكد من إلغاء هذا الحجز؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إلغاء الحجز')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final result = await ref.read(adminRepositoryProvider).adminCancelBooking(bookingId);
    if (!mounted) return;
    result.when(
      success: (data) {
        _load();
        final msg = data['message'] as String? ?? 'تم إلغاء الحجز';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(e)))),
    );
  }
}
