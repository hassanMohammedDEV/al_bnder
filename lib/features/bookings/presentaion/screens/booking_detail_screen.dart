import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/booking.dart';
import '../../providers/booking_provider.dart';
import '../../../../core/helpers/error_helper.dart';

class BookingDetailScreen extends ConsumerWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final bookingsState = ref.watch(myBookingsProvider);
    final bookings = bookingsState.data?.items ?? [];
    final booking = bookings.where((b) => b.id == bookingId).firstOrNull;

    final canCancel = () {
      if (booking == null) return false;
      if (booking.isAdminBooking) return false;
      if (booking.status != 'pending' && booking.status != 'confirmed' && booking.status != 'pending_approval') return false;
      final instance = booking.instances?.isNotEmpty == true ? booking.instances!.first : null;
      if (instance == null) return false;
      final startAt = DateTime.parse(instance.startAt).toLocal();
      return DateTime.now().isBefore(startAt);
    }();

    if (booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الحجز')),
        body: const Center(child: Text('الحجز غير موجود')),
      );
    }

    final dateFmt = DateFormat('yyyy/MM/dd');

    String fmt12(DateTime dt) {
      final local = dt.toLocal();
      final h = local.hour;
      final hour12 = h == 0 ? 12 : (h <= 12 ? h : h - 12);
      final period = h < 12 ? 'ص' : 'م';
      return '$hour12:00 $period';
    }

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
                        Text('${dateFmt.format(start.toLocal())} - ${fmt12(start)} إلى ${fmt12(end)}'),
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
          // Creation time
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text('تم الإنشاء: ${_formatDateTime(booking.createdAt)}',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Price
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.payments, color: scheme.primary),
                      const SizedBox(width: 12),
                      Text('الإجمالي', style: TextStyle(color: scheme.onSurfaceVariant)),
                      const Spacer(),
                      Text('${booking.totalPrice.toStringAsFixed(0)} ر.ي', style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: scheme.onSurface,
                      )),
                    ],
                  ),
                  if (booking.isAdminBooking) ...[
                    const Divider(height: 20),
                    Row(
                      children: [
                        Icon(Icons.admin_panel_settings, size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Text('تم الدفع للإدارة', style: TextStyle(
                          color: Colors.green, fontWeight: FontWeight.w500,
                        )),
                      ],
                    ),
                  ] else if (booking.paidAmount > 0) ...[
                    const Divider(height: 20),
                    Row(
                      children: [
                        Icon(Icons.receipt, size: 16,
                          color: booking.paidAmount >= booking.totalPrice ? Colors.green : scheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          booking.paidAmount >= booking.totalPrice
                              ? 'مدفوع بالكامل'
                              : 'مدفوع: ${booking.paidAmount.toStringAsFixed(0)} ر.ي',
                          style: TextStyle(
                            color: booking.paidAmount >= booking.totalPrice ? Colors.green : scheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (booking.paidAmount < booking.totalPrice) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.money_off, size: 16, color: scheme.error),
                          const SizedBox(width: 8),
                          Text('المتبقي: ${(booking.totalPrice - booking.paidAmount).toStringAsFixed(0)} ر.ي',
                            style: TextStyle(color: scheme.error, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ],
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
                    QrImageView(
                      data: booking.instances!.first.qrToken!,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Text('رمز التحقق', style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          // Cancel button
          if (booking.isAdminBooking)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock, size: 18, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'هذا الحجز تم عبر الإدارة، للإلغاء يرجى التواصل معهم',
                      style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else if (canCancel)
            OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('إلغاء الحجز'),
                    content: Text(_cancelMessage(booking)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('رجوع')),
                      FilledButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final result = await ref.read(bookingActionProvider.notifier).cancelBooking(booking.id);
                          if (context.mounted) {
                            result.when(
                              success: (data) {
                                final msg = data['message'] as String? ?? 'تم إلغاء الحجز';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(msg)),
                                );
                                context.pop();
                              },
                              failure: (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(translateError(e))),
                                );
                              },
                            );
                          }
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
      case 'pending_approval': color = Colors.blue; label = 'شبه مؤكد'; break;
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

String _formatDateTime(String iso) {
  final dt = DateTime.parse(iso).toLocal();
  final h = dt.hour;
  final m = dt.minute;
  final hour12 = h == 0 ? 12 : (h <= 12 ? h : h - 12);
  final period = h < 12 ? 'ص' : 'م';
  return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} $hour12:${m.toString().padLeft(2, '0')} $period';
}

String _cancelMessage(Booking booking) {
  if (booking.isAdminBooking) {
    return 'هذا الحجز تم عبر الإدارة. للإلغاء يرجى التواصل مع الإدارة.';
  }
  if (booking.paidAmount >= booking.totalPrice) {
    return 'تم دفع المبلغ كاملاً. سيتم خصم العربون كرسوم إلغاء وإرجاع الباقي.';
  }
  if (booking.paidAmount > 0) {
    return 'تم دفع العربون فقط. سيتم خصم العربون كرسوم إلغاء.';
  }
  return 'لم يتم دفع أي مبلغ. الإلغاء بدون رسوم.';
}
