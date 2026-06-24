import 'package:app_platform_network/network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../constants.dart';
import 'token_provider.dart';

final apiClientProvider = Provider<HttpApiClient>((ref) {
  return HttpApiClient(
    baseUrl: supabaseRestUrl,
    client: http.Client(),
    tokenProvider: AppTokenProvider(ref),
    defaultHeaders: {
      'apikey': supabaseAnonKey,
    },
  );
});

final authApiClientProvider = Provider<HttpApiClient>((ref) {
  return HttpApiClient(
    baseUrl: supabaseUrl,
    client: http.Client(),
    tokenProvider: AppTokenProvider(ref),
    defaultHeaders: {
      'apikey': supabaseAnonKey,
    },
  );
});
