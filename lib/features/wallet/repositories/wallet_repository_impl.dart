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

  WalletRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient; // ignore: prefer_initializing_formals

  @override
  Future<Result<WalletPaginatedState>> getWallet(String facilityGroupId, {Pagination? pagination}) {
    return _apiClient.post('rpc/get_my_wallet', body: {
      'p_facility_group_id': facilityGroupId,
      if (pagination != null) 'p_page': pagination.page,
      if (pagination != null) 'p_page_size': pagination.limit,
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

      final totalCount = data['total_count'] as int? ?? txs.length;
      final effectivePage = pagination ?? const Pagination(page: 0, limit: 20);

      return WalletPaginatedState(
        walletId: data['wallet_id'],
        balance: (data['balance'] as num).toDouble(),
        facilityGroupId: data['facility_group_id'],
        transactions: Paginated<WalletTransaction>(
          items: txs,
          pagination: effectivePage,
          hasNext: pagination != null
              ? effectivePage.page * effectivePage.limit + txs.length < totalCount
              : false,
        ),
      );
    });
  }
}
