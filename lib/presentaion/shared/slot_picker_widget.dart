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

    // No start yet → set start
    if (_start == null) {
      _setStart(h24);
      return;
    }

    // Start set, but no end yet
    if (_end == null) {
      if (h24 == _start) {
        _clear();
      } else {
        _setEnd(h24);
      }
      return;
    }

    // Both start and end are set
    if (h24 == _start || h24 == _end) {
      // Tap start or end → clear all
      _clear();
    } else if (h24 < _start!) {
      _setStart(h24);
    } else if (h24 < _end!) {
      setState(() => _end = h24);
      widget.onChanged(SlotSelection(start: _start!, end: h24));
    } else {
      _setEnd(h24);
    }
  }

  void _clear() {
    setState(() {
      _start = null;
      _end = null;
    });
    widget.onChanged(const SlotSelection.clear());
  }

  void _setStart(int h24) {
    final autoEnd = (h24 + 1 >= widget.close24 || _isBooked(h24 + 1)) ? h24 + 1 : null;
    setState(() {
      _start = h24;
      _end = autoEnd;
    });
    widget.onChanged(SlotSelection(start: h24, end: autoEnd));
  }

  void _setEnd(int h24) {
    if (h24 <= _start!) {
      // Tap at or before start → ignore (shouldn't reach here due to _onTap logic)
      return;
    }
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
    if (widget.close24 > widget.open24) {
      for (var h = widget.open24; h < widget.close24; h++) {
        hours.add(h);
      }
    } else if (widget.close24 < widget.open24) {
      for (var h = widget.open24; h < 24; h++) {
        hours.add(h);
      }
      for (var h = 0; h < widget.close24; h++) {
        hours.add(h);
      }
    }

    String statusText;
    IconData statusIcon;
    Color statusColor;
    if (_start == null) {
      statusText = 'اختر وقت البداية';
      statusIcon = Icons.touch_app;
      statusColor = scheme.primary;
    } else if (_end == null) {
      statusText = 'اخترت ${_fmt(_start!)}، بإمكانك اختيار وقت النهاية (أو اتركها ساعة واحدة)';
      statusIcon = Icons.arrow_forward;
      statusColor = scheme.tertiary;
    } else if (_end! - _start! == 1 && (_start! + 1 >= widget.close24 || _isBooked(_start! + 1))) {
      statusText = 'تم اختيار الوقت (متاح ساعة واحدة فقط)';
      statusIcon = Icons.check_circle;
      statusColor = Colors.orange;
    } else {
      statusText = 'تم اختيار الوقت';
      statusIcon = Icons.check_circle;
      statusColor = Colors.green;
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
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: statusColor.withAlpha(60)),
          ),
          child: Row(
            children: [
              Icon(statusIcon, size: 18, color: statusColor),
              const SizedBox(width: 8),
              Expanded(child: Text(statusText, style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: statusColor,
              ))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _LegendChip(color: isDark ? Colors.green.shade900.withAlpha(120) : Colors.green.shade100, label: 'متاح'),
            const SizedBox(width: 12),
            _LegendChip(color: Colors.red.shade100, label: 'محجوز'),
            if (_start != null) ...[
              const SizedBox(width: 12),
              _LegendChip(color: scheme.primary, label: 'البداية'),
            ],
            if (_end != null) ...[
              const SizedBox(width: 12),
              _LegendChip(color: scheme.primaryContainer, label: 'النهاية'),
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
              final isStart = _start == h24;
              final isEnd = _end == h24;
              final inRange = _isInRange(h24);

              Color bg;
              Color fg;
              if (booked) {
                bg = scheme.surfaceContainerHighest;
                fg = scheme.onSurfaceVariant.withAlpha(100);
              } else if (isStart) {
                bg = scheme.primary;
                fg = scheme.onPrimary;
              } else if (isEnd) {
                bg = scheme.primaryContainer;
                fg = scheme.onPrimaryContainer;
              } else if (inRange) {
                bg = scheme.primaryContainer.withAlpha(120);
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
                        booked ? Icons.block : (isStart ? Icons.radio_button_checked : (inRange ? Icons.circle : Icons.radio_button_unchecked)),
                        size: 20,
                        color: booked ? fg : (isStart ? fg : Colors.green.shade400),
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
                      if (isStart)
                        Text('البداية', style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500)),
                      if (isEnd && !isStart)
                        Text('النهاية', style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500)),
                      if (inRange && !isStart && !isEnd)
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
        if (_start != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (_end != null ? scheme.primaryContainer : scheme.tertiaryContainer).withAlpha(180),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(_end != null ? Icons.check_circle : Icons.remove_red_eye, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(_fmt(_start!), style: TextStyle(
                            fontWeight: FontWeight.w700, color: scheme.onSurface, fontSize: 16,
                          )),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.arrow_forward, size: 18, color: scheme.primary),
                          ),
                          Text(_fmt(_end ?? _start! + 1), style: TextStyle(
                            fontWeight: FontWeight.w700, color: scheme.onSurface, fontSize: 16,
                          )),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${(_end ?? _start! + 1) - _start!} ساعات = ${(widget.pricePerHour * ((_end ?? _start! + 1) - _start!)).toStringAsFixed(0)} ر.ي',
                        style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                if (_end == null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text('ترشيح', style: TextStyle(fontSize: 11, color: scheme.primary, fontWeight: FontWeight.w500)),
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
  final int? start;
  final int? end;
  const SlotSelection({this.start, this.end});
  const SlotSelection.clear() : start = null, end = null;
}
