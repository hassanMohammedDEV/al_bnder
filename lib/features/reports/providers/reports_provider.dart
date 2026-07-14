import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/reports_repository_impl.dart';

final reportsProvider = FutureProvider.family<List<Map<String, dynamic>>, ReportsQuery>(
  (ref, query) async {
    final repo = ref.read(reportsRepositoryProvider);
    final result = await repo.searchBookingsByDateRange(
      facilityGroupId: query.facilityGroupId,
      startDate: query.startDate,
      endDate: query.endDate,
    );
    return result.when(
      success: (data) => data,
      failure: (e) => throw e,
    );
  },
);

class ReportsQuery {
  final String? facilityGroupId;
  final DateTime startDate;
  final DateTime endDate;

  const ReportsQuery({
    this.facilityGroupId,
    required this.startDate,
    required this.endDate,
  });

  @override
  bool operator ==(Object other) =>
      other is ReportsQuery &&
      other.facilityGroupId == facilityGroupId &&
      other.startDate == startDate &&
      other.endDate == endDate;

  @override
  int get hashCode => Object.hash(facilityGroupId, startDate, endDate);
}
