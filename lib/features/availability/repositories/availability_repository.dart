import 'package:app_platform_core/core.dart';

import '../models/group_availability.dart';

abstract class AvailabilityRepository {
  Future<Result<GroupAvailability>> getAvailableSlots({
    required String facilityGroupId,
    required String date,
  });
}
