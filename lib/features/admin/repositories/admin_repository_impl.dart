import 'package:app_platform_core/core.dart';
import 'package:app_platform_network/network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/providers/api_client_provider.dart';
import 'admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepositoryImpl(
    apiClient: ref.read(apiClientProvider),
    authApiClient: ref.read(authApiClientProvider),
  );
});

class AdminRepositoryImpl implements AdminRepository {
  final ApiClient _apiClient;
  final ApiClient _authApiClient;

  AdminRepositoryImpl({
    required ApiClient apiClient,
    required ApiClient authApiClient,
  })  : _apiClient = apiClient,
        _authApiClient = authApiClient;

  @override
  Future<Result<Map<String, dynamic>>> getDashboard({String? facilityGroupId}) {
    return _apiClient.post('rpc/get_admin_dashboard', body: {
      'p_facility_group_id': facilityGroupId,
    }, parser: (json) => json as Map<String, dynamic>);
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
  Future<Result<void>> confirmBooking(String bookingId, {double paidAmount = 0}) {
    return _apiClient.post('rpc/admin_confirm_booking', body: {
      'p_booking_id': bookingId,
      'p_paid_amount': paidAmount,
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

  @override
  Future<Result<Map<String, dynamic>>> deductWallet({
    required String targetUserId,
    required String facilityGroupId,
    required double amount,
    String? description,
  }) {
    return _apiClient.post('rpc/admin_deduct_wallet', body: {
      'p_target_user_id': targetUserId,
      'p_facility_group_id': facilityGroupId,
      'p_amount': amount,
      'p_description': description,
    }, parser: (json) => json as Map<String, dynamic>);
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> searchUsers(String query, {String? facilityGroupId}) {
    return _apiClient.post('rpc/search_users_by_phone', body: {
      'p_phone_query': query,
      if (facilityGroupId != null) 'p_facility_group_id': facilityGroupId,
    }, parser: (json) {
      final data = (json as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      final users = data['users'] as List;
      return users.cast<Map<String, dynamic>>();
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> createBooking({
    String? targetUserId,
    required String facilityId,
    required DateTime startAt,
    required DateTime endAt,
    String? targetName,
    String? targetPhone,
    bool isRecurring = false,
    Map<String, dynamic>? recurringRule,
    bool autoConfirm = true,
    String paymentType = 'full',
  }) {
    return _apiClient.post('rpc/admin_create_booking', body: {
      if (targetUserId != null) 'p_target_user_id': targetUserId,
      'p_facility_id': facilityId,
      'p_start_at': startAt.toUtc().toIso8601String(),
      'p_end_at': endAt.toUtc().toIso8601String(),
      if (targetName != null) 'p_target_name': targetName,
      if (targetPhone != null) 'p_target_phone': targetPhone,
      'p_is_recurring': isRecurring,
      if (recurringRule != null) 'p_recurring_rule': recurringRule,
      'p_auto_confirm': autoConfirm,
      'p_payment_type': paymentType,
    }, parser: (json) => json as Map<String, dynamic>);
  }

  @override
  Future<Result<Map<String, dynamic>>> registerUser({
    required String phone,
    String? name,
  }) {
    final email = '$phone@al-bndr.app';
    return _authApiClient.post('auth/v1/signup',
      body: {
        'email': email,
        'password': 'temppass123',
        'data': {
          'name': name ?? '',
          'phone': phone,
        },
      },
      headers: {
        'Authorization': 'Bearer $supabaseAnonKey',
      },
      parser: (json) {
        final map = json as Map<String, dynamic>;
        final userId = map['user']?['id'] as String?;
        if (userId == null) {
          throw Exception('فشل إنشاء المستخدم');
        }
        return {
          'user_id': userId,
          'phone': phone,
          'name': name ?? '',
        };
      },
    );
  }

  @override
  Future<Result<void>> recordSettlement({
    required String facilityGroupId,
    required double amount,
    String? notes,
  }) {
    return _apiClient.post('rpc/record_developer_settlement', body: {
      'p_facility_group_id': facilityGroupId,
        'p_amount': amount,
      if (notes != null) 'p_notes': notes,
    }, parser: (_) {});
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getTodayBookings(String facilityGroupId) {
    return _apiClient.post('rpc/admin_get_today_bookings', body: {
      'p_facility_group_id': facilityGroupId,
    }, parser: (json) {
      final data = (json as Map<String, dynamic>)['data'] as List;
      return data.cast<Map<String, dynamic>>();
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> getGroupSettings(String facilityGroupId) {
    return _apiClient.post('rpc/get_group_settings', body: {
      'p_facility_group_id': facilityGroupId,
    }, parser: (json) => (json as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  @override
  Future<Result<void>> updateGroupSettings({
    required String facilityGroupId,
    required String openingTime,
    required String closingTimeSun,
    required String closingTimeMon,
    required String closingTimeTue,
    required String closingTimeWed,
    required String closingTimeThu,
    required String closingTimeFri,
    required String closingTimeSat,
    required double depositAmount,
    required int contractExpiryHours,
  }) {
    return _apiClient.post('rpc/upsert_group_settings', body: {
      'p_facility_group_id': facilityGroupId,
      'p_opening_time': openingTime,
      'p_closing_time_sun': closingTimeSun,
      'p_closing_time_mon': closingTimeMon,
      'p_closing_time_tue': closingTimeTue,
      'p_closing_time_wed': closingTimeWed,
      'p_closing_time_thu': closingTimeThu,
      'p_closing_time_fri': closingTimeFri,
      'p_closing_time_sat': closingTimeSat,
      'p_deposit_amount': depositAmount,
      'p_contract_expiry_hours': contractExpiryHours,
    }, parser: (_) {});
  }

  @override
  Future<Result<Map<String, dynamic>>> getBookingByQrToken(String qrToken) {
    return _apiClient.post('rpc/admin_get_booking_by_qr_token', body: {
      'p_qr_token': qrToken,
    }, parser: (json) {
      final data = (json as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      return data;
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> getUserWallet({
    required String targetUserId,
    required String facilityGroupId,
  }) {
    return _apiClient.post('rpc/admin_get_user_wallet', body: {
      'p_target_user_id': targetUserId,
      'p_facility_group_id': facilityGroupId,
    }, parser: (json) {
      final data = (json as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      return data;
    });
  }

  @override
  Future<Result<void>> autoCancelExpiredBookings() {
    return _apiClient.post('rpc/auto_cancel_expired_pending_approval', body: {}, parser: (_) {});
  }

  @override
  Future<Result<void>> autoDeleteExpiredPlayerAds() {
    return _apiClient.post('rpc/auto_delete_expired_player_ads', body: {}, parser: (_) {});
  }

  @override
  Future<Result<Map<String, dynamic>>> adminCancelBooking(String bookingId) {
    return _apiClient.post('rpc/cancel_booking', body: {
      'p_booking_id': bookingId,
    }, parser: (json) => json as Map<String, dynamic>);
  }

  @override
  Future<Result<Map<String, dynamic>>> shrinkBooking({
    required String bookingId,
    required DateTime newEndAt,
  }) {
    return _apiClient.post('rpc/admin_shrink_booking', body: {
      'p_booking_id': bookingId,
      'p_new_end_at': newEndAt.toUtc().toIso8601String(),
    }, parser: (json) => json as Map<String, dynamic>);
  }

  @override
  Future<Result<Map<String, dynamic>>> rescheduleBooking({
    required String bookingId,
    required DateTime newStartAt,
    required DateTime newEndAt,
  }) {
    return _apiClient.post('rpc/admin_reschedule_booking', body: {
      'p_booking_id': bookingId,
      'p_new_start_at': newStartAt.toUtc().toIso8601String(),
      'p_new_end_at': newEndAt.toUtc().toIso8601String(),
    }, parser: (json) => json as Map<String, dynamic>);
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> adminGetFacilities(String facilityGroupId) {
    return _apiClient.post('rpc/admin_get_facilities', body: {
      'p_facility_group_id': facilityGroupId,
    }, parser: (json) {
      final data = (json as Map<String, dynamic>)['data'] as List;
      return data.cast<Map<String, dynamic>>();
    });
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> searchBookingsByDateRange({
    String? facilityGroupId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _apiClient.post('rpc/admin_search_bookings_by_date_range', body: {
      if (facilityGroupId != null) 'p_facility_group_id': facilityGroupId,
      'p_start_date': startDate.toIso8601String().substring(0, 10),
      'p_end_date': endDate.toIso8601String().substring(0, 10),
    }, parser: (json) {
      final data = (json as Map<String, dynamic>)['data'] as List;
      return data.cast<Map<String, dynamic>>();
    });
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> searchBookingsByPhone(
    String phoneQuery, {
    String? facilityGroupId,
  }) {
    return _apiClient.post('rpc/admin_search_bookings_by_phone', body: {
      'p_phone_query': phoneQuery,
      if (facilityGroupId != null) 'p_facility_group_id': facilityGroupId,
    }, parser: (json) {
      final data = (json as Map<String, dynamic>)['data'] as List;
      return data.cast<Map<String, dynamic>>();
    });
  }

  @override
  Future<Result<void>> updateFacility({
    required String facilityId,
    required String name,
    String? description,
    double? pricePerHour,
    bool? isActive,
  }) {
    return _apiClient.post('rpc/update_facility', body: {
      'p_facility_id': facilityId,
      'p_name': name,
      if (description != null) 'p_description': description,
      if (pricePerHour != null) 'p_price_per_hour': pricePerHour,
      if (isActive != null) 'p_is_active': isActive,
    }, parser: (_) {});
  }
}
