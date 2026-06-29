import 'package:app_platform_core/core.dart';
import 'package:app_platform_network/network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/api_client_provider.dart';
import 'reports_repository.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepositoryImpl(apiClient: ref.read(apiClientProvider));
});

class ReportsRepositoryImpl implements ReportsRepository {
  final ApiClient _apiClient;

  ReportsRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

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
  Future<Result<List<Map<String, dynamic>>>> getWalletOperations({
    required String facilityGroupId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _apiClient.post('rpc/get_wallet_operations_report', body: {
      'p_facility_group_id': facilityGroupId,
      'p_start_date': startDate.toIso8601String().substring(0, 10),
      'p_end_date': endDate.toIso8601String().substring(0, 10),
    }, parser: (json) {
      final data = (json as Map<String, dynamic>)['data'] as List;
      return data.cast<Map<String, dynamic>>();
    });
  }
}
