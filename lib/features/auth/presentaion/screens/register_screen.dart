import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../presentaion/shared/app_text_field.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/auth_validation_provider.dart';

class RegisterScreen extends ConsumerWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authStateProvider);
    final validation = ref.watch(authValidationProvider);

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
              Text('أدخل رقم جوالك لإنشاء حساب', style: TextStyle(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
              )),
              const SizedBox(height: 32),
              AppTextField(
                label: 'رقم الجوال',
                hint: '05xxxxxxxx',
                error: validation.field(AuthFields.phone).error,
                onChanged: (v) {
                  ref.read(authStateProvider.notifier).updatePhone(v);
                  ref.read(authValidationProvider.notifier).validatePhone();
                },
                keyboardType: TextInputType.phone,
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
                onPressed: () {
                  ref.read(authValidationProvider.notifier).validateAll();
                  if (!ref.read(authValidationProvider).isValid) return;
                  context.go('/verify-otp', extra: auth.phone);
                },
                child: const Text('التالي', style: TextStyle(fontSize: 16)),
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
