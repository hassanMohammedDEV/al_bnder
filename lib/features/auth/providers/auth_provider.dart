import 'dart:async';
import 'dart:convert';

import 'package:app_platform_core/core.dart';
import 'package:app_platform_state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/providers/token_provider.dart';
import '../../../features/facilities/providers/facility_provider.dart';
import '../../../features/facilities/providers/selected_group_provider.dart';
import '../../../features/wallet/providers/wallet_provider.dart';
import '../../../features/admin/providers/admin_provider.dart';
import '../../../features/announcements/repositories/announcement_repository_impl.dart';
import '../../../features/announcements/providers/announcement_provider.dart';
import '../../../features/announcements/providers/local_notification_provider.dart';
import '../../../features/bookings/providers/booking_provider.dart';
import '../../../features/player_ads/providers/player_ad_provider.dart';
import '../../../features/ads/providers/ads_provider.dart';
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
    Future.microtask(() async {
      try {
        const secure = FlutterSecureStorage();
        final savedSession = await secure
            .read(key: 'auth_session')
            .timeout(const Duration(seconds: 10));
        final savedToken = await secure
            .read(key: 'auth_token')
            .timeout(const Duration(seconds: 10));
        if (savedSession != null) {
          final map = jsonDecode(savedSession) as Map<String, dynamic>;
          final initial = AuthState(
            name: map['name'] as String? ?? '',
            phone: map['phone'] as String? ?? '',
            isLoggedIn: map['isLoggedIn'] as bool? ?? false,
            isProfileLoaded: map['isProfileLoaded'] as bool? ?? false,
            phoneVerified: map['phoneVerified'] as bool? ?? false,
            needsPhoneVerification: false,
            userId: map['userId'] as String?,
            role: map['role'] as String?,
            facilityGroupId: map['facility_group_id'] as String?,
            pendingPhone: map['pendingPhone'] as String?,
          );

          if (savedToken != null && savedToken.isNotEmpty) {
            ref.read(tokenManagerProvider).setLoadedToken(savedToken);
          }

          if (initial.phone.isNotEmpty) {
            await secure.write(key: 'remembered_phone', value: initial.phone);
          }

          state = initial.copyWith(isLoading: false);

          if (initial.isLoggedIn) {
            final result = await ref.read(authServiceProvider).getProfile();
            result.when(
              success: (profile) {
                updateProfile(profile);
              },
              failure: (_) {
                state = const AuthState();
                _clearSession();
              },
            );
          }
        } else {
          state = const AuthState();
        }
      } on TimeoutException {
        state = const AuthState();
      } catch (_) {
        state = const AuthState();
        _clearSession();
      }
    });
    return const AuthState(isLoading: true);
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
    ref.invalidate(walletInfoProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(pendingBookingsProvider);
    ref.invalidate(myBookingsProvider);
    ref.invalidate(selectedGroupProvider);
    ref.invalidate(announcementsProvider);
    ref.invalidate(unreadCountProvider);
    ref.invalidate(playerAdsProvider);
    ref.invalidate(reportedPlayerAdsProvider);
    ref.invalidate(adsProvider);
    ref.invalidate(bookingFormProvider);
  }

  void updateProfile(Map<String, dynamic> profile) {
    final verified = profile['phone_verified'] as bool? ?? state.phoneVerified;
    state = state.copyWith(
      name: profile['full_name'] as String? ?? state.name,
      role: profile['role'] as String?,
      facilityGroupId: profile['facility_group_id'] as String?,
      phoneVerified: verified,
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
    _clearSession();
    ref.read(localNotificationsProvider.notifier).clear();
    unawaited(ref.read(sharedPreferencesProvider).remove('selected_group_id'));
    ref.invalidate(facilityGroupsProvider);
    ref.invalidate(facilitiesProvider);
    ref.invalidate(walletInfoFamilyProvider);
    ref.invalidate(walletInfoProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(pendingBookingsProvider);
    ref.invalidate(myBookingsProvider);
    ref.invalidate(selectedGroupProvider);
    ref.invalidate(announcementsProvider);
    ref.invalidate(unreadCountProvider);
    ref.invalidate(playerAdsProvider);
    ref.invalidate(reportedPlayerAdsProvider);
    ref.invalidate(adsProvider);
    ref.invalidate(bookingFormProvider);
    ref.invalidate(localNotificationsProvider);
  }

  Future<void> logoutAndClear() async {
    await _clearSession();
    await ref.read(localNotificationsProvider.notifier).clear();
    await ref.read(sharedPreferencesProvider).remove('selected_group_id');
    state = const AuthState();
    ref.invalidate(facilityGroupsProvider);
    ref.invalidate(facilitiesProvider);
    ref.invalidate(walletInfoFamilyProvider);
    ref.invalidate(walletInfoProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(pendingBookingsProvider);
    ref.invalidate(myBookingsProvider);
    ref.invalidate(selectedGroupProvider);
    ref.invalidate(announcementsProvider);
    ref.invalidate(unreadCountProvider);
    ref.invalidate(playerAdsProvider);
    ref.invalidate(reportedPlayerAdsProvider);
    ref.invalidate(adsProvider);
    ref.invalidate(bookingFormProvider);
    ref.invalidate(localNotificationsProvider);
  }

  Future<void> _saveSession(AuthState auth) async {
    const secure = FlutterSecureStorage();
    await secure.write(key: 'auth_session', value: jsonEncode({
      'name': auth.name,
      'phone': auth.phone,
      'isLoggedIn': auth.isLoggedIn,
      'isProfileLoaded': auth.isProfileLoaded,
      'phoneVerified': auth.phoneVerified,
      'userId': auth.userId,
      'role': auth.role,
      'facilityGroupId': auth.facilityGroupId,
      'pendingPhone': auth.pendingPhone,
    }));
    if (auth.phone.isNotEmpty) {
      await secure.write(key: 'remembered_phone', value: auth.phone);
    }
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
  AuthService({required AuthRepository repo}) : _repo = repo; // ignore: prefer_initializing_formals

  Future<Result<void>> generateOtp(String phone) => _repo.generateOtp(phone);
  Future<Result<void>> verifyOtp(String phone, String code) => _repo.verifyOtp(phone, code);
  Future<Result<bool>> checkOtp(String phone, String code) => _repo.checkOtp(phone, code);
  Future<Result<bool>> checkPhone(String phone) => _repo.checkPhone(phone);
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
      ref.read(authStateProvider.notifier).setPhoneVerified(true);
      state = state.success(key);
      AuthRepositoryImpl.saveBiometricCredentials(phone, password);
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
        await ref.read(authServiceProvider).setPhoneVerifiedDb();
        await _fetchProfile();
        await ref.read(announcementRepositoryProvider).markAllAnnouncementsRead();
        ref.read(authStateProvider.notifier).setPhoneVerified(true);
        ref.read(pendingRegistrationProvider.notifier).state = null;
        ref.read(authStateProvider.notifier).clearPendingPhone();
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
