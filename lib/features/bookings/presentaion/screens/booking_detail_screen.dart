import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/booking_provider.dart';

class BookingDetailScreen extends ConsumerWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final bookingsState = ref.watch(myBookingsProvider);
    final bookings = bookingsState.data ?? [];
    final booking = bookings.where((b) => b.id == bookingId).firstOrNull;

    if (booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الحجز')),
        body: const Center(child: Text('الحجز غير موجود')),
      );
    }

    final dateFmt = DateFormat('yyyy/MM/dd');
    final timeFmt = DateFormat('HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الحجز')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: scheme.primary, size: 32),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.facilityName, style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: scheme.onSurface,
                    )),
                    Text(booking.groupName, style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Booking details
          Text('تفاصيل الحجز', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface,
          )),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: booking.instances?.map((instance) {
                  final start = DateTime.parse(instance.startAt);
                  final end = DateTime.parse(instance.endAt);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: scheme.primary),
                        const SizedBox(width: 8),
                        Text('${dateFmt.format(start)} - ${timeFmt.format(start)} إلى ${timeFmt.format(end)}'),
                        const Spacer(),
                        _StatusBadge(status: instance.status),
                      ],
                    ),
                  );
                }).toList() ?? [],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Price
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.payments, color: scheme.primary),
                  const SizedBox(width: 12),
                  Text('الإجمالي', style: TextStyle(color: scheme.onSurfaceVariant)),
                  const Spacer(),
                  Text('${booking.totalPrice.toStringAsFixed(0)} ر.س', style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: scheme.onSurface,
                  )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // QR Code
          if (booking.instances?.isNotEmpty == true && booking.instances!.first.qrToken != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.qr_code_2, size: 64, color: scheme.primary),
                    const SizedBox(height: 8),
                    Text('رمز التحقق', style: TextStyle(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(booking.instances!.first.qrToken!, style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant,
                    )),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          // Cancel button
          if (booking.status == 'pending' || booking.status == 'confirmed')
            OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('إلغاء الحجز'),
                    content: const Text('هل أنت متأكد من إلغاء هذا الحجز؟'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('رجوع')),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ref.read(bookingActionProvider.notifier).cancelBooking(booking.id);
                          context.go('/my-bookings');
                        },
                        child: const Text('تأكيد الإلغاء'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('إلغاء الحجز'),
              style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color color;
    String label;
    switch (status) {
      case 'confirmed': color = Colors.green; label = 'مؤكد'; break;
      case 'pending': color = Colors.orange; label = 'معلق'; break;
      case 'cancelled': color = scheme.error; label = 'ملغي'; break;
      case 'completed': color = scheme.primary; label = 'منتهي'; break;
      default: color = scheme.onSurfaceVariant; label = status; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
