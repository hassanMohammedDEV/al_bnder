import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../../../core/helpers/error_helper.dart';
import '../../../../presentaion/shared/app_text_field.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/auth_validation_provider.dart';
import '../../repositories/auth_repository_impl.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _hasBiometrics = false;
  bool _biometricChecked = false;

  @override
  void initState() {
    super.initState();
    _loadSavedPhone();
    _checkBiometrics();
  }

  Future<void> _loadSavedPhone() async {
    const secure = FlutterSecureStorage();
    final phone = await secure.read(key: 'remembered_phone');
    if (phone != null && phone.isNotEmpty && mounted) {
      ref.read(authStateProvider.notifier).updatePhone(phone);
    }
  }

  Future<void> _checkBiometrics() async {
    try {
      final creds = await AuthRepositoryImpl.getBiometricCredentials();
      if (creds != null && mounted) {
        final localAuth = LocalAuthentication();
        final canCheck = await localAuth.canCheckBiometrics;
        if (canCheck && mounted) {
          final enrolled = await localAuth.isDeviceSupported();
          if (mounted) {
            setState(() {
              _hasBiometrics = enrolled;
              _biometricChecked = true;
            });
          }
        } else if (mounted) {
          setState(() => _biometricChecked = true);
        }
      } else if (mounted) {
        setState(() => _biometricChecked = true);
      }
    } catch (_) {
      if (mounted) setState(() => _biometricChecked = true);
    }
  }

  Future<void> _loginWithBiometrics() async {
    try {
      final localAuth = LocalAuthentication();
      final authed = await localAuth.authenticate(
        localizedReason: 'استخدم بصمتك لتسجيل الدخول',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (!authed || !mounted) return;

      final creds = await AuthRepositoryImpl.getBiometricCredentials();
      if (creds == null || !mounted) return;

      ref.read(authStateProvider.notifier).updatePhone(creds['phone']!);
      ref.read(authStateProvider.notifier).updatePassword(creds['password']!);

      final action = ref.read(authActionProvider.notifier);
      final result = await action.login(creds['phone']!, creds['password']!);
      if (!mounted) return;
      result.when(
        success: (_) {},
        failure: (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(translateError(e))),
          );
        },
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشلت البصمة، حاول مرة أخرى')),
        );
      }
    }
  }

  Future<void> login() async {
    FocusScope.of(context).unfocus();
    ref.read(authValidationProvider.notifier)
        .validateStep([AuthFields.phone, AuthFields.password]);
    if (!ref.read(authValidationProvider).isValid) return;

    final phone = ref.read(authStateProvider).phone;
    final password = ref.read(authStateProvider).password;
    final result = await ref.read(authActionProvider.notifier).login(phone, password);
    if (!mounted) return;

    result.when(
      success: (_) {
        AuthRepositoryImpl.saveBiometricCredentials(phone, password);
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
    final validation = ref.watch(authValidationProvider);
    final action = ref.watch(authActionProvider);

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
              if (_hasBiometrics && _biometricChecked) ...[
                OutlinedButton.icon(
                  onPressed: action.isLoading('login') ? null : _loginWithBiometrics,
                  icon: Icon(Icons.fingerprint, color: scheme.primary),
                  label: Text('بصمة الدخول', style: TextStyle(color: scheme.primary)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: action.isLoading('login') ? null : login,
                child: action.isLoading('login')
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('دخول', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.push('/forgot-password'),
                child: const Text('نسيت كلمة السر؟'),
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
