import 'package:flutter/material.dart';

class BookingFormState {
  final String facilityId;
  final DateTime selectedDate;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool isRecurring;
  final List<int> recurringDays;
  final DateTime? recurringEndDate;

  const BookingFormState({
    required this.facilityId,
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

  BookingFormState copyWith({
    String? facilityId,
    DateTime? selectedDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? isRecurring,
    List<int>? recurringDays,
    DateTime? recurringEndDate,
  }) {
    return BookingFormState(
      facilityId: facilityId ?? this.facilityId,
      selectedDate: selectedDate ?? this.selectedDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringDays: recurringDays ?? this.recurringDays,
      recurringEndDate: recurringEndDate ?? this.recurringEndDate,
    );
  }
}
