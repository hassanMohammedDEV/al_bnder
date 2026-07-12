import 'package:app_platform_core/core.dart';

import '../models/wallet.dart';

abstract class WalletRepository {
  Future<Result<WalletPaginatedState>> getWallet(String facilityGroupId, {Pagination? pagination});
}
