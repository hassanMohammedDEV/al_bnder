import 'package:app_platform_core/core.dart';
import 'package:app_platform_network/network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/api_client_provider.dart';
import '../models/booking.dart';
import 'booking_repository.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepositoryImpl(apiClient: ref.read(apiClientProvider));
});

class BookingRepositoryImpl implements BookingRepository {
  final ApiClient _apiClient;

  BookingRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient; // ignore: prefer_initializing_formals

  @override
  Future<Result<Paginated<Booking>>> getMyBookings({String? status, String? facilityGroupId, Pagination? pagination}) {
    return _apiClient.post('rpc/get_my_bookings', body: {
      'p_status': status,
      'p_facility_group_id': facilityGroupId,
      if (pagination != null) 'p_page': pagination.page,
      if (pagination != null) 'p_page_size': pagination.limit,
    }, parser: (json) {
      final data = (json as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      final bookings = (data['bookings'] as List).map((e) => Booking.fromMap(e)).toList();
      final totalCount = data['total_count'] as int? ?? bookings.length;
      final page = pagination ?? const Pagination(page: 0, limit: 20);
      return Paginated<Booking>(
        items: bookings,
        pagination: page,
        hasNext: page.page * page.limit + bookings.length < totalCount,
      );
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> createBooking({
    required String facilityId,
    required DateTime startAt,
    required DateTime endAt,
    bool isRecurring = false,
    Map<String, dynamic>? recurringRule,
    String paymentType = 'auto',
  }) {
    return _apiClient.post('rpc/create_booking', body: {
      'p_facility_id': facilityId,
      'p_start_at': startAt.toUtc().toIso8601String(),
      'p_end_at': endAt.toUtc().toIso8601String(),
      'p_is_recurring': isRecurring,
      'p_recurring_rule': recurringRule,
      'p_payment_type': paymentType,
    }, parser: (json) => json as Map<String, dynamic>);
  }

  @override
  Future<Result<Map<String, dynamic>>> cancelBooking(String bookingId) {
    return _apiClient.post('rpc/cancel_booking', body: {
      'p_booking_id': bookingId,
    }, parser: (json) => json as Map<String, dynamic>);
  }
}
