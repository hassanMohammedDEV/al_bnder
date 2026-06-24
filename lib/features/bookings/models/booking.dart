import 'package:dart_mappable/dart_mappable.dart';

part 'booking.mapper.dart';

@MappableClass(caseStyle: CaseStyle.snakeCase)
class Booking with BookingMappable {
  final String id;
  final String userId;
  final String facilityId;
  final String facilityName;
  final String groupName;
  final double totalPrice;
  final String status;
  final String paymentStatus;
  final bool isRecurring;
  final Map<String, dynamic>? recurringRule;
  final String createdAt;
  final List<BookingInstance>? instances;

  const Booking({
    required this.id,
    required this.userId,
    required this.facilityId,
    required this.facilityName,
    required this.groupName,
    required this.totalPrice,
    required this.status,
    this.paymentStatus = 'unpaid',
    this.isRecurring = false,
    this.recurringRule,
    required this.createdAt,
    this.instances,
  });

  static const fromMap = BookingMapper.fromMap;
}

@MappableClass(caseStyle: CaseStyle.snakeCase)
class BookingInstance with BookingInstanceMappable {
  final String id;
  final String startAt;
  final String endAt;
  final String status;
  final String? qrToken;

  const BookingInstance({
    required this.id,
    required this.startAt,
    required this.endAt,
    required this.status,
    this.qrToken,
  });

  static const fromMap = BookingInstanceMapper.fromMap;
}
