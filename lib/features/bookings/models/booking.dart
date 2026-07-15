import 'package:dart_mappable/dart_mappable.dart';

part 'booking.mapper.dart';

@MappableClass(caseStyle: CaseStyle.snakeCase)
class Booking with BookingMappable {
  final String id;
  final String userId;
  final String facilityId;
  final String facilityName;
  final String groupId;
  final String groupName;
  final double totalPrice;
  final double paidAmount;
  final String status;
  final String paymentStatus;
  final bool isRecurring;
  final Map<String, dynamic>? recurringRule;
  final String createdAt;
  final bool isAdminBooking;
  final List<BookingInstance>? instances;

  const Booking({
    required this.id,
    required this.userId,
    required this.facilityId,
    required this.facilityName,
    required this.groupId,
    required this.groupName,
    required this.totalPrice,
    this.paidAmount = 0,
    required this.status,
    this.paymentStatus = 'unpaid',
    this.isRecurring = false,
    this.recurringRule,
    required this.createdAt,
    this.isAdminBooking = false,
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
