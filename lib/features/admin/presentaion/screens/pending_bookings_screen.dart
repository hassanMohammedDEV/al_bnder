import 'package:app_platform_state/state.dart';
import 'package:app_platform_ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../presentaion/shared/time_picker_dialog.dart';
import '../../providers/admin_provider.dart';
import '../../repositories/admin_repository_impl.dart';
import '../../../../core/helpers/error_helper.dart';

class PendingBookingsScreen extends ConsumerStatefulWidget {
  final bool inShell;
  const PendingBookingsScreen({super.key, this.inShell = false});

  @override
  ConsumerState<PendingBookingsScreen> createState() => _PendingBookingsScreenState();
}

class _PendingBookingsScreenState extends ConsumerState<PendingBookingsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(pendingBookingsProvider.notifier).load());
  }

  Future<void> _confirm(String bookingId, double totalPrice) async {
    final paidAmount = await showDialog<double>(
      context: context,
      builder: (ctx) {
        String? option;
        final depositCtl = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('تأكيد الحجز'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('هل تم استلام الدفع؟', style: TextStyle(fontSize: 15)),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => setDialogState(() { option = 'none'; depositCtl.clear(); }),
                  child: Row(
                    children: [
                      Radio<String?>(value: 'none', groupValue: option, onChanged: (v) => setDialogState(() { option = v; depositCtl.clear(); })),
                      const Text('لم يتم الدفع', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => setDialogState(() => option = 'deposit'),
                  child: Row(
                    children: [
                      Radio<String?>(value: 'deposit', groupValue: option, onChanged: (v) => setDialogState(() => option = v)),
                      const Text('عربون', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                if (option == 'deposit')
                  Padding(
                    padding: const EdgeInsets.only(left: 40, bottom: 8),
                    child: TextField(
                      controller: depositCtl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'المبلغ',
                        suffixText: 'ر.ي',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                InkWell(
                  onTap: () => setDialogState(() { option = 'full'; depositCtl.clear(); }),
                  child: Row(
                    children: [
                      Radio<String?>(value: 'full', groupValue: option, onChanged: (v) => setDialogState(() { option = v; depositCtl.clear(); })),
                      Text('المبلغ كامل (${totalPrice.toStringAsFixed(0)} ر.ي)', style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
              FilledButton(
                onPressed: () {
                  if (option == 'none') Navigator.pop(ctx, 0);
                  else if (option == 'full') Navigator.pop(ctx, totalPrice);
                  else if (option == 'deposit') {
                    final v = double.tryParse(depositCtl.text);
                    if (v != null && v > 0) Navigator.pop(ctx, v);
                  }
                },
                child: const Text('تأكيد'),
              ),
            ],
          ),
        );
      },
    );
    if (paidAmount == null) return;

    final result = await ref.read(adminActionProvider.notifier).confirmBooking(bookingId, paidAmount: paidAmount);
    if (!mounted) return;
    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              paidAmount > 0
                  ? 'تم تأكيد الحجز (المدفوع: ${paidAmount.toStringAsFixed(0)} ر.ي)'
                  : 'تم تأكيد الحجز (لم يتم الدفع)',
            ),
          ),
        );
      },
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(translateError(e))),
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
                suffixText: 'ر.ي',
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
        final fmt = NumberFormat('#,###');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم شحن ${fmt.format(amount)} ر.ي بنجاح')),
        );
      },
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(translateError(e))),
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

    Widget bodyContent = AsyncView<List<Map<String, dynamic>>>(
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
              Text(translateError(e), style: TextStyle(color: scheme.error)),
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
      );

    if (widget.inShell) return bodyContent;
    return Scaffold(appBar: AppBar(title: const Text('الحجوزات المعلقة')), body: bodyContent);
  }

  Widget _buildBookingCard(Map<String, dynamic> booking, ColorScheme scheme, ActionStore action) {
    final id = booking['id'] as String;
    final isProcessing = action.isLoading('confirm') || action.isLoading('deposit');

    final status = booking['status'] as String? ?? 'pending';
    final isPendingApproval = status == 'pending_approval';

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
                    color: (isPendingApproval ? Colors.blue : Colors.orange).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isPendingApproval ? 'شبه مؤكد' : 'معلق',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: isPendingApproval ? Colors.blue : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _infoRow(scheme, Icons.person, 'المستخدم', booking['user_name'] as String? ?? ''),
            _infoRow(scheme, Icons.phone, 'الجوال', booking['user_phone'] as String? ?? ''),
            _infoRow(scheme, Icons.payments, 'المبلغ', '${(booking['total_price'] as num?)?.toStringAsFixed(0) ?? '0'} ر.ي'),
            if (booking['paid_amount'] != null && (booking['paid_amount'] as num) > 0)
              _infoRow(scheme, Icons.receipt, 'المدفوع',
                (booking['paid_amount'] as num) >= (booking['total_price'] as num)
                    ? 'مدفوع بالكامل'
                    : 'عربون: ${(booking['paid_amount'] as num).toStringAsFixed(0)} ر.ي'),
            _infoRow(scheme, Icons.calendar_today, 'تاريخ الحجز',
                formatDateTime12(DateTime.parse(booking['created_at'] as String))),
            if (booking['instances'] is List && (booking['instances'] as List).isNotEmpty)
              _infoRow(scheme, Icons.event, 'موعد الحجز',
                  dateLabelWithDay(DateTime.parse((booking['instances'] as List).first['start_at'] as String).toLocal())),
            if (booking['instances'] is List && (booking['instances'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'الأوقات: ${(booking['instances'] as List).map((inst) {
                    final startDt = DateTime.parse(inst['start_at']).toLocal();
                    final endDt = DateTime.parse(inst['end_at']).toLocal();
                    final sh = startDt.hour;
                    final eh = endDt.hour;
                    final sh12 = sh == 0 ? 12 : (sh <= 12 ? sh : sh - 12);
                    final eh12 = eh == 0 ? 12 : (eh <= 12 ? eh : eh - 12);
                    final sp = sh < 12 ? 'ص' : 'م';
                    final ep = eh < 12 ? 'ص' : 'م';
                    return '$sh12:00 $sp - $eh12:00 $ep';
                  }).join(', ')}',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: isProcessing ? null : () => _confirm(id, (booking['total_price'] as num?)?.toDouble() ?? 0),
                    style: FilledButton.styleFrom(backgroundColor: Colors.green),
                    child: action.isLoading('confirm')
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('تأكيد', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                  ),
                ),
                if (booking['user_id'] != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isProcessing ? null : () => _deposit(
                        userId: booking['user_id'] as String,
                        groupId: booking['group_id'] as String,
                        userName: booking['user_name'] as String? ?? '',
                      ),
                      child: const Text('شحن المحفظة', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: Text('إلغاء', maxLines: 1, overflow: TextOverflow.ellipsis),
                    style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
                    onPressed: isProcessing ? null : () => _cancelBooking(context, id),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
        ref.read(pendingBookingsProvider.notifier).load();
        final msg = data['message'] as String? ?? 'تم إلغاء الحجز';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(e)))),
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
