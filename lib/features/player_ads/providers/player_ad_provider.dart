import 'package:app_platform_core/core.dart';
import 'package:app_platform_state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/player_ad.dart';
import '../repositories/player_ad_repository_impl.dart';
import '../../facilities/providers/selected_group_provider.dart';

final playerAdsProvider = NotifierProvider<PlayerAdsNotifier, BaseState<List<PlayerAd>>>(
  PlayerAdsNotifier.new,
);

final playerAdActionProvider = NotifierProvider<PlayerAdActionNotifier, ActionStore>(
  PlayerAdActionNotifier.new,
);

final reportedPlayerAdsProvider = NotifierProvider<ReportedPlayerAdsNotifier, BaseState<List<PlayerAd>>>(
  ReportedPlayerAdsNotifier.new,
);

class PlayerAdsNotifier extends BaseNotifier<List<PlayerAd>> {
  @override
  BaseState<List<PlayerAd>> build() {
    final selected = ref.read(selectedGroupProvider);
    if (selected != null) {
      _currentGroupId = selected;
      Future.microtask(() => load());
    }
    return const BaseState(status: LoadStatus.loading);
  }

  String? _currentGroupId;

  Future<void> load() async {
    final groupId = _currentGroupId ?? ref.read(selectedGroupProvider);
    if (groupId == null) return;
    setLoading();
    final result = await ref.read(playerAdRepositoryProvider).getPlayerAds(groupId);
    result.when(
      success: (data) => setSuccess(data),
      failure: (e) => setError(e),
    );
  }

  Future<void> reload() => load();
}

class ReportedPlayerAdsNotifier extends BaseNotifier<List<PlayerAd>> {
  @override
  BaseState<List<PlayerAd>> build() => const BaseState();

  Future<void> load(String facilityGroupId) async {
    setLoading();
    final result = await ref.read(playerAdRepositoryProvider).getReportedAds(facilityGroupId);
    result.when(
      success: (data) => setSuccess(data),
      failure: (e) => setError(e),
    );
  }
}

class PlayerAdActionNotifier extends Notifier<ActionStore> {
  @override
  ActionStore build() => ActionStore();

  Future<Result<void>> createAd(Map<String, dynamic> data) async {
    const key = 'create';
    state = state.start(key);
    final result = await ref.read(playerAdRepositoryProvider).createPlayerAd(data);
    result.when(
      success: (_) {
        state = state.success(key);
        ref.read(playerAdsProvider.notifier).reload();
      },
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

  Future<Result<void>> createOfficialAd(Map<String, dynamic> data) async {
    const key = 'create';
    state = state.start(key);
    final result = await ref.read(playerAdRepositoryProvider).createOfficialPlayerAd(data);
    result.when(
      success: (_) {
        state = state.success(key);
        ref.read(playerAdsProvider.notifier).reload();
      },
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

  Future<Result<void>> deleteAd(String id) async {
    const key = 'delete';
    state = state.start(key);
    final result = await ref.read(playerAdRepositoryProvider).deletePlayerAd(id);
    result.when(
      success: (_) {
        state = state.success(key);
        ref.read(playerAdsProvider.notifier).reload();
        final groupId = ref.read(selectedGroupProvider);
        if (groupId != null) {
          ref.read(reportedPlayerAdsProvider.notifier).load(groupId);
        }
      },
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

  Future<Result<void>> updateAd(String adId, Map<String, dynamic> data) async {
    const key = 'update';
    state = state.start(key);
    final result = await ref.read(playerAdRepositoryProvider).updatePlayerAd(adId, data);
    result.when(
      success: (_) {
        state = state.success(key);
        ref.read(playerAdsProvider.notifier).reload();
      },
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

  Future<Result<void>> reportAd(String adId, String reason) async {
    const key = 'report';
    state = state.start(key);
    final result = await ref.read(playerAdRepositoryProvider).reportPlayerAd(adId, reason);
    result.when(
      success: (_) => state = state.success(key),
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

  Future<Result<void>> dismissReport(String adId) async {
    const key = 'dismiss';
    state = state.start(key);
    final result = await ref.read(playerAdRepositoryProvider).dismissReport(adId);
    result.when(
      success: (_) {
        state = state.success(key);
        ref.read(reportedPlayerAdsProvider.notifier).load(
          ref.read(selectedGroupProvider) ?? '',
        );
      },
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }
}
