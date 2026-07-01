import 'package:app_platform_core/core.dart';

abstract class ReportsRepository {
  Future<Result<List<Map<String, dynamic>>>> searchBookingsByDateRange({
    String? facilityGroupId,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<Result<List<Map<String, dynamic>>>> getWalletOperations({
    required String facilityGroupId,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<Result<Map<String, dynamic>>> getAnalytics({
    required String facilityGroupId,
    required DateTime startDate,
    required DateTime endDate,
  });
}