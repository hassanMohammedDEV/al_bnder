import 'package:app_platform_core/core.dart';

import '../models/auth_state.dart';

abstract class AuthRepository {
  Future<Result<void>> generateOtp(String phone);
  Future<Result<void>> verifyOtp(String phone, String code);
  Future<Result<bool>> checkOtp(String phone, String code);
  Future<Result<bool>> checkPhone(String phone);
  Future<Result<AuthState>> login(String phone, String password);
  Future<Result<AuthState>> register(String phone, String password, {String? name});
  Future<Result<Map<String, dynamic>>> getProfile();
  Future<Result<void>> deleteAccount();
  Future<Result<void>> resetPassword(String phone, String code, String newPassword);
  Future<Result<Map<String, dynamic>>> updateName(String name);
  Future<Result<Map<String, dynamic>>> changePassword(String newPassword);
  Future<Result<void>> setPhoneVerifiedDb();
}
