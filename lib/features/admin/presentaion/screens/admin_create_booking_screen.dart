import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../presentaion/shared/app_text_field.dart';
import '../../../../presentaion/shared/time_picker_dialog.dart';
import '../../../../presentaion/shared/slot_picker_widget.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../facilities/providers/facility_provider.dart';
import '../../../facilities/repositories/facility_repository_impl.dart';
import '../../providers/admin_provider.dart';
import '../../repositories/admin_repository_impl.dart';
import '../../../../core/helpers/error_helper.dart';

class AdminCreateBookingScreen extends ConsumerStatefulWidget {
  const AdminCreateBookingScreen({super.key});

  @override
  ConsumerState<AdminCreateBookingScreen> createState() => _AdminCreateBookingScreenState();
}

class _AdminCreateBookingScreenState extends ConsumerState<AdminCreateBookingScreen> {
  final _searchCtl = TextEditingController();
  final _newNameCtl = TextEditingController();
  final _newPhoneCtl = TextEditingController();

  bool _isNewUser = false;
  List<Map<String, dynamic>>? _users;
  Map<String, dynamic>? _selectedUser;
  bool _searching = false;

  String? _selectedFacilityId;
  String? _selectedGroupId; // for super_admin who has no facilityGroupId
  DateTime _selectedDate = DateTime.now();
  int _startHour24 = 16;
  int _endHour24 = 17;
  bool _submitting = false;
  List<BookedSlotInfo> _bookedSlots = [];
  int _open24 = 16;
  int _close24 = 22;
  bool _loadingSlots = false;

  bool _isRecurring = false;
  final Set<int> _recurringDays = {};
  DateTime? _recurringEndDate;
  bool _autoConfirm = true;
  String _paymentType = 'full';

  @override
  void dispose() {
    _searchCtl.dispose();
    _newNameCtl.dispose();
    _newPhoneCtl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
    ));
  }

  Future<void> _searchUsers() async {
    final query = _searchCtl.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _selectedUser = null;
    });
    final result = await ref.read(adminActionProvider.notifier).searchUsers(
      query,
      facilityGroupId: ref.read(authStateProvider).facilityGroupId,
    );
    result.when(
      success: (users) => setState(() => _users = users),
      failure: (e) {
        _snack(translateError(e), isError: true);
        setState(() => _users = []);
      },
    );
    setState(() => _searching = false);
  }

  Future<void> _loadSlots() async {
    final auth = ref.read(authStateProvider);
    final groupId = _selectedGroupId ?? auth.facilityGroupId;
    final facilityId = _selectedFacilityId;
    if (groupId == null || facilityId == null) return;

    setState(() => _loadingSlots = true);

    try {
      final settingsResult = await ref.read(adminRepositoryProvider).getGroupSettings(groupId);
      settingsResult.when(
        success: (data) {
          final parts = (data['opening_time'] as String? ?? '00:00').split(':');
          final open24 = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 16;
          final dayIndex = _selectedDate.weekday;
          final closeKey = [
            'closing_time_sun', 'closing_time_mon', 'closing_time_tue',
            'closing_time_wed', 'closing_time_thu', 'closing_time_fri', 'closing_time_sat',
          ][dayIndex == 7 ? 0 : dayIndex];
          final closeParts = ((data[closeKey] as String?) ?? '00:00').split(':');
          final close24 = int.tryParse(closeParts.isNotEmpty ? closeParts[0] : '0') ?? 22;
          _open24 = open24;
          _close24 = close24;
        },
        failure: (_) {},
      );

      final slotsResult = await ref.read(facilityRepositoryProvider).getAvailableSlots(
        facilityId, _selectedDate,
      );
      slotsResult.when(
        success: (data) {
          final booked = (data['booked_slots'] as List?) ?? [];
          setState(() {
            _bookedSlots = booked.map((b) {
              final startStr = b['start_at'] as String? ?? '';
              final endStr = b['end_at'] as String? ?? '';
              final startDt = DateTime.tryParse(startStr)?.toLocal();
              final endDt = DateTime.tryParse(endStr)?.toLocal();
              if (startDt == null || endDt == null) return BookedSlotInfo(startHour: 0, endHour: 0);
              return BookedSlotInfo(startHour: startDt.hour, endHour: endDt.hour);
            }).toList();
            _startHour24 = _open24;
            _endHour24 = _open24 + 1;
          });
        },
        failure: (_) => setState(() => _bookedSlots = []),
      );
    } catch (_) {}

    setState(() => _loadingSlots = false);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _selectedDate,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadSlots();
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startHour24 : _endHour24;
    final initial12 = initial == 0 ? 12 : (initial > 12 ? initial - 12 : initial);
    final initialPm = initial >= 12;

    // Fetch working hours
    final auth = ref.read(authStateProvider);
    final groupId = _selectedGroupId ?? auth.facilityGroupId;
    int open24 = 0;
    int close24 = 24;
    if (groupId != null) {
      try {
        final result = await ref.read(adminRepositoryProvider).getGroupSettings(groupId);
        result.when(
          success: (data) {
            final parts = (data['opening_time'] as String? ?? '00:00').split(':');
            open24 = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
            final dayIndex = _selectedDate.weekday;
            final closeKey = [
              'closing_time_sun', 'closing_time_mon', 'closing_time_tue',
              'closing_time_wed', 'closing_time_thu', 'closing_time_fri', 'closing_time_sat',
            ][dayIndex == 7 ? 0 : dayIndex];
            final closeParts = ((data[closeKey] as String?) ?? '00:00').split(':');
            close24 = int.tryParse(closeParts.isNotEmpty ? closeParts[0] : '0') ?? 0;
          },
          failure: (_) {},
        );
      } catch (_) {}
    }

    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => HourPickerDialog(
        initialHour: initial12,
        initialPm: initialPm,
        title: isStart ? 'اختر وقت البداية' : 'اختر وقت النهاية',
        open24: open24,
        close24: close24,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startHour24 = picked;
          if (_endHour24 <= picked) _endHour24 = picked + 1;
        } else {
          _endHour24 = picked;
        }
      });
    }
  }

  String _formatTime(int hour24) {
    final h = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final p = hour24 < 12 ? 'ص' : 'م';
    return '$h:00 $p';
  }

  Future<void> _submit() async {
    if (_selectedFacilityId == null) { _snack('اختر الملعب', isError: true); return; }
    if (_endHour24 <= _startHour24) { _snack('وقت النهاية يجب أن يكون بعد وقت البداية', isError: true); return; }
    if (_isRecurring && _recurringDays.isEmpty) { _snack('اختر أيام التكرار', isError: true); return; }
    if (_isRecurring && _recurringEndDate == null) { _snack('اختر تاريخ انتهاء التكرار', isError: true); return; }

    setState(() => _submitting = true);

    String? targetUserId;
    String? targetName;
    String? targetPhone;

    if (_isNewUser) {
      targetName = _newNameCtl.text.trim();
      targetPhone = _newPhoneCtl.text.trim();
      if (targetName.isEmpty) { _snack('أدخل اسم المستخدم', isError: true); setState(() => _submitting = false); return; }
      if (targetPhone.isEmpty) { _snack('أدخل رقم الجوال', isError: true); setState(() => _submitting = false); return; }
    } else {
      if (_selectedUser == null) { _snack('اختر مستخدم أولاً', isError: true); setState(() => _submitting = false); return; }
      targetUserId = _selectedUser!['id'] as String;
    }

    final startAt = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day, _startHour24,
    );
    final endAt = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day, _endHour24,
    );

    Map<String, dynamic>? recurringRule;
    if (_isRecurring) {
      recurringRule = {
        'days_of_week': _recurringDays.toList(),
        'end_date': _recurringEndDate!.toIso8601String(),
      };
    }

    final result = await ref.read(adminActionProvider.notifier).createBooking(
      targetUserId: targetUserId,
      facilityId: _selectedFacilityId!,
      startAt: startAt,
      endAt: endAt,
      targetName: targetName,
      targetPhone: targetPhone,
      isRecurring: _isRecurring,
      recurringRule: recurringRule,
      autoConfirm: _autoConfirm,
      paymentType: _paymentType,
    );

    setState(() => _submitting = false);

    result.when(
      success: (data) {
        final d = data['data'] as Map<String, dynamic>?;
        final totalPrice = (d?['total_price'] as num? ?? 0).toDouble();
        final paidAmount = (d?['paid_amount'] as num? ?? 0).toDouble();
        final facilityName = d?['facility_name'] as String? ?? '';
        final isRecurring = d?['is_recurring'] as bool? ?? false;
        final instanceCount = d?['instance_count'] as int? ?? 1;
        final deadline = d?['approval_deadline'] as String?;
        final scheme = Theme.of(context).colorScheme;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(_autoConfirm ? Icons.check_circle : Icons.schedule,
                  color: _autoConfirm ? Colors.green : Colors.orange),
                const SizedBox(width: 8),
                Text(_autoConfirm ? 'تم تأكيد الحجز' : 'حجز شبه مؤكد'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$facilityName - ${totalPrice.toStringAsFixed(0)} ر.س'),
                if (paidAmount > 0 && paidAmount < totalPrice)
                  Text('المخصوم (عربون): ${paidAmount.toStringAsFixed(0)} ر.س',
                    style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                if (isRecurring) ...[
                  const SizedBox(height: 4),
                  Text('حجز متسلسل: $instanceCount حجزة'),
                ],
                const SizedBox(height: 8),
                Text(_autoConfirm
                  ? (paidAmount > 0 ? 'تم الخصم من المحفظة' : 'تم الحجز (الدفع خارج التطبيق)')
                  : 'سيتم إلغاء الحجز تلقائياً بعد انتهاء المهلة'),
                if (deadline != null) ...[
                  const SizedBox(height: 4),
                  Text('الموعد النهائي: ${formatDateTime12(DateTime.parse(deadline))}',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      },
      failure: (e) => _snack(translateError(e), isError: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authStateProvider);
    final groupId = auth.facilityGroupId;
    final effectiveGroupId = _selectedGroupId ?? groupId;
    final facilitiesAsync = effectiveGroupId != null ? ref.watch(facilitiesProvider(effectiveGroupId)) : null;
    final groupsState = ref.watch(facilityGroupsProvider);
    final _selectedFacilityPrice = () {
      try {
        final facilities = facilitiesAsync?.value;
        if (facilities == null || _selectedFacilityId == null) return 0.0;
        final f = facilities.where((f) => f.id == _selectedFacilityId).firstOrNull;
        return f?.pricePerHour ?? 0.0;
      } catch (_) {
        return 0.0;
      }
    }();

    return Scaffold(
      appBar: AppBar(title: const Text('حجز لعميل')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User type toggle
          const Text('المستخدم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('مستخدم موجود')),
              ButtonSegment(value: true, label: Text('مستخدم جديد')),
            ],
            selected: {_isNewUser},
            onSelectionChanged: (v) {
              setState(() {
                _isNewUser = v.first;
                _selectedUser = null;
                _users = null;
              });
            },
          ),
          const SizedBox(height: 16),
          if (_isNewUser) ...[
            AppTextField(
              label: 'الاسم',
              hint: 'أدخل اسم المستخدم',
              controller: _newNameCtl,
              prefix: Icon(Icons.person, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'رقم الجوال',
              hint: '05xxxxxxxx',
              controller: _newPhoneCtl,
              keyboardType: TextInputType.phone,
              prefix: Icon(Icons.phone, color: scheme.onSurfaceVariant),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'رقم الجوال',
                    hint: '05xxxxxxxx',
                    controller: _searchCtl,
                    keyboardType: TextInputType.phone,
                    onChanged: (_) => setState(() => _users = null),
                    prefix: Icon(Icons.search, color: scheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searching ? null : _searchUsers,
                  child: _searching
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('بحث'),
                ),
              ],
            ),
            if (_users != null) ...[
              const SizedBox(height: 12),
              if (_users!.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 12),
                        Text('لا يوجد مستخدمين بهذا الرقم',
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                )
              else
                ...(_users!.map((u) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedUser = u),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: _selectedUser?['id'] == u['id']
                                  ? scheme.primary : scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.person,
                              color: _selectedUser?['id'] == u['id']
                                  ? scheme.onPrimary : scheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(u['full_name'] ?? 'بدون اسم',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(u['phone'],
                                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          if (_selectedUser?['id'] == u['id'])
                            Icon(Icons.check_circle, color: scheme.primary),
                        ],
                      ),
                    ),
                  ),
                ))),
            ],
          ],
          if (_isNewUser || _selectedUser != null) ...[
            const SizedBox(height: 24),
            // Group selector (for super_admin without a fixed group)
            if (groupId == null) ...[
              const Text('اختر المجموعة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              () {
                final groups = groupsState.data;
                if (groups == null) return const LinearProgressIndicator();
                if (groupsState.error != null) {
                  return Text('خطأ: ${groupsState.error}', style: TextStyle(color: scheme.error));
                }
                return DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.groups, color: scheme.primary),
                  ),
                  hint: const Text('اختر المجموعة'),
                  initialValue: _selectedGroupId,
                  items: groups.map((g) => DropdownMenuItem(
                    value: g.id,
                    child: Text(g.name),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedGroupId = v),
                );
              }(),
              const SizedBox(height: 16),
            ],
            // Facility selection
            const Text('اختر الملعب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            facilitiesAsync?.when(
              data: (facilities) {
                final active = facilities.where((f) => f.isActive).toList();
                return DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.stadium, color: scheme.primary),
                  ),
                  hint: const Text('اختر الملعب'),
                  initialValue: _selectedFacilityId,
                  items: active.map((f) => DropdownMenuItem(
                    value: f.id,
                    child: Text('${f.name} (${f.pricePerHour.toStringAsFixed(0)} ر.س/س)'),
                  )).toList(),
                  onChanged: (v) {
                    setState(() => _selectedFacilityId = v);
                    _loadSlots();
                  },
                );
              },
              error: (e, __) => Text('خطأ: $e', style: TextStyle(color: scheme.error)),
              loading: () => const LinearProgressIndicator(),
            ) ?? const Text('لا توجد مجموعة ملاعب', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            // Date
            const Text('اختر التاريخ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _AdminFieldCard(
              icon: Icons.calendar_today,
              value: dateLabelWithDay(_selectedDate),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),
            if (_selectedFacilityId != null && _loadingSlots)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_selectedFacilityId != null)
              SlotPickerWidget(
                open24: _open24,
                close24: _close24,
                bookedSlots: _bookedSlots,
                pricePerHour: _selectedFacilityPrice,
                onChanged: (sel) {
                  setState(() {
                    _startHour24 = sel.start;
                    _endHour24 = sel.end ?? sel.start + 1;
                  });
                },
              ),
            const SizedBox(height: 24),
            // Recurring
            const Divider(),
            SwitchListTile(
              title: const Text('حجز متسلسل'),
              subtitle: const Text('تكرار الحجز أسبوعياً'),
              value: _isRecurring,
              onChanged: (v) => setState(() => _isRecurring = v),
            ),
            if (_isRecurring) ...[
              const SizedBox(height: 8),
              Text('أيام التكرار', style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant,
              )),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(7, (i) {
                  final days = ['أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];
                  final selected = _recurringDays.contains(i);
                  return FilterChip(
                    label: Text(days[i]),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        if (selected) { _recurringDays.remove(i); }
                        else { _recurringDays.add(i); }
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
              Text('تاريخ الانتهاء', style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant,
              )),
              const SizedBox(height: 8),
              _AdminFieldCard(
                icon: Icons.date_range,
                value: _recurringEndDate != null
                    ? dateLabelWithDay(_recurringEndDate!)
                    : 'اختر تاريخ',
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: _selectedDate,
                    lastDate: _selectedDate.add(const Duration(days: 365)),
                    initialDate: _recurringEndDate,
                  );
                  if (picked != null) setState(() => _recurringEndDate = picked);
                },
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            SwitchListTile(
              title: const Text('تأكيد فوري'),
              subtitle: const Text('إذا كان إيقاف، يكون الحجز شبه مؤكد وينتهي تلقائياً بعد المدة المحددة'),
              value: _autoConfirm,
              onChanged: (v) => setState(() => _autoConfirm = v),
            ),
            if (_autoConfirm && _selectedUser != null) ...[
              const SizedBox(height: 8),
              Text('طريقة الدفع', style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant,
              )),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'full', label: Text('دفع كامل')),
                  ButtonSegment(value: 'deposit', label: Text('عربون')),
                ],
                selected: {_paymentType},
                onSelectionChanged: (v) => setState(() => _paymentType = v.first),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('تأكيد الحجز', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminFieldCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final VoidCallback onTap;

  const _AdminFieldCard({
    required this.icon,
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
