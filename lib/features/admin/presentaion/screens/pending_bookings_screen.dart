import 'package:app_platform_state/state.dart';
import 'package:app_platform_ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
                RadioGroup<String?>(
                  groupValue: option,
                  onChanged: (v) => setDialogState(() { option = v; depositCtl.clear(); }),
                  child: InkWell(
                    onTap: () => setDialogState(() { option = 'none'; depositCtl.clear(); }),
                    child: Row(
                      children: [
                        Radio<String?>(value: 'none'),
                        const Text('لم يتم الدفع', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                RadioGroup<String?>(
                  groupValue: option,
                  onChanged: (v) => setDialogState(() => option = v),
                  child: InkWell(
                    onTap: () => setDialogState(() => option = 'deposit'),
                    child: Row(
                      children: [
                        Radio<String?>(value: 'deposit'),
                        const Text('عربون', style: TextStyle(fontSize: 14)),
                      ],
                    ),
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
                RadioGroup<String?>(
                  groupValue: option,
                  onChanged: (v) => setDialogState(() { option = v; depositCtl.clear(); }),
                  child: InkWell(
                    onTap: () => setDialogState(() { option = 'full'; depositCtl.clear(); }),
                    child: Row(
                      children: [
                        Radio<String?>(value: 'full'),
                        Text('المبلغ كامل (${totalPrice.toStringAsFixed(0)} ر.ي)', style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
              FilledButton(
                onPressed: () {
                  if (option == 'none') {
                    Navigator.pop(ctx, 0);
                  } else if (option == 'full') {
                    Navigator.pop(ctx, totalPrice);
                  } else if (option == 'deposit') {
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

    Widget bodyContent = RefreshIndicator(
      onRefresh: () => ref.read(pendingBookingsProvider.notifier).load(),
      child: AsyncView<List<Map<String, dynamic>>>(
        status: state.status,
        data: state.data,
        error: state.error,
        onLoading: () => LayoutBuilder(
          builder: (_, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: constraints.maxHeight, child: const Center(child: CircularProgressIndicator())),
            ],
          ),
        ),
        onEmpty: () => LayoutBuilder(
          builder: (_, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                      const SizedBox(height: 16),
                      Text('لا توجد حجوزات معلقة', style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        onError: (e) => LayoutBuilder(
          builder: (_, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: constraints.maxHeight, child: Center(
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
              )),
            ],
          ),
        ),
        onSuccess: (_) => ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (_, i) => _buildBookingCard(bookings[i], scheme, action),
        ),
      ),
    );

    if (widget.inShell) return bodyContent;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الحجوزات المعلقة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/admin/search-bookings'),
          ),
        ],
      ),
      body: bodyContent,
    );
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
                child: _buildInstancesWidget(booking['instances'] as List, booking['id'] as String, scheme),
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
              ],
            ),
            const SizedBox(height: 8),
            ..._buildCancelButtons(booking, isProcessing, scheme),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCancelButtons(Map<String, dynamic> booking, bool isProcessing, ColorScheme scheme) {
    final id = booking['id'] as String;
    final instancesList = (booking['instances'] as List?) ?? [];
    final isRecurring = instancesList.length > 1;
    if (!isRecurring) {
      return [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: const Text('إلغاء', maxLines: 1, overflow: TextOverflow.ellipsis),
            style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
            onPressed: isProcessing ? null : () => _cancelBooking(context, id),
          ),
        ),
      ];
    }
    return instancesList
        .where((inst) => inst['status'] != 'cancelled' && inst['status'] != 'completed')
        .map((inst) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: Text('إلغاء: ${dateLabelWithDay(DateTime.parse(inst['start_at'] as String).toLocal())}'),
              style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
              onPressed: isProcessing ? null : () => _cancelInstance(id, inst['id'] as String, DateTime.parse(inst['start_at'] as String).toLocal()),
            ),
          ),
        )).toList();
  }

  Future<void> _cancelInstance(String bookingId, String instanceId, DateTime dt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد إلغاء الموعد'),
        content: Text('هل أنت متأكد من إلغاء موعد ${dateLabelWithDay(dt)}؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إلغاء الموعد')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final result = await ref.read(adminRepositoryProvider).cancelBookingInstance(
      bookingId: bookingId, instanceId: instanceId,
    );
    if (!mounted) return;
    result.when(
      success: (data) {
        ref.read(pendingBookingsProvider.notifier).load();
        final msg = data['message'] as String? ?? 'تم إلغاء الموعد';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(e)))),
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

  Widget _buildInstancesWidget(List instances, String bookingId, ColorScheme scheme) {
    final active = instances.where((inst) =>
      inst['status'] != 'cancelled' && inst['status'] != 'completed'
    ).toList();
    if (active.isEmpty) return const SizedBox.shrink();
    final firstStart = DateTime.parse(active.first['start_at']).toLocal();
    final firstEnd = DateTime.parse(active.first['end_at']).toLocal();
    final s = firstStart.hour < 12 ? 'ص' : 'م';
    final e = firstEnd.hour < 12 ? 'ص' : 'م';
    final sh = firstStart.hour == 0 ? 12 : (firstStart.hour <= 12 ? firstStart.hour : firstStart.hour - 12);
    final eh = firstEnd.hour == 0 ? 12 : (firstEnd.hour <= 12 ? firstEnd.hour : firstEnd.hour - 12);
    final timeStr = '$sh:00 $s - $eh:00 $e';
    if (active.length == 1) {
      return Text('الوقت: $timeStr', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('الوقت: $timeStr', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        ...active.map<Widget>((inst) {
          final dt = DateTime.parse(inst['start_at']).toLocal();
          final instanceId = inst['id'] as String;
          final canCancel = dt.isAfter(DateTime.now());
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(dateLabelWithDay(dt), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ),
                if (canCancel)
                  SizedBox(
                    width: 28, height: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.cancel_outlined, size: 16, color: scheme.error),
                      tooltip: 'إلغاء هذا الموعد',
                      onPressed: () => _cancelInstance(bookingId, instanceId, dt),
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
