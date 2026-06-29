class GroupAvailability {
  final String groupName;
  final String date;
  final String? openingTime;
  final String? closingTime;
  final List<FacilityAvailability> facilities;

  const GroupAvailability({
    required this.groupName,
    required this.date,
    this.openingTime,
    this.closingTime,
    this.facilities = const [],
  });

  factory GroupAvailability.fromMap(Map<String, dynamic> map) {
    return GroupAvailability(
      groupName: map['group_name'] as String? ?? '',
      date: map['date'] as String? ?? '',
      openingTime: map['opening_time'] as String?,
      closingTime: map['closing_time'] as String?,
      facilities: ((map['facilities'] as List?) ?? [])
          .map((e) => FacilityAvailability.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class FacilityAvailability {
  final String id;
  final String name;
  final double pricePerHour;
  final List<BookedSlot> bookedSlots;

  const FacilityAvailability({
    required this.id,
    required this.name,
    this.pricePerHour = 0,
    this.bookedSlots = const [],
  });

  factory FacilityAvailability.fromMap(Map<String, dynamic> map) {
    return FacilityAvailability(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      pricePerHour: (map['price_per_hour'] as num?)?.toDouble() ?? 0,
      bookedSlots: ((map['booked_slots'] as List?) ?? [])
          .map((e) => BookedSlot.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class BookedSlot {
  final String id;
  final String startAt;
  final String endAt;
  final String status;

  const BookedSlot({
    required this.id,
    required this.startAt,
    required this.endAt,
    required this.status,
  });

  factory BookedSlot.fromMap(Map<String, dynamic> map) {
    return BookedSlot(
      id: map['id'] as String? ?? '',
      startAt: map['start_at'] as String? ?? '',
      endAt: map['end_at'] as String? ?? '',
      status: map['status'] as String? ?? '',
    );
  }
}
