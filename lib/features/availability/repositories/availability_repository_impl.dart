import 'package:app_platform_core/core.dart';
import 'package:app_platform_network/network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/api_client_provider.dart';
import '../models/group_availability.dart';
import 'availability_repository.dart';

final availabilityRepositoryProvider = Provider<AvailabilityRepository>((ref) {
  return AvailabilityRepositoryImpl(apiClient: ref.read(apiClientProvider));
});

class AvailabilityRepositoryImpl implements AvailabilityRepository {
  final ApiClient _apiClient;

  AvailabilityRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient; // ignore: prefer_initializing_formals

  @override
  Future<Result<GroupAvailability>> getAvailableSlots({
    required String facilityGroupId,
    required String date,
  }) {
    return _apiClient.post('rpc/get_group_available_slots', body: {
      'p_facility_group_id': facilityGroupId,
      'p_date': date,
    }, parser: (json) {
      final data = (json as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      return GroupAvailability.fromMap(data);
    });
  }
}
