import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../presentaion/shared/loading_dialog.dart';
import '../../../../presentaion/shared/time_picker_dialog.dart';
import '../../../../presentaion/shared/slot_picker_widget.dart';
import '../../../../features/facilities/models/facility.dart';
import '../../../../features/facilities/repositories/facility_repository_impl.dart';
import '../../../../features/admin/models/group_settings.dart';
import '../../../../features/admin/repositories/admin_repository_impl.dart';
import '../../providers/booking_provider.dart';
import '../../../wallet/providers/wallet_provider.dart';
import '../../../../core/helpers/error_helper.dart';

class CreateBookingScreen extends ConsumerStatefulWidget {
  final Facility facility;
  const CreateBookingScreen({super.key, required this.facility});

  @override
  ConsumerState<CreateBookingScreen> createState() => _CreateBookingScreenState();
}

class _CreateBookingScreenState extends ConsumerState<CreateBookingScreen> {
  int? _startMinute;
  int? _endMinute;
  List<BookedSlotInfo> _bookedSlots = [];
  int _openMinutes = 16 * 60;
  int _closeMinutes = 22 * 60;
  int _maxBookingMinutes = 3 * 60;
  int _fineFromMinutes = 16 * 60;
  int _fineToMinutes = 20 * 60;
  bool _loadingSlots = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final f = widget.facility;
      ref.read(bookingFormProvider.notifier).init(f.id, f.name, f.pricePerHour);
      _loadSlots();
    });
  }

  Future<void> _loadSlots() async {
    final form = ref.read(bookingFormProvider);
    debugPrint('_loadSlots groupId=${widget.facility.groupId} date=${form.selectedDate}');
    setState(() => _loadingSlots = true);

    try {
      final settingsResult = await ref.read(adminRepositoryProvider).getGroupSettings(widget.facility.groupId);
      settingsResult.when(
        success: (data) {
          final s = GroupSettings.fromJson(data);
          final openParts = s.openingTime.split(':');
          final openH = int.tryParse(openParts.isNotEmpty ? openParts[0] : '16') ?? 16;
          final openM = int.tryParse(openParts.length > 1 ? openParts[1] : '0') ?? 0;
          final dayIndex = form.selectedDate.weekday;
          final closeKey = [
            'closing_time_sun', 'closing_time_mon', 'closing_time_tue',
            'closing_time_wed', 'closing_time_thu', 'closing_time_fri', 'closing_time_sat',
          ][dayIndex == 7 ? 0 : dayIndex];
          final closeStr = data[closeKey] as String? ?? s.closingTimeSun;
          final closeParts = closeStr.split(':');
          final closeH = int.tryParse(closeParts.isNotEmpty ? closeParts[0] : '22') ?? 22;
          final closeM = int.tryParse(closeParts.length > 1 ? closeParts[1] : '0') ?? 0;
          final fineFromParts = s.slotFineFrom.split(':');
          final fineFromH = int.tryParse(fineFromParts.isNotEmpty ? fineFromParts[0] : '16') ?? 16;
          final fineFromM = int.tryParse(fineFromParts.length > 1 ? fineFromParts[1] : '0') ?? 0;
          final fineToParts = s.slotFineTo.split(':');
          final fineToH = int.tryParse(fineToParts.isNotEmpty ? fineToParts[0] : '20') ?? 20;
          final fineToM = int.tryParse(fineToParts.length > 1 ? fineToParts[1] : '0') ?? 0;
          setState(() {
            _openMinutes = openH * 60 + openM;
            _closeMinutes = closeH * 60 + closeM;
            _maxBookingMinutes = (s.maxBookingHours * 60).round();
            _fineFromMinutes = fineFromH * 60 + fineFromM;
            _fineToMinutes = fineToH * 60 + fineToM;
          });
        },
        failure: (_) {},
      );

      final slotsResult = await ref.read(facilityRepositoryProvider).getAvailableSlots(
        widget.facility.id, form.selectedDate,
      );
      slotsResult.when(
        success: (data) {
          final booked = (data['booked_slots'] as List?) ?? [];
          setState(() {
            _bookedSlots = booked.map((b) {
              final startStr = b['start_at'] as String? ?? '';
              final endStr = b['end_at'] as String? ?? '';
              final startDt = DateTime.tryParse(startStr)?.toLocal();
              final endDt = DateTime.tryParse(endStr)?.toLocal();
              if (startDt == null || endDt == null) return BookedSlotInfo(startMinute: 0, endMinute: 0);
              return BookedSlotInfo(startMinute: startDt.hour * 60 + startDt.minute, endMinute: endDt.hour * 60 + endDt.minute);
            }).toList();
            _startMinute = null;
            _endMinute = null;
          });
        },
        failure: (_) => setState(() => _bookedSlots = []),
      );
    } catch (_) {}

    debugPrint('_loadSlots done open=$_openMinutes close=$_closeMinutes max=$_maxBookingMinutes booked=${_bookedSlots.length}');
    if (mounted) setState(() => _loadingSlots = false);
  }

  Future<void> _pickDate() async {
    if (_loadingSlots) return;
    final form = ref.read(bookingFormProvider);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: form.selectedDate,
    );
    if (picked != null) {
      ref.read(bookingFormProvider.notifier).setDate(picked);
      _loadSlots();
    }
  }

  int _effectiveMinutes(int start, int end) =>
      end <= start ? end + 1440 - start : end - start;

  Future<void> _submit() async {
    if (_startMinute == null || _endMinute == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر وقت البداية والمدة')),
      );
      return;
    }
    final effMin = _effectiveMinutes(_startMinute!, _endMinute!);
    if (effMin < 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مدة الحجز لا تقل عن ساعة')),
      );
      return;
    }

    final crossesMidnight = _closeMinutes < _openMinutes;

    DateTime _dt(int min, DateTime date) {
      var d = DateTime(date.year, date.month, date.day, min ~/ 60, min % 60);
      if (crossesMidnight && min < _openMinutes) d = d.add(const Duration(days: 1));
      return d;
    }

    final form = ref.read(bookingFormProvider);
    final start = _dt(_startMinute!, form.selectedDate);
    final end = _dt(_endMinute!, form.selectedDate);

    double balance = 0;
    double depositAmount = 5000;
    try {
      final walletAsync = await ref.read(walletInfoFamilyProvider(widget.facility.groupId).future);
      balance = walletAsync.balance;
    } catch (_) {}

    try {
      final settingsResult = await ref.read(adminRepositoryProvider).getGroupSettings(widget.facility.groupId);
      settingsResult.when(
        success: (data) {
          final settings = GroupSettings.fromJson(data);
          depositAmount = settings.depositAmount;
        },
        failure: (_) {},
      );
    } catch (_) {}

    final totalMinutes = effMin;
    final totalPrice = (totalMinutes / 60) * form.pricePerHour;

    if (balance >= totalPrice) {
      final scheme = Theme.of(context).colorScheme;
      final choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('طريقة الدفع'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('رصيد المحفظة: ${balance.toStringAsFixed(0)} ر.ي'),
              Text('المبلغ الإجمالي: ${totalPrice.toStringAsFixed(0)} ر.ي'),
              Text('قيمة العربون: ${depositAmount.toStringAsFixed(0)} ر.ي'),
              const SizedBox(height: 16),
              const Text('اختر طريقة الدفع:'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('deposit'),
              child: Text('عربون (${depositAmount.toStringAsFixed(0)} ر.ي)',
                style: TextStyle(color: scheme.primary)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop('full'),
              child: Text('دفع كامل (${totalPrice.toStringAsFixed(0)} ر.ي)'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      );
      if (choice == null) return;
      await _doSubmit(start, end, choice);
    } else if (balance >= depositAmount) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تأكيد دفع العربون'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الرصيد الحالي: ${balance.toStringAsFixed(0)} ر.ي'),
              Text('سعر الحجز: ${totalPrice.toStringAsFixed(0)} ر.ي'),
              Text('العربون: ${depositAmount.toStringAsFixed(0)} ر.ي'),
              const SizedBox(height: 12),
              const Text('سيتم خصم العربون فقط وتأكيد الحجز.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await _doSubmit(start, end, 'deposit');
    } else {
      await _doSubmit(start, end, 'auto');
    }
  }

  Future<void> _doSubmit(DateTime start, DateTime end, String paymentType) async {
    showLoadingDialog(context, message: 'جاري تأكيد الحجز...');
    final result = await ref.read(bookingActionProvider.notifier).createBookingRaw(
      facilityId: widget.facility.id,
      startAt: start,
      endAt: end,
      paymentType: paymentType,
    );
    if (!mounted) return;
    Navigator.of(context).pop();

    result.when(
      success: (data) {
        final d = data['data'] as Map<String, dynamic>?;
        final status = d?['status'] as String? ?? 'pending';
        final totalPrice = (d?['total_price'] as num? ?? 0).toDouble();
        final paidAmount = (d?['paid_amount'] as num? ?? 0).toDouble();
        final balanceAfter = (d?['balance_after'] as num? ?? 0).toDouble();
        final facilityName = d?['facility_name'] as String? ?? '';
        ref.invalidate(walletInfoFamilyProvider(widget.facility.groupId));

        if (status == 'confirmed') {
          _showDoneDialog(Icons.check_circle, Colors.green, 'تم تأكيد الحجز', Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(facilityName, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text('المبلغ الإجمالي: ${totalPrice.toStringAsFixed(0)} ر.ي'),
              if (paidAmount < totalPrice)
                Text('المبلغ المخصوم (عربون): ${paidAmount.toStringAsFixed(0)} ر.ي')
              else
                Text('المبلغ المخصوم: ${paidAmount.toStringAsFixed(0)} ر.ي'),
              Text('الرصيد المتبقي: ${balanceAfter.toStringAsFixed(0)} ر.ي'),
            ],
          ));
        } else {
          _showDoneDialog(Icons.access_time, Colors.orange, 'الحجز معلق', Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$facilityName - ${totalPrice.toStringAsFixed(0)} ر.ي'),
              const SizedBox(height: 12),
              const Text('الحجز بانتظار التأكيد من إدارة الملعب.'),
              const SizedBox(height: 8),
              const Text('يرجى التواصل مع الإدارة عبر واتساب وإرسال سند الدفع', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ));
        }
      },
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateError(e))));
      },
    );
  }

  void _showDoneDialog(IconData icon, Color color, String title, Widget content) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(title),
        ]),
        content: content,
        actions: [
          TextButton(
            onPressed: () { Navigator.of(ctx).pop(); context.pop(); },
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final form = ref.watch(bookingFormProvider);
    final action = ref.watch(bookingActionProvider);

    return Scaffold(
      appBar: AppBar(title: Text(form.facilityName)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(form.facilityName, style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: scheme.onPrimaryContainer,
                  )),
                  const SizedBox(height: 8),
                  Text('${form.pricePerHour.toStringAsFixed(0)} ر.ي / ساعة', style: TextStyle(
                    color: scheme.onPrimaryContainer,
                  )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _FieldCard(
            icon: Icons.calendar_today,
            label: 'التاريخ',
            value: dateLabelWithDay(form.selectedDate),
            onTap: _pickDate,
          ),
          const SizedBox(height: 24),
          if (_loadingSlots)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SlotPickerWidget(
              openMinutes: _openMinutes,
              closeMinutes: _closeMinutes,
              bookedSlots: _bookedSlots,
              pricePerHour: form.pricePerHour,
              maxBookingMinutes: _maxBookingMinutes,
              fineFromMinutes: _fineFromMinutes,
              fineToMinutes: _fineToMinutes,
              onChanged: (sel) {
                setState(() {
                  _startMinute = sel.startMinute;
                  _endMinute = sel.endMinute;
                });
              },
            ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: action.isLoading('create') ? null : _submit,
            child: action.isLoading('create')
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('تأكيد الحجز', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _FieldCard({
    required this.icon,
    required this.label,
    required this.value,
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
              const Spacer(),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
