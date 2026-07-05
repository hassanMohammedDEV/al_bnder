import 'package:flutter/material.dart';

class BookedSlotInfo {
  final int startMinute;
  final int endMinute;
  BookedSlotInfo({required this.startMinute, required this.endMinute});
}

class SlotPickerWidget extends StatefulWidget {
  final int openMinutes;
  final int closeMinutes;
  final List<BookedSlotInfo> bookedSlots;
  final double pricePerHour;
  final int maxBookingMinutes;
  final int fineFromMinutes;
  final int fineToMinutes;
  final ValueChanged<SlotSelection> onChanged;

  const SlotPickerWidget({
    super.key,
    required this.openMinutes,
    required this.closeMinutes,
    required this.bookedSlots,
    required this.pricePerHour,
    required this.maxBookingMinutes,
    this.fineFromMinutes = 960,
    this.fineToMinutes = 1200,
    required this.onChanged,
  });

  @override
  State<SlotPickerWidget> createState() => _SlotPickerWidgetState();
}

class _SlotPickerWidgetState extends State<SlotPickerWidget> {
  int? _startAdj;
  int? _endAdj;

  int get _minMin => 60;
  int get _maxMin => widget.maxBookingMinutes;
  int get _adjClose =>
      widget.closeMinutes < widget.openMinutes
          ? widget.closeMinutes + 1440
          : widget.closeMinutes;
  bool get _crossMidnight => widget.closeMinutes < widget.openMinutes;

  int _toDisplay(int adj) => adj >= 1440 ? adj - 1440 : adj;

  int _toAdj(int display) =>
      _crossMidnight && display < widget.openMinutes
          ? display + 1440
          : display;

  bool get _hasInvertedFine => widget.fineFromMinutes > widget.fineToMinutes;

  int _stepAt(int adj) {
    if (_hasInvertedFine) return 30;
    final d = _toDisplay(adj);
    return d >= widget.fineFromMinutes && d < widget.fineToMinutes ? 30 : 60;
  }

  List<int> get _gridAdj {
    final g = <int>[];
    for (var m = widget.openMinutes; m <= _adjClose;) {
      g.add(m);
      m += _stepAt(m);
    }
    return g;
  }

  List<int> get _startSlots => _gridAdj.map(_toDisplay).toList();

  int? _nextBookingStartAdj(int startAdj) {
    int? nearest;
    for (final b in widget.bookedSlots) {
      final bStart = b.startMinute < widget.openMinutes
          ? b.startMinute + 1440
          : b.startMinute;
      if (bStart > startAdj) {
        if (nearest == null || bStart < nearest) {
          nearest = bStart;
        }
      }
    }
    return nearest;
  }

  List<int> _validEndsFor(int startAdj) {
    final ends = <int>[];
    final minEnd = startAdj + _minMin;
    final nextStart = _nextBookingStartAdj(startAdj);
    final maxEnd = (nextStart ?? _adjClose) > startAdj + _maxMin
        ? startAdj + _maxMin
        : (nextStart ?? _adjClose);
    for (final a in _gridAdj) {
      if (a <= startAdj) continue;
      if (a < minEnd) continue;
      if (a > maxEnd) break;
      if (!_isBookedRangeAdj(startAdj, a)) {
        ends.add(a);
      }
    }
    return ends;
  }

  List<int> _durationsFor(int startAdj) {
    return _validEndsFor(startAdj).map((e) => e - startAdj).toList();
  }

  bool _isBooked(int displayMinute) {
    for (final b in widget.bookedSlots) {
      if (b.endMinute < b.startMinute) {
        if (displayMinute >= b.startMinute || displayMinute < b.endMinute) return true;
      } else {
        if (displayMinute >= b.startMinute && displayMinute < b.endMinute) return true;
      }
    }
    return false;
  }

  bool _isBookedRangeAdj(int fromAdj, int toAdj) {
    for (final b in widget.bookedSlots) {
      final bStart = b.startMinute < widget.openMinutes
          ? b.startMinute + 1440
          : b.startMinute;
      final bRawEnd = b.endMinute < b.startMinute ? b.endMinute + 1440 : b.endMinute;
      final bEndAdj = bRawEnd < widget.openMinutes ? bRawEnd + 1440 : bRawEnd;
      if (bStart < toAdj && bEndAdj > fromAdj) return true;
    }
    return false;
  }

  String? _durationHint(int startAdj) {
    final nextStart = _nextBookingStartAdj(startAdj);
    if (nextStart != null && nextStart < startAdj + _minMin) {
      final gap = nextStart - startAdj;
      return 'لا يمكن الحجز - يوجد حجز بعدها بـ $gap دقيقة فقط';
    }
    final limitByBooking = nextStart != null && nextStart < startAdj + _maxMin && nextStart < _adjClose;
    if (limitByBooking) return 'يتوفر حتى ${_fmt(_toDisplay(nextStart))} - يوجد حجز';
    final limitByClosing = _adjClose < startAdj + _maxMin;
    if (limitByClosing) return 'آخر موعد متاح ${_fmt(_toDisplay(_adjClose))}';
    return null;
  }

  void _onStartTap(int displayMinute) {
    if (_isBooked(displayMinute)) return;
    final adj = _toAdj(displayMinute);
    setState(() {
      _startAdj = adj;
      _endAdj = null;
    });
    widget.onChanged(SlotSelection(
      startMinute: displayMinute,
      endMinute: null,
    ));
  }

  void _onDurationTap(int durationMinutes) {
    if (_startAdj == null) return;
    final adjEnd = _startAdj! + durationMinutes;
    if (adjEnd > _adjClose) return;
    setState(() => _endAdj = adjEnd);
    widget.onChanged(SlotSelection(
      startMinute: _toDisplay(_startAdj!),
      endMinute: _toDisplay(adjEnd),
    ));
  }

  void _clear() {
    setState(() {
      _startAdj = null;
      _endAdj = null;
    });
    widget.onChanged(const SlotSelection.clear());
  }

  String _fmt(int minute) {
    final h = minute ~/ 60;
    final m = minute % 60;
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final p = h < 12 ? 'ص' : 'م';
    return m == 0 ? '$h12:00 $p' : '$h12:$m $p';
  }

  String _fmtDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '$h ساعة';
    return '$h.5 ساعة';
  }

  double _calcPrice(int durationMinutes) {
    return widget.pricePerHour * durationMinutes / 60;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final startSlots = _startSlots;
    final durations = _startAdj != null ? _durationsFor(_startAdj!) : <int>[];

    String statusText;
    IconData statusIcon;
    Color statusColor;
    if (_startAdj == null) {
      statusText = 'اختر من الأوقات المتاحة بالأسفل';
      statusIcon = Icons.arrow_downward;
      statusColor = scheme.primary;
    } else if (_endAdj == null) {
      statusText = 'اخترت ${_fmt(_toDisplay(_startAdj!))}، اختر المدة';
      statusIcon = Icons.timer_outlined;
      statusColor = scheme.tertiary;
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
            const Spacer(),
            if (_startAdj != null)
              TextButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('إلغاء', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.error,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
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
            _LegendChip(
              color: isDark ? Colors.green.shade800.withAlpha(160) : Colors.green.shade200,
              label: 'متاح',
            ),
            const SizedBox(width: 12),
            _LegendChip(color: isDark ? Colors.red.shade300.withAlpha(80) : Colors.red.shade100, label: 'محجوز'),
          ],
        ),
        const SizedBox(height: 12),
        Text('أوقات البداية', style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant,
        )),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: startSlots.map((minute) {
            final adj = _toAdj(minute);
            final booked = _isBooked(minute);
            final isSelected = _startAdj == adj;
            final inFine = _toDisplay(adj) >= widget.fineFromMinutes &&
                _toDisplay(adj) < widget.fineToMinutes;

            return FilterChip(
              label: Text(
                _fmt(minute),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: booked
                      ? scheme.error
                      : isSelected
                          ? scheme.onPrimary
                          : scheme.onSurface,
                ),
              ),
              selected: isSelected,
              onSelected: booked ? null : (_) => _onStartTap(minute),
              selectedColor: scheme.primary,
              backgroundColor: booked
                  ? (isDark ? Colors.red.shade300.withAlpha(60) : Colors.red.shade100)
                  : (isDark
                      ? Colors.green.shade800.withAlpha(120)
                      : Colors.green.shade100),
              checkmarkColor: scheme.onPrimary,
              showCheckmark: isSelected,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: inFine && !booked && !isSelected
                      ? scheme.primary.withAlpha(60)
                      : Colors.transparent,
                ),
              ),
            );
          }).toList(),
        ),
        if (durations.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('اختر المدة', style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant,
          )),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: durations.map((dur) {
              final endAdj = _startAdj! + dur;
              final isSelected = _endAdj == endAdj;
              final price = _calcPrice(dur);
              return FilterChip(
                label: Text(
                  '${_fmtDuration(dur)}\n${price.toStringAsFixed(0)} ر.ي',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? scheme.onPrimary : scheme.onSurface,
                    height: 1.3,
                  ),
                ),
                selected: isSelected,
                onSelected: (_) => _onDurationTap(dur),
                selectedColor: scheme.primary,
                backgroundColor: scheme.surfaceContainerHighest,
                checkmarkColor: scheme.onPrimary,
                showCheckmark: isSelected,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }).toList(),
          ),
        ],
        if (_startAdj != null) ...[
          const SizedBox(height: 6),
          _DurationHint(hint: _durationHint(_startAdj!)),
        ],
        if (_startAdj != null && _endAdj != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withAlpha(180),
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
                      Row(
                        children: [
                          Text(_fmt(_toDisplay(_startAdj!)), style: TextStyle(
                            fontWeight: FontWeight.w700, color: scheme.onSurface, fontSize: 16,
                          )),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.arrow_forward, size: 18, color: scheme.primary),
                          ),
                          Text(_fmt(_toDisplay(_endAdj!)), style: TextStyle(
                            fontWeight: FontWeight.w700, color: scheme.onSurface, fontSize: 16,
                          )),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_fmtDuration(_endAdj! - _startAdj!)} = ${_calcPrice(_endAdj! - _startAdj!).toStringAsFixed(0)} ر.ي',
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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

class _DurationHint extends StatelessWidget {
  final String? hint;
  const _DurationHint({required this.hint});

  @override
  Widget build(BuildContext context) {
    if (hint == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.info_outline, size: 14, color: scheme.primary),
        const SizedBox(width: 6),
        Text(hint!, style: TextStyle(fontSize: 12, color: scheme.primary)),
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
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(
          fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant,
        )),
      ],
    );
  }
}

class SlotSelection {
  final int? startMinute;
  final int? endMinute;
  const SlotSelection({this.startMinute, this.endMinute});
  const SlotSelection.clear() : startMinute = null, endMinute = null;
}
