import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/helpers/error_helper.dart';
import '../../../../presentaion/shared/app_text_field.dart';
import '../../providers/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  String _password = '';
  String _confirm = '';
  bool _savePassword = false;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authStateProvider);
    _nameCtrl = TextEditingController(text: auth.name);
    _phoneCtrl = TextEditingController(text: auth.phone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> save() async {
    FocusScope.of(context).unfocus();
    final action = ref.read(authActionProvider.notifier);

    if (_nameCtrl.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الاسم يجب أن يكون حرفين على الأقل')),
      );
      return;
    }

    if (_savePassword) {
      if (_password.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('كلمة السر يجب أن تكون 6 أحرف على الأقل')),
        );
        return;
      }
      if (_password != _confirm) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('كلمتا السر غير متطابقتين')),
        );
        return;
      }
    }

    final nameResult = await action.updateName(_nameCtrl.text.trim());
    if (!context.mounted) return;
    String? err;
    nameResult.when(success: (_) {}, failure: (e) => err = translateError(e));
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err!)));
      return;
    }

    if (_savePassword) {
      final pwResult = await action.changePassword(_password);
      if (!context.mounted) return;
      String? pwErr;
      pwResult.when(success: (_) {}, failure: (e) => pwErr = translateError(e));
      if (pwErr != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pwErr!)));
        return;
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ التغييرات')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final action = ref.watch(authActionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('تعديل الملف الشخصي')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text('البيانات الشخصية', style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              )),
              const SizedBox(height: 20),
              AppTextField(
                label: 'الاسم',
                hint: 'الاسم الكامل',
                controller: _nameCtrl,
                prefix: Icon(Icons.person, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'رقم الجوال',
                hint: '7xxxxxxxx',
                readOnly: true,
                controller: _phoneCtrl,
                prefix: Icon(Icons.phone, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Text('تغيير كلمة السر', style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  )),
                  const Spacer(),
                  Switch(
                    value: _savePassword,
                    onChanged: (v) => setState(() => _savePassword = v),
                  ),
                ],
              ),
              if (_savePassword) ...[
                const SizedBox(height: 20),
                PasswordField(
                  label: 'كلمة السر الجديدة',
                  hint: '••••••••',
                  onChanged: (v) => _password = v,
                  prefix: Icon(Icons.lock_outline, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                PasswordField(
                  label: 'تأكيد كلمة السر',
                  hint: '••••••••',
                  onChanged: (v) => _confirm = v,
                  prefix: Icon(Icons.lock_outline, color: scheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 32),
              FilledButton(
                onPressed: action.isLoading('update_name') || action.isLoading('change_password') ? null : save,
                child: action.isLoading('update_name') || action.isLoading('change_password')
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('حفظ', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
