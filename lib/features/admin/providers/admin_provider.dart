import 'package:app_platform_core/core.dart';
import 'package:app_platform_state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/group_settings.dart';
import '../models/group_stats.dart';
import '../repositories/admin_repository_impl.dart';

final dashboardProvider = FutureProvider<List<GroupStats>>((ref) async {
  // Auto-cancel expired pending_approval bookings
  await ref.read(adminRepositoryProvider).autoCancelExpiredBookings();

  final result = await ref.read(adminRepositoryProvider).getDashboard();
  return result.when(
    success: (data) {
      final raw = data['data'];
      if (raw is List) {
        return raw.map((e) => GroupStats.fromJson(e as Map<String, dynamic>)).toList();
      } else if (raw is Map<String, dynamic>) {
        return [GroupStats.fromJson(raw)];
      }
      return <GroupStats>[];
    },
    failure: (e) => throw e,
  );
});

final groupSettingsProvider = FutureProvider.family<GroupSettings, String>((ref, facilityGroupId) async {
  final result = await ref.read(adminRepositoryProvider).getGroupSettings(facilityGroupId);
  return result.when(
    success: (data) => GroupSettings.fromJson(data),
    failure: (e) => throw e,
  );
});

final pendingBookingsProvider = NotifierProvider<PendingBookingsNotifier, BaseState<List<Map<String, dynamic>>>>(
  PendingBookingsNotifier.new,
);

final adminActionProvider = StateNotifierProvider<AdminActionNotifier, ActionStore>(
  (ref) => AdminActionNotifier(ref: ref),
);

class PendingBookingsNotifier extends BaseNotifier<List<Map<String, dynamic>>> {
  @override
  BaseState<List<Map<String, dynamic>>> build() => const BaseState();

  Future<void> load({String? facilityGroupId}) async {
    setLoading();
    final result = await ref.read(adminRepositoryProvider).getPendingBookings(
      facilityGroupId: facilityGroupId,
    );
    result.when(
      success: (data) => setSuccess(data),
      failure: (e) => setError(e),
    );
  }
}

class AdminActionNotifier extends StateNotifier<ActionStore> {
  AdminActionNotifier({required this.ref}) : super(ActionStore());

  final Ref ref;

  Future<Result<void>> confirmBooking(String bookingId) async {
    const key = 'confirm';
    state = state.start(key);
    final result = await ref.read(adminRepositoryProvider).confirmBooking(bookingId);
    result.when(
      success: (_) {
        state = state.success(key);
        ref.read(pendingBookingsProvider.notifier).load();
        ref.invalidate(dashboardProvider);
      },
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

  Future<Result<List<Map<String, dynamic>>>> searchUsers(String query, {String? facilityGroupId}) {
    return ref.read(adminRepositoryProvider).searchUsers(query, facilityGroupId: facilityGroupId);
  }

  Future<Result<Map<String, dynamic>>> depositWallet({
    required String targetUserId,
    required String facilityGroupId,
    required double amount,
    String? description,
  }) async {
    const key = 'deposit';
    state = state.start(key);
    final result = await ref.read(adminRepositoryProvider).depositWallet(
      targetUserId: targetUserId,
      facilityGroupId: facilityGroupId,
      amount: amount,
      description: description,
    );
    result.when(
      success: (_) {
        state = state.success(key);
        ref.invalidate(dashboardProvider);
      },
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

  Future<Result<Map<String, dynamic>>> deductWallet({
    required String targetUserId,
    required String facilityGroupId,
    required double amount,
    String? description,
  }) async {
    const key = 'deduct';
    state = state.start(key);
    final result = await ref.read(adminRepositoryProvider).deductWallet(
      targetUserId: targetUserId,
      facilityGroupId: facilityGroupId,
      amount: amount,
      description: description,
    );
    result.when(
      success: (_) {
        state = state.success(key);
        ref.invalidate(dashboardProvider);
      },
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

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
  }) async {
    const key = 'create_booking';
    state = state.start(key);
    final result = await ref.read(adminRepositoryProvider).createBooking(
      targetUserId: targetUserId,
      facilityId: facilityId,
      startAt: startAt,
      endAt: endAt,
      targetName: targetName,
      targetPhone: targetPhone,
      isRecurring: isRecurring,
      recurringRule: recurringRule,
      autoConfirm: autoConfirm,
      paymentType: paymentType,
    );
    result.when(
      success: (_) => state = state.success(key),
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

  Future<Result<Map<String, dynamic>>> registerUser({
    required String phone,
    String? name,
  }) async {
    const key = 'register_user';
    state = state.start(key);
    final result = await ref.read(adminRepositoryProvider).registerUser(
      phone: phone,
      name: name,
    );
    result.when(
      success: (_) => state = state.success(key),
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

  Future<Result<void>> recordSettlement({
    required String facilityGroupId,
    required double amount,
    String? notes,
  }) async {
    const key = 'settlement';
    state = state.start(key);
    final result = await ref.read(adminRepositoryProvider).recordSettlement(
      facilityGroupId: facilityGroupId,
      amount: amount,
      notes: notes,
    );
    result.when(
      success: (_) {
        state = state.success(key);
        ref.invalidate(dashboardProvider);
      },
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

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
  }) async {
    const key = 'settings';
    state = state.start(key);
    final result = await ref.read(adminRepositoryProvider).updateGroupSettings(
      facilityGroupId: facilityGroupId,
      openingTime: openingTime,
      closingTimeSun: closingTimeSun,
      closingTimeMon: closingTimeMon,
      closingTimeTue: closingTimeTue,
      closingTimeWed: closingTimeWed,
      closingTimeThu: closingTimeThu,
      closingTimeFri: closingTimeFri,
      closingTimeSat: closingTimeSat,
      depositAmount: depositAmount,
      contractExpiryHours: contractExpiryHours,
    );
    result.when(
      success: (_) {
        state = state.success(key);
        ref.invalidate(groupSettingsProvider(facilityGroupId));
      },
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

  void reset() => state = ActionStore();
}
