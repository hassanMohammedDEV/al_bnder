import 'package:flutter/material.dart';

class BookedSlotInfo {
  final int startHour;
  final int endHour;
  BookedSlotInfo({required this.startHour, required this.endHour});
}

class SlotPickerWidget extends StatefulWidget {
  final int open24;
  final int close24;
  final List<BookedSlotInfo> bookedSlots;
  final double pricePerHour;
  final ValueChanged<SlotSelection> onChanged;

  const SlotPickerWidget({
    super.key,
    required this.open24,
    required this.close24,
    required this.bookedSlots,
    required this.pricePerHour,
    required this.onChanged,
  });

  @override
  State<SlotPickerWidget> createState() => _SlotPickerWidgetState();
}

class _SlotPickerWidgetState extends State<SlotPickerWidget> {
  int? _start;
  int? _end;

  bool _isBooked(int h24) {
    for (final b in widget.bookedSlots) {
      if (h24 >= b.startHour && h24 < b.endHour) return true;
    }
    return false;
  }

  bool _isInRange(int h24) {
    if (_start == null || _end == null) return false;
    return h24 >= _start! && h24 < _end!;
  }

  void _onTap(int h24) {
    if (_isBooked(h24)) return;

    // First selection
    if (_start == null || (_end != null)) {
      setState(() {
        _start = h24;
        _end = null;
      });
      // Auto-select if only this hour is available (next is booked or closing)
      if (h24 + 1 >= widget.close24 || _isBooked(h24 + 1)) {
        setState(() => _end = h24 + 1);
        widget.onChanged(SlotSelection(start: h24, end: h24 + 1));
      } else {
        widget.onChanged(SlotSelection(start: h24, end: null));
      }
      return;
    }

    // Tap before or at start → reset
    if (h24 <= _start!) {
      setState(() {
        _start = h24;
        _end = null;
      });
      if (h24 + 1 >= widget.close24 || _isBooked(h24 + 1)) {
        setState(() => _end = h24 + 1);
        widget.onChanged(SlotSelection(start: h24, end: h24 + 1));
      } else {
        widget.onChanged(SlotSelection(start: h24, end: null));
      }
      return;
    }

    // Tap after start → find first booked hour in between
    int? blocked;
    for (var h = _start! + 1; h < h24; h++) {
      if (_isBooked(h)) {
        blocked = h;
        break;
      }
    }

    if (blocked != null) {
      setState(() => _end = blocked);
      widget.onChanged(SlotSelection(start: _start!, end: blocked));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يوجد حجز في الفترة المحددة، تم ضبط الوقت'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      setState(() => _end = h24);
      widget.onChanged(SlotSelection(start: _start!, end: h24));
    }
  }

  String _fmt(int h24) {
    final h = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24);
    final p = h24 < 12 ? 'ص' : 'م';
    return '$h:00 $p';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hours = <int>[];
    var h = widget.open24;
    while (true) {
      if (widget.close24 > widget.open24) {
        if (h >= widget.close24) break;
      } else {
        if (h >= widget.close24 && h < widget.open24) { h = widget.open24; continue; }
      }
      hours.add(h);
      h++;
      if (widget.close24 <= widget.open24 && h >= 24) h = 0;
      if (h == widget.open24) break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.access_time, size: 16, color: scheme.primary),
            const SizedBox(width: 6),
            Text('اختر وقت الحجز', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurface,
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _LegendChip(color: isDark ? Colors.green.shade900.withAlpha(120) : Colors.green.shade100, label: 'متاح'),
            const SizedBox(width: 12),
            _LegendChip(color: Colors.red.shade100, label: 'محجوز'),
            if (_start != null) ...[
              const SizedBox(width: 12),
              _LegendChip(color: scheme.primaryContainer, label: 'المحدد'),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: List.generate(hours.length, (i) {
              final h24 = hours[i];
              final booked = _isBooked(h24);
              final selected = _start == h24 || _end == h24;
              final inRange = _isInRange(h24);

              Color bg;
              Color fg;
              if (booked) {
                bg = scheme.surfaceContainerHighest;
                fg = scheme.onSurfaceVariant.withAlpha(100);
              } else if (selected) {
                bg = scheme.primary;
                fg = scheme.onPrimary;
              } else if (inRange) {
                bg = scheme.primaryContainer;
                fg = scheme.onPrimaryContainer;
              } else {
                bg = isDark ? Colors.green.shade900.withAlpha(100) : Colors.green.shade50;
                fg = isDark ? Colors.green.shade200 : scheme.onSurface;
              }

              return InkWell(
                onTap: booked ? null : () => _onTap(h24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: bg,
                    border: i < hours.length - 1
                        ? Border(bottom: BorderSide(color: scheme.outlineVariant.withAlpha(60)))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        booked ? Icons.block : (selected ? Icons.check_circle : Icons.circle_outlined),
                        size: 20,
                        color: booked ? fg : (selected ? fg : Colors.green.shade400),
                      ),
                      const SizedBox(width: 12),
                      Text(_fmt(h24), style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600, color: fg,
                      )),
                      const Spacer(),
                      if (booked)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.error.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('محجوز', style: TextStyle(
                            fontSize: 11, color: scheme.error, fontWeight: FontWeight.w500,
                          )),
                        ),
                      if (selected)
                        Icon(Icons.check, size: 18, color: fg),
                      if (inRange && !selected)
                        Container(
                          height: 8, width: 8,
                          decoration: BoxDecoration(
                            color: scheme.primary.withAlpha(80),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        if (_start != null && _end != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_fmt(_start!)} ← ${_fmt(_end!)}', style: TextStyle(
                        fontWeight: FontWeight.w600, color: scheme.onSurface,
                      )),
                      const SizedBox(height: 2),
                      Text('${_end! - _start!} ساعات = ${(widget.pricePerHour * (_end! - _start!)).toStringAsFixed(0)} ر.س',
                        style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(3),
        )),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class SlotSelection {
  final int start;
  final int? end;
  const SlotSelection({required this.start, this.end});
}
