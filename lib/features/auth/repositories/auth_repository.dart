import 'package:app_platform_core/core.dart';

import '../models/auth_state.dart';

abstract class AuthRepository {
  Future<Result<void>> generateOtp(String phone);
  Future<Result<void>> verifyOtp(String phone, String code);
  Future<Result<AuthState>> login(String phone, String password);
  Future<Result<AuthState>> register(String phone, String password);
}
