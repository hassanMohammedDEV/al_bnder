import 'dart:convert';

import 'package:app_platform_core/core.dart';
import 'package:app_platform_state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/providers/initial_state_provider.dart';
import '../../../core/providers/token_provider.dart';
import '../../../features/facilities/providers/facility_provider.dart';
import '../../../features/wallet/providers/wallet_provider.dart';
import '../../../features/admin/providers/admin_provider.dart';
import '../models/auth_state.dart';
import '../repositories/auth_repository.dart';
import '../repositories/auth_repository_impl.dart';

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final initial = ref.read(initialAuthProvider);
    if (initial != null) return initial;
    return const AuthState();
  }

  void updateName(String value) => state = state.copyWith(name: value);
  void updatePhone(String value) => state = state.copyWith(phone: value);
  void updatePassword(String value) => state = state.copyWith(password: value);
  void setLoggedIn(AuthState auth) {
    state = auth.copyWith(isLoggedIn: true, isProfileLoaded: false);
    _saveSession(state);
    ref.invalidate(facilityGroupsProvider);
    ref.invalidate(facilitiesProvider);
    ref.invalidate(walletInfoFamilyProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(pendingBookingsProvider);
  }

  void updateProfile(Map<String, dynamic> profile) {
    state = state.copyWith(
      name: profile['full_name'] as String? ?? state.name,
      role: profile['role'] as String?,
      facilityGroupId: profile['facility_group_id'] as String?,
      isProfileLoaded: true,
    );
    _saveSession(state);
  }

  void profileLoadFailed() {
    state = state.copyWith(isProfileLoaded: true);
  }

  void logout() {
    state = const AuthState();
    _clearSession();
    ref.invalidate(facilityGroupsProvider);
    ref.invalidate(facilitiesProvider);
    ref.invalidate(walletInfoFamilyProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(pendingBookingsProvider);
  }

  Future<void> _saveSession(AuthState auth) async {
    const secure = FlutterSecureStorage();
    await secure.write(key: 'auth_session', value: jsonEncode({
      'name': auth.name,
      'phone': auth.phone,
      'isLoggedIn': auth.isLoggedIn,
      'isProfileLoaded': auth.isProfileLoaded,
      'userId': auth.userId,
      'role': auth.role,
      'facilityGroupId': auth.facilityGroupId,
    }));
  }

  Future<void> _clearSession() async {
    const secure = FlutterSecureStorage();
    await secure.delete(key: 'auth_session');
    await ref.read(tokenManagerProvider).clear();
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(repo: ref.read(authRepositoryProvider));
});

class AuthService {
  final AuthRepository _repo;
  AuthService({required AuthRepository repo}) : _repo = repo;

  Future<Result<void>> generateOtp(String phone) => _repo.generateOtp(phone);
  Future<Result<void>> verifyOtp(String phone, String code) => _repo.verifyOtp(phone, code);
  Future<Result<AuthState>> register(String phone, String password, {String? name}) => _repo.register(phone, password, name: name);
  Future<Result<AuthState>> login(String phone, String password) => _repo.login(phone, password);
  Future<Result<Map<String, dynamic>>> getProfile() => _repo.getProfile();
}

final authActionProvider = StateNotifierProvider<AuthActionNotifier, ActionStore>(
  (ref) => AuthActionNotifier(ref: ref),
);

class AuthActionNotifier extends StateNotifier<ActionStore> {
  AuthActionNotifier({required this.ref}) : super(ActionStore());

  final Ref ref;

  Future<Result<void>> generateOtp(String phone) async {
    const key = 'otp';
    state = state.start(key);
    final result = await ref.read(authServiceProvider).generateOtp(phone);
    result.when(
      success: (_) => state = state.success(key),
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

  Future<Result<void>> verifyOtp(String phone, String code) async {
    const key = 'verify';
    state = state.start(key);
    final result = await ref.read(authServiceProvider).verifyOtp(phone, code);
    result.when(
      success: (_) => state = state.success(key),
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

  Future<Result<AuthState>> login(String phone, String password) async {
    const key = 'login';
    state = state.start(key);
    final result = await ref.read(authServiceProvider).login(phone, password);
    if (result is Success<AuthState>) {
      ref.read(authStateProvider.notifier).setLoggedIn(result.data);
      await _fetchProfile();
      state = state.success(key);
    } else if (result is Failure<AuthState>) {
      state = state.fail(key, result.error);
    }
    return result;
  }

  Future<Result<AuthState>> register(String phone, String password, {String? name}) async {
    const key = 'register';
    state = state.start(key);
    final result = await ref.read(authServiceProvider).register(phone, password, name: name);
    if (result is Success<AuthState>) {
      ref.read(authStateProvider.notifier).setLoggedIn(result.data);
      await _fetchProfile();
      state = state.success(key);
    } else if (result is Failure<AuthState>) {
      state = state.fail(key, result.error);
    }
    return result;
  }

  Future<Result<void>> deleteAccount() async {
    const key = 'delete_account';
    state = state.start(key);
    final result = await ref.read(authServiceProvider)._repo.deleteAccount();
    result.when(
      success: (_) {
        ref.read(authStateProvider.notifier).logout();
        state = state.success(key);
      },
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

  Future<void> _fetchProfile() async {
    final result = await ref.read(authServiceProvider).getProfile();
    result.when(
      success: (profile) {
        ref.read(authStateProvider.notifier).updateProfile(profile);
      },
      failure: (_) {
        ref.read(authStateProvider.notifier).profileLoadFailed();
      },
    );
  }

  void reset() => state = ActionStore();
}
