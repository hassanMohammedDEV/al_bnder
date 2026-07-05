import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../presentaion/shared/time_picker_dialog.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../repositories/admin_repository_impl.dart';
import '../../../../core/helpers/error_helper.dart';

class AdminSearchBookingsScreen extends ConsumerStatefulWidget {
  const AdminSearchBookingsScreen({super.key});

  @override
  ConsumerState<AdminSearchBookingsScreen> createState() => _AdminSearchBookingsScreenState();
}

class _AdminSearchBookingsScreenState extends ConsumerState<AdminSearchBookingsScreen> {
  var _tabIndex = 0;

  // Phone search
  final _searchCtl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  var _loading = false;

  // Date range search
  final _startCtl = TextEditingController();
  final _endCtl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  String _normalizeDigits(String s) {
    return s
        .replaceAll('٠', '0').replaceAll('١', '1').replaceAll('٢', '2').replaceAll('٣', '3').replaceAll('٤', '4')
        .replaceAll('٥', '5').replaceAll('٦', '6').replaceAll('٧', '7').replaceAll('٨', '8').replaceAll('٩', '9')
        .replaceAll('۰', '0').replaceAll('۱', '1').replaceAll('۲', '2').replaceAll('۳', '3').replaceAll('۴', '4')
        .replaceAll('۵', '5').replaceAll('۶', '6').replaceAll('۷', '7').replaceAll('۸', '8').replaceAll('۹', '9');
  }

  Future<void> _searchByPhone() async {
    FocusScope.of(context).unfocus();
    final query = _normalizeDigits(_searchCtl.text.trim());
    if (query.isEmpty) return;
    setState(() => _loading = true);
    final groupId = ref.read(authStateProvider).facilityGroupId;
    final result = await ref.read(adminRepositoryProvider).searchBookingsByPhone(
      query,
      facilityGroupId: groupId,
    );
    if (!mounted) return;
    result.when(
      success: (data) => setState(() { _results = data; _loading = false; }),
      failure: (e) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(e))));
      },
    );
  }

  Future<void> _searchByDateRange() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى اختيار تاريخ البداية والنهاية')));
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تاريخ النهاية يجب أن يكون بعد تاريخ البداية')));
      return;
    }
    setState(() => _loading = true);
    final groupId = ref.read(authStateProvider).facilityGroupId;
    final result = await ref.read(adminRepositoryProvider).searchBookingsByDateRange(
      facilityGroupId: groupId,
      startDate: _startDate!,
      endDate: _endDate!,
    );
    if (!mounted) return;
    result.when(
      success: (data) => setState(() { _results = data; _loading = false; }),
      failure: (e) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(e))));
      },
    );
  }

  Future<void> _search() async {
    if (_tabIndex == 0) {
      await _searchByPhone();
    } else {
      await _searchByDateRange();
    }
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _startCtl.dispose();
    _endCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('بحث')),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() { _tabIndex = 0; _results = []; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _tabIndex == 0 ? scheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('بحث بالجوال', textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _tabIndex == 0 ? scheme.onPrimary : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        )),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() { _tabIndex = 1; _results = []; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _tabIndex == 1 ? scheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('بحث بتاريخ', textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _tabIndex == 1 ? scheme.onPrimary : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        )),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_tabIndex == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtl,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.search,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: 'أدخل رقم الجوال',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _searchByPhone,
                        ),
                ),
                onSubmitted: (_) => _searchByPhone(),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: _startDate != null ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _startCtl.text.isEmpty ? 'من' : _startCtl.text,
                          style: TextStyle(color: _startCtl.text.isEmpty ? Theme.of(context).colorScheme.onSurfaceVariant : null),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: _endDate != null ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _endCtl.text.isEmpty ? 'إلى' : _endCtl.text,
                          style: TextStyle(color: _endCtl.text.isEmpty ? Theme.of(context).colorScheme.onSurfaceVariant : null),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _loading ? null : _searchByDateRange,
                    icon: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.search),
                  ),
                ],
              ),
            ),
          if (_results.isEmpty && !_loading)
            Expanded(
              child: Center(child: Text(
                _tabIndex == 0 ? 'ابحث برقم الجوال لعرض الحجوزات' : 'اختر تاريخين للبحث',
                style: TextStyle(color: scheme.onSurfaceVariant),
              )),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _search,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _results.length,
                  itemBuilder: (_, i) => _buildCard(_results[i], scheme),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickDate(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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
        _startCtl.text = dateLabelWithDay(date);
      } else {
        _endDate = date;
        _endCtl.text = dateLabelWithDay(date);
      }
    });
  }

  List<Widget> _buildSearchInstances(List instances, String bookingId, ColorScheme scheme) {
    final active = instances.where((inst) =>
      inst['status'] != 'cancelled' && inst['status'] != 'completed'
    ).toList();
    if (active.isEmpty) return [];
    final firstStart = DateTime.parse(active.first['start_at'] as String).toLocal();
    final firstEnd = DateTime.parse(active.first['end_at'] as String).toLocal();
    final timeStr = '${format12(firstStart.hour)} → ${format12(firstEnd.hour)}';
    if (active.length == 1) {
      return [Text(timeStr, style: TextStyle(fontSize: 13, color: scheme.primary))];
    }
    return [
      Text(timeStr, style: TextStyle(fontSize: 13, color: scheme.primary)),
      const SizedBox(height: 4),
      ...active.map((inst) {
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
    ];
  }

  Widget _buildCard(Map<String, dynamic> b, ColorScheme scheme) {
    final id = b['id'] as String;
    final name = b['user_name'] as String? ?? '';
    final phone = b['user_phone'] as String? ?? '';
    final facilityName = b['facility_name'] as String? ?? '';
    final price = (b['total_price'] as num?)?.toDouble() ?? 0;
    final paidAmount = (b['paid_amount'] as num?)?.toDouble() ?? 0;
    final status = b['status'] as String? ?? '';
    final instances = (b['instances'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final isRecurring = instances.length > 1;

    String statusLabel;
    Color statusColor;
    switch (status) {
      case 'confirmed':
        statusLabel = 'مؤكد';
        statusColor = Colors.green;
      case 'pending':
        statusLabel = 'معلق';
        statusColor = Colors.orange;
      case 'pending_approval':
        statusLabel = 'شبه مؤكد';
        statusColor = Colors.blue;
      case 'cancelled':
        statusLabel = 'ملغي';
        statusColor = scheme.error;
      default:
        statusLabel = status;
        statusColor = scheme.onSurfaceVariant;
    }

    final bookingDate = instances.isNotEmpty
        ? DateTime.parse(instances.first['start_at'] as String).toLocal()
        : null;
    final canCancel = status != 'cancelled' && (bookingDate == null || DateTime.now().isBefore(bookingDate));

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      Text(phone, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(statusLabel, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            const Divider(height: 16),
            Text(facilityName, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
            if (bookingDate != null) ...[
              const SizedBox(height: 2),
              Text(dateLabelWithDay(bookingDate),
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 4),
            ..._buildSearchInstances(instances, id, scheme),
            const SizedBox(height: 4),
            Text('$price ر.ي', style: const TextStyle(fontWeight: FontWeight.w600)),
            if (paidAmount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Icon(Icons.receipt, size: 14,
                      color: paidAmount >= price ? Colors.green : scheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      paidAmount >= price ? 'مدفوع بالكامل' : 'عربون: ${paidAmount.toStringAsFixed(0)} ر.ي',
                      style: TextStyle(fontSize: 12,
                        color: paidAmount >= price ? Colors.green : scheme.primary,
                        fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            if (canCancel && !isRecurring) ...[
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
            if (canCancel && isRecurring) ...[
              const SizedBox(height: 8),
              ...instances
                  .where((inst) => inst['status'] != 'cancelled' && inst['status'] != 'completed')
                  .map((inst) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: Text('إلغاء: ${dateLabelWithDay(DateTime.parse(inst['start_at'] as String).toLocal())}'),
                        style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
                        onPressed: () => _cancelInstance(id, inst['id'] as String, DateTime.parse(inst['start_at'] as String).toLocal()),
                      ),
                    ),
                  )),
            ],
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
        _search();
        final msg = data['message'] as String? ?? 'تم إلغاء الحجز';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(e)))),
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
        _search();
        final msg = data['message'] as String? ?? 'تم إلغاء الموعد';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(e)))),
    );
  }
}
