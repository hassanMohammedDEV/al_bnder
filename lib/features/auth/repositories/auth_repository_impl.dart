import 'package:app_platform_core/core.dart';
import 'package:app_platform_network/network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
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
  Future<Result<Map<String, dynamic>>> getProfile() {
    return _apiClient.post('rpc/get_my_profile', body: {}, parser: (json) {
      return (json as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    });
  }

  @override
  Future<Result<AuthState>> login(String phone, String password) async {
    final email = '$phone@al-bndr.app';
    return _authApiClient.post('auth/v1/token?grant_type=password',
        body: {
      'email': email,
      'password': password,
    },
        headers: {
      'Authorization': 'Bearer $supabaseAnonKey',
    },
        parser: (json) {
      final map = json as Map<String, dynamic>;
      final accessToken = map['access_token'] as String?;
      if (accessToken != null) {
        _ref.read(tokenManagerProvider).setToken(accessToken);
      }
      return AuthState(
        phone: phone,
        userId: map['user']?['id'],
        isLoggedIn: true,
      );
    });
  }

  @override
  Future<Result<AuthState>> register(String phone, String password,
      {String? name}) async {
    final email = '$phone@al-bndr.app';
    return _authApiClient.post('auth/v1/signup',
        body: {
      'email': email,
      'password': password,
      'data': {
        'name': name ?? '',
        'phone': phone,
      },
    },
        headers: {
      'Authorization': 'Bearer $supabaseAnonKey',
    },
        parser: (json) {
      final map = json as Map<String, dynamic>;
      final accessToken = map['access_token'] as String?;
      if (accessToken != null) {
        _ref.read(tokenManagerProvider).setToken(accessToken);
      }
      return AuthState(
        name: name ?? '',
        phone: phone,
        userId: map['user']?['id'],
        isLoggedIn: true,
      );
    });
  }
}
