import 'package:app_platform_core/core.dart';

import '../models/facility_group.dart';
import '../models/facility.dart';

abstract class FacilityRepository {
  Future<Result<List<FacilityGroup>>> getGroups();
  Future<Result<List<Facility>>> getFacilities(String groupId);
  Future<Result<Map<String, dynamic>>> getAvailableSlots(String facilityId, DateTime date);
}
