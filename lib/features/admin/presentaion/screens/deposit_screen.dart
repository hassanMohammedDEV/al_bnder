import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../presentaion/shared/app_text_field.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/admin_provider.dart';
import '../../../../core/helpers/error_helper.dart';
import '../../../../core/helpers/arabic_numbers.dart';

class DepositScreen extends ConsumerStatefulWidget {
  const DepositScreen({super.key});

  @override
  ConsumerState<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends ConsumerState<DepositScreen> {
  final _searchCtl = TextEditingController();
  final _amountCtl = TextEditingController();
  final _descCtl = TextEditingController();

  List<Map<String, dynamic>>? _users;
  Map<String, dynamic>? _selectedUser;
  bool _searching = false;
  bool _depositing = false;
  bool _deducting = false;
  String? _amountError;

  @override
  void dispose() {
    _searchCtl.dispose();
    _amountCtl.dispose();
    _descCtl.dispose();
    super.dispose();
  }

  static final _fmt = NumberFormat('#,###');

  String _f(double v) => _fmt.format(v);
  String _w(double v) => numberToArabicWords(v.round());

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
    ));
  }

  Future<void> _search() async {
    final raw = _searchCtl.text.trim();
    if (raw.isEmpty) return;
    setState(() {
      _searching = true;
      _selectedUser = null;
    });
    final auth = ref.read(authStateProvider);
    final result = await ref.read(adminActionProvider.notifier).searchUsers(
      raw,
      facilityGroupId: auth.facilityGroupId,
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

  Future<void> _deposit() async {
    final amountText = _amountCtl.text.trim();
    if (amountText.isEmpty) {
      setState(() => _amountError = 'أدخل المبلغ');
      return;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _amountError = 'المبلغ يجب أن يكون أكبر من صفر');
      return;
    }
    setState(() => _amountError = null);

    if (_selectedUser == null) {
      _snack('اختر مستخدم أولاً', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الشحن'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المستخدم: ${_selectedUser!['full_name'] ?? 'بدون اسم'}'),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('المبلغ:', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                const SizedBox(width: 8),
                Text('${_f(amount)} ر.ي',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            Text('(${_w(amount)})',
              style: TextStyle(fontSize: 14, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد الشحن')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _depositing = true);
    final auth = ref.read(authStateProvider);
    final result = await ref.read(adminActionProvider.notifier).depositWallet(
      targetUserId: _selectedUser!['id'] as String,
      facilityGroupId: auth.facilityGroupId!,
      amount: amount,
      description: _descCtl.text.trim().isNotEmpty ? _descCtl.text.trim() : null,
    );
    setState(() => _depositing = false);

    result.when(
      success: (_) {
        _snack('تم شحن ${_f(amount)} ر.ي بنجاح');
        _amountCtl.clear();
        _descCtl.clear();
        setState(() => _selectedUser = null);
      },
      failure: (e) => _snack(translateError(e), isError: true),
    );
  }

  Future<void> _deduct() async {
    final amountText = _amountCtl.text.trim();
    if (amountText.isEmpty) {
      setState(() => _amountError = 'أدخل المبلغ');
      return;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _amountError = 'المبلغ يجب أن يكون أكبر من صفر');
      return;
    }
    setState(() => _amountError = null);

    if (_selectedUser == null) {
      _snack('اختر مستخدم أولاً', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الخصم'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المستخدم: ${_selectedUser!['full_name'] ?? 'بدون اسم'}'),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('المبلغ:', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                const SizedBox(width: 8),
                Text('${_f(amount)} ر.ي',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            Text('(${_w(amount)})',
              style: TextStyle(fontSize: 14, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد الخصم')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deducting = true);
    final auth = ref.read(authStateProvider);
    final result = await ref.read(adminActionProvider.notifier).deductWallet(
      targetUserId: _selectedUser!['id'] as String,
      facilityGroupId: auth.facilityGroupId!,
      amount: amount,
      description: _descCtl.text.trim().isNotEmpty ? _descCtl.text.trim() : null,
    );
    setState(() => _deducting = false);

    result.when(
      success: (_) {
        _snack('تم خصم ${_f(amount)} ر.ي بنجاح');
        _amountCtl.clear();
        _descCtl.clear();
        setState(() => _selectedUser = null);
      },
      failure: (e) => _snack(translateError(e), isError: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('شحن المحفظة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('ابحث عن المستخدم برقم الجوال',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                    child: AppTextField(
                      label: 'رقم الجوال',
                      hint: '05xxxxxxxx',
                      controller: _searchCtl,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) {
                        FocusScope.of(context).unfocus();
                        _search();
                      },
                      inputFormatters: [_PhoneInputFormatter()],
                      onChanged: (_) => setState(() => _users = null),
                      suffix: IconButton(
                        icon: Icon(Icons.search, color: scheme.onSurfaceVariant),
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          _search();
                        },
                      ),
                    ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searching ? null : () {
                    FocusScope.of(context).unfocus();
                    _search();
                  },
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
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
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
          if (_selectedUser != null) ...[
            const SizedBox(height: 24),
            AppTextField(
              label: 'المبلغ (ر.ي)',
              hint: 'أدخل المبلغ',
              controller: _amountCtl,
              keyboardType: TextInputType.number,
              error: _amountError,
              onChanged: (_) => setState(() => _amountError = null),
              prefix: Icon(Icons.money, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'سبب الشحن',
              hint: 'اختياري',
              controller: _descCtl,
              maxLines: 2,
              prefix: Icon(Icons.notes, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _depositing ? null : _deposit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: _depositing
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('شحن المحفظة', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _deducting ? null : _deduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: Colors.white,
                      ),
                      child: _deducting
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('خصم من المحفظة', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => context.push('/admin/user-wallet', extra: {
                  'userId': _selectedUser!['id'] as String,
                  'groupId': ref.read(authStateProvider).facilityGroupId ?? '',
                  'userName': _selectedUser!['full_name'] as String? ?? '',
                }),
                child: const Text('عرض المحفظة', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhoneInputFormatter extends TextInputFormatter {
  static final _arabicDigits = RegExp(r'[\u0660-\u0669]');
  static final _arabicLetters = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    var text = next.text;
    text = text.replaceAll(_arabicLetters, '');
    text = text.replaceAllMapped(_arabicDigits, (m) {
      return String.fromCharCode(m[0]!.codeUnitAt(0) - 0x0660 + 0x30);
    });
    if (text == next.text) return next;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
