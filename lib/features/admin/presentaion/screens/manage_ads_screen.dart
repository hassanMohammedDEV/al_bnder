import 'package:app_platform_core/core.dart';
import 'package:app_platform_state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ads/models/facility_ad.dart';
import '../../../ads/providers/ads_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/admin_provider.dart';

class ManageAdsScreen extends ConsumerStatefulWidget {
  const ManageAdsScreen({super.key});

  @override
  ConsumerState<ManageAdsScreen> createState() => _ManageAdsScreenState();
}

class _ManageAdsScreenState extends ConsumerState<ManageAdsScreen> {
  String? _selectedGroupId;
  String? _loadedGroupId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authStateProvider);
      if (auth.role != 'super_admin') {
        final gid = auth.facilityGroupId;
        if (gid != null) _loadAds(gid);
      }
    });
  }

  void _loadAds(String groupId) {
    if (groupId == _loadedGroupId) return;
    _loadedGroupId = groupId;
    _selectedGroupId = groupId;
    ref.read(adsProvider.notifier).load(groupId);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authStateProvider);
    final state = ref.watch(adsProvider);
    final actionState = ref.watch(adActionProvider);
    final isSuperAdmin = auth.role == 'super_admin';

    final groupId = _selectedGroupId ?? auth.facilityGroupId;

    return Scaffold(
      appBar: AppBar(title: const Text('الإعلانات الممولة')),
      body: Column(
        children: [
          if (isSuperAdmin) _buildGroupSelector(scheme),
          if (groupId == null && !isSuperAdmin)
            const Expanded(
              child: Center(child: Text('لم يتم تحديد مجموعة')),
            )
          else if (groupId == null)
            const Expanded(
              child: Center(child: Text('جاري تحميل المجموعات...')),
            )
          else
            Expanded(
              child: _buildContent(scheme, state, actionState),
            ),
        ],
      ),
      floatingActionButton: groupId != null
          ? FloatingActionButton(
              onPressed: () => context.push('/admin/ads/create', extra: groupId),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildGroupSelector(ColorScheme scheme) {
    final groupsAsync = ref.watch(dashboardProvider);

    return groupsAsync.when(
      data: (groups) {
        if (groups.isEmpty) return const SizedBox.shrink();

        final groupId = ref.read(authStateProvider).facilityGroupId;
        final actual = _selectedGroupId ?? groupId ?? groups.first.groupId;
        if (_loadedGroupId == null) {
          _loadAds(actual);
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: DropdownButtonFormField<String>(
            initialValue: actual,
            decoration: const InputDecoration(
              labelText: 'المجموعة',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: groups.map((g) => DropdownMenuItem(
              value: g.groupId,
              child: Text(g.groupName),
            )).toList(),
            onChanged: (v) {
              if (v != null) _loadAds(v);
            },
          ),
        );
      },
      error: (_, _) => const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
    );
  }

  Widget _buildContent(ColorScheme scheme, BaseState<List<FacilityAd>> state, ActionStore actionState) {
    if (state.status == LoadStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == LoadStatus.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: scheme.error),
            const SizedBox(height: 8),
            Text('فشل تحميل الإعلانات', style: TextStyle(color: scheme.error)),
          ],
        ),
      );
    }
    final ads = state.data;
    if (ads == null || ads.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined, size: 64, color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('لا توجد إعلانات', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16)),
            const SizedBox(height: 8),
            Text('اضغط + لإضافة إعلان', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => ref.read(adsProvider.notifier).reload(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: ads.length,
        itemBuilder: (_, i) => _AdCard(
          ad: ads[i],
          actionState: actionState,
          onToggle: (v) => ref.read(adActionProvider.notifier).toggleActive(ads[i].id, v),
          onEdit: () => context.push('/admin/ads/create', extra: {
            'facilityGroupId': ads[i].facilityGroupId,
            'ad': ads[i],
          }),
          onDelete: () => _confirmDelete(context, ref, ads[i]),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, FacilityAd ad) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الإعلان'),
        content: Text('هل أنت متأكد من حذف الإعلان "${ad.title}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(adActionProvider.notifier).deleteAd(ad.id);
            },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

class _AdCard extends ConsumerWidget {
  final FacilityAd ad;
  final ActionStore actionState;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AdCard({
    required this.ad,
    required this.actionState,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isToggling = actionState.isLoading('toggle');
    final isSorting = actionState.isLoading('sort');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ad.isActive ? null : scheme.surfaceContainerHighest,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.campaign, size: 20, color: ad.isActive ? scheme.primary : scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ad.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: ad.isActive ? null : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('#${ad.sortOrder}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onPrimaryContainer)),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: Icon(Icons.keyboard_arrow_up, color: isSorting ? scheme.onSurfaceVariant.withAlpha(80) : scheme.primary),
                    onPressed: isSorting ? null : () => ref.read(adActionProvider.notifier).updateSortOrder(ad.id, ad.sortOrder - 1),
                  ),
                  IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: Icon(Icons.keyboard_arrow_down, color: isSorting ? scheme.onSurfaceVariant.withAlpha(80) : scheme.primary),
                    onPressed: isSorting ? null : () => ref.read(adActionProvider.notifier).updateSortOrder(ad.id, ad.sortOrder + 1),
                  ),
                  Switch(
                    value: ad.isActive,
                    onChanged: isToggling ? null : onToggle,
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    onSelected: (v) {
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'delete', child: Text('حذف')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (ad.description != null && ad.description!.isNotEmpty)
                Text(
                  ad.description!,
                  style: TextStyle(
                    color: ad.isActive ? scheme.onSurfaceVariant : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              if (ad.imageUrl != null && ad.imageUrl!.isNotEmpty) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    ad.imageUrl!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 120,
                        color: scheme.surfaceContainerHighest,
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
