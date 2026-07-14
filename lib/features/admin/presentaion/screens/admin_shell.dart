import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../announcements/providers/announcement_provider.dart';
import '../../../reports/presentaion/screens/reports_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_settings_screen.dart';
import 'pending_bookings_screen.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _tabIndex = 0;
  final _visitedTabs = <int>{0};

  void _selectTab(int i) {
    setState(() {
      _tabIndex = i;
      _visitedTabs.add(i);
    });
  }

  Widget _tab(int index, Widget child) =>
    _visitedTabs.contains(index) ? child : const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tabIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _selectTab(0);
      },
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(
          title: const Text('البندر | تجريبي'),
          actions: [
            IconButton(
              icon: const Icon(Icons.schedule),
              tooltip: 'الأوقات المتاحة',
              onPressed: () => context.push('/available-slots'),
            ),
            _bellBadge(),
          ],
        ),
        body: SafeArea(
          top: true,
          bottom: false,
          child: IndexedStack(
            index: _tabIndex,
            children: [
              const AdminDashboardScreen(inShell: true),
              _tab(1, const PendingBookingsScreen(inShell: true)),
              _tab(2, const ReportsScreen(inShell: true)),
              _tab(3, const AdminSettingsScreen()),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tabIndex,
          onDestinationSelected: _selectTab,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'لوحة التحكم'),
            NavigationDestination(icon: Icon(Icons.pending_actions_outlined), selectedIcon: Icon(Icons.pending_actions), label: 'الحجوزات'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'التقارير'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'المزيد'),
          ],
        ),
      ),
    );
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
}
