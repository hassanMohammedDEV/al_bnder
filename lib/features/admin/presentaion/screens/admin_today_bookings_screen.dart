import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../presentaion/shared/time_picker_dialog.dart';
import '../../repositories/admin_repository_impl.dart';
import '../../providers/admin_provider.dart';
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
  List<Map<String, dynamic>> _filtered = [];
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await ref.read(adminRepositoryProvider).getTodayBookings(widget.facilityGroupId);
    if (!mounted) return;
    result.when(
      success: (data) => setState(() { _all = data; _filtered = data; }),
      failure: (e) => setState(() {}),
    );
  }

  void _onSearch(String q) {
    setState(() {
      if (q.isEmpty) {
        _filtered = List.from(_all);
      } else {
        _filtered = _all.where((b) {
          final phone = (b['user_phone'] as String? ?? '').toLowerCase();
          final name = (b['user_name'] as String? ?? '').toLowerCase();
          final ql = q.toLowerCase();
          return phone.contains(ql) || name.contains(ql);
        }).toList();
      }
    });
  }

  List<Map<String, dynamic>> _byStatus(String status) =>
      _filtered.where((b) => b['status'] == status).toList();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('حجوزات اليوم'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) _onSearch('');
              });
            },
          ),
        ],
        bottom: _showSearch
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'بحث برقم الجوال...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    onChanged: _onSearch,
                  ),
                ),
              )
            : TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'مؤكدة (${_byStatus('confirmed').length})'),
            Tab(text: 'معلقة (${_byStatus('pending').length})'),
            Tab(text: 'شبه مؤكدة (${_byStatus('pending_approval').length})'),
          ],
        ),
      ),
      body: IndexedStack(
        index: _tabController.index,
        children: [
          RefreshIndicator(onRefresh: _load, child: _list(scheme, _byStatus('confirmed'), Colors.green)),
          RefreshIndicator(onRefresh: _load, child: _list(scheme, _byStatus('pending'), Colors.orange)),
          RefreshIndicator(onRefresh: _load, child: _list(scheme, _byStatus('pending_approval'), Colors.blue)),
        ],
      ),
    );
  }

  Widget _list(ColorScheme scheme, List<Map<String, dynamic>> items, Color color) {
    if (items.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(child: Text('لا توجد حجوزات', style: TextStyle(color: scheme.onSurfaceVariant))),
          ),
        ],
      );
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
                      Text('${(b['total_price'] as num?)?.toStringAsFixed(0) ?? '0'} ر.ي',
                        style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurface),
                      ),
                      if (b['paid_amount'] != null && (b['paid_amount'] as num) > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          (b['paid_amount'] as num) >= (b['total_price'] as num)
                              ? 'مدفوع بالكامل'
                              : 'عربون: ${(b['paid_amount'] as num).toStringAsFixed(0)} ر.ي',
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
                Text(b['facility_name'] as String? ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: scheme.primary)),
                const SizedBox(height: 4),
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
                    child: _buildInstancesWidget(instances, id, scheme),
                  ),
                const SizedBox(height: 8),
                if (status == 'pending' || status == 'pending_approval')
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('تأكيد الحجز'),
                      onPressed: () => _confirmBooking(context, id, (b['total_price'] as num?)?.toDouble() ?? 0),
                    ),
                  )
                else if (status == 'confirmed')
                  Align(
                    alignment: Alignment.centerLeft,
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (v) {
                        switch (v) {
                          case 'cancel':
                            _cancelBooking(context, id);
                          case 'shrink':
                            _shrinkBooking(context, b, instances);
                          case 'reschedule':
                            _rescheduleBooking(context, b, instances);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'cancel', child: ListTile(leading: Icon(Icons.cancel_outlined, color: Colors.red), title: Text('إلغاء'), dense: true)),
                        if (instances.length <= 1)
                          const PopupMenuItem(value: 'shrink', child: ListTile(leading: Icon(Icons.compress), title: Text('تقليص'), dense: true)),
                        if (instances.length <= 1)
                          const PopupMenuItem(value: 'reschedule', child: ListTile(leading: Icon(Icons.swap_horiz), title: Text('نقل'), dense: true)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _shrinkBooking(BuildContext context, Map<String, dynamic> booking, List instances) async {
    if (instances.isEmpty) return;
    final inst = instances.first;
    final bookingId = booking['id'] as String;
    final startAt = DateTime.parse(inst['start_at'] as String).toLocal();
    final oldEndAt = DateTime.parse(inst['end_at'] as String).toLocal();

    final picker = HourPickerDialog(
      initialHour: oldEndAt.hour > 12 ? oldEndAt.hour - 12 : (oldEndAt.hour == 0 ? 12 : oldEndAt.hour),
      initialPm: oldEndAt.hour >= 12,
      title: 'اختر وقت النهاية الجديد',
      open24: startAt.hour + 1,
      close24: oldEndAt.hour,
    );
    final picked = await showDialog<int>(
      context: context,
      builder: (_) => picker,
    );
    if (picked == null) return;

    final newEndAt = DateTime(
      startAt.year, startAt.month, startAt.day,
      picked,
      startAt.minute,
    );

    if (!context.mounted) return;
    if (!newEndAt.isAfter(startAt)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('وقت النهاية يجب أن يكون بعد وقت البداية')));
      return;
    }

    if (!context.mounted) return;
    final fmt = NumberFormat('#,###');
    final oldPrice = (inst['price'] as num?)?.toDouble() ?? 0;
    final oldMins = oldEndAt.difference(startAt).inMinutes;
    final newMins = newEndAt.difference(startAt).inMinutes;
    final newPrice = oldPrice * newMins / oldMins;

    final paidAmount = (booking['paid_amount'] as num?)?.toDouble() ?? 0;
    final totalPrice = (booking['total_price'] as num?)?.toDouble() ?? 0;
    final isFullPayment = paidAmount >= totalPrice && paidAmount > 0;
    final refund = isFullPayment ? oldPrice - newPrice : 0.0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد تقليص الحجز'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الوقت الحالي: ${format12(startAt.hour)} - ${format12(oldEndAt.hour)}'),
            const SizedBox(height: 4),
            Text('الوقت الجديد: ${format12(startAt.hour)} - ${format12(picked)}'),
            const SizedBox(height: 8),
            Text('السعر القديم: ${fmt.format(oldPrice)} ر.ي'),
            Text('السعر الجديد: ${fmt.format(newPrice.round())} ر.ي'),
            if (refund > 0) ...[
              const SizedBox(height: 8),
              Text('سيتم استرجاع: ${fmt.format(refund.round())} ر.ي',
                style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد التقليص')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await ref.read(adminRepositoryProvider).shrinkBooking(
      bookingId: bookingId,
      newEndAt: newEndAt,
    );
    if (!mounted) return;
    result.when(
      success: (data) {
        _load();
        final msg = data['message'] as String? ?? 'تم تقليص الحجز بنجاح';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(e)))),
    );
  }

  Future<void> _rescheduleBooking(BuildContext context, Map<String, dynamic> booking, List instances) async {
    if (instances.isEmpty) return;
    final inst = instances.first;
    final bookingId = booking['id'] as String;
    final oldStartAt = DateTime.parse(inst['start_at'] as String).toLocal();
    final oldEndAt = DateTime.parse(inst['end_at'] as String).toLocal();
    final scheme = Theme.of(context).colorScheme;

    // 1. Pick new date
    final newDate = await showDatePicker(
      context: context,
      initialDate: oldStartAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (newDate == null || !context.mounted) return;

    // 2. Pick new start time
    final startPicked = await showDialog<int>(
      context: context,
      builder: (_) => HourPickerDialog(
        initialHour: oldStartAt.hour > 12 ? oldStartAt.hour - 12 : (oldStartAt.hour == 0 ? 12 : oldStartAt.hour),
        initialPm: oldStartAt.hour >= 12,
        title: 'اختر وقت البداية الجديد',
        open24: 0,
        close24: 24,
      ),
    );
    if (startPicked == null || !context.mounted) return;

    // 3. Pick new end time
    final endPicked = await showDialog<int>(
      context: context,
      builder: (_) => HourPickerDialog(
        initialHour: startPicked > 12 ? startPicked - 12 : (startPicked == 0 ? 12 : startPicked),
        initialPm: startPicked >= 12,
        title: 'اختر وقت النهاية الجديد',
        open24: startPicked + 1,
        close24: 24,
      ),
    );
    if (endPicked == null || !context.mounted) return;

    final newStartAt = DateTime(newDate.year, newDate.month, newDate.day, startPicked, 0);
    final newEndAt = DateTime(newDate.year, newDate.month, newDate.day, endPicked, 0);

    if (newEndAt.isBefore(newStartAt) || newEndAt.isAtSameMomentAs(newStartAt)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('وقت النهاية يجب أن يكون بعد وقت البداية')));
      return;
    }

    // 4. Confirmation
    final fmt = NumberFormat('#,###');
    final oldPrice = (inst['price'] as num?)?.toDouble() ?? 0;
    final oldMins = oldEndAt.difference(oldStartAt).inMinutes;
    final newMins = newEndAt.difference(newStartAt).inMinutes;
    final newPrice = oldPrice * newMins / oldMins;

    final paidAmount = (booking['paid_amount'] as num?)?.toDouble() ?? 0;
    final totalPrice = (booking['total_price'] as num?)?.toDouble() ?? 0;
    final isFullPayment = paidAmount >= totalPrice && paidAmount > 0;
    final refund = isFullPayment && newPrice < oldPrice ? oldPrice - newPrice : 0.0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد نقل الحجز'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الوقت الحالي:', style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface)),
            const SizedBox(height: 4),
            Text('${dateLabelWithDay(oldStartAt)} - ${format12(oldStartAt.hour)} إلى ${format12(oldEndAt.hour)}'),
            const SizedBox(height: 12),
            Text('الوقت الجديد:', style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface)),
            const SizedBox(height: 4),
            Text('${dateLabelWithDay(newStartAt)} - ${format12(startPicked)} إلى ${format12(endPicked)}'),
            const SizedBox(height: 12),
            Text('السعر القديم: ${fmt.format(oldPrice)} ر.ي'),
            Text('السعر الجديد: ${fmt.format(newPrice.round())} ر.ي'),
            if (refund > 0) ...[
              const SizedBox(height: 8),
              Text('سيتم استرجاع: ${fmt.format(refund.round())} ر.ي',
                style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد النقل')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await ref.read(adminRepositoryProvider).rescheduleBooking(
      bookingId: bookingId,
      newStartAt: newStartAt,
      newEndAt: newEndAt,
    );
    if (!mounted) return;
    result.when(
      success: (data) {
        _load();
        final msg = data['message'] as String? ?? 'تم نقل الحجز بنجاح';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(e)))),
    );
  }

  Widget _buildInstancesWidget(List instances, String bookingId, ColorScheme scheme) {
    final active = instances.where((inst) =>
      inst['status'] != 'cancelled' && inst['status'] != 'completed'
    ).toList();
    if (active.isEmpty) return const SizedBox.shrink();
    final firstStart = DateTime.parse(active.first['start_at'] as String).toLocal();
    final firstEnd = DateTime.parse(active.first['end_at'] as String).toLocal();
    final timeStr = '${format12(firstStart.hour)} - ${format12(firstEnd.hour)}';
    if (active.length == 1) {
      return Text('الوقت: $timeStr', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('الوقت: $timeStr', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        ...active.map<Widget>((inst) {
          final dt = DateTime.parse(inst['start_at'] as String).toLocal();
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
        _load();
        final msg = data['message'] as String? ?? 'تم إلغاء الموعد';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(e)))),
    );
  }

  Future<void> _confirmBooking(BuildContext context, String bookingId, double totalPrice) async {
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
        _load();
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
