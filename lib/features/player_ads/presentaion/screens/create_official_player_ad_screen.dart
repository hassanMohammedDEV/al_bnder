import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/player_ad_provider.dart';
import '../../../admin/repositories/admin_repository_impl.dart';
import '../../../facilities/providers/facility_provider.dart';
import '../../../facilities/providers/selected_group_provider.dart';
import '../../../../presentaion/shared/time_picker_dialog.dart';

class CreateOfficialPlayerAdScreen extends ConsumerStatefulWidget {
  const CreateOfficialPlayerAdScreen({super.key});

  @override
  ConsumerState<CreateOfficialPlayerAdScreen> createState() => _CreateOfficialPlayerAdScreenState();
}

class _CreateOfficialPlayerAdScreenState extends ConsumerState<CreateOfficialPlayerAdScreen> {
  String _type = 'nakusna';
  final Set<String> _selectedDays = {};
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _selectedFacilityId;
  String? _selectedFacilityName;
  DateTime? _pickedDate;
  int _playersNeeded = 1;
  String? _position;
  final _notesCtrl = TextEditingController();
  bool _isSubmitting = false;

  final _days = [
    ('saturday', 'سبت'),
    ('sunday', 'أحد'),
    ('monday', 'اثنين'),
    ('tuesday', 'ثلاثاء'),
    ('wednesday', 'أربعاء'),
    ('thursday', 'خميس'),
    ('friday', 'جمعة'),
  ];

  final _positions = ['حارس', 'دفاع', 'وسط', 'هجوم'];

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? (_startTime ?? const TimeOfDay(hour: 17, minute: 0)) : (_endTime ?? const TimeOfDay(hour: 22, minute: 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3)),
    );
    if (picked != null) {
      setState(() => _pickedDate = picked);
    }
  }

  String _dateLabel() {
    if (_pickedDate == null) return 'اختر التاريخ';
    return dateLabelWithDay(_pickedDate!);
  }

  String _timeToString(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final period = t.period == DayPeriod.am ? 'ص' : 'م';
    return '${hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _submit() async {
    final groupId = ref.read(selectedGroupProvider);

    if (groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر مجموعة ملاعب أولاً')),
      );
      return;
    }

    if (_notesCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب نص الإعلان الرسمي')),
      );
      return;
    }

    if (_pickedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر التاريخ')),
      );
      return;
    }

    if (_type == 'nakusna' && _playersNeeded < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب أن يكون عدد اللاعبين الناقصين 1 على الأقل')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    if (_startTime != null && _endTime != null) {
      final startMin = _startTime!.hour * 60 + _startTime!.minute;
      final endMin = _endTime!.hour * 60 + _endTime!.minute;
      final durationHours = (endMin - startMin) / 60.0;

      if (durationHours <= 0) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('وقت النهاية يجب أن يكون بعد وقت البداية')),
        );
        return;
      }

      double maxHours = 3.0;
      try {
        final result = await ref.read(adminRepositoryProvider).getGroupSettings(groupId);
        result.when(
          success: (data) {
            maxHours = (data['max_booking_hours'] as num?)?.toDouble() ?? 3.0;
          },
          failure: (_) {},
        );
      } catch (_) {}

      if (!mounted) return;
      if (durationHours > maxHours) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('المدة لا تتجاوز ${maxHours.toInt()} ساعات')),
        );
        return;
      }
    }

    if (!mounted) return;

    final dayNames = ['', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final day = dayNames[_pickedDate!.weekday];
    final dateStr = '${_pickedDate!.year}-${_pickedDate!.month.toString().padLeft(2, '0')}-${_pickedDate!.day.toString().padLeft(2, '0')}';

    final data = <String, dynamic>{
      'p_facility_group_id': groupId,
      'p_type': _type,
      'p_days': [day],
      'p_start_time': _startTime != null ? _timeToString(_startTime!) : null,
      'p_end_time': _endTime != null ? _timeToString(_endTime!) : null,
      'p_facility_id': _selectedFacilityId,
      'p_facility_name': _selectedFacilityName,
      'p_date': dateStr,
      'p_players_needed': _playersNeeded,
      'p_position': _position,
      'p_notes': _notesCtrl.text.trim(),
    };

    final result = await ref.read(playerAdActionProvider.notifier).createOfficialAd(data);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم نشر الإعلان الرسمي')),
        );
        context.pop();
      },
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is Exception ? e.toString() : 'فشل النشر')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groupId = ref.watch(selectedGroupProvider);
    final facilitiesAsync = groupId != null ? ref.watch(facilitiesProvider(groupId)) : null;
    final action = ref.watch(playerAdActionProvider);
    final isLoading = _isSubmitting || action.isLoading('create');

    return Scaffold(
      appBar: AppBar(title: const Text('إعلان رسمي من الإدارة')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'هذا الإعلان سيظهر كإعلان رسمي من إدارة الملعب مع أيقونة توثيق',
                      style: TextStyle(fontSize: 13, color: Colors.green.shade800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Type toggle
            Row(
              children: [
                Expanded(
                  child: _TypeOption(
                    label: 'أبحث عن فريق',
                    icon: Icons.person_search,
                    selected: _type == 'looking_team',
                    onTap: () => setState(() => _type = 'looking_team'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TypeOption(
                    label: 'ناقصنا لاعبين',
                    icon: Icons.group_add,
                    selected: _type == 'nakusna',
                    onTap: () => setState(() => _type = 'nakusna'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_type == 'looking_team') ...[
              Text('الأيام المناسبة', style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _days.map((d) => FilterChip(
                  label: Text(d.$2, style: const TextStyle(fontSize: 13)),
                  selected: _selectedDays.contains(d.$1),
                  onSelected: (v) {
                    setState(() {
                      if (v) { _selectedDays.add(d.$1); } else { _selectedDays.remove(d.$1); }
                    });
                  },
                )).toList(),
              ),
              const SizedBox(height: 20),

              // Date picker
              Text('تاريخ اللعب', style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Text(_dateLabel(), style: TextStyle(color: _pickedDate != null ? scheme.onSurface : scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text('المركز (اختياري)', style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: _positions.map((p) => ChoiceChip(
                  label: Text(p, style: const TextStyle(fontSize: 13)),
                  selected: _position == p,
                  onSelected: (v) => setState(() => _position = v ? p : null),
                )).toList(),
              ),
              const SizedBox(height: 20),
            ] else ...[
              Text('تاريخ اللعب', style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Text(_dateLabel(), style: TextStyle(color: _pickedDate != null ? scheme.onSurface : scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text('عدد اللاعبين الناقصين', style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface)),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: _playersNeeded > 1
                        ? () => setState(() => _playersNeeded = _playersNeeded - 1)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('$_playersNeeded', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  IconButton(
                    onPressed: _playersNeeded < 20
                        ? () => setState(() => _playersNeeded = _playersNeeded + 1)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // Time
            Text('الوقت', style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(isStart: true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _startTime != null ? _timeToString(_startTime!) : 'من',
                        style: TextStyle(color: _startTime != null ? scheme.onSurface : scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(isStart: false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _endTime != null ? _timeToString(_endTime!) : 'إلى',
                        style: TextStyle(color: _endTime != null ? scheme.onSurface : scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Facility picker
            Text('الملعب${_type == 'nakusna' ? '' : ' (اختياري)'}', style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface)),
            const SizedBox(height: 8),
            facilitiesAsync?.when(
              data: (facilities) {
                final active = facilities.where((f) => f.isActive).toList();
                return DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    hintText: 'اختر الملعب',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  items: active.map((f) => DropdownMenuItem(
                    value: f.id,
                    child: Text(f.name),
                  )).toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedFacilityId = v;
                      _selectedFacilityName = active.firstWhere((f) => f.id == v).name;
                    });
                  },
                );
              },
              loading: () => const SizedBox(height: 48, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              error: (_, _) => const SizedBox(height: 48, child: Center(child: Text('فشل تحميل الملاعب'))),
            ) ?? const SizedBox(height: 48, child: Center(child: Text('اختر مجموعة ملاعب أولاً'))),
            const SizedBox(height: 20),

            // Notes
            Text('نص الإعلان', style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              maxLength: 160,
              decoration: InputDecoration(
                hintText: 'اكتب الإعلان الرسمي...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),

            // Submit
            FilledButton.icon(
              onPressed: isLoading ? null : _submit,
              icon: isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.verified, size: 18),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              label: Text(isLoading ? 'جاري النشر...' : 'نشر الإعلان الرسمي', style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeOption({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: selected ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            )),
          ],
        ),
      ),
    );
  }
}
