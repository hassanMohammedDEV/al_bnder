import 'package:flutter/material.dart';

String format12(int hour24) {
  final h = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
  final p = hour24 < 12 ? 'ص' : 'م';
  return '$h:00 $p';
}

String formatDateTime12(DateTime dt) {
  final local = dt.toLocal();
  final h = local.hour;
  final hour12 = h == 0 ? 12 : (h <= 12 ? h : h - 12);
  final period = h < 12 ? 'ص' : 'م';
  final dateStr = '${local.year}/${_p(local.month)}/${_p(local.day)}';
  return '$dateStr - $hour12:${_p(local.minute)} $period';
}

String _p(int n) => n.toString().padLeft(2, '0');

String dateLabel(DateTime d) {
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month && d.day == now.day) {
    return 'اليوم';
  }
  return '${d.year}/${_p(d.month)}/${_p(d.day)}';
}

String dayName(DateTime d) {
  const names = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
  return names[d.weekday - 1];
}

String dateLabelWithDay(DateTime d) {
  final now = DateTime.now();
  final dateStr = (d.year == now.year && d.month == now.month && d.day == now.day)
      ? 'اليوم'
      : '${d.year}/${_p(d.month)}/${_p(d.day)}';
  return '${dayName(d)} - $dateStr';
}

int _to24Hour(int h12, bool pm) {
  if (!pm) return h12 == 12 ? 0 : h12;
  return h12 == 12 ? 12 : h12 + 12;
}

bool isHourInRange(int h24, int open24, int close24) {
  if (close24 > open24) {
    return h24 >= open24 && h24 < close24;
  }
  return h24 >= open24 || h24 < close24;
}

class HourPickerDialog extends StatefulWidget {
  final int initialHour;
  final bool initialPm;
  final String title;
  final int open24;
  final int close24;

  const HourPickerDialog({
    super.key,
    required this.initialHour,
    required this.initialPm,
    required this.title,
    required this.open24,
    required this.close24,
  });

  @override
  State<HourPickerDialog> createState() => _HourPickerDialogState();
}

class _HourPickerDialogState extends State<HourPickerDialog> {
  late int selectedHour;
  late bool selectedPm;

  @override
  void initState() {
    super.initState();
    selectedHour = widget.initialHour;
    selectedPm = widget.initialPm;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(12, (i) {
              final h = i + 1;
              final valid = isHourInRange(
                _to24Hour(h, selectedPm),
                widget.open24,
                widget.close24,
              );
              return FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: h == selectedHour ? scheme.primary : null,
                  foregroundColor: h == selectedHour ? scheme.onPrimary : null,
                ),
                onPressed: valid ? () => setState(() => selectedHour = h) : null,
                child: Text(
                  '$h',
                  style: TextStyle(color: valid ? null : scheme.onSurfaceVariant.withAlpha(100)),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: !selectedPm ? scheme.primary : null,
                    foregroundColor: !selectedPm ? scheme.onPrimary : null,
                  ),
                  onPressed: () => setState(() => selectedPm = false),
                  child: const Text('ص'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: selectedPm ? scheme.primary : null,
                    foregroundColor: selectedPm ? scheme.onPrimary : null,
                  ),
                  onPressed: () => setState(() => selectedPm = true),
                  child: const Text('م'),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            final hour24 = _to24Hour(selectedHour, selectedPm);
            Navigator.of(context).pop(hour24);
          },
          child: const Text('اختيار'),
        ),
      ],
    );
  }
}
