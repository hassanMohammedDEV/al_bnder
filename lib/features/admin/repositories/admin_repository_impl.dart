import 'package:app_platform_core/core.dart';
import 'package:app_platform_network/network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/api_client_provider.dart';
import 'admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepositoryImpl(apiClient: ref.read(apiClientProvider));
});

class AdminRepositoryImpl implements AdminRepository {
  final ApiClient _apiClient;

  AdminRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<Result<Map<String, dynamic>>> getDashboard({String? facilityGroupId}) {
    return _apiClient.post('rpc/get_admin_dashboard', body: {
      'p_facility_group_id': facilityGroupId,
    }, parser: (json) {
      return (json as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    });
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getPendingBookings({String? facilityGroupId}) {
    return _apiClient.post('rpc/admin_get_pending_bookings', body: {
      'p_facility_group_id': facilityGroupId,
    }, parser: (json) {
      final data = (json as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      final bookings = data['bookings'] as List;
      return bookings.cast<Map<String, dynamic>>();
    });
  }

  @override
  Future<Result<void>> confirmBooking(String bookingId) {
    return _apiClient.post('rpc/admin_confirm_booking', body: {
      'p_booking_id': bookingId,
    }, parser: (_) {});
  }

  @override
  Future<Result<Map<String, dynamic>>> depositWallet({
    required String targetUserId,
    required String facilityGroupId,
    required double amount,
    String? description,
  }) {
    return _apiClient.post('rpc/admin_deposit_wallet', body: {
      'p_target_user_id': targetUserId,
      'p_facility_group_id': facilityGroupId,
      'p_amount': amount,
      'p_description': description,
    }, parser: (json) => json as Map<String, dynamic>);
  }
}
