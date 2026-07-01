import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/helpers/error_helper.dart';
import '../../../../presentaion/shared/app_text_field.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/auth_validation_provider.dart';

class RegisterScreen extends ConsumerWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final validation = ref.watch(authValidationProvider);
    final action = ref.watch(authActionProvider);

    Future<void> register() async {
      FocusScope.of(context).unfocus();
      ref.read(authValidationProvider.notifier).validateAll();
      if (!ref.read(authValidationProvider).isValid) return;

      final auth = ref.read(authStateProvider);
      final result = await ref.read(authActionProvider.notifier).register(
        auth.phone,
        auth.password,
        name: auth.name,
      );
      if (!context.mounted) return;
      result.when(
        success: (_) {},
        failure: (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(translateError(e))),
          );
        },
      );
    }

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
              AppTextField(
                label: 'كلمة المرور',
                hint: '••••••••',
                error: validation.field(AuthFields.password).error,
                obscure: true,
                onChanged: (v) {
                  ref.read(authStateProvider.notifier).updatePassword(v);
                  ref.read(authValidationProvider.notifier).validatePassword();
                },
                prefix: Icon(Icons.lock_outline, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: action.isLoading('register') ? null : register,
                child: action.isLoading('register')
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('تسجيل', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('لديك حساب؟ سجل دخول'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
