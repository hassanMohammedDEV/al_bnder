import 'package:app_platform_core/core.dart';
import 'package:app_platform_state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/wallet.dart';
import '../repositories/wallet_repository_impl.dart';

final walletInfoProvider = NotifierProvider<WalletNotifier, BaseState<WalletPaginatedState>>(
  WalletNotifier.new,
);

final walletInfoFamilyProvider = FutureProvider.family<WalletInfo, String>((ref, groupId) async {
  final repo = ref.read(walletRepositoryProvider);
  final result = await repo.getWallet(groupId);
  return result.when(
    success: (data) => WalletInfo(
      id: data.walletId,
      balance: data.balance,
      facilityGroupId: data.facilityGroupId,
      transactions: data.transactions.items,
    ),
    failure: (e) => throw Exception(e.message),
  );
});

class WalletNotifier extends BaseNotifier<WalletPaginatedState> {
  String? _currentGroupId;

  @override
  BaseState<WalletPaginatedState> build() => const BaseState(status: LoadStatus.loading);

  void setGroupId(String? groupId) {
    if (groupId != _currentGroupId) {
      _currentGroupId = groupId;
      load();
    }
  }

  Future<void> load({String? facilityGroupId}) async {
    final groupId = facilityGroupId ?? _currentGroupId;
    if (groupId == null) return;

    _currentGroupId = groupId;
    setLoading();
    final result = await ref.read(walletRepositoryProvider).getWallet(
      groupId,
      pagination: const Pagination(page: 0, limit: 20),
    );
    result.when(
      success: (data) => setSuccess(data),
      failure: (e) => setError(e),
    );
  }

  Future<void> loadMore() async {
    final current = state.data;
    if (current == null || !current.transactions.hasNext || current.transactions.isLoadingMore) return;

    final nextPage = current.transactions.pagination.next();
    state = state.copyWith(
      data: current.copyWith(
        transactions: current.transactions.copyWith(isLoadingMore: true),
      ),
    );

    final result = await ref.read(walletRepositoryProvider).getWallet(
      _currentGroupId!,
      pagination: nextPage,
    );
    result.when(
      success: (page) {
        final currentTxs = current.transactions;
        final allItems = [...currentTxs.items, ...page.transactions.items];
        state = state.copyWith(
          data: current.copyWith(
            transactions: currentTxs.copyWith(
              items: allItems,
              pagination: nextPage,
              hasNext: page.transactions.hasNext,
              isLoadingMore: false,
            ),
          ),
        );
      },
      failure: (e) {
        state = state.copyWith(
          data: current.copyWith(
            transactions: current.transactions.copyWith(
              isLoadingMore: false,
              paginationError: e,
            ),
          ),
        );
      },
    );
  }
}
