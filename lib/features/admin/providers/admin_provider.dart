import 'package:app_platform_core/core.dart';
import 'package:app_platform_state/state.dart' hide ActionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

export '../../auth/providers/auth_provider.dart' show ActionState;
import '../repositories/admin_repository_impl.dart';

final pendingBookingsProvider = NotifierProvider<PendingBookingsNotifier, BaseState<List<Map<String, dynamic>>>>(
  PendingBookingsNotifier.new,
);

final adminActionProvider = NotifierProvider<AdminActionNotifier, ActionState>(
  AdminActionNotifier.new,
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

class AdminActionNotifier extends Notifier<ActionState> {
  @override
  ActionState build() => const ActionState();

  Future<Result<void>> confirmBooking(String bookingId) async {
    state = state.start('confirm');
    final result = await ref.read(adminRepositoryProvider).confirmBooking(bookingId);
    result.when(
      success: (_) {
        state = state.success('confirm');
        ref.read(pendingBookingsProvider.notifier).load();
      },
      failure: (e) => state = state.fail('confirm', e.message),
    );
    return result;
  }

  Future<Result<Map<String, dynamic>>> depositWallet({
    required String targetUserId,
    required String facilityGroupId,
    required double amount,
    String? description,
  }) async {
    state = state.start('deposit');
    final result = await ref.read(adminRepositoryProvider).depositWallet(
      targetUserId: targetUserId,
      facilityGroupId: facilityGroupId,
      amount: amount,
      description: description,
    );
    result.when(
      success: (data) => state = state.success('deposit'),
      failure: (e) => state = state.fail('deposit', e.message),
    );
    return result;
  }

  void reset() => state = const ActionState();
}
