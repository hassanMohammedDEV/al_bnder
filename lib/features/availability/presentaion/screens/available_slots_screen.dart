import 'package:app_platform_core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../facilities/providers/selected_group_provider.dart';
import '../../../facilities/providers/facility_provider.dart';
import '../../models/group_availability.dart';
import '../../repositories/availability_repository_impl.dart';

class AvailableSlotsScreen extends ConsumerStatefulWidget {
  final bool inShell;
  const AvailableSlotsScreen({super.key, this.inShell = false});

  @override
  ConsumerState<AvailableSlotsScreen> createState() => _AvailableSlotsScreenState();
}

class _AvailableSlotsScreenState extends ConsumerState<AvailableSlotsScreen> {
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 3));
  final List<_DayResult> _results = [];
  bool _loading = false;
  String? _error;
  int _loadingDay = 0;
  int _totalDays = 0;

  Future<void> _fetch() async {
    final groupId = ref.read(selectedGroupProvider);
    if (groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر مجموعة ملاعب أولاً')),
      );
      return;
    }

    final days = _endDate.difference(_startDate).inDays + 1;
    if (days > 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يمكن اختيار 7 أيام كحد أقصى')),
      );
      return;
    }

    setState(() { _loading = true; _error = null; _results.clear(); _totalDays = days; _loadingDay = 0; });

    final repo = ref.read(availabilityRepositoryProvider);

    for (int i = 0; i < days; i++) {
      final date = _startDate.add(Duration(days: i));
      if (!mounted) return;
      setState(() => _loadingDay = i + 1);

      final result = await repo.getAvailableSlots(
        facilityGroupId: groupId,
        date: DateFormat('yyyy-MM-dd').format(date),
      );

      if (!mounted) return;
      result.when(
        success: (data) => _results.add(_DayResult(date: date, data: data)),
        failure: (e) {
          if (mounted) setState(() => _error = e is NetworkError ? e.message : 'فشل تحميل يوم ${DateFormat('d/M', 'ar').format(date)}');
        },
      );
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      helpText: 'اختر نطاق التاريخ',
      confirmText: 'اختيار',
      cancelText: 'إلغاء',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _results.clear();
        _error = null;
      });
    }
  }

  List<_FreeSlot> _computeFreeSlots(String open, String close, List<BookedSlot> booked) {
    final openParts = open.split(':');
    final closeParts = close.split(':');
    final openMin = int.parse(openParts[0]) * 60 + int.parse(openParts[1]);
    int closeMin = int.parse(closeParts[0]) * 60 + int.parse(closeParts[1]);
    if (closeMin <= openMin) closeMin += 24 * 60;

    final slots = <_FreeSlot>[];
    final sorted = List<BookedSlot>.from(booked)
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

    int cursor = openMin;
    for (final b in sorted) {
      final start = DateTime.parse(b.startAt).toLocal();
      final end = DateTime.parse(b.endAt).toLocal();
      final startMin = start.hour * 60 + start.minute;
      final endMin = end.hour * 60 + end.minute;

      if (startMin > cursor) {
        slots.add(_FreeSlot(cursor, startMin));
      }
      cursor = endMin > cursor ? endMin : cursor;
    }

    if (cursor < closeMin) {
      slots.add(_FreeSlot(cursor, closeMin));
    }

    return slots;
  }

  String _buildShareText() {
    if (_results.isEmpty) return '';
    final buf = StringBuffer();
    buf.writeln('🏟️ ${_results.first.data.groupName}');
    buf.writeln('');

    for (final day in _results) {
      final dateStr = DateFormat('EEEE d MMMM y', 'ar').format(day.date);
      buf.writeln('📅 $dateStr');
      buf.writeln('');

      for (final f in day.data.facilities) {
        final freeSlots = _computeFreeSlots(
          day.data.openingTime ?? '00:00',
          day.data.closingTime ?? '00:00',
          f.bookedSlots,
        );

        buf.writeln('${f.name} (${f.pricePerHour.toInt()} ر.ي/ساعة):');
        if (freeSlots.isEmpty) {
          buf.writeln('❌ لا توجد أوقات متاحة');
        } else {
          for (final s in freeSlots) {
            final startStr = _to12h(s.start);
            final endStr = _to12h(s.end);
            buf.writeln('🟢 $startStr - $endStr');
          }
        }
        buf.writeln('');
      }
    }

    buf.writeln('---');
    buf.writeln('تطبيق البندر لحجز الملاعب');
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groupsState = ref.watch(facilityGroupsProvider);
    final groups = groupsState.data ?? [];
    final selectedId = ref.watch(selectedGroupProvider);

    Widget content = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Group chips
        if (groups.isNotEmpty) ...[
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final g = groups[i];
                return FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!g.isActive) ...[
                        const Icon(Icons.lock, size: 14),
                        const SizedBox(width: 4),
                      ],
                      Text(g.name, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                  selected: g.id == selectedId && g.isActive,
                  onSelected: g.isActive
                      ? (_) => ref.read(selectedGroupProvider.notifier).select(g.id)
                      : (_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ستتوفر قريباً')),
                          );
                        },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Date range card
        Card(
          child: ListTile(
            leading: Icon(Icons.date_range, color: scheme.primary),
            title: Text(
              '${DateFormat('d MMM', 'ar').format(_startDate)} - ${DateFormat('d MMM y', 'ar').format(_endDate)}',
              style: const TextStyle(fontSize: 15),
            ),
            subtitle: Text('${_endDate.difference(_startDate).inDays + 1} أيام',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            trailing: const Icon(Icons.edit_calendar),
            onTap: _pickDateRange,
          ),
        ),
        const SizedBox(height: 12),
        // Fetch button
        FilledButton.icon(
          onPressed: _loading ? null : _fetch,
          icon: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.search),
          label: Text(_loading ? 'جار البحث... ($_loadingDay/$_totalDays)' : 'عرض الأوقات المتاحة'),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
        const SizedBox(height: 16),
        // Error
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: scheme.error, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: TextStyle(color: scheme.error))),
              ],
            ),
          ),
        // Results per day
        for (int i = 0; i < _results.length; i++) ...[
          const Divider(height: 8),
          Text(
            '${DateFormat('EEEE d MMMM y', 'ar').format(_results[i].date)} | ${_results[i].data.groupName}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: scheme.primary),
          ),
          if (_results[i].data.openingTime != null)
            Text(
              'ساعات العمل: ${_formatTimeOnly(_results[i].data.openingTime!)} - ${_formatTimeOnly(_results[i].data.closingTime ?? '')}',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          const SizedBox(height: 12),
          ..._results[i].data.facilities.map((f) => _FacilitySlotsCard(
            facility: f,
            open: _results[i].data.openingTime ?? '00:00',
            close: _results[i].data.closingTime ?? '00:00',
            scheme: scheme,
          )),
          const SizedBox(height: 12),
        ],
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 8),
          // Share buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _buildShareText()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نسخ النص')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('نسخ'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    final text = _buildShareText();
                    final encoded = Uri.encodeFull(text);
                    final url = Uri.parse('https://api.whatsapp.com/send?text=$encoded');
                    try {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.chat, color: Colors.white),
                  label: const Text('واتساب'),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    if (widget.inShell) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('الأوقات المتاحة')),
      body: content,
    );
  }

  String _formatTimeOnly(String timeStr) {
    if (timeStr.length < 5) return timeStr;
    final parts = timeStr.substring(0, 5).split(':');
    final h = int.parse(parts[0]);
    final m = parts[1];
    final period = h >= 12 ? 'م' : 'ص';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour12:$m $period';
  }

  String _to12h(int minutesSinceMidnight) {
    final h = minutesSinceMidnight ~/ 60;
    final m = (minutesSinceMidnight % 60).toString().padLeft(2, '0');
    final period = h >= 12 ? 'م' : 'ص';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour12:$m $period';
  }
}

class _DayResult {
  final DateTime date;
  final GroupAvailability data;
  const _DayResult({required this.date, required this.data});
}

class _FreeSlot {
  final int start;
  final int end;
  const _FreeSlot(this.start, this.end);
}

class _FacilitySlotsCard extends StatelessWidget {
  final FacilityAvailability facility;
  final String open;
  final String close;
  final ColorScheme scheme;

  const _FacilitySlotsCard({
    required this.facility,
    required this.open,
    required this.close,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sports_soccer, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(facility.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${facility.pricePerHour.toInt()} ر.ي/ساعة',
                  style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 12),
            if (facility.bookedSlots.isEmpty)
              _TimeBar(label: 'الملعب متاح طوال اليوم', color: Colors.green, scheme: scheme)
            else
              for (final b in facility.bookedSlots)
                _TimeBar(
                  label: '${_formatSlotTime(b.startAt)} - ${_formatSlotTime(b.endAt)} (${_statusLabel(b.status)})',
                  color: Colors.red.shade300,
                  scheme: scheme,
                ),
          ],
        ),
      ),
    );
  }

  String _formatSlotTime(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'م' : 'ص';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour12:$m $period';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'confirmed': return 'مؤكد';
      case 'pending': return 'معلق';
      case 'pending_approval': return 'شبه مؤكد';
      default: return status;
    }
  }
}

class _TimeBar extends StatelessWidget {
  final String label;
  final Color color;
  final ColorScheme scheme;

  const _TimeBar({required this.label, required this.color, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 8, height: 8, margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: scheme.onSurface))),
        ],
      ),
    );
  }
}
