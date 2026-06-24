import 'package:app_platform_core/core.dart';
import 'package:app_platform_network/network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/api_client_provider.dart';
import '../../../core/providers/token_provider.dart';
import '../models/auth_state.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    apiClient: ref.read(apiClientProvider),
    authApiClient: ref.read(authApiClientProvider),
    ref: ref,
  );
});

class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _apiClient;
  final ApiClient _authApiClient;
  final Ref _ref;

  AuthRepositoryImpl({
    required ApiClient apiClient,
    required ApiClient authApiClient,
    required Ref ref,
  })  : _apiClient = apiClient,
        _authApiClient = authApiClient,
        _ref = ref;

  @override
  Future<Result<void>> generateOtp(String phone) async {
    return _apiClient.post('rpc/generate_otp', body: {
      'p_phone': phone,
      'p_purpose': 'registration',
    }, parser: (_) {});
  }

  @override
  Future<Result<void>> verifyOtp(String phone, String code) async {
    return _apiClient.post('rpc/verify_otp', body: {
      'p_phone': phone,
      'p_code': code,
      'p_purpose': 'registration',
    }, parser: (_) {});
  }

  @override
  Future<Result<AuthState>> login(String phone, String password) async {
    return _authApiClient.post('auth/v1/token?grant_type=password', body: {
      'phone': phone,
      'password': password,
    }, parser: (json) {
      final map = json as Map<String, dynamic>;
      final accessToken = map['access_token'] as String?;
      if (accessToken != null) {
        _ref.read(tokenManagerProvider.notifier).setToken(accessToken);
      }
      return AuthState(
        isLoggedIn: true,
        userId: map['user']?['id'],
      );
    });
  }

  @override
  Future<Result<AuthState>> register(String phone, String password) async {
    return _authApiClient.post('auth/v1/signup', body: {
      'phone': phone,
      'password': password,
    }, parser: (json) {
      final map = json as Map<String, dynamic>;
      final accessToken = map['access_token'] as String?;
      if (accessToken != null) {
        _ref.read(tokenManagerProvider.notifier).setToken(accessToken);
      }
      return AuthState(
        isLoggedIn: true,
        userId: map['user']?['id'],
      );
    });
  }
}
