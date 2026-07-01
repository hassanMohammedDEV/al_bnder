import 'package:app_platform_core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/player_ad.dart';
import '../../providers/player_ad_provider.dart';
import '../../../facilities/providers/selected_group_provider.dart';

class ReportedAdsScreen extends ConsumerStatefulWidget {
  final bool inShell;
  const ReportedAdsScreen({super.key, this.inShell = false});

  @override
  ConsumerState<ReportedAdsScreen> createState() => _ReportedAdsScreenState();
}

class _ReportedAdsScreenState extends ConsumerState<ReportedAdsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupId = ref.read(selectedGroupProvider);
      if (groupId != null) {
        ref.read(reportedPlayerAdsProvider.notifier).load(groupId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(reportedPlayerAdsProvider);
    final action = ref.watch(playerAdActionProvider);

    Widget content;

    if (state.status == LoadStatus.loading && state.data == null) {
      content = const Center(child: CircularProgressIndicator());
    } else if (state.status == LoadStatus.error) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: scheme.error),
            const SizedBox(height: 8),
            Text('فشل التحميل', style: TextStyle(color: scheme.error)),
          ],
        ),
      );
    } else if (state.data == null || state.data!.isEmpty) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_outlined, size: 64, color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('لا توجد بلاغات', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16)),
          ],
        ),
      );
    } else {
      final bottomInset = MediaQuery.of(context).padding.bottom;
      content = ListView.builder(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
        itemCount: state.data!.length,
        itemBuilder: (_, i) => _ReportedAdCard(
          ad: state.data![i],
          isProcessing: action.isLoading('dismiss'),
          onDismiss: () => ref.read(playerAdActionProvider.notifier).dismissReport(state.data![i].id),
          onDelete: () => _confirmDelete(context, state.data![i].id),
        ),
      );
    }

    if (widget.inShell) {
      return Scaffold(
        appBar: AppBar(title: const Text('البلاغات')),
        body: content,
      );
    }
    return Scaffold(appBar: AppBar(title: const Text('البلاغات')), body: content);
  }

  void _confirmDelete(BuildContext context, String adId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الإعلان'),
        content: const Text('سيتم حذف الإعلان وجميع البلاغات المرتبطة به'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(playerAdActionProvider.notifier).deleteAd(adId);
            },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

class _ReportedAdCard extends StatelessWidget {
  final PlayerAd ad;
  final bool isProcessing;
  final VoidCallback onDismiss;
  final VoidCallback onDelete;

  const _ReportedAdCard({
    required this.ad,
    required this.isProcessing,
    required this.onDismiss,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLooking = ad.type == 'looking_team';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: scheme.errorContainer.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag, size: 16, color: scheme.error),
                const SizedBox(width: 6),
                Text(isLooking ? 'أبحث عن فريق' : 'ناقصنا لاعبين',
                  style: TextStyle(fontWeight: FontWeight.w600, color: scheme.error)),
                const Spacer(),
                Text(ad.creatorName, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            Text(ad.notes ?? '', style: TextStyle(color: scheme.onSurface, fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isProcessing ? null : onDismiss,
                    child: const Text('تجاهل'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: isProcessing ? null : onDelete,
                    style: FilledButton.styleFrom(backgroundColor: scheme.error),
                    child: const Text('حذف الإعلان'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
