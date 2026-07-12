import 'package:app_platform_core/core.dart';

class WalletPaginatedState {
  final String walletId;
  final double balance;
  final String facilityGroupId;
  final Paginated<WalletTransaction> transactions;

  const WalletPaginatedState({
    required this.walletId,
    required this.balance,
    required this.facilityGroupId,
    required this.transactions,
  });

  WalletPaginatedState copyWith({
    String? walletId,
    double? balance,
    String? facilityGroupId,
    Paginated<WalletTransaction>? transactions,
  }) {
    return WalletPaginatedState(
      walletId: walletId ?? this.walletId,
      balance: balance ?? this.balance,
      facilityGroupId: facilityGroupId ?? this.facilityGroupId,
      transactions: transactions ?? this.transactions,
    );
  }
}

class WalletInfo {
  final String id;
  final double balance;
  final String facilityGroupId;
  final String? facilityGroupName;
  final List<WalletTransaction> transactions;

  const WalletInfo({
    required this.id,
    required this.balance,
    required this.facilityGroupId,
    this.facilityGroupName,
    this.transactions = const [],
  });
}

class WalletTransaction {
  final String id;
  final double amount;
  final String type;
  final String? referenceType;
  final String? referenceId;
  final String? description;
  final String createdAt;

  const WalletTransaction({
    required this.id,
    required this.amount,
    required this.type,
    this.referenceType,
    this.referenceId,
    this.description,
    required this.createdAt,
  });
}
