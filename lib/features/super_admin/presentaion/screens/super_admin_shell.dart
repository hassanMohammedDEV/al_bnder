import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../admin/presentaion/screens/admin_settings_screen.dart';
import '../../../admin/presentaion/screens/pending_bookings_screen.dart';
import '../../../reports/presentaion/screens/reports_screen.dart';
import 'cleanup_screen.dart';
import 'settlement_screen.dart';

class SuperAdminShell extends ConsumerStatefulWidget {
  const SuperAdminShell({super.key});

  @override
  ConsumerState<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends ConsumerState<SuperAdminShell> {
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
    final scheme = Theme.of(context).colorScheme;

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
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('مشرف عام', style: TextStyle(
                fontSize: 12, color: scheme.onTertiaryContainer, fontWeight: FontWeight.w500,
              )),
            ),
          ],
        ),
        body: SafeArea(
          child: IndexedStack(
            index: _tabIndex,
            children: [
              const SettlementScreen(),
              _tab(1, const PendingBookingsScreen(inShell: true)),
              _tab(2, const ReportsScreen(inShell: true)),
              _tab(3, const CleanupScreen()),
              _tab(4, const AdminSettingsScreen()),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tabIndex,
          onDestinationSelected: _selectTab,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.payments_outlined, color: scheme.onSurfaceVariant),
              selectedIcon: Icon(Icons.payments, color: scheme.primary),
              label: 'التسوية',
            ),
            NavigationDestination(
              icon: Icon(Icons.pending_actions_outlined, color: scheme.onSurfaceVariant),
              selectedIcon: Icon(Icons.pending_actions, color: scheme.primary),
              label: 'الحجوزات',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined, color: scheme.onSurfaceVariant),
              selectedIcon: Icon(Icons.bar_chart, color: scheme.primary),
              label: 'التقارير',
            ),
            NavigationDestination(
              icon: Icon(Icons.cleaning_services_outlined, color: scheme.onSurfaceVariant),
              selectedIcon: Icon(Icons.cleaning_services, color: scheme.primary),
              label: 'التنظيف',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: scheme.onSurfaceVariant),
              selectedIcon: Icon(Icons.person, color: scheme.primary),
              label: 'المزيد',
            ),
          ],
        ),
      ),
    );
  }
}
