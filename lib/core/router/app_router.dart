import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentaion/screens/login_screen.dart';
import '../../features/auth/presentaion/screens/register_screen.dart';
import '../../features/auth/presentaion/screens/otp_screen.dart';
import '../../features/facilities/presentaion/screens/home_screen.dart';
import '../../features/facilities/presentaion/screens/facilities_screen.dart';
import '../../features/bookings/presentaion/screens/create_booking_screen.dart';
import '../../features/bookings/presentaion/screens/my_bookings_screen.dart';
import '../../features/bookings/presentaion/screens/booking_detail_screen.dart';
import '../../features/wallet/presentaion/screens/wallet_screen.dart';
import '../../features/admin/presentaion/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentaion/screens/pending_bookings_screen.dart';
import '../../features/admin/presentaion/screens/manage_facilities_screen.dart';
import '../../features/admin/presentaion/screens/manage_ads_screen.dart';
import '../../features/settings/presentaion/screens/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/verify-otp',
        builder: (_, state) => OtpScreen(
          phone: state.extra as String,
        ),
      ),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/facilities/:groupId',
        builder: (_, state) => FacilitiesScreen(
          groupId: state.pathParameters['groupId']!,
        ),
      ),
      GoRoute(
        path: '/create-booking',
        builder: (_, state) => CreateBookingScreen(
          facilityId: state.extra as String,
        ),
      ),
      GoRoute(path: '/my-bookings', builder: (_, __) => const MyBookingsScreen()),
      GoRoute(
        path: '/booking/:id',
        builder: (_, state) => BookingDetailScreen(
          bookingId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen()),
      GoRoute(
        path: '/admin/dashboard',
        builder: (_, __) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/pending',
        builder: (_, __) => const PendingBookingsScreen(),
      ),
      GoRoute(
        path: '/admin/facilities',
        builder: (_, __) => const ManageFacilitiesScreen(),
      ),
      GoRoute(
        path: '/admin/ads',
        builder: (_, __) => const ManageAdsScreen(),
      ),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    ],
  );
});
