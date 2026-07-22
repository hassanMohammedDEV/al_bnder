import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../../../core/helpers/error_helper.dart';
import '../../../announcements/providers/local_notification_provider.dart';

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
  String get _phone {
    final pending = ref.read(pendingRegistrationProvider);
    if (pending != null) return pending.phone;
    return ref.read(authStateProvider).phone;
  }

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

  void _goBackToLogin() {
    final pending = ref.read(pendingRegistrationProvider);
    if (pending != null) {
      ref.read(authStateProvider.notifier).clearPendingPhone();
      ref.read(pendingRegistrationProvider.notifier).state = null;
      ref.read(authStateProvider.notifier).logout();
      context.go('/register');
    } else {
      ref.read(authStateProvider.notifier).logout();
      context.go('/login');
    }
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
    if (!mounted) { _loading = false; return; }

    result.when(
      success: (_) async {
        final pending = ref.read(pendingRegistrationProvider);
        if (pending != null) {
          final regResult = await ref.read(authActionProvider.notifier).completeRegistration();
          if (!mounted) { _loading = false; return; }
          regResult.when(
            success: (auth) {
              ref.read(authStateProvider.notifier).setLoggedIn(auth);
              ref.read(localNotificationsProvider.notifier).add(
                LocalNotification(
                  id: 'welcome',
                  type: 'welcome',
                  title: '🎉 أهلاً بك يابطل في ملاعب البندر!',
                  body: 'نحن سعداء بانضمامك إلينا! استعد لعيش تجارب رياضية لا تُنسى مع أفضل الملاعب. سجل حجزك الآن وابدأ رحلتك ⚽',
                  createdAt: DateTime.now(),
                ),
              );
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _loading = false;
                  context.go('/home');
                }
              });
            },
            failure: (e) {
              setState(() => _loading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(translateError(e))),
              );
            },
          );
        } else {
          if (ref.read(authStateProvider).isLoggedIn) {
            ref.read(authStateProvider.notifier).setPhoneVerified(true);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _loading = false;
                context.go('/home');
              }
            });
          } else {
            setState(() => _loading = false);
            ref.read(authStateProvider.notifier).clearPendingPhone();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('انتهت صلاحية الجلسة، يرجى التسجيل مرة أخرى')),
              );
              context.go('/register');
            }
          }
        }
      },
      failure: (e) {
        setState(() => _loading = false);
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
        title: const Text('تأكيد رقم الجوال'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBackToLogin,
        ),
      ),
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
              const Spacer(),
              TextButton.icon(
                onPressed: _goBackToLogin,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('رقم خطأ؟ سجل برقم جديد'),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
