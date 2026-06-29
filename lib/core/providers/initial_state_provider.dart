import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/models/auth_state.dart';

final initialAuthProvider = Provider<AuthState?>((ref) => null);
