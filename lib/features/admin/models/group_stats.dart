class GroupStats {
  final String groupId;
  final String groupName;
  final int totalBookings;
  final int confirmedBookings;
  final int pendingBookings;
  final int pendingApprovalBookings;
  final double totalRevenue;
  final double totalDeposits;
  final double developerDue;
  final int developerDueCount;
  final int todayConfirmed;
  final int todayPending;
  final int todayPendingApproval;

  const GroupStats({
    required this.groupId,
    required this.groupName,
    required this.totalBookings,
    required this.confirmedBookings,
    required this.pendingBookings,
    required this.pendingApprovalBookings,
    required this.totalRevenue,
    required this.totalDeposits,
    required this.developerDue,
    this.developerDueCount = 0,
    this.todayConfirmed = 0,
    this.todayPending = 0,
    this.todayPendingApproval = 0,
  });

  factory GroupStats.fromJson(Map<String, dynamic> json) => GroupStats(
    groupId: json['group_id'] as String? ?? '',
    groupName: json['group_name'] as String? ?? '',
    totalBookings: (json['total_bookings'] as num?)?.toInt() ?? 0,
    confirmedBookings: (json['confirmed_bookings'] as num?)?.toInt() ?? 0,
    pendingBookings: (json['pending_bookings'] as num?)?.toInt() ?? 0,
    pendingApprovalBookings: (json['pending_approval_bookings'] as num?)?.toInt() ?? 0,
    totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
    totalDeposits: (json['total_deposits'] as num?)?.toDouble() ?? 0,
    developerDue: (json['developer_due'] as num?)?.toDouble() ?? 0,
    developerDueCount: (json['developer_due_count'] as num?)?.toInt() ?? 0,
    todayConfirmed: (json['today_confirmed'] as num?)?.toInt() ?? 0,
    todayPending: (json['today_pending'] as num?)?.toInt() ?? 0,
    todayPendingApproval: (json['today_pending_approval'] as num?)?.toInt() ?? 0,
  );

  GroupStats merge(GroupStats other) => GroupStats(
    groupId: groupId,
    groupName: groupName,
    totalBookings: totalBookings + other.totalBookings,
    confirmedBookings: confirmedBookings + other.confirmedBookings,
    pendingBookings: pendingBookings + other.pendingBookings,
    pendingApprovalBookings: pendingApprovalBookings + other.pendingApprovalBookings,
    totalRevenue: totalRevenue + other.totalRevenue,
    totalDeposits: totalDeposits + other.totalDeposits,
    developerDue: developerDue + other.developerDue,
    developerDueCount: developerDueCount + other.developerDueCount,
    todayConfirmed: todayConfirmed + other.todayConfirmed,
    todayPending: todayPending + other.todayPending,
    todayPendingApproval: todayPendingApproval + other.todayPendingApproval,
  );
}
