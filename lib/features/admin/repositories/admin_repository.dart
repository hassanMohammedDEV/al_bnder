import 'package:app_platform_core/core.dart';

abstract class AdminRepository {
  Future<Result<Map<String, dynamic>>> getDashboard({String? facilityGroupId});
  Future<Result<List<Map<String, dynamic>>>> getPendingBookings({String? facilityGroupId});
  Future<Result<void>> confirmBooking(String bookingId, {double paidAmount = 0});
  Future<Result<Map<String, dynamic>>> depositWallet({
    required String targetUserId,
    required String facilityGroupId,
    required double amount,
    String? description,
  });
  Future<Result<Map<String, dynamic>>> deductWallet({
    required String targetUserId,
    required String facilityGroupId,
    required double amount,
    String? description,
  });
  Future<Result<List<Map<String, dynamic>>>> searchUsers(String query, {String? facilityGroupId});
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
  });
  Future<Result<Map<String, dynamic>>> registerUser({
    required String phone,
    String? name,
  });
  Future<Result<void>> recordSettlement({
    required String facilityGroupId,
    required double amount,
    String? notes,
  });
  Future<Result<Map<String, dynamic>>> getGroupSettings(String facilityGroupId);
  Future<Result<List<Map<String, dynamic>>>> getTodayBookings(String facilityGroupId);
  Future<Result<Map<String, dynamic>>> getBookingByQrToken(String qrToken);
  Future<Result<Map<String, dynamic>>> getUserWallet({
    required String targetUserId,
    required String facilityGroupId,
  });
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
  });
  Future<Result<void>> autoCancelExpiredBookings();
  Future<Result<Map<String, dynamic>>> adminCancelBooking(String bookingId);
  Future<Result<Map<String, dynamic>>> shrinkBooking({
    required String bookingId,
    required DateTime newEndAt,
  });
  Future<Result<Map<String, dynamic>>> rescheduleBooking({
    required String bookingId,
    required DateTime newStartAt,
    required DateTime newEndAt,
  });
  Future<Result<List<Map<String, dynamic>>>> searchBookingsByPhone(String phoneQuery, {String? facilityGroupId});
  Future<Result<List<Map<String, dynamic>>>> searchBookingsByDateRange({
    String? facilityGroupId,
    required DateTime startDate,
    required DateTime endDate,
  });
  Future<Result<List<Map<String, dynamic>>>> adminGetFacilities(String facilityGroupId);
  Future<Result<void>> updateFacility({
    required String facilityId,
    required String name,
    String? description,
    double? pricePerHour,
    bool? isActive,
  });
}
