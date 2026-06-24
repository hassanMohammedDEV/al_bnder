import 'package:app_platform_core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_state.dart';
import '../repositories/auth_repository_impl.dart';

class ActionState {
  final Map<String, bool> loading;
  final Map<String, String?> errors;
  const ActionState({this.loading = const {}, this.errors = const {}});

  ActionState start(String key) => ActionState(
    loading: {...loading, key: true},
    errors: {...errors, key: null},
  );

  ActionState success(String key) => ActionState(
    loading: {...loading, key: false},
    errors: {...errors, key: null},
  );

  ActionState fail(String key, String error) => ActionState(
    loading: {...loading, key: false},
    errors: {...errors, key: error},
  );

  bool isLoading(String key) => loading[key] ?? false;
  String? error(String key) => errors[key];
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final authActionProvider = NotifierProvider<AuthActionNotifier, ActionState>(
  AuthActionNotifier.new,
);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  void updatePhone(String value) => state = state.copyWith(phone: value);
  void updatePassword(String value) => state = state.copyWith(password: value);
  void setLoggedIn(AuthState auth) => state = auth.copyWith(isLoggedIn: true);
  void logout() => state = const AuthState();
}

class AuthActionNotifier extends Notifier<ActionState> {
  @override
  ActionState build() => const ActionState();

  Future<Result<void>> generateOtp(String phone) async {
    state = state.start('otp');
    final result = await ref.read(authRepositoryProvider).generateOtp(phone);
    result.when(
      success: (_) => state = state.success('otp'),
      failure: (e) => state = state.fail('otp', e.message),
    );
    return result;
  }

  Future<Result<void>> verifyOtp(String phone, String code) async {
    state = state.start('verify');
    final result = await ref.read(authRepositoryProvider).verifyOtp(phone, code);
    result.when(
      success: (_) => state = state.success('verify'),
      failure: (e) => state = state.fail('verify', e.message),
    );
    return result;
  }

  Future<Result<AuthState>> register(String phone, String password) async {
    state = state.start('register');
    final result = await ref.read(authRepositoryProvider).register(phone, password);
    result.when(
      success: (data) => state = state.success('register'),
      failure: (e) => state = state.fail('register', e.message),
    );
    return result;
  }

  void reset() => state = const ActionState();
}
