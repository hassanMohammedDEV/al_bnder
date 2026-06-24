import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../providers/facility_provider.dart';

class FacilitiesScreen extends ConsumerWidget {
  final String groupId;
  const FacilitiesScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final facilitiesAsync = ref.watch(facilitiesProvider(groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('الملاعب')),
      body: facilitiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: scheme.error),
              const SizedBox(height: 16),
              Text('$e', style: TextStyle(color: scheme.error)),
            ],
          ),
        ),
        data: (facilities) => facilities.isEmpty
            ? Center(child: Text('لا توجد ملاعب', style: TextStyle(color: scheme.onSurfaceVariant)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: facilities.length,
                itemBuilder: (_, i) => _FacilityCard(facility: facilities[i]),
              ),
      ),
    );
  }
}

class _FacilityCard extends StatelessWidget {
  final Facility facility;
  const _FacilityCard({required this.facility});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.go('/create-booking', extra: facility.id),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.stadium_outlined, color: scheme.primary, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(facility.name, style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    )),
                    const SizedBox(height: 4),
                    Text('${facility.pricePerHour.toStringAsFixed(0)} ر.س/الساعة', style: TextStyle(
                      fontSize: 14,
                      color: scheme.primary,
                      fontWeight: FontWeight.w500,
                    )),
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
