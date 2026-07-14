import 'dart:convert';

import 'package:app_platform_core/core.dart';
import 'package:app_platform_network/network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../constants.dart';
import 'token_provider.dart';
import '../../features/auth/providers/auth_provider.dart';

class _SessionAwareClient extends http.BaseClient {
  final http.Client inner;
  final void Function() onUnauthorized;

  _SessionAwareClient({required this.inner, required this.onUnauthorized});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await inner.send(request);
    if (response.statusCode == 401) {
      onUnauthorized();
    }
    return response;
  }

  @override
  void close() => inner.close();
}

String _extractErrorMessage(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final msg = decoded['msg'] as String?
          ?? decoded['message'] as String?
          ?? decoded['error'] as String?
          ?? decoded['error_description'] as String?;
      if (msg != null && msg.isNotEmpty) return msg;
    }
  } catch (_) {}
  return body;
}

Result<T> _responseHandler<T>(http.Response response, JsonParser<T> parser) {
  if (response.statusCode >= 200 && response.statusCode < 300) {
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {}
    }
    if (decoded is Map<String, dynamic> && decoded['success'] == false) {
      return Failure(NetworkError(_extractErrorMessage(response.body)));
    }
    return Success(parser(decoded));
  }
  final msg = _extractErrorMessage(response.body);
  switch (response.statusCode) {
    case 400:
      return Failure(NetworkError(msg));
    case 401:
      return Failure(const UnauthorizedError());
    case 403:
      return Failure(const ForbiddenError());
    case 404:
      return Failure(const NotFoundError());
    case 422:
      dynamic decodedBody;
      try {
        decodedBody = jsonDecode(response.body);
      } catch (_) {}
      return Failure(ValidationError(msg,
          fields: decodedBody is Map ? decodedBody['errors'] : null));
    default:
      return Failure(ServerError(response.statusCode, msg));
  }
}

final apiClientProvider = Provider<HttpApiClient>((ref) {
  return HttpApiClient(
    baseUrl: supabaseRestUrl,
    client: _SessionAwareClient(
      inner: http.Client(),
      onUnauthorized: () {
        Future.microtask(() async {
          await ref.read(tokenManagerProvider).clear();
          ref.read(authStateProvider.notifier).logout();
        });
      },
    ),
    customHandler: _responseHandler,
    tokenProvider: AppTokenProvider(ref),
    timeout: const Duration(seconds: 15),
    defaultHeaders: {
      'apikey': supabaseAnonKey,
    },
  );
});

final authApiClientProvider = Provider<HttpApiClient>((ref) {
  return HttpApiClient(
    baseUrl: supabaseUrl,
    client: http.Client(),
    customHandler: _responseHandler,
    tokenProvider: AppTokenProvider(ref),
    timeout: const Duration(seconds: 15),
    defaultHeaders: {
      'apikey': supabaseAnonKey,
    },
  );
});
