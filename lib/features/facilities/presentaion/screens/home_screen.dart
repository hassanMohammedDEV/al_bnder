import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../announcements/providers/announcement_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../bookings/presentaion/screens/my_bookings_screen.dart';
import '../../../settings/presentaion/screens/settings_screen.dart';
import '../../../wallet/presentaion/screens/wallet_screen.dart';
import '../../../admin/presentaion/screens/admin_dashboard_screen.dart';
import '../../../admin/presentaion/screens/pending_bookings_screen.dart';
import '../../../reports/presentaion/screens/reports_screen.dart';
import 'home_tab.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final role = auth.role;

    if (role == 'facility_admin' || role == 'super_admin') return _buildAdminShell();
    if (role == 'facility_viewer') return _buildViewerShell();
    return _buildUserShell();
  }

  Widget _bellBadge() {
    final count = ref.watch(unreadCountProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => context.push('/announcements'),
        ),
        if (count > 0)
          Positioned(
            left: 4, top: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUserShell() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('البندر'),
        actions: [_bellBadge()],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Offstage(offstage: _tabIndex != 0, child: const HomeTab()),
            Offstage(offstage: _tabIndex != 1, child: const MyBookingsScreen(inShell: true)),
            Offstage(offstage: _tabIndex != 2, child: const WalletScreen(inShell: true)),
            Offstage(offstage: _tabIndex != 3, child: SettingsScreen(inShell: true)),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'حجوزاتي'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'المحفظة'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'المزيد'),
        ],
      ),
    );
  }

  Widget _buildViewerShell() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('البندر'),
        actions: [_bellBadge()],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Offstage(offstage: _tabIndex != 0, child: const ReportsScreen(inShell: true)),
            Offstage(offstage: _tabIndex != 1, child: SettingsScreen(inShell: true)),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'التقارير'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'المزيد'),
        ],
      ),
    );
  }

  Widget _buildAdminShell() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('البندر'),
        actions: [_bellBadge()],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Offstage(offstage: _tabIndex != 0, child: const AdminDashboardScreen(inShell: true)),
            Offstage(offstage: _tabIndex != 1, child: const PendingBookingsScreen(inShell: true)),
            Offstage(offstage: _tabIndex != 2, child: const ReportsScreen(inShell: true)),
            Offstage(offstage: _tabIndex != 3, child: SettingsScreen(inShell: true)),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'لوحة التحكم'),
          NavigationDestination(icon: Icon(Icons.pending_actions_outlined), selectedIcon: Icon(Icons.pending_actions), label: 'الحجوزات'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'التقارير'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'المزيد'),
        ],
      ),
    );
  }
}
