import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../../../core/helpers/error_helper.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _codeController = TextEditingController();
  Timer? _timer;
  bool _loading = false;
  static const _resendWait = 60;
  int _remaining = 0;
  String get _phone => ref.read(authStateProvider).phone;

  @override
  void initState() {
    super.initState();
    _startTimer();
    Future.microtask(() {
      if (_phone.isNotEmpty) _sendOtp();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _remaining = _resendWait;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remaining <= 1) {
        setState(() => _remaining = 0);
        timer.cancel();
        return;
      }
      setState(() => _remaining--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phone;
    if (phone.isEmpty) return;
    setState(() => _loading = true);
    final result = await ref.read(authServiceProvider).generateOtp(phone);
    if (!mounted) return;
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

  Future<void> _verify() async {
    if (_codeController.text.length != 6) return;
    final phone = _phone;
    if (phone.isEmpty) return;
    setState(() => _loading = true);
    final result = await ref.read(authServiceProvider).verifyOtp(
      phone,
      _codeController.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    result.when(
      success: (_) {
        ref.read(authStateProvider.notifier).setPhoneVerified(true);
        context.go('/home');
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
      appBar: AppBar(title: const Text('تأكيد رقم الجوال')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                onChanged: (v) {
                  if (v.length == 6) _verify();
                },
              ),
              const SizedBox(height: 24),
              if (_loading)
                const CircularProgressIndicator()
              else
                TextButton(
                  onPressed: _remaining == 0 ? _sendOtp : null,
                  child: Text(_remaining > 0
                      ? 'إعادة إرسال الرمز (${_remaining}s)'
                      : 'إعادة إرسال الرمز'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
