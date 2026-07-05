import 'dart:convert';

import 'package:app_platform_core/core.dart';
import 'package:app_platform_network/network.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

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
  Future<Result<void>> deleteAccount() async {
    final token = _ref.read(tokenManagerProvider).token;
    final client = http.Client();
    try {
      final uri = Uri.parse('${supabaseRestUrl}rpc/delete_my_account');
      debugPrint('DELETE URI: $uri');
      final response = await client.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'apikey': supabaseAnonKey,
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'p_dummy': ''}),
      );
      debugPrint('DELETE status: ${response.statusCode}');
      debugPrint('DELETE body: ${response.body}');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Success(null);
      }
      return Failure(NotFoundError());
    } finally {
      client.close();
    }
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
  Future<Result<Map<String, dynamic>>> forgotPassword(String phone) {
    return _apiClient.post('rpc/forgot_password', body: {
      'p_phone': phone,
    }, parser: (json) {
      return (json as Map<String, dynamic>);
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> updateName(String name) {
    return _apiClient.post('rpc/update_my_profile', body: {
      'p_full_name': name,
    }, parser: (json) {
      return (json as Map<String, dynamic>);
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> changePassword(String newPassword) {
    return _apiClient.post('rpc/change_my_password', body: {
      'p_new_password': newPassword,
    }, parser: (json) {
      return (json as Map<String, dynamic>);
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
