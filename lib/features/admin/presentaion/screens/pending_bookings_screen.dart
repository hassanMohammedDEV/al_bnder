import 'package:app_platform_ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/admin_provider.dart';

class PendingBookingsScreen extends ConsumerStatefulWidget {
  const PendingBookingsScreen({super.key});

  @override
  ConsumerState<PendingBookingsScreen> createState() => _PendingBookingsScreenState();
}

class _PendingBookingsScreenState extends ConsumerState<PendingBookingsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(pendingBookingsProvider.notifier).load());
  }

  Future<void> _confirm(String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحجز'),
        content: const Text('هل أنت متأكد من تأكيد هذا الحجز؟ (تم الدفع خارجياً عبر واتساب)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد')),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await ref.read(adminActionProvider.notifier).confirmBooking(bookingId);
    if (!mounted) return;
    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تأكيد الحجز بنجاح')),
        );
      },
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      },
    );
  }

  Future<void> _deposit({
    required String userId,
    required String groupId,
    required String userName,
  }) async {
    final amountController = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('شحن المحفظة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المستخدم: $userName'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ',
                suffixText: 'ر.س',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('رجوع')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(amountController.text);
              if (v == null || v <= 0) return;
              Navigator.pop(ctx, v);
            },
            child: const Text('شحن'),
          ),
        ],
      ),
    );
    if (amount == null || amount <= 0) return;

    final result = await ref.read(adminActionProvider.notifier).depositWallet(
      targetUserId: userId,
      facilityGroupId: groupId,
      amount: amount,
      description: 'شحن رصيد عبر واتساب',
    );
    if (!mounted) return;
    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم شحن $amount ر.س بنجاح')),
        );
      },
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(pendingBookingsProvider);
    final action = ref.watch(adminActionProvider);
    final bookings = state.data ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('الحجوزات المعلقة')),
      body: AsyncView<List<Map<String, dynamic>>>(
        status: state.status,
        data: state.data,
        error: state.error,
        onLoading: () => const Center(child: CircularProgressIndicator()),
        onEmpty: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
              const SizedBox(height: 16),
              Text('لا توجد حجوزات معلقة', style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        onError: (e) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: scheme.error),
              const SizedBox(height: 16),
              Text(e.message, style: TextStyle(color: scheme.error)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.read(pendingBookingsProvider.notifier).load(),
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        onSuccess: (_) => RefreshIndicator(
          onRefresh: () => ref.read(pendingBookingsProvider.notifier).load(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (_, i) => _buildBookingCard(bookings[i], scheme, action),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking, ColorScheme scheme, ActionState action) {
    final dateFmt = DateFormat('yyyy/MM/dd HH:mm');
    final id = booking['id'] as String;
    final isProcessing = action.isLoading('confirm') || action.isLoading('deposit');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(booking['facility_name'] as String? ?? '', style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600,
                  )),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('معلق', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange,
                  )),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _infoRow(scheme, Icons.person, 'المستخدم', booking['user_name'] as String? ?? ''),
            _infoRow(scheme, Icons.phone, 'الجوال', booking['user_phone'] as String? ?? ''),
            _infoRow(scheme, Icons.payments, 'المبلغ', '${(booking['total_price'] as num?)?.toStringAsFixed(0) ?? '0'} ر.س'),
            _infoRow(scheme, Icons.calendar_today, 'تاريخ الحجز',
                dateFmt.format(DateTime.parse(booking['created_at'] as String))),
            if (booking['instances'] is List && (booking['instances'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'الأوقات: ${(booking['instances'] as List).map((inst) {
                    final start = DateFormat('HH:mm').format(DateTime.parse(inst['start_at']));
                    final end = DateFormat('HH:mm').format(DateTime.parse(inst['end_at']));
                    return '$start - $end';
                  }).join(', ')}',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: isProcessing ? null : () => _confirm(id),
                    style: FilledButton.styleFrom(backgroundColor: Colors.green),
                    child: action.isLoading('confirm')
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('تأكيد', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: isProcessing ? null : () => _deposit(
                      userId: booking['user_id'] as String,
                      groupId: booking['group_id'] as String,
                      userName: booking['user_name'] as String? ?? '',
                    ),
                    child: const Text('شحن المحفظة'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(ColorScheme scheme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
