import 'package:app_platform_network/network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenManager {
  String? _token;
  String? get token => _token;

  void setToken(String t) {
    _token = t;
    _persist();
  }

  Future<void> clear() async {
    _token = null;
    await _remove();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) {
      await prefs.setString('auth_token', _token!);
    }
  }

  Future<void> _remove() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
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
