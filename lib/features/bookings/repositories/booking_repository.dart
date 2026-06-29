import 'package:app_platform_core/core.dart';

import '../models/booking.dart';

abstract class BookingRepository {
  Future<Result<List<Booking>>> getMyBookings({String? status, String? facilityGroupId});
  Future<Result<Map<String, dynamic>>> createBooking({
    required String facilityId,
    required DateTime startAt,
    required DateTime endAt,
    bool isRecurring = false,
    Map<String, dynamic>? recurringRule,
    String paymentType = 'auto',
  });
  Future<Result<Map<String, dynamic>>> cancelBooking(String bookingId);
}
