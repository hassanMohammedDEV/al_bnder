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
