import 'package:app_platform_state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/wallet.dart';
import '../repositories/wallet_repository_impl.dart';

final walletInfoProvider = NotifierProvider<WalletNotifier, BaseState<WalletInfo>>(
  WalletNotifier.new,
);

final walletInfoFamilyProvider = FutureProvider.family<WalletInfo, String>((ref, groupId) async {
  final repo = ref.read(walletRepositoryProvider);
  final result = await repo.getWallet(groupId);
  return result.when(
    success: (data) => data,
    failure: (e) => throw Exception(e.message),
  );
});

class WalletNotifier extends BaseNotifier<WalletInfo> {
  @override
  BaseState<WalletInfo> build() => const BaseState();

  Future<void> load(String groupId) async {
    setLoading();
    final result = await ref.read(walletRepositoryProvider).getWallet(groupId);
    result.when(
      success: (data) => setSuccess(data),
      failure: (e) => setError(e),
    );
  }
}
