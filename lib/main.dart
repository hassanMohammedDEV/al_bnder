import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/providers/initial_state_provider.dart';
import 'core/providers/token_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/models/auth_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');

  final secure = const FlutterSecureStorage();
  final savedSession = await secure.read(key: 'auth_session');
  final savedToken = await secure.read(key: 'auth_token');

  AuthState? initialAuth;
  if (savedSession != null) {
    final map = jsonDecode(savedSession) as Map<String, dynamic>;
    initialAuth = AuthState(
      name: map['name'] as String? ?? '',
      phone: map['pendingPhone'] as String? ?? map['phone'] as String? ?? '',
      isLoggedIn: map['isLoggedIn'] as bool? ?? false,
      isProfileLoaded: map['isProfileLoaded'] as bool? ?? false,
      phoneVerified: map['phoneVerified'] as bool? ?? false,
      needsPhoneVerification: map['needsPhoneVerification'] as bool? ?? false,
      userId: map['userId'] as String?,
      role: map['role'] as String?,
      facilityGroupId: map['facilityGroupId'] as String?,
      pendingPhone: map['pendingPhone'] as String?,
    );
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        initialAuthProvider.overrideWithValue(initialAuth),
        if (savedToken != null && savedToken.isNotEmpty)
          tokenManagerProvider.overrideWith((ref) {
            final tm = TokenManager();
            tm.setLoadedToken(savedToken);
            return tm;
          }),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const AlBndrApp(),
    ),
  );
}

class AlBndrApp extends ConsumerWidget {
  const AlBndrApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'البندر',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
    );
  }
}
