import 'package:app_platform_state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/facility_group.dart';
import '../models/facility.dart';
import '../repositories/facility_repository_impl.dart';

final facilityGroupsProvider = NotifierProvider<FacilityGroupsNotifier, BaseState<List<FacilityGroup>>>(
  FacilityGroupsNotifier.new,
);

final facilitiesProvider = FutureProvider.family<List<Facility>, String>((ref, groupId) async {
  final repo = ref.read(facilityRepositoryProvider);
  final result = await repo.getFacilities(groupId);
  return result.when(
    success: (data) => data,
    failure: (e) => throw Exception(e.message),
  );
});

class FacilityGroupsNotifier extends BaseNotifier<List<FacilityGroup>> {
  @override
  BaseState<List<FacilityGroup>> build() {
    Future.microtask(() => load());
    return const BaseState();
  }

  Future<void> load() async {
    setLoading();
    final result = await ref.read(facilityRepositoryProvider).getGroups();
    result.when(
      success: (data) => setSuccess(data),
      failure: (e) => setError(e),
    );
  }
}
