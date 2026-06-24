import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../presentaion/shared/loading_dialog.dart';
import '../../providers/booking_provider.dart';

class CreateBookingScreen extends ConsumerStatefulWidget {
  final String facilityId;
  const CreateBookingScreen({super.key, required this.facilityId});

  @override
  ConsumerState<CreateBookingScreen> createState() => _CreateBookingScreenState();
}

class _CreateBookingScreenState extends ConsumerState<CreateBookingScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(bookingFormProvider.notifier).init(widget.facilityId);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      initialDate: ref.read(bookingFormProvider).selectedDate,
    );
    if (picked != null) {
      ref.read(bookingFormProvider.notifier).setDate(picked);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = ref.read(bookingFormProvider);
    final initial = isStart ? current.startTime : current.endTime;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      if (isStart) {
        ref.read(bookingFormProvider.notifier).setStartTime(picked);
      } else {
        ref.read(bookingFormProvider.notifier).setEndTime(picked);
      }
    }
  }

  Future<void> _submit() async {
    final form = ref.read(bookingFormProvider);
    if (form.hours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('وقت النهاية يجب أن يكون بعد وقت البداية')),
      );
      return;
    }

    showLoadingDialog(context, message: 'جاري تأكيد الحجز...');
    final result = await ref.read(bookingActionProvider.notifier).createBooking(form);
    if (!mounted) return;
    Navigator.of(context).pop();

    result.when(
      success: (data) {
        final message = data['message'] as String? ?? 'تم الحجز';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        context.go('/my-bookings');
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
    final form = ref.watch(bookingFormProvider);
    final action = ref.watch(bookingActionProvider);
    final dateFmt = DateFormat('yyyy/MM/dd');

    return Scaffold(
      appBar: AppBar(title: const Text('حجز ملعب')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Date
          _FieldCard(
            icon: Icons.calendar_today,
            label: 'التاريخ',
            value: dateFmt.format(form.selectedDate),
            onTap: _pickDate,
          ),
          const SizedBox(height: 16),
          // Start time
          _FieldCard(
            icon: Icons.schedule,
            label: 'من',
            value: form.startTime.format(context),
            onTap: () => _pickTime(isStart: true),
          ),
          const SizedBox(height: 16),
          // End time
          _FieldCard(
            icon: Icons.schedule,
            label: 'إلى',
            value: form.endTime.format(context),
            onTap: () => _pickTime(isStart: false),
          ),
          const SizedBox(height: 16),
          // Hours summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.access_time, color: scheme.primary),
                  const SizedBox(width: 12),
                  Text('عدد الساعات:', style: TextStyle(color: scheme.onSurfaceVariant)),
                  const Spacer(),
                  Text('${form.hours.toStringAsFixed(1)} ساعات',
                    style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Recurring toggle
          SwitchListTile(
            title: const Text('حجز متسلسل'),
            subtitle: const Text('تكرار الحجز أسبوعياً'),
            value: form.isRecurring,
            onChanged: (_) => ref.read(bookingFormProvider.notifier).toggleRecurring(),
          ),
          if (form.isRecurring) ...[
            const SizedBox(height: 16),
            Text('أيام التكرار', style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant,
            )),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: List.generate(7, (i) {
                final days = ['أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];
                final selected = form.recurringDays.contains(i);
                return FilterChip(
                  label: Text(days[i]),
                  selected: selected,
                  onSelected: (_) => ref.read(bookingFormProvider.notifier).toggleDay(i),
                );
              }),
            ),
            const SizedBox(height: 16),
            _FieldCard(
              icon: Icons.date_range,
              label: 'تاريخ الانتهاء',
              value: form.recurringEndDate != null
                  ? dateFmt.format(form.recurringEndDate!)
                  : 'اختر تاريخ',
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: form.selectedDate,
                  lastDate: form.selectedDate.add(const Duration(days: 365)),
                );
                if (picked != null) {
                  ref.read(bookingFormProvider.notifier).setRecurringEnd(picked);
                }
              },
            ),
          ],
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
              Icon(Icons.chevron_left, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
