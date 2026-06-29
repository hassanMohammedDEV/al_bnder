import 'package:flutter/material.dart';

class BookingFormState {
  final String facilityId;
  final String facilityName;
  final double pricePerHour;
  final DateTime selectedDate;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool isRecurring;
  final List<int> recurringDays;
  final DateTime? recurringEndDate;

  const BookingFormState({
    required this.facilityId,
    required this.facilityName,
    required this.pricePerHour,
    required this.selectedDate,
    required this.startTime,
    required this.endTime,
    this.isRecurring = false,
    this.recurringDays = const [],
    this.recurringEndDate,
  });

  double get hours {
    final start = startTime.hour + startTime.minute / 60;
    final end = endTime.hour + endTime.minute / 60;
    return end - start;
  }

  double get totalPrice => hours * pricePerHour;

  BookingFormState copyWith({
    String? facilityId,
    String? facilityName,
    double? pricePerHour,
    DateTime? selectedDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? isRecurring,
    List<int>? recurringDays,
    DateTime? recurringEndDate,
  }) {
    return BookingFormState(
      facilityId: facilityId ?? this.facilityId,
      facilityName: facilityName ?? this.facilityName,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      selectedDate: selectedDate ?? this.selectedDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringDays: recurringDays ?? this.recurringDays,
      recurringEndDate: recurringEndDate ?? this.recurringEndDate,
    );
  }
}
