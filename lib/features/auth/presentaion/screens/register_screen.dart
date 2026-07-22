import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/helpers/error_helper.dart';
import '../../../../presentaion/shared/app_text_field.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/auth_validation_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  bool _consentAccepted = false;

  Future<void> register() async {
    FocusScope.of(context).unfocus();
    ref.read(authValidationProvider.notifier).validateAll();
    if (!ref.read(authValidationProvider).isValid) return;
    if (!_consentAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى الموافقة على سياسة الخصوصية وشروط الاستخدام')),
      );
      return;
    }

    final auth = ref.read(authStateProvider);

    bool phoneExists = false;
    final phoneCheck = await ref.read(authServiceProvider).checkPhone(auth.phone);
    if (!mounted) return;
    phoneCheck.when(success: (exists) => phoneExists = exists, failure: (_) {});
    if (phoneExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('المستخدم موجود مسبقاً')),
      );
      return;
    }

    final result = await ref.read(authActionProvider.notifier).startRegistration(
      auth.phone,
      auth.password,
      name: auth.name,
    );
    if (!mounted) return;
    result.when(
      success: (_) => context.go('/verify-otp'),
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(translateError(e))),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final validation = ref.watch(authValidationProvider);
    final action = ref.watch(authActionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('حساب جديد')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text('إنشاء حساب جديد', style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              )),
              const SizedBox(height: 8),
              Text('أدخل بياناتك لإنشاء حساب', style: TextStyle(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
              )),
              const SizedBox(height: 32),
              AppTextField(
                label: 'الاسم',
                hint: 'الاسم الكامل',
                error: validation.field(AuthFields.name).error,
                onChanged: (v) {
                  ref.read(authStateProvider.notifier).updateName(v);
                  ref.read(authValidationProvider.notifier).validateName();
                },
                prefix: Icon(Icons.person, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'رقم الجوال',
                hint: '7xxxxxxxx',
                error: validation.field(AuthFields.phone).error,
                onChanged: (v) {
                  ref.read(authStateProvider.notifier).updatePhone(v);
                  ref.read(authValidationProvider.notifier).validatePhone();
                },
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                prefix: Icon(Icons.phone, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              PasswordField(
                label: 'كلمة المرور',
                hint: '••••••••',
                error: validation.field(AuthFields.password).error,
                onChanged: (v) {
                  ref.read(authStateProvider.notifier).updatePassword(v);
                  ref.read(authValidationProvider.notifier).validatePassword();
                },
                prefix: Icon(Icons.lock_outline, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _consentAccepted,
                    onChanged: (v) => setState(() => _consentAccepted = v ?? false),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _consentAccepted = !_consentAccepted),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                          children: [
                            const TextSpan(text: 'أوافق على '),
                            TextSpan(
                              text: 'سياسة الخصوصية',
                              style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => context.push('/privacy'),
                            ),
                            const TextSpan(text: ' و '),
                            TextSpan(
                              text: 'شروط الاستخدام',
                              style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => context.push('/terms'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: action.isLoading('start_registration') ? null : register,
                child: action.isLoading('start_registration')
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('تسجيل', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),
              TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('لديك حساب؟ سجل دخول'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
