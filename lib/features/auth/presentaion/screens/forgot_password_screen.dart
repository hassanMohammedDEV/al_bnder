import 'package:app_platform_core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/helpers/error_helper.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../presentaion/shared/app_text_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim().replaceAll(RegExp(r'^0+'), '');
    if (phone.length != 9 || !RegExp(r'^\d{9}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال 9 أرقام صحيحة')),
      );
      return;
    }
    setState(() => _loading = true);
    final existsResult = await ref.read(authServiceProvider).checkPhone(phone);
    if (!mounted) { _loading = false; return; }
    final exists = existsResult is Success<bool> && existsResult.data;
    if (!exists) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رقم الجوال غير مسجل')),
      );
      return;
    }
    final result = await ref.read(authActionProvider.notifier).generateOtp(phone);
    if (!mounted) { _loading = false; return; }
    setState(() => _loading = false);
    result.when(
      success: (_) => context.go('/forgot-password-otp', extra: phone),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('نسيت كلمة السر'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Icon(Icons.lock_reset, size: 80, color: scheme.primary),
              const SizedBox(height: 24),
              Text('أدخل رقم جوالك', style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              )),
              const SizedBox(height: 8),
              Text('سيتم إرسال رمز تحقق إلى رقمك', style: TextStyle(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
              )),
              const SizedBox(height: 32),
              AppTextField(
                controller: _phoneController,
                label: 'رقم الجوال',
                hint: '7xxxxxxxx',
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                prefix: Icon(Icons.phone, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _sendOtp,
                  child: _loading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('إرسال رمز التحقق'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
