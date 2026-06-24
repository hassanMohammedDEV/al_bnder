import 'package:app_platform_core/core.dart';

import '../models/booking.dart';

abstract class BookingRepository {
  Future<Result<List<Booking>>> getMyBookings({String? status});
  Future<Result<Map<String, dynamic>>> createBooking({
    required String facilityId,
    required DateTime startAt,
    required DateTime endAt,
    bool isRecurring = false,
    Map<String, dynamic>? recurringRule,
  });
  Future<Result<void>> cancelBooking(String bookingId);
}
