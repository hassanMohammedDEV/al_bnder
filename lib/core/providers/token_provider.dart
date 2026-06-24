import 'package:app_platform_network/network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final tokenManagerProvider = NotifierProvider<TokenManager, String?>(TokenManager.new);

class TokenManager extends Notifier<String?> {
  @override
  String? build() => null;

  void setToken(String token) => state = token;
  void clear() => state = null;
}

class AppTokenProvider implements TokenProvider {
  final Ref ref;
  AppTokenProvider(this.ref);

  @override
  Future<String> getToken() async => ref.read(tokenManagerProvider) ?? '';
}
