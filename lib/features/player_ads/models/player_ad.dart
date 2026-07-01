class PlayerAd {
  final String id;
  final String facilityGroupId;
  final String creatorId;
  final String creatorName;
  final String creatorPhone;
  final String type;
  final List<String> days;
  final String? startTime;
  final String? endTime;
  final String? facilityId;
  final String? facilityName;
  final String? date;
  final int? playersNeeded;
  final String? position;
  final String? notes;
  final String status;
  final String createdAt;

  const PlayerAd({
    required this.id,
    required this.facilityGroupId,
    required this.creatorId,
    required this.creatorName,
    required this.creatorPhone,
    required this.type,
    this.days = const [],
    this.startTime,
    this.endTime,
    this.facilityId,
    this.facilityName,
    this.date,
    this.playersNeeded,
    this.position,
    this.notes,
    this.status = 'active',
    required this.createdAt,
  });

  factory PlayerAd.fromMap(Map<String, dynamic> map) {
    return PlayerAd(
      id: map['id'] as String,
      facilityGroupId: map['facility_group_id'] as String,
      creatorId: map['creator_id'] as String,
      creatorName: map['creator_name'] as String? ?? '',
      creatorPhone: map['creator_phone'] as String? ?? '',
      type: map['type'] as String,
      days: (map['days'] as List?)?.map((e) => e as String).toList() ?? [],
      startTime: map['start_time'] as String?,
      endTime: map['end_time'] as String?,
      facilityId: map['facility_id'] as String?,
      facilityName: map['facility_name'] as String?,
      date: map['date'] as String?,
      playersNeeded: map['players_needed'] as int?,
      position: map['position'] as String?,
      notes: map['notes'] as String?,
      status: map['status'] as String? ?? 'active',
      createdAt: map['created_at'] as String,
    );
  }
}
