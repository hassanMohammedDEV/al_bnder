import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../announcements/providers/announcement_provider.dart';
import '../../../bookings/presentaion/screens/my_bookings_screen.dart';
import '../../../facilities/presentaion/screens/home_tab.dart';
import '../../../wallet/presentaion/screens/wallet_screen.dart';
import 'user_settings_screen.dart';

class UserShell extends ConsumerStatefulWidget {
  const UserShell({super.key});

  @override
  ConsumerState<UserShell> createState() => _UserShellState();
}

class _UserShellState extends ConsumerState<UserShell> {
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
          child: IndexedStack(
            index: _tabIndex,
            children: [
              const HomeTab(),
              _tab(1, const MyBookingsScreen(inShell: true)),
              _tab(2, const WalletScreen(inShell: true)),
              _tab(3, const UserSettingsScreen()),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tabIndex,
          onDestinationSelected: _selectTab,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'حجوزاتي'),
            NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'المحفظة'),
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
