class GroupSettings {
  final String facilityGroupId;
  final String openingTime;
  final String closingTimeSun;
  final String closingTimeMon;
  final String closingTimeTue;
  final String closingTimeWed;
  final String closingTimeThu;
  final String closingTimeFri;
  final String closingTimeSat;
  final double depositAmount;
  final int contractExpiryHours;
  final double maxBookingHours;
  final String slotFineFrom;
  final String slotFineTo;

  const GroupSettings({
    required this.facilityGroupId,
    required this.openingTime,
    required this.closingTimeSun,
    required this.closingTimeMon,
    required this.closingTimeTue,
    required this.closingTimeWed,
    required this.closingTimeThu,
    required this.closingTimeFri,
    required this.closingTimeSat,
    required this.depositAmount,
    required this.contractExpiryHours,
    required this.maxBookingHours,
    required this.slotFineFrom,
    required this.slotFineTo,
  });

  factory GroupSettings.fromJson(Map<String, dynamic> json) => GroupSettings(
    facilityGroupId: json['facility_group_id'] as String? ?? '',
    openingTime: json['opening_time'] as String? ?? '16:00',
    closingTimeSun: json['closing_time_sun'] as String? ?? '22:00',
    closingTimeMon: json['closing_time_mon'] as String? ?? '22:00',
    closingTimeTue: json['closing_time_tue'] as String? ?? '22:00',
    closingTimeWed: json['closing_time_wed'] as String? ?? '22:00',
    closingTimeThu: json['closing_time_thu'] as String? ?? '22:00',
    closingTimeFri: json['closing_time_fri'] as String? ?? '22:00',
    closingTimeSat: json['closing_time_sat'] as String? ?? '22:00',
    depositAmount: (json['deposit_amount'] as num?)?.toDouble() ?? 5000,
    contractExpiryHours: (json['contract_expiry_hours'] as num?)?.toInt() ?? 8,
    maxBookingHours: (json['max_booking_hours'] as num?)?.toDouble() ?? 3.0,
    slotFineFrom: json['slot_fine_from'] as String? ?? '16:00',
    slotFineTo: json['slot_fine_to'] as String? ?? '20:00',
  );
}
