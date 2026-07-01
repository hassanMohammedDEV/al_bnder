import 'package:app_platform_core/core.dart';
import 'package:app_platform_state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/facility_ad.dart';
import '../repositories/ads_repository_impl.dart';

final adsProvider = NotifierProvider<AdsNotifier, BaseState<List<FacilityAd>>>(
  AdsNotifier.new,
);

final activeAdsProvider = FutureProvider<List<FacilityAd>>((ref) async {
  final result = await ref.read(adsRepositoryProvider).getAllActiveAds();
  return result.when(
    success: (data) => data,
    failure: (e) => throw e,
  );
});

final adActionProvider = NotifierProvider<AdActionNotifier, ActionStore>(
  AdActionNotifier.new,
);

class AdsNotifier extends BaseNotifier<List<FacilityAd>> {
  String? _facilityGroupId;

  void load(String facilityGroupId) {
    _facilityGroupId = facilityGroupId;
    _load();
  }

  void reload() {
    if (_facilityGroupId != null) _load();
  }

  @override
  BaseState<List<FacilityAd>> build() => const BaseState();

  Future<void> _load() async {
    if (_facilityGroupId == null) return;
    setLoading();
    final result = await ref.read(adsRepositoryProvider).getAds(_facilityGroupId!);
    result.when(
      success: (data) => setSuccess(data),
      failure: (e) => setError(e),
    );
  }
}

class AdActionNotifier extends Notifier<ActionStore> {
  @override
  ActionStore build() => ActionStore();

  Future<Result<void>> createAd({
    required String facilityGroupId,
    required String title,
    String? description,
    String? imageUrl,
    String? linkUrl,
    String? startsAt,
    String? endsAt,
    int sortOrder = 0,
  }) async {
    const key = 'create';
    state = state.start(key);
    final result = await ref.read(adsRepositoryProvider).createAd(
      facilityGroupId: facilityGroupId,
      title: title,
      description: description,
      imageUrl: imageUrl,
      linkUrl: linkUrl,
      startsAt: startsAt,
      endsAt: endsAt,
      sortOrder: sortOrder,
    );
    result.when(
      success: (_) {
        state = state.success(key);
        ref.read(adsProvider.notifier).reload();
        ref.invalidate(activeAdsProvider);
      },
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

  Future<Result<void>> updateAd({
    required String adId,
    required String title,
    String? description,
    String? imageUrl,
    String? linkUrl,
    String? startsAt,
    String? endsAt,
    int? sortOrder,
  }) async {
    const key = 'update';
    state = state.start(key);
    final result = await ref.read(adsRepositoryProvider).updateAd(
      adId: adId,
      title: title,
      description: description,
      imageUrl: imageUrl,
      linkUrl: linkUrl,
      startsAt: startsAt,
      endsAt: endsAt,
      sortOrder: sortOrder,
    );
    result.when(
      success: (_) {
        state = state.success(key);
        ref.read(adsProvider.notifier).reload();
        ref.invalidate(activeAdsProvider);
      },
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

  Future<Result<void>> toggleActive(String adId, bool isActive) async {
    const key = 'toggle';
    state = state.start(key);
    final result = await ref.read(adsRepositoryProvider).toggleActive(adId, isActive);
    result.when(
      success: (_) {
        state = state.success(key);
        ref.read(adsProvider.notifier).reload();
        ref.invalidate(activeAdsProvider);
      },
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

  Future<Result<void>> updateSortOrder(String adId, int sortOrder) async {
    const key = 'sort';
    state = state.start(key);
    final result = await ref.read(adsRepositoryProvider).updateSortOrder(adId, sortOrder);
    result.when(
      success: (_) {
        state = state.success(key);
        ref.read(adsProvider.notifier).reload();
        ref.invalidate(activeAdsProvider);
      },
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

  Future<Result<void>> deleteAd(String adId) async {
    const key = 'delete';
    state = state.start(key);
    final result = await ref.read(adsRepositoryProvider).deleteAd(adId);
    result.when(
      success: (_) {
        state = state.success(key);
        ref.read(adsProvider.notifier).reload();
        ref.invalidate(activeAdsProvider);
      },
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }
}
