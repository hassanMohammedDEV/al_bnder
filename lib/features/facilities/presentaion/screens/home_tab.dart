import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/helpers/error_helper.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/facility.dart';
import '../../providers/facility_provider.dart';
import '../../providers/selected_group_provider.dart';
import '../../models/facility_group.dart';
import '../../../wallet/providers/wallet_provider.dart';
import '../../../../presentaion/shared/ad_banner.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groupsState = ref.watch(facilityGroupsProvider);
    final groups = groupsState.data ?? [];
    final selectedId = ref.watch(selectedGroupProvider);
    final selectedGroup = groups.where((g) => g.id == selectedId).firstOrNull;

    // Auto-select first active group
    if (selectedId == null && groups.isNotEmpty) {
      final firstActive = groups.where((g) => g.isActive).firstOrNull ?? groups.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedGroupProvider.notifier).select(firstActive.id);
      });
    }

    return RefreshIndicator(
      onRefresh: () async {
        final selected = ref.read(selectedGroupProvider);
        ref.invalidate(facilityGroupsProvider);
        if (selected != null) ref.invalidate(facilitiesProvider(selected));
        await Future.delayed(const Duration(seconds: 1));
      },
      child: RepaintBoundary(
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
        // Group selector
        groups.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _GroupChip(
                    group: groups[i],
                    isSelected: groups[i].id == selectedId,
                    onTap: () {
                      final g = groups[i];
                      if (!g.isActive) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('سيتم إضافة ${g.name} قريباً، ترقبوا الإعلانات'),
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                          ),
                        );
                        return;
                      }
                      ref.read(selectedGroupProvider.notifier).select(g.id);
                    },
                  ),
                ),
              ),
        const SizedBox(height: 16),

        // Wallet card (only for active groups)
        if (selectedGroup != null && selectedGroup.isActive)
          _WalletCard(groupId: selectedGroup.id),

        const SizedBox(height: 12),

        // Ad banner
        const AdBanner(),

        // Facilities section (only for active groups)
        if (selectedGroup != null && selectedGroup.isActive) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Text('الملاعب', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: scheme.onSurface,
              )),
              const Spacer(),
              Text(
                selectedGroup.name,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _FacilitiesList(groupId: selectedGroup.id),
        ],
      ],
      ),
    ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  final FacilityGroup group;
  final bool isSelected;
  final VoidCallback onTap;

  const _GroupChip({
    required this.group,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isActive = group.isActive;
    final opacity = isActive ? 1.0 : 0.5;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: opacity,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(22),
            boxShadow: isSelected
                ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? Icons.sports_soccer : Icons.construction,
                size: 16,
                color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                group.name,
                style: TextStyle(
                  color: isSelected ? scheme.onPrimary : scheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletCard extends ConsumerWidget {
  final String groupId;
  const _WalletCard({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final walletAsync = ref.watch(walletInfoFamilyProvider(groupId));

    return InkWell(
      onTap: () => context.push('/wallet'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [scheme.primary, scheme.primary.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الرصيد الحالي', style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  )),
                  const SizedBox(height: 4),
                  Text(
                    walletAsync.when(
                      data: (w) => '${w.balance.toStringAsFixed(0)} ر.ي',
                      loading: () => '---',
                      error: (_, __) => '---',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left, color: Colors.white.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}

class _FacilitiesList extends ConsumerWidget {
  final String groupId;
  const _FacilitiesList({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final facilitiesAsync = ref.watch(facilitiesProvider(groupId));

    return facilitiesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          children: [
            Icon(Icons.cloud_off, size: 48, color: scheme.error),
            const SizedBox(height: 8),
            Text(translateError(e), style: TextStyle(color: scheme.error, fontSize: 13)),
          ],
        ),
      ),
      data: (facilities) {
        if (facilities.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('لا توجد ملاعب متاحة',
                style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
          );
        }
        return Column(
          children: facilities.map((f) => _FacilityCard(facility: f)).toList(),
        );
      },
    );
  }
}

class _FacilityCard extends ConsumerWidget {
  final Facility facility;
  const _FacilityCard({required this.facility});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authStateProvider);
    final isAdmin = auth.role == 'facility_admin' || auth.role == 'super_admin';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          if (isAdmin) {
            context.go('/admin/dashboard');
          } else {
            context.push('/create-booking', extra: facility);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.sports_soccer, color: scheme.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(facility.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.payments, size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('${facility.pricePerHour.toStringAsFixed(0)} ر.ي / ساعة',
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
