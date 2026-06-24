import 'package:app_platform_core/core.dart';
import 'package:app_platform_network/network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/api_client_provider.dart';
import '../models/wallet.dart';
import 'wallet_repository.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepositoryImpl(apiClient: ref.read(apiClientProvider));
});

class WalletRepositoryImpl implements WalletRepository {
  final ApiClient _apiClient;

  WalletRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<Result<WalletInfo>> getWallet(String facilityGroupId) {
    return _apiClient.post('rpc/get_my_wallet', body: {
      'p_facility_group_id': facilityGroupId,
    }, parser: (json) {
      final data = (json as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      final txs = (data['transactions'] as List?)?.map((t) => WalletTransaction(
        id: t['id'],
        amount: (t['amount'] as num).toDouble(),
        type: t['type'],
        referenceType: t['reference_type'],
        referenceId: t['reference_id'],
        description: t['description'],
        createdAt: t['created_at'],
      )).toList() ?? [];

      return WalletInfo(
        id: data['wallet_id'],
        balance: (data['balance'] as num).toDouble(),
        facilityGroupId: data['facility_group_id'],
        transactions: txs,
      );
    });
  }
}
