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
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  GroupAvailability? _result;
  bool _loading = false;
  String? _error;

  Future<void> _fetch() async {
    final groupId = ref.read(selectedGroupProvider);
    if (groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر مجموعة ملاعب أولاً')),
      );
      return;
    }

    setState(() { _loading = true; _error = null; _result = null; });

    final repo = ref.read(availabilityRepositoryProvider);
    final result = await repo.getAvailableSlots(
      facilityGroupId: groupId,
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
    );

    if (!mounted) return;
    result.when(
      success: (data) => setState(() { _result = data; _loading = false; }),
      failure: (e) => setState(() { _error = e is NetworkError ? e.message : 'فشل التحميل'; _loading = false; }),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  List<_FreeSlot> _computeFreeSlots(String open, String close, List<BookedSlot> booked) {
    final openParts = open.split(':');
    final closeParts = close.split(':');
    final openMin = int.parse(openParts[0]) * 60 + int.parse(openParts[1]);
    final closeMin = int.parse(closeParts[0]) * 60 + int.parse(closeParts[1]);

    final slots = <_FreeSlot>[];
    final sorted = List<BookedSlot>.from(booked)
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

    int cursor = openMin;
    for (final b in sorted) {
      final start = DateTime.parse(b.startAt);
      final end = DateTime.parse(b.endAt);
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
    if (_result == null) return '';
    final buf = StringBuffer();
    final dateStr = DateFormat('EEEE d MMMM y', 'ar').format(_selectedDate);
    buf.writeln('📅 $dateStr');
    buf.writeln('🏟️ ${_result!.groupName}');
    buf.writeln('');

    for (final f in _result!.facilities) {
      final freeSlots = _computeFreeSlots(
        _result!.openingTime ?? '00:00',
        _result!.closingTime ?? '00:00',
        f.bookedSlots,
      );

      buf.writeln('${f.name} (${f.pricePerHour.toInt()} ر.ي/ساعة):');
      if (freeSlots.isEmpty) {
        buf.writeln('❌ لا توجد أوقات متاحة');
      } else {
        for (final s in freeSlots) {
          final startStr = '${(s.start ~/ 60).toString().padLeft(2, '0')}:${(s.start % 60).toString().padLeft(2, '0')}';
          final endStr = '${(s.end ~/ 60).toString().padLeft(2, '0')}:${(s.end % 60).toString().padLeft(2, '0')}';
          buf.writeln('🟢 $startStr - $endStr');
        }
      }
      buf.writeln('');
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
                  label: Text(g.name, style: const TextStyle(fontSize: 13)),
                  selected: g.id == selectedId,
                  onSelected: (_) => ref.read(selectedGroupProvider.notifier).select(g.id),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Date picker card
        Card(
          child: ListTile(
            leading: Icon(Icons.calendar_today, color: scheme.primary),
            title: Text(DateFormat('EEEE d MMMM y', 'ar').format(_selectedDate)),
            trailing: const Icon(Icons.edit_calendar),
            onTap: _pickDate,
          ),
        ),
        const SizedBox(height: 12),
        // Fetch button
        FilledButton.icon(
          onPressed: _loading ? null : _fetch,
          icon: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.search),
          label: Text(_loading ? 'جار البحث...' : 'عرض الأوقات المتاحة'),
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
        // Results
        if (_result != null) ...[
          Text(
            '${_result!.groupName} | ${DateFormat('EEEE d MMMM y', 'ar').format(_selectedDate)}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: scheme.primary),
          ),
          if (_result!.openingTime != null)
            Text(
              'ساعات العمل: ${_formatTimeOnly(_result!.openingTime!)} - ${_formatTimeOnly(_result!.closingTime ?? '')}',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          const SizedBox(height: 12),
          ..._result!.facilities.map((f) => _FacilitySlotsCard(
            facility: f,
            open: _result!.openingTime ?? '00:00',
            close: _result!.closingTime ?? '00:00',
            scheme: scheme,
          )),
          const SizedBox(height: 16),
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
                    final url = Uri.parse('https://wa.me/?text=$encoded');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
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
    if (timeStr.length >= 5) return timeStr.substring(0, 5);
    return timeStr;
  }
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
    return DateFormat('HH:mm').format(DateTime.parse(iso));
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
