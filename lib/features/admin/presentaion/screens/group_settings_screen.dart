import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../presentaion/shared/time_picker_dialog.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../facilities/providers/facility_provider.dart';
import '../../models/group_settings.dart';
import '../../providers/admin_provider.dart';
import '../../../../core/helpers/error_helper.dart';

class GroupSettingsScreen extends ConsumerStatefulWidget {
  const GroupSettingsScreen({super.key});

  @override
  ConsumerState<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  int? _openingHour;
  final _closingHours = <String, int>{};
  final _depositCtl = TextEditingController();
  final _expiryCtl = TextEditingController();
  final _maxBookingCtl = TextEditingController();
  int? _fineFromHour;
  int? _fineFromMinute;
  int? _fineToHour;
  int? _fineToMinute;

  String? _selectedGroupId;
  String? _error;
  bool _saving = false;
  bool _initialized = false;

  static const _dayKeys = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
  static const _dayLabels = {
    'sun': 'الأحد',
    'mon': 'الإثنين',
    'tue': 'الثلاثاء',
    'wed': 'الأربعاء',
    'thu': 'الخميس',
    'fri': 'الجمعة',
    'sat': 'السبت',
  };

  String _format12(int? hour24) {
    if (hour24 == null) return 'اختر';
    final h = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final p = hour24 < 12 ? 'ص' : 'م';
    return '$h:00 $p';
  }

  String _format12Fine(int? hour24, int? minute) {
    if (hour24 == null) return 'اختر';
    final h = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final p = hour24 < 12 ? 'ص' : 'م';
    final m = (minute ?? 0).toString().padLeft(2, '0');
    return '$h:$m $p';
  }

  @override
  void dispose() {
    _depositCtl.dispose();
    _expiryCtl.dispose();
    _maxBookingCtl.dispose();
    super.dispose();
  }

  void _initFromSettings(GroupSettings s) {
    final openParts = s.openingTime.split(':');
    _openingHour = int.tryParse(openParts.isNotEmpty ? openParts[0] : '0');
    final closeMap = {
      'sun': s.closingTimeSun, 'mon': s.closingTimeMon, 'tue': s.closingTimeTue,
      'wed': s.closingTimeWed, 'thu': s.closingTimeThu, 'fri': s.closingTimeFri,
      'sat': s.closingTimeSat,
    };
    for (final day in _dayKeys) {
      final parts = closeMap[day]!.split(':');
      _closingHours[day] = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
    }
    final fineFromParts = s.slotFineFrom.split(':');
    _fineFromHour = int.tryParse(fineFromParts.isNotEmpty ? fineFromParts[0] : '16') ?? 16;
    _fineFromMinute = int.tryParse(fineFromParts.length > 1 ? fineFromParts[1] : '0') ?? 0;
    final fineToParts = s.slotFineTo.split(':');
    _fineToHour = int.tryParse(fineToParts.isNotEmpty ? fineToParts[0] : '20') ?? 20;
    _fineToMinute = int.tryParse(fineToParts.length > 1 ? fineToParts[1] : '0') ?? 0;
    _depositCtl.text = s.depositAmount.toStringAsFixed(0);
    _expiryCtl.text = s.contractExpiryHours.toString();
    _maxBookingCtl.text = s.maxBookingHours.toStringAsFixed(1);
    _initialized = true;
  }

  Future<void> _pickOpening() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => HourPickerDialog(
        initialHour: _openingHour == null ? 8 : (_openingHour! == 0 ? 12 : (_openingHour! > 12 ? _openingHour! - 12 : _openingHour!)),
        initialPm: _openingHour != null && _openingHour! >= 12,
        title: 'اختر وقت بداية العمل',
        open24: 0,
        close24: 24,
      ),
    );
    if (picked != null) setState(() => _openingHour = picked);
  }

  Future<void> _pickClosing(String day) async {
    final cur = _closingHours[day];
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => HourPickerDialog(
        initialHour: cur == null ? 22 : (cur == 0 ? 12 : (cur > 12 ? cur - 12 : cur)),
        initialPm: cur != null && cur >= 12,
        title: 'اختر وقت نهاية العمل - ${_dayLabels[day]}',
        open24: 0,
        close24: 24,
      ),
    );
    if (picked != null) setState(() => _closingHours[day] = picked);
  }

  Future<void> _pickFineFrom() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => HourPickerDialog(
        initialHour: _fineFromHour == null ? 16 : (_fineFromHour! == 0 ? 12 : (_fineFromHour! > 12 ? _fineFromHour! - 12 : _fineFromHour!)),
        initialPm: _fineFromHour != null && _fineFromHour! >= 12,
        title: 'اختر بداية فترة التقسيم الدقيق',
        open24: 0,
        close24: 24,
      ),
    );
    if (picked != null) setState(() {
      _fineFromHour = picked;
      _fineFromMinute = 0;
    });
  }

  Future<void> _pickFineTo() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => HourPickerDialog(
        initialHour: _fineToHour == null ? 20 : (_fineToHour! == 0 ? 12 : (_fineToHour! > 12 ? _fineToHour! - 12 : _fineToHour!)),
        initialPm: _fineToHour != null && _fineToHour! >= 12,
        title: 'اختر نهاية فترة التقسيم الدقيق',
        open24: 0,
        close24: 24,
      ),
    );
    if (picked != null) setState(() {
      _fineToHour = picked;
      _fineToMinute = 0;
    });
  }

  String _toTimeStr(int? hour) {
    if (hour == null) return '00:00';
    return '${hour.toString().padLeft(2, '0')}:00';
  }

  String _toTimeStrWithMin(int? hour, int? minute) {
    if (hour == null) return '00:00';
    return '${hour.toString().padLeft(2, '0')}:${(minute ?? 0).toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    final auth = ref.read(authStateProvider);
    final isSuperAdmin = auth.role == 'super_admin';
    final groupId = isSuperAdmin ? _selectedGroupId : auth.facilityGroupId;
    if (groupId == null) return;
    setState(() => _error = null);

    final deposit = double.tryParse(_depositCtl.text.trim());
    if (deposit == null || deposit < 0) {
      setState(() => _error = 'مبلغ العربون غير صالح');
      return;
    }
    final expiry = int.tryParse(_expiryCtl.text.trim());
    if (expiry == null || expiry <= 0) {
      setState(() => _error = 'مدة انتهاء العقد غير صالحة');
      return;
    }
    final maxHours = double.tryParse(_maxBookingCtl.text.trim());
    if (maxHours == null || maxHours <= 0) {
      setState(() => _error = 'الحد الأقصى للحجز غير صالح');
      return;
    }

    setState(() => _saving = true);
    final result = await ref.read(adminActionProvider.notifier).updateGroupSettings(
      facilityGroupId: groupId,
      openingTime: _toTimeStr(_openingHour),
      closingTimeSun: _toTimeStr(_closingHours['sun']),
      closingTimeMon: _toTimeStr(_closingHours['mon']),
      closingTimeTue: _toTimeStr(_closingHours['tue']),
      closingTimeWed: _toTimeStr(_closingHours['wed']),
      closingTimeThu: _toTimeStr(_closingHours['thu']),
      closingTimeFri: _toTimeStr(_closingHours['fri']),
      closingTimeSat: _toTimeStr(_closingHours['sat']),
      depositAmount: deposit,
      contractExpiryHours: expiry,
      maxBookingHours: maxHours,
      slotFineFrom: _toTimeStrWithMin(_fineFromHour, _fineFromMinute),
      slotFineTo: _toTimeStrWithMin(_fineToHour, _fineToMinute),
    );
    setState(() => _saving = false);

    if (!mounted) return;
    result.when(
      success: (_) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الإعدادات')),
      ),
      failure: (e) => setState(() => _error = translateError(e)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authStateProvider);
    final isSuperAdmin = auth.role == 'super_admin';
    final effectiveGroupId = isSuperAdmin ? _selectedGroupId : auth.facilityGroupId;
    final groupsState = ref.watch(facilityGroupsProvider);
    final groups = groupsState.data ?? [];
    final settingsAsync = effectiveGroupId != null ? ref.watch(groupSettingsProvider(effectiveGroupId)) : null;

    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات المجموعة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isSuperAdmin) ...[
            DropdownButtonFormField<String>(
              value: _selectedGroupId,
              decoration: const InputDecoration(labelText: 'اختر المجموعة'),
              items: groups.map((g) => DropdownMenuItem(
                value: g.id,
                child: Text(g.name),
              )).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedGroupId = v;
                  _initialized = false;
                });
              },
            ),
            const SizedBox(height: 16),
          ],
          if (settingsAsync != null) ...[
            settingsAsync.when(
              data: (settings) {
                if (!_initialized) _initFromSettings(settings);
                return _buildForm(scheme);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('خطأ في تحميل الإعدادات: $e', style: TextStyle(color: scheme.error))),
            ),
          ] else if (!isSuperAdmin) ...[
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Widget _buildForm(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('وقت بداية العمل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Card(
          child: ListTile(
            leading: Icon(Icons.wb_sunny_outlined, color: scheme.primary),
            title: Text(_format12(_openingHour)),
            trailing: const Icon(Icons.edit),
            onTap: _pickOpening,
          ),
        ),
        const SizedBox(height: 16),
        Text('أوقات نهاية العمل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        for (final day in _dayKeys) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                leading: Icon(Icons.nightlight_outlined, color: scheme.primary),
                title: Text(_dayLabels[day]!),
                trailing: Text(_format12(_closingHours[day]), style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => _pickClosing(day),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text('مبلغ العربون (ر.ي)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        TextField(
          controller: _depositCtl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '5000'),
        ),
        const SizedBox(height: 16),
        Text('الحد الأقصى للحجز (ساعة)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        TextField(
          controller: _maxBookingCtl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '3'),
        ),
        const SizedBox(height: 16),
        Text('بداية فترة التقسيم الدقيق (تقسيم 30 دقيقة)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Card(
          child: ListTile(
            leading: Icon(Icons.schedule, color: scheme.primary),
            title: Text(_format12Fine(_fineFromHour, _fineFromMinute)),
            trailing: const Icon(Icons.edit),
            onTap: _pickFineFrom,
          ),
        ),
        const SizedBox(height: 16),
        Text('نهاية فترة التقسيم الدقيق (تقسيم 60 دقيقة)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Card(
          child: ListTile(
            leading: Icon(Icons.schedule, color: scheme.primary),
            title: Text(_format12Fine(_fineToHour, _fineToMinute)),
            trailing: const Icon(Icons.edit),
            onTap: _pickFineTo,
          ),
        ),
        const SizedBox(height: 16),
        Text('مدة انتهاء العقد (ساعة)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        TextField(
          controller: _expiryCtl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '8'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: scheme.error)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('حفظ الإعدادات'),
          ),
        ),
      ],
    );
  }
}
