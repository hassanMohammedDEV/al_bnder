import 'package:app_platform_core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/helpers/error_helper.dart';
import '../../../../presentaion/shared/time_picker_dialog.dart';
import '../../models/booking.dart';
import '../../providers/booking_provider.dart';
import '../../../facilities/providers/selected_group_provider.dart';
import '../../../facilities/providers/facility_provider.dart';

class MyBookingsScreen extends ConsumerStatefulWidget {
  final bool inShell;
  const MyBookingsScreen({super.key, this.inShell = false});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  String? _statusFilter;

  void _setStatus(String? status) {
    setState(() => _statusFilter = status);
    ref.read(myBookingsProvider.notifier).load(status: status);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupsState = ref.watch(facilityGroupsProvider);
    final allGroups = groupsState.data ?? [];
    final activeGroups = allGroups.where((g) => g.isActive).toList();

    // Sync group changes
    if (selectedGroup != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(myBookingsProvider.notifier).setGroupId(selectedGroup);
      });
    }

    Widget content = Column(
      children: [
        // Group selector (active only)
        if (activeGroups.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: activeGroups.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => FilterChip(
                  label: Text(activeGroups[i].name, style: const TextStyle(fontSize: 13)),
                  selected: activeGroups[i].id == selectedGroup,
                  onSelected: (_) => ref.read(selectedGroupProvider.notifier).select(activeGroups[i].id),
                ),
              ),
            ),
          ),
        // Status filter
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                FilterChip(
                  label: const Text('الكل', style: TextStyle(fontSize: 13)),
                  selected: _statusFilter == null,
                  onSelected: (_) => _setStatus(null),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('مؤكد', style: TextStyle(fontSize: 13)),
                  selected: _statusFilter == 'confirmed',
                  onSelected: (_) => _setStatus('confirmed'),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('معلق', style: TextStyle(fontSize: 13)),
                  selected: _statusFilter == 'pending',
                  onSelected: (_) => _setStatus('pending'),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('شبه مؤكد', style: TextStyle(fontSize: 13)),
                  selected: _statusFilter == 'pending_approval',
                  onSelected: (_) => _setStatus('pending_approval'),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('ملغي', style: TextStyle(fontSize: 13)),
                  selected: _statusFilter == 'cancelled',
                  onSelected: (_) => _setStatus('cancelled'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildBody(scheme)),
      ],
    );

    if (widget.inShell) return content;
    return Scaffold(appBar: AppBar(title: const Text('حجوزاتي')), body: content);
  }

  Widget _buildBody(ColorScheme scheme) {
    final state = ref.watch(myBookingsProvider);
    final notifier = ref.read(myBookingsProvider.notifier);

    switch (state.status) {
      case LoadStatus.loading:
        return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.6),
          const Center(child: CircularProgressIndicator()),
        ]);
      case LoadStatus.error:
        return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
          const SizedBox(height: 100),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off, size: 48, color: scheme.error),
                const SizedBox(height: 16),
                Text(translateError(state.error!), style: TextStyle(color: scheme.error)),
                ElevatedButton.icon(
                  onPressed: () => notifier.load(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ]);
      case LoadStatus.success:
        final paginated = state.data;
        final bookings = paginated?.items ?? [];
        if (bookings.isEmpty) {
          return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
            const SizedBox(height: 100),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_busy, size: 64, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('لا توجد حجوزات', style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ]);
        }
        return _BookingPaginatedList(
          paginated: paginated!,
          onRefresh: () => notifier.load(),
          onLoadMore: () => notifier.loadMore(),
          scheme: scheme,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _BookingPaginatedList extends StatefulWidget {
  final Paginated<Booking> paginated;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final ColorScheme scheme;

  const _BookingPaginatedList({
    required this.paginated,
    required this.onRefresh,
    required this.onLoadMore,
    required this.scheme,
  });

  @override
  State<_BookingPaginatedList> createState() => _BookingPaginatedListState();
}

class _BookingPaginatedListState extends State<_BookingPaginatedList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookings = widget.paginated.items;
    final isLoadingMore = widget.paginated.isLoadingMore;
    final hasMore = widget.paginated.hasNext;
    final itemCount = bookings.length + (hasMore || isLoadingMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        itemBuilder: (_, i) {
          if (i == bookings.length) {
            if (widget.paginated.paginationError != null) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Column(
                    children: [
                      Text('فشل التحميل', style: TextStyle(color: widget.scheme.error, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: widget.onLoadMore,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return _BookingCard(booking: bookings[i]);
        },
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
      case 'pending_approval': return Colors.blue;
      case 'cancelled': return scheme.error;
      case 'completed': return scheme.primary;
      default: return scheme.onSurfaceVariant;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'confirmed': return 'مؤكد';
      case 'pending': return 'معلق';
      case 'pending_approval': return 'شبه مؤكد';
      case 'cancelled': return 'ملغي';
      case 'completed': return 'منتهي';
      default: return status;
    }
  }

  String _formatCreatedAt(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour;
      final m = dt.minute;
      final hour12 = h == 0 ? 12 : (h <= 12 ? h : h - 12);
      final period = h < 12 ? 'ص' : 'م';
      final minute = m.toString().padLeft(2, '0');
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} $hour12:$minute $period';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final activeInstances = booking.instances
        ?.where((i) => i.status != 'cancelled' && i.status != 'completed')
        .toList() ?? [];
    final isRecurring = activeInstances.length > 1;
    final firstInstance = activeInstances.isNotEmpty ? activeInstances.first : booking.instances?.firstOrNull;
    final bookingDate = firstInstance != null
        ? DateTime.parse(firstInstance.startAt).toLocal()
        : null;
    final bookingEnd = firstInstance != null
        ? DateTime.parse(firstInstance.endAt).toLocal()
        : null;

    String fmt12(DateTime dt) {
      final h = dt.hour;
      final m = dt.minute;
      final hour12 = h == 0 ? 12 : (h <= 12 ? h : h - 12);
      final period = h < 12 ? 'ص' : 'م';
      final minute = m.toString().padLeft(2, '0');
      return '$hour12:$minute $period';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/booking/${booking.id}'),
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
                  if (isRecurring)
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        children: activeInstances.map((i) {
                          final dt = DateTime.parse(i.startAt).toLocal();
                          return Text(dateLabelWithDay(dt),
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant));
                        }).toList(),
                      ),
                    )
                  else
                    Text(
                      bookingDate != null ? dateLabelWithDay(bookingDate) : '--',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  const SizedBox(width: 16),
                  Icon(Icons.payments, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text('${booking.totalPrice.toStringAsFixed(0)} ر.ي',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
              if (bookingDate != null && bookingEnd != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, size: 13, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '${fmt12(bookingDate)} إلى ${fmt12(bookingEnd)}',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              if (isRecurring)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: activeInstances.map((i) {
                      final dt = DateTime.parse(i.startAt).toLocal();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('• ${dateLabelWithDay(dt)}',
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                      );
                    }).toList(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 13, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      'تم الإنشاء: ${_formatCreatedAt(booking.createdAt)}',
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (booking.status == 'pending')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'هذا الحجز معلق، يرجى التواصل مع الإدارة لتأكيد الحجز، وإلا لن يتم احتسابه',
                            style: TextStyle(fontSize: 11, color: Colors.orange.shade800, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (booking.isAdminBooking)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings, size: 13, color: Colors.green),
                      const SizedBox(width: 4),
                      Text('تم الدفع للإدارة', style: TextStyle(
                        fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500,
                      )),
                    ],
                  ),
                )
              else if (booking.paidAmount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.receipt, size: 13,
                        color: booking.paidAmount >= booking.totalPrice ? Colors.green : scheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        booking.paidAmount >= booking.totalPrice
                            ? 'مدفوع بالكامل'
                            : 'عربون: ${booking.paidAmount.toStringAsFixed(0)} ر.ي',
                        style: TextStyle(
                          fontSize: 12,
                          color: booking.paidAmount >= booking.totalPrice ? Colors.green : scheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.receipt, size: 13, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('لم يتم الدفع', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
