import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/helpers/error_helper.dart';
import '../../../../presentaion/shared/app_text_field.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/auth_validation_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final validation = ref.watch(authValidationProvider);
    final action = ref.watch(authActionProvider);

    Future<void> login() async {
      FocusScope.of(context).unfocus();
      ref.read(authValidationProvider.notifier)
          .validateStep([AuthFields.phone, AuthFields.password]);
      if (!ref.read(authValidationProvider).isValid) return;

      final result = await ref.read(authActionProvider.notifier).login(
        ref.read(authStateProvider).phone,
        ref.read(authStateProvider).password,
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              Icon(Icons.sports_soccer, size: 80, color: scheme.primary),
              const SizedBox(height: 16),
              Text('البندر', style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ), textAlign: TextAlign.center),
              Text('نظام حجز الملاعب', style: TextStyle(
                fontSize: 16,
                color: scheme.onSurfaceVariant,
              ), textAlign: TextAlign.center),
              const SizedBox(height: 48),
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
              const SizedBox(height: 32),
              FilledButton(
                onPressed: action.isLoading('login') ? null : login,
                child: action.isLoading('login')
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('دخول', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/register'),
                child: const Text('ليس لديك حساب؟ سجل الآن'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
