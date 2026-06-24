import 'package:app_platform_ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/booking.dart';
import '../../providers/booking_provider.dart';

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final bookingsState = ref.watch(myBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('حجوزاتي')),
      body: AsyncView<List<Booking>>(
        status: bookingsState.status,
        data: bookingsState.data,
        error: bookingsState.error,
        onLoading: () => const Center(child: CircularProgressIndicator()),
        onEmpty: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_busy, size: 64, color: scheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('لا توجد حجوزات', style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        onError: (e) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: scheme.error),
              const SizedBox(height: 16),
              Text(e.message, style: TextStyle(color: scheme.error)),
              ElevatedButton.icon(
                onPressed: () => ref.read(myBookingsProvider.notifier).load(),
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        onSuccess: (bookings) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (_, i) => _BookingCard(booking: bookings[i]),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  const _BookingCard({required this.booking});

  Color _statusColor(String status, ColorScheme scheme) {
    switch (status) {
      case 'confirmed': return Colors.green;
      case 'pending': return Colors.orange;
      case 'cancelled': return scheme.error;
      case 'completed': return scheme.primary;
      default: return scheme.onSurfaceVariant;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'confirmed': return 'مؤكد';
      case 'pending': return 'معلق';
      case 'cancelled': return 'ملغي';
      case 'completed': return 'منتهي';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('yyyy/MM/dd');
    final instance = booking.instances?.isNotEmpty == true ? booking.instances!.first : null;
    final date = instance != null
        ? dateFmt.format(DateTime.parse(instance.startAt))
        : '--';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.go('/booking/${booking.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(booking.facilityName, style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600,
                    )),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(booking.status, scheme).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusLabel(booking.status),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(booking.status, scheme),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(date, style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(width: 16),
                  Icon(Icons.payments, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text('${booking.totalPrice.toStringAsFixed(0)} ر.س',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
