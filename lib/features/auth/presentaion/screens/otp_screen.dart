import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../../../core/helpers/error_helper.dart';

/// OTP bypassed — kept for reference only.
class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;

  Future<void> _sendOtp() async {
    setState(() => _loading = true);
    final result = await ref.read(authServiceProvider).generateOtp(widget.phone);
    if (!mounted) return;
    setState(() => _loading = false);
    result.when(
      success: (_) {},
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(translateError(e))),
        );
      },
    );
  }

  Future<void> _verify() async {
    if (_codeController.text.length != 6) return;
    setState(() => _loading = true);
    final result = await ref.read(authServiceProvider).verifyOtp(
      widget.phone,
      _codeController.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    result.when(
      success: (_) {
        ref.read(authStateProvider.notifier).updatePhone(widget.phone);
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
  void dispose() {
    _codeController.dispose();
    super.dispose();
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
              Text('إلى رقم ${widget.phone}', style: TextStyle(
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
                  onPressed: _loading ? null : _sendOtp,
                  child: const Text('إعادة إرسال الرمز'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
