import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../admin/presentaion/screens/admin_shell.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../shared/presentaion/screens/viewer_shell.dart';
import '../../../super_admin/presentaion/screens/super_admin_shell.dart';
import '../../../user/presentaion/screens/user_shell.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authStateProvider).role;

    if (role == 'super_admin') return const SuperAdminShell();
    if (role == 'facility_admin') return const AdminShell();
    if (role == 'facility_viewer') return const ViewerShell();
    return const UserShell();
  }
}
