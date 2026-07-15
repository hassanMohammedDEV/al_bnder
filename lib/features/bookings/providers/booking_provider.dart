import 'package:app_platform_core/core.dart';
import 'package:app_platform_state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/booking.dart';
import '../models/booking_state.dart';
import '../repositories/booking_repository_impl.dart';
import '../../announcements/providers/local_notification_provider.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../../facilities/providers/selected_group_provider.dart';

final myBookingsProvider = NotifierProvider<MyBookingsNotifier, BaseState<Paginated<Booking>>>(
  MyBookingsNotifier.new,
);

final bookingFormProvider = NotifierProvider<BookingFormNotifier, BookingFormState>(
  BookingFormNotifier.new,
);

final bookingActionProvider = StateNotifierProvider<BookingActionNotifier, ActionStore>(
  (ref) => BookingActionNotifier(ref: ref),
);

class MyBookingsNotifier extends BaseNotifier<Paginated<Booking>> {
  String? _currentGroupId;
  String? _currentStatus;

  @override
  BaseState<Paginated<Booking>> build() {
    final selected = ref.read(selectedGroupProvider);
    if (selected != null) {
      _currentGroupId = selected;
      Future.microtask(() => load());
    }
    return const BaseState(status: LoadStatus.loading);
  }

  void setGroupId(String? groupId) {
    if (groupId != _currentGroupId) {
      _currentGroupId = groupId;
      load();
    }
  }

  Future<void> load({String? status, String? facilityGroupId}) async {
    if (status != null) _currentStatus = status;
    setLoading();
    final result = await ref.read(bookingRepositoryProvider).getMyBookings(
      status: status ?? _currentStatus,
      facilityGroupId: facilityGroupId ?? _currentGroupId,
      pagination: const Pagination(page: 0, limit: 20),
    );
    result.when(
      success: (data) => setSuccess(data),
      failure: (e) => setError(e),
    );
  }

  Future<void> loadMore() async {
    final current = state.data;
    if (current == null || !current.hasNext || current.isLoadingMore) return;
    final nextPage = current.pagination.next();
    state = state.copyWith(
      data: current.copyWith(isLoadingMore: true),
    );
    final result = await ref.read(bookingRepositoryProvider).getMyBookings(
      status: _currentStatus,
      facilityGroupId: _currentGroupId,
      pagination: nextPage,
    );
    result.when(
      success: (page) {
        final allItems = [...current.items, ...page.items];
        state = state.copyWith(
          data: current.copyWith(
            items: allItems,
            pagination: nextPage,
            hasNext: page.hasNext,
            isLoadingMore: false,
          ),
        );
      },
      failure: (e) {
        state = state.copyWith(
          data: current.copyWith(isLoadingMore: false, paginationError: e),
        );
      },
    );
  }
}

class BookingFormNotifier extends Notifier<BookingFormState> {
  @override
  BookingFormState build() => BookingFormState(
    facilityId: '',
    facilityName: '',
    pricePerHour: 0,
    selectedDate: DateTime.now().add(const Duration(days: 1)),
    startTime: const TimeOfDay(hour: 16, minute: 0),
    endTime: const TimeOfDay(hour: 18, minute: 0),
  );

  void init(String facilityId, String facilityName, double pricePerHour) =>
    state = state.copyWith(facilityId: facilityId, facilityName: facilityName, pricePerHour: pricePerHour);
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

class BookingActionNotifier extends StateNotifier<ActionStore> {
  BookingActionNotifier({required this.ref}) : super(ActionStore());

  final Ref ref;

  Future<Result<Map<String, dynamic>>> createBooking(BookingFormState form, {String paymentType = 'auto'}) async {
    const key = 'create';
    state = state.start(key);
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
      paymentType: paymentType,
    );

    result.when(
      success: (_) {
        state = state.success(key);
        ref.read(myBookingsProvider.notifier).load();
        ref.read(localNotificationsProvider.notifier).add(
          LocalNotification(
            id: 'booking_${DateTime.now().millisecondsSinceEpoch}',
            type: 'booking',
            title: '✅ تم إنشاء حجزك في ${form.facilityName}',
            body: 'تم إنشاء حجزك بنجاح. تابع حالة الحجز من صفحة حجوزاتي. نتمنى لك وقتاً ممتعاً! ⚽',
            createdAt: DateTime.now(),
          ),
        );
      },
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

  Future<Result<Map<String, dynamic>>> createBookingRaw({
    required String facilityId,
    required DateTime startAt,
    required DateTime endAt,
    String paymentType = 'auto',
  }) async {
    const key = 'create';
    state = state.start(key);
    final result = await ref.read(bookingRepositoryProvider).createBooking(
      facilityId: facilityId,
      startAt: startAt,
      endAt: endAt,
      paymentType: paymentType,
    );
    result.when(
      success: (_) {
        state = state.success(key);
        ref.read(myBookingsProvider.notifier).load();
      },
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

  Future<Result<Map<String, dynamic>>> cancelBooking(String bookingId) async {
    const key = 'cancel';
    state = state.start(key);
    final result = await ref.read(bookingRepositoryProvider).cancelBooking(bookingId);
    result.when(
      success: (_) {
        state = state.success(key);
        ref.read(myBookingsProvider.notifier).load();
        ref.invalidate(walletInfoFamilyProvider);
      },
      failure: (e) => state = state.fail(key, e),
    );
    return result;
  }

  void reset() => state = ActionStore();
}
