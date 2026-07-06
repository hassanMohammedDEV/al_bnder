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

class PendingRegistration {
  final String phone;
  final String password;
  final String? name;
  PendingRegistration({required this.phone, required this.password, this.name});
}

final pendingRegistrationProvider = StateProvider<PendingRegistration?>((ref) => null);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final initial = ref.read(initialAuthProvider);
    if (initial != null) {
      if (initial.isLoggedIn && !initial.isProfileLoaded) {
        Future.microtask(() async {
          final result = await ref.read(authServiceProvider).getProfile();
          result.when(
            success: (profile) => updateProfile(profile),
            failure: (_) {
              state = const AuthState();
              _clearSession();
            },
          );
        });
      }
      return initial;
    }
    return const AuthState();
  }

  void updateName(String value) => state = state.copyWith(name: value);
  void updatePhone(String value) => state = state.copyWith(phone: value);
  void updatePassword(String value) => state = state.copyWith(password: value);
  void setLoggedIn(AuthState auth) {
    state = auth.copyWith(
      isLoggedIn: true,
      isProfileLoaded: state.isProfileLoaded,
      needsPhoneVerification: state.needsPhoneVerification,
    );
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
      phoneVerified: profile['phone_verified'] as bool? ?? state.phoneVerified,
      isProfileLoaded: true,
    );
    _saveSession(state);
  }

  void setPhoneVerified(bool value) {
    state = state.copyWith(phoneVerified: value, needsPhoneVerification: false);
    _saveSession(state);
  }

  void setNeedsPhoneVerification(bool value) {
    state = state.copyWith(needsPhoneVerification: value);
    _saveSession(state);
  }

  void setPendingPhone(String phone) {
    state = state.copyWith(phone: phone, pendingPhone: phone);
    _saveSession(state);
  }

  void clearPendingPhone() {
    state = state.copyWith(pendingPhone: '', clearPendingPhone: true);
    _saveSession(state);
  }

  void profileLoadFailed() {
    state = state.copyWith(isProfileLoaded: true);
  }

  void logout() {
    state = const AuthState();
    ref.invalidate(facilityGroupsProvider);
    ref.invalidate(facilitiesProvider);
    ref.invalidate(walletInfoFamilyProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(pendingBookingsProvider);
  }

  Future<void> logoutAndClear() async {
    await _clearSession();
    state = const AuthState();
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
      'phoneVerified': auth.phoneVerified,
      'needsPhoneVerification': auth.needsPhoneVerification,
      'userId': auth.userId,
      'role': auth.role,
      'facilityGroupId': auth.facilityGroupId,
      'pendingPhone': auth.pendingPhone,
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
  Future<Result<void>> resetPassword(String phone, String code, String newPassword) => _repo.resetPassword(phone, code, newPassword);
  Future<Result<Map<String, dynamic>>> updateName(String name) => _repo.updateName(name);
  Future<Result<Map<String, dynamic>>> changePassword(String password) => _repo.changePassword(password);
  Future<Result<void>> setPhoneVerifiedDb() => _repo.setPhoneVerifiedDb();
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

  Future<Result<void>> startRegistration(String phone, String password, {String? name}) async {
    const key = 'start_registration';
    state = state.start(key);
    ref.read(pendingRegistrationProvider.notifier).state = PendingRegistration(
      phone: phone, password: password, name: name,
    );
    ref.read(authStateProvider.notifier).setPendingPhone(phone);
    state = state.success(key);
    return Success(null);
  }

  Future<Result<AuthState>> completeRegistration() async {
    const key = 'complete_registration';
    state = state.start(key);
    final pending = ref.read(pendingRegistrationProvider);
    if (pending == null) {
      state = state.fail(key, NetworkError('لا توجد بيانات تسجيل'));
      return Failure(NetworkError('لا توجد بيانات تسجيل'));
    }
    try {
      final result = await ref.read(authServiceProvider).register(
        pending.phone, pending.password, name: pending.name,
      );
      if (result is Success<AuthState>) {
        await _fetchProfile();
        await ref.read(authServiceProvider).setPhoneVerifiedDb();
        ref.read(pendingRegistrationProvider.notifier).state = null;
        ref.read(authStateProvider.notifier).clearPendingPhone();
        ref.read(authStateProvider.notifier).setPhoneVerified(true);
        state = state.success(key);
        return result;
      } else if (result is Failure<AuthState>) {
        state = state.fail(key, result.error);
        return result;
      }
    } catch (e) {
      final err = NetworkError(e.toString());
      state = state.fail(key, err);
      return Failure(err);
    }
    const err = NetworkError('فشل التسجيل');
    state = state.fail(key, err);
    return Failure(err);
  }

  Future<Result<Map<String, dynamic>>> updateName(String name) async {
    const key = 'update_name';
    state = state.start(key);
    final result = await ref.read(authServiceProvider).updateName(name);
    result.when(
      success: (_) {
        ref.read(authStateProvider.notifier).updateName(name);
        state = state.success(key);
      },
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

  Future<Result<Map<String, dynamic>>> changePassword(String password) async {
    const key = 'change_password';
    state = state.start(key);
    final result = await ref.read(authServiceProvider).changePassword(password);
    result.when(
      success: (_) => state = state.success(key),
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

  Future<Result<void>> resetPassword(String phone, String code, String newPassword) async {
    const key = 'reset_password';
    state = state.start(key);
    final result = await ref.read(authServiceProvider).resetPassword(phone, code, newPassword);
    result.when(
      success: (_) => state = state.success(key),
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

  Future<Result<void>> deleteAccount() async {
    const key = 'delete_account';
    state = state.start(key);
    final result = await ref.read(authServiceProvider)._repo.deleteAccount();
    if (result is Success) {
      await ref.read(authStateProvider.notifier).logoutAndClear();
      state = state.success(key);
    } else if (result is Failure) {
      state = state.fail(key, result.error);
    }
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
