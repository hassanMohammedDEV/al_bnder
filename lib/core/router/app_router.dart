import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentaion/screens/login_screen.dart';
import '../../features/auth/presentaion/screens/register_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
// OTP bypassed
// import '../../features/auth/presentaion/screens/otp_screen.dart';
import '../../features/facilities/models/facility.dart';
import '../../features/facilities/presentaion/screens/home_screen.dart';
import '../../features/facilities/presentaion/screens/facilities_screen.dart';
import '../../features/bookings/presentaion/screens/create_booking_screen.dart';
import '../../features/bookings/presentaion/screens/my_bookings_screen.dart';
import '../../features/bookings/presentaion/screens/booking_detail_screen.dart';
import '../../features/wallet/presentaion/screens/wallet_screen.dart';
import '../../features/admin/presentaion/screens/admin_create_booking_screen.dart';
import '../../features/admin/presentaion/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentaion/screens/pending_bookings_screen.dart';
import '../../features/admin/presentaion/screens/manage_facilities_screen.dart';
import '../../features/admin/presentaion/screens/manage_ads_screen.dart';
import '../../features/admin/presentaion/screens/create_edit_ad_screen.dart';
import '../../features/admin/presentaion/screens/deposit_screen.dart';
import '../../features/admin/presentaion/screens/scan_qr_screen.dart';
import '../../features/admin/presentaion/screens/group_settings_screen.dart';
import '../../features/admin/presentaion/screens/admin_today_bookings_screen.dart';
import '../../features/admin/presentaion/screens/admin_user_wallet_screen.dart';
import '../../features/admin/presentaion/screens/admin_search_bookings_screen.dart';
import '../../features/reports/presentaion/screens/reports_screen.dart';
import '../../features/ads/models/facility_ad.dart';
import '../../features/announcements/presentaion/screens/announcements_screen.dart';
import '../../features/announcements/presentaion/screens/create_announcement_screen.dart';
import '../../features/availability/presentaion/screens/available_slots_screen.dart';
import '../../features/settings/presentaion/screens/settings_screen.dart';
import '../../features/settings/presentaion/screens/privacy_policy_screen.dart';
import '../../features/settings/presentaion/screens/terms_screen.dart';
import '../../features/player_ads/presentaion/screens/player_ads_screen.dart';
import '../../features/player_ads/presentaion/screens/create_player_ad_screen.dart';
import '../../features/player_ads/presentaion/screens/create_official_player_ad_screen.dart';
import '../../features/player_ads/presentaion/screens/reported_ads_screen.dart';
import '../../features/player_ads/presentaion/screens/banned_users_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final isLoggedIn = auth.isLoggedIn;
      final profileLoaded = auth.isProfileLoaded;
      final location = state.matchedLocation;
      final isAuthRoute = location == '/login' || location == '/register';

      if (isLoggedIn && profileLoaded && isAuthRoute) return '/home';
      if (!isLoggedIn && !isAuthRoute && location != '/register') return '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/login', pageBuilder: (_, __) => const CupertinoPage(child: LoginScreen())),
      GoRoute(path: '/register', pageBuilder: (_, __) => const CupertinoPage(child: RegisterScreen())),
      // /verify-otp bypassed
      GoRoute(path: '/home', pageBuilder: (_, __) => const CupertinoPage(child: HomeScreen())),
      GoRoute(
        path: '/facilities/:groupId',
        pageBuilder: (_, state) => CupertinoPage(
          child: FacilitiesScreen(
            groupId: state.pathParameters['groupId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/create-booking',
        pageBuilder: (_, state) => CupertinoPage(
          child: CreateBookingScreen(
            facility: state.extra as Facility,
          ),
        ),
      ),
      GoRoute(path: '/my-bookings', pageBuilder: (_, __) => const CupertinoPage(child: MyBookingsScreen())),
      GoRoute(
        path: '/booking/:id',
        pageBuilder: (_, state) => CupertinoPage(
          child: BookingDetailScreen(
            bookingId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(path: '/wallet', pageBuilder: (_, __) => const CupertinoPage(child: WalletScreen())),
      GoRoute(
        path: '/admin/dashboard',
        pageBuilder: (_, __) => const CupertinoPage(child: AdminDashboardScreen()),
      ),
      GoRoute(
        path: '/admin/pending',
        pageBuilder: (_, __) => const CupertinoPage(child: PendingBookingsScreen()),
      ),
      GoRoute(
        path: '/admin/facilities',
        pageBuilder: (_, __) => const CupertinoPage(child: ManageFacilitiesScreen()),
      ),
      GoRoute(
        path: '/admin/ads',
        pageBuilder: (_, __) => const CupertinoPage(child: ManageAdsScreen()),
      ),
      GoRoute(
        path: '/admin/ads/create',
        pageBuilder: (_, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            return CupertinoPage(
              child: CreateEditAdScreen(
                facilityGroupId: extra['facilityGroupId'] as String,
                ad: extra['ad'] as FacilityAd?,
              ),
            );
          }
          return CupertinoPage(
            child: CreateEditAdScreen(
              facilityGroupId: extra as String,
            ),
          );
        },
      ),
      GoRoute(
        path: '/admin/deposit',
        pageBuilder: (_, __) => const CupertinoPage(child: DepositScreen()),
      ),
      GoRoute(
        path: '/admin/create-booking',
        pageBuilder: (_, __) => const CupertinoPage(child: AdminCreateBookingScreen()),
      ),
      GoRoute(
        path: '/admin/scan-qr',
        pageBuilder: (_, __) => const CupertinoPage(child: ScanQrScreen()),
      ),
      GoRoute(
        path: '/admin/search-bookings',
        pageBuilder: (_, __) => const CupertinoPage(child: AdminSearchBookingsScreen()),
      ),
      GoRoute(
        path: '/admin/reports',
        pageBuilder: (_, __) => const CupertinoPage(child: ReportsScreen()),
      ),
      GoRoute(
        path: '/admin/settings',
        pageBuilder: (_, __) => const CupertinoPage(child: GroupSettingsScreen()),
      ),
      GoRoute(
        path: '/admin/today-bookings',
        pageBuilder: (_, state) => CupertinoPage(
          child: AdminTodayBookingsScreen(
            facilityGroupId: state.extra as String,
          ),
        ),
      ),
      GoRoute(
        path: '/admin/user-wallet',
        pageBuilder: (_, state) {
          final args = state.extra as Map<String, String>;
          return CupertinoPage(
            child: AdminUserWalletScreen(
              userId: args['userId']!,
              groupId: args['groupId']!,
              userName: args['userName']!,
            ),
          );
        },
      ),
      GoRoute(path: '/settings', pageBuilder: (_, __) => const CupertinoPage(child: SettingsScreen())),
      GoRoute(path: '/announcements', pageBuilder: (_, __) => const CupertinoPage(child: AnnouncementsScreen())),
      GoRoute(path: '/available-slots', pageBuilder: (_, __) => const CupertinoPage(child: AvailableSlotsScreen())),
      GoRoute(path: '/admin/create-announcement', pageBuilder: (_, __) => const CupertinoPage(child: CreateAnnouncementScreen())),
      GoRoute(path: '/player-ads', pageBuilder: (_, __) => const CupertinoPage(child: PlayerAdsScreen())),
      GoRoute(path: '/create-player-ad', pageBuilder: (_, __) => const CupertinoPage(child: CreatePlayerAdScreen())),
      GoRoute(path: '/admin/reported-ads', pageBuilder: (_, __) => const CupertinoPage(child: ReportedAdsScreen())),
      GoRoute(path: '/admin/create-official-ad', pageBuilder: (_, __) => const CupertinoPage(child: CreateOfficialPlayerAdScreen())),
      GoRoute(path: '/admin/banned-users', pageBuilder: (_, __) => const CupertinoPage(child: BannedUsersScreen())),
      GoRoute(path: '/privacy', pageBuilder: (_, __) => const CupertinoPage(child: PrivacyPolicyScreen())),
      GoRoute(path: '/terms', pageBuilder: (_, __) => const CupertinoPage(child: TermsScreen())),
    ],
  );

  ref.listen(authStateProvider, (_, __) => router.refresh());

  return router;
});
