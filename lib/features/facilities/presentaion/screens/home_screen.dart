import 'package:app_platform_ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../providers/facility_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final groupsState = ref.watch(facilityGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('البندر'),
        actions: [
          IconButton(
            icon: const Icon(Icons.wallet_outlined),
            onPressed: () => context.go('/wallet'),
          ),
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _showMenu(context, ref),
          ),
        ],
      ),
      body: AsyncView<List<FacilityGroup>>(
        status: groupsState.status,
        data: groupsState.data,
        error: groupsState.error,
        onLoading: () => const Center(child: CircularProgressIndicator()),
        onEmpty: () => Center(child: Text('لا توجد مجموعات ملاعب',
          style: TextStyle(color: scheme.onSurfaceVariant),
        )),
        onError: (e) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: scheme.error),
              const SizedBox(height: 16),
              Text(e.message, style: TextStyle(color: scheme.error)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.read(facilityGroupsProvider.notifier).load(),
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        onSuccess: (groups) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groups.length,
          itemBuilder: (_, i) => _GroupCard(group: groups[i]),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('حجوزاتي'),
            onTap: () {
              Navigator.pop(context);
              context.go('/my-bookings');
            },
          ),
          ListTile(
            leading: const Icon(Icons.wallet_outlined),
            title: const Text('المحفظة'),
            onTap: () {
              Navigator.pop(context);
              context.go('/wallet');
            },
          ),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings),
            title: const Text('لوحة الإدارة'),
            onTap: () {
              Navigator.pop(context);
              context.go('/admin/dashboard');
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('الإعدادات'),
            onTap: () {
              Navigator.pop(context);
              context.go('/settings');
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _GroupCard extends ConsumerWidget {
  final FacilityGroup group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.go('/facilities/${group.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.sports_soccer, color: scheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(group.name, style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                )),
              ),
              Icon(Icons.chevron_left, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
