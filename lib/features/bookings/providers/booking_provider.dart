import 'package:app_platform_core/core.dart';
import 'package:app_platform_state/state.dart' hide ActionState;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

export '../../auth/providers/auth_provider.dart' show ActionState;
import '../models/booking.dart';
import '../models/booking_state.dart';
import '../repositories/booking_repository_impl.dart';

final myBookingsProvider = NotifierProvider<MyBookingsNotifier, BaseState<List<Booking>>>(
  MyBookingsNotifier.new,
);

final bookingFormProvider = NotifierProvider<BookingFormNotifier, BookingFormState>(
  BookingFormNotifier.new,
);

final bookingActionProvider = NotifierProvider<BookingActionNotifier, ActionState>(
  BookingActionNotifier.new,
);

class MyBookingsNotifier extends BaseNotifier<List<Booking>> {
  @override
  BaseState<List<Booking>> build() {
    Future.microtask(() => load());
    return const BaseState();
  }

  Future<void> load({String? status}) async {
    setLoading();
    final result = await ref.read(bookingRepositoryProvider).getMyBookings(status: status);
    result.when(
      success: (data) => setSuccess(data),
      failure: (e) => setError(e),
    );
  }
}

class BookingFormNotifier extends Notifier<BookingFormState> {
  @override
  BookingFormState build() => BookingFormState(
    facilityId: '',
    selectedDate: DateTime.now().add(const Duration(days: 1)),
    startTime: const TimeOfDay(hour: 16, minute: 0),
    endTime: const TimeOfDay(hour: 18, minute: 0),
  );

  void init(String facilityId) => state = state.copyWith(facilityId: facilityId);
  void setDate(DateTime d) => state = state.copyWith(selectedDate: d);
  void setStartTime(TimeOfDay t) => state = state.copyWith(startTime: t);
  void setEndTime(TimeOfDay t) => state = state.copyWith(endTime: t);
  void toggleRecurring() => state = state.copyWith(isRecurring: !state.isRecurring);
  void toggleDay(int day) {
    final days = List<int>.from(state.recurringDays);
    if (days.contains(day)) {
      days.remove(day);
    } else {
      days.add(day);
    }
    state = state.copyWith(recurringDays: days);
  }
  void setRecurringEnd(DateTime d) => state = state.copyWith(recurringEndDate: d);
}

class BookingActionNotifier extends Notifier<ActionState> {
  @override
  ActionState build() => const ActionState();

  Future<Result<Map<String, dynamic>>> createBooking(BookingFormState form) async {
    state = state.start('create');
    final start = DateTime(
      form.selectedDate.year,
      form.selectedDate.month,
      form.selectedDate.day,
      form.startTime.hour,
      form.startTime.minute,
    );
    final end = DateTime(
      form.selectedDate.year,
      form.selectedDate.month,
      form.selectedDate.day,
      form.endTime.hour,
      form.endTime.minute,
    );

    Map<String, dynamic>? rule;
    if (form.isRecurring && form.recurringDays.isNotEmpty) {
      rule = {
        'frequency': 'weekly',
        'days_of_week': form.recurringDays,
        'end_date': form.recurringEndDate?.toIso8601String(),
      };
    }

    final result = await ref.read(bookingRepositoryProvider).createBooking(
      facilityId: form.facilityId,
      startAt: start,
      endAt: end,
      isRecurring: form.isRecurring,
      recurringRule: rule,
    );

    result.when(
      success: (_) {
        state = state.success('create');
        ref.read(myBookingsProvider.notifier).load();
      },
      failure: (e) => state = state.fail('create', e.message),
    );
    return result;
  }

  Future<Result<void>> cancelBooking(String bookingId) async {
    state = state.start('cancel');
    final result = await ref.read(bookingRepositoryProvider).cancelBooking(bookingId);
    result.when(
      success: (_) {
        state = state.success('cancel');
        ref.read(myBookingsProvider.notifier).load();
      },
      failure: (e) => state = state.fail('cancel', e.message),
    );
    return result;
  }

  void reset() {
    state = const ActionState();
  }
}
