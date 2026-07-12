import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../reports/presentaion/screens/reports_screen.dart';
import 'simple_settings_screen.dart';

class ViewerShell extends ConsumerStatefulWidget {
  const ViewerShell({super.key});

  @override
  ConsumerState<ViewerShell> createState() => _ViewerShellState();
}

class _ViewerShellState extends ConsumerState<ViewerShell> {
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
        appBar: AppBar(
          title: const Text('البندر'),
        ),
        body: SafeArea(
          child: IndexedStack(
            index: _tabIndex,
            children: [
              const ReportsScreen(inShell: true),
              _tab(1, const SimpleSettingsScreen()),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tabIndex,
          onDestinationSelected: _selectTab,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'التقارير'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'المزيد'),
          ],
        ),
      ),
    );
  }
}
