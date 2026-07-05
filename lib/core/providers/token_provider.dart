import 'package:app_platform_network/network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenManager {
  String? _token;
  String? get token => _token;
  final _secure = const FlutterSecureStorage();

  /// Used by ProviderScope override in main.dart (avoids async).
  void setLoadedToken(String t) => _token = t;

  Future<void> setToken(String t) async {
    _token = t;
    await _secure.write(key: 'auth_token', value: t);
  }

  Future<void> clear() async {
    _token = null;
    await _secure.delete(key: 'auth_token');
  }
}

final tokenManagerProvider = Provider<TokenManager>((ref) => TokenManager());

class AppTokenProvider implements TokenProvider {
  final Ref ref;
  AppTokenProvider(this.ref);

  @override
  Future<String?> getToken() async {
    final t = ref.read(tokenManagerProvider).token;
    return (t != null && t.isNotEmpty) ? t : null;
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override sharedPreferencesProvider in main()');
});
