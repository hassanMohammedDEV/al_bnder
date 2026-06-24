import 'package:app_platform_core/core.dart';

abstract class AdminRepository {
  Future<Result<Map<String, dynamic>>> getDashboard({String? facilityGroupId});
  Future<Result<List<Map<String, dynamic>>>> getPendingBookings({String? facilityGroupId});
  Future<Result<void>> confirmBooking(String bookingId);
  Future<Result<Map<String, dynamic>>> depositWallet({
    required String targetUserId,
    required String facilityGroupId,
    required double amount,
    String? description,
  });
}
