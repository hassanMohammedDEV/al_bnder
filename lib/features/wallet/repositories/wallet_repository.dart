import 'package:app_platform_core/core.dart';

import '../models/wallet.dart';

abstract class WalletRepository {
  Future<Result<WalletInfo>> getWallet(String facilityGroupId);
}
