import 'package:app_platform_core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../repositories/player_ad_repository_impl.dart';
import '../../providers/player_ad_provider.dart';
import '../../../admin/repositories/admin_repository_impl.dart';
import '../../../facilities/providers/facility_provider.dart';
import '../../../facilities/providers/selected_group_provider.dart';
import '../../../../presentaion/shared/time_picker_dialog.dart';

class CreatePlayerAdScreen extends ConsumerStatefulWidget {
  const CreatePlayerAdScreen({super.key});

  @override
  ConsumerState<CreatePlayerAdScreen> createState() => _CreatePlayerAdScreenState();
}

class _CreatePlayerAdScreenState extends ConsumerState<CreatePlayerAdScreen> {
  String _type = 'looking_team';
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _selectedFacilityId;
  String? _selectedFacilityName;
  DateTime? _pickedDate;
  int _playersNeeded = 1;
  String? _position;
  final _notesCtrl = TextEditingController();
  bool _isSubmitting = false;

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

    if (_type == 'nakusna' && _selectedFacilityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر الملعب')),
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

    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر وقت البداية والنهاية')),
      );
      return;
    }

    final startMin = _startTime!.hour * 60 + _startTime!.minute;
    final endMin = _endTime!.hour * 60 + _endTime!.minute;
    final durationHours = (endMin - startMin) / 60.0;

    if (durationHours <= 0) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('المدة لا تتجاوز ${maxHours.toInt()} ساعات')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final banResult = await ref.read(playerAdRepositoryProvider).checkBanned(groupId);
    if (!mounted) return;
    if (banResult is Success && (banResult as Success).data == true) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حظرك من نشر الإعلانات')),
      );
      return;
    }

    final dayNames = ['', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final day = dayNames[_pickedDate!.weekday];
    final dateStr = '${_pickedDate!.year}-${_pickedDate!.month.toString().padLeft(2, '0')}-${_pickedDate!.day.toString().padLeft(2, '0')}';

    final data = <String, dynamic>{
      'p_facility_group_id': groupId,
      'p_type': _type,
      'p_days': _type == 'looking_team' ? [day] : <String>[],
      'p_start_time': _timeToString(_startTime!),
      'p_end_time': _timeToString(_endTime!),
      'p_facility_id': _selectedFacilityId,
      'p_facility_name': _selectedFacilityName,
      'p_date': dateStr,
      if (_type == 'nakusna') 'p_players_needed': _playersNeeded,
      if (_type == 'looking_team') 'p_position': _position,
      if (_notesCtrl.text.trim().isNotEmpty) 'p_notes': _notesCtrl.text.trim(),
    };

    final result = await ref.read(playerAdActionProvider.notifier).createAd(data);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم نشر الإعلان')),
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
      appBar: AppBar(title: const Text('إعلان جديد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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

              // Position
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

              // Players needed
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
                  initialValue: _selectedFacilityId,
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
            Text('ملاحظات (اختياري)', style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              maxLength: 160,
              decoration: InputDecoration(
                hintText: 'أي معلومات إضافية...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),

            // Submit
            FilledButton(
              onPressed: isLoading ? null : _submit,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('نشر الإعلان', style: TextStyle(fontSize: 16)),
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
