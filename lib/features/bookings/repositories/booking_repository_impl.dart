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

  BookingRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<Result<List<Booking>>> getMyBookings({String? status}) {
    return _apiClient.post('rpc/get_my_bookings', body: {
      'p_status': status,
    }, parser: (json) {
      final data = json as Map<String, dynamic>;
      final bookings = (data['data'] as Map<String, dynamic>)['bookings'] as List;
      return bookings.map((e) => Booking.fromMap(e)).toList();
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> createBooking({
    required String facilityId,
    required DateTime startAt,
    required DateTime endAt,
    bool isRecurring = false,
    Map<String, dynamic>? recurringRule,
  }) {
    return _apiClient.post('rpc/create_booking', body: {
      'p_facility_id': facilityId,
      'p_start_at': startAt.toUtc().toIso8601String(),
      'p_end_at': endAt.toUtc().toIso8601String(),
      'p_is_recurring': isRecurring,
      'p_recurring_rule': recurringRule,
    }, parser: (json) => json as Map<String, dynamic>);
  }

  @override
  Future<Result<void>> cancelBooking(String bookingId) {
    return _apiClient.post('rpc/cancel_booking', body: {
      'p_booking_id': bookingId,
    }, parser: (_) {});
  }
}
