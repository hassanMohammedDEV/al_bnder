import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/helpers/error_helper.dart';
import '../../providers/auth_provider.dart';

class ForgotPasswordOtpScreen extends ConsumerStatefulWidget {
  const ForgotPasswordOtpScreen({super.key});

  @override
  ConsumerState<ForgotPasswordOtpScreen> createState() => _ForgotPasswordOtpScreenState();
}

class _ForgotPasswordOtpScreenState extends ConsumerState<ForgotPasswordOtpScreen> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  Timer? _timer;
  bool _loading = false;
  bool _otpVerified = false;
  static const _resendWait = 60;
  int _remaining = 0;

  String get _phone => GoRouterState.of(context).extra as String? ?? '';

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _remaining = _resendWait;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_remaining <= 1) {
        setState(() => _remaining = 0);
        timer.cancel();
        return;
      }
      setState(() => _remaining--);
    });
  }

  Future<void> _sendOtp() async {
    final phone = _phone;
    if (phone.isEmpty) return;
    setState(() => _loading = true);
    final result = await ref.read(authActionProvider.notifier).generateOtp(phone);
    if (!mounted) { _loading = false; return; }
    setState(() => _loading = false);
    result.when(
      success: (_) => _startTimer(),
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(translateError(e))),
        );
      },
    );
  }

  Future<void> _resetPassword() async {
    final phone = _phone;
    final code = _codeController.text;
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كلمة المرور يجب أن تكون 6 أحرف على الأقل')),
      );
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كلمة المرور غير متطابقة')),
      );
      return;
    }

    setState(() => _loading = true);
    final result = await ref.read(authActionProvider.notifier).resetPassword(phone, code, password);
    if (!mounted) { _loading = false; return; }
    setState(() => _loading = false);
    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تغيير كلمة السر بنجاح')),
        );
        context.go('/login');
      },
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
        title: const Text('تأكيد رمز التحقق'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/forgot-password'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 40),
                Icon(Icons.smartphone, size: 80, color: scheme.primary),
                const SizedBox(height: 24),
                Text('تم إرسال رمز التحقق', style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                )),
                const SizedBox(height: 8),
                Text('إلى رقم $_phone', style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                )),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _codeController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  enabled: !_otpVerified,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    hintStyle: TextStyle(
                      fontSize: 28,
                      color: scheme.outlineVariant,
                      letterSpacing: 8,
                    ),
                  ),
                  onChanged: (v) async {
                    if (v.length == 6 && !_otpVerified) {
                      final phone = _phone;
                      if (phone.isEmpty) return;
                      setState(() => _loading = true);
                      final result = await ref.read(authServiceProvider).checkOtp(phone, v);
                      if (!mounted) { _loading = false; return; }
                      setState(() => _loading = false);
                      result.when(
                        success: (valid) {
                          if (valid) {
                            setState(() => _otpVerified = true);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('رمز التحقق خاطئ أو منتهي الصلاحية')),
                            );
                          }
                        },
                        failure: (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(translateError(e))),
                          );
                        },
                      );
                    }
                  },
                ),
                const SizedBox(height: 24),
                if (!_otpVerified)
                  _loading
                      ? const CircularProgressIndicator()
                      : TextButton(
                          onPressed: _remaining == 0 ? _sendOtp : null,
                          child: Text(_remaining > 0
                              ? 'إعادة إرسال الرمز (${_remaining}s)'
                              : 'إعادة إرسال الرمز'),
                        ),
                if (_otpVerified) ...[
                  const SizedBox(height: 16),
                  Icon(Icons.check_circle, size: 48, color: Colors.green),
                  const SizedBox(height: 8),
                  Text('تم التحقق', style: TextStyle(
                    fontSize: 16,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  )),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الجديدة',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'تأكيد كلمة المرور',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _resetPassword,
                      child: _loading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('تأكيد'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
