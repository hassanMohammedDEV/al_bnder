import 'package:app_platform_core/core.dart';
import 'package:app_platform_network/network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/api_client_provider.dart';
import '../models/facility_group.dart';
import '../models/facility.dart';
import 'facility_repository.dart';

final facilityRepositoryProvider = Provider<FacilityRepository>((ref) {
  return FacilityRepositoryImpl(apiClient: ref.read(apiClientProvider));
});

class FacilityRepositoryImpl implements FacilityRepository {
  final ApiClient _apiClient;

  FacilityRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<Result<List<FacilityGroup>>> getGroups() {
    return _apiClient.post('rpc/get_facility_groups', body: {}, parser: (json) {
      final list = (json as Map<String, dynamic>)['data'] as List;
      return list.map((e) => FacilityGroup.fromMap(e)).toList();
    });
  }

  @override
  Future<Result<List<Facility>>> getFacilities(String groupId) {
    return _apiClient.post('rpc/get_facilities', body: {
      'p_group_id': groupId,
    }, parser: (json) {
      final list = (json as Map<String, dynamic>)['data'] as List;
      return list.map((e) => Facility.fromMap(e)).toList();
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> getAvailableSlots(String facilityId, DateTime date) {
    final ds = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _apiClient.post('rpc/get_available_slots', body: {
      'p_facility_id': facilityId,
      'p_date': ds,
    }, parser: (json) => (json as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }
}
