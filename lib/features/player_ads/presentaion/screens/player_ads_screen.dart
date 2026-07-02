import 'package:app_platform_core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/helpers/error_messages.dart';
import '../../models/player_ad.dart';
import '../../providers/player_ad_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../facilities/providers/selected_group_provider.dart';

class PlayerAdsScreen extends ConsumerStatefulWidget {
  final bool inShell;
  const PlayerAdsScreen({super.key, this.inShell = false});

  @override
  ConsumerState<PlayerAdsScreen> createState() => _PlayerAdsScreenState();
}

class _PlayerAdsScreenState extends ConsumerState<PlayerAdsScreen> {
  String _typeFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final state = ref.watch(playerAdsProvider);
    final userId = ref.read(authStateProvider).userId;

    if (selectedGroup == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('إعلانات اللاعبين')),
        body: Center(
          child: Text('اختر مجموعة ملاعب أولاً', style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
      );
    }

    Widget content;

    if (state.status == LoadStatus.loading && state.data == null) {
      content = const Center(child: CircularProgressIndicator());
    } else if (state.status == LoadStatus.error) {
      final errMsg = state.error?.userMessage ?? 'فشل تحميل الإعلانات';
      content = RefreshIndicator(
        onRefresh: () => ref.read(playerAdsProvider.notifier).reload(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: scheme.error),
                  const SizedBox(height: 8),
                  Text(errMsg, style: TextStyle(color: scheme.error)),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => ref.read(playerAdsProvider.notifier).reload(),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      final ads = state.data ?? [];
      final filtered = _typeFilter == 'all'
          ? ads
          : _typeFilter == 'mine'
              ? (userId != null ? ads.where((a) => a.creatorId == userId).toList() : ads)
              : ads.where((a) => a.type == _typeFilter).toList();

      if (filtered.isEmpty) {
        content = RefreshIndicator(
          onRefresh: () => ref.read(playerAdsProvider.notifier).reload(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline, size: 64, color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text('لا توجد إعلانات', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('أضف أول إعلان', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        );
      } else {
        final bottomInset = MediaQuery.of(context).padding.bottom;
        content = RefreshIndicator(
          onRefresh: () => ref.read(playerAdsProvider.notifier).reload(),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 80),
            itemCount: filtered.length,
            itemBuilder: (_, i) => _PlayerAdCard(ad: filtered[i]),
          ),
        );
      }
    }

    if (widget.inShell) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('إعلانات اللاعبين'),
          actions: [
            _TypeFilter(
              current: _typeFilter,
              onChanged: (v) => setState(() => _typeFilter = v),
            ),
          ],
        ),
        body: content,
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.push('/create-player-ad'),
          child: const Icon(Icons.add),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعلانات اللاعبين'),
        actions: [
          _TypeFilter(
            current: _typeFilter,
            onChanged: (v) => setState(() => _typeFilter = v),
          ),
        ],
      ),
      body: content,
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/create-player-ad'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TypeFilter extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const _TypeFilter({
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FilterChip(
          label: 'الكل',
          selected: current == 'all',
          onTap: () => onChanged('all'),
        ),
        const SizedBox(width: 4),
        _FilterChip(
          label: 'أبحث عن فريق',
          selected: current == 'looking_team',
          onTap: () => onChanged('looking_team'),
        ),
        const SizedBox(width: 4),
        _FilterChip(
          label: 'ناقصنا',
          selected: current == 'nakusna',
          onTap: () => onChanged('nakusna'),
        ),
        const SizedBox(width: 4),
        _FilterChip(
          label: 'إعلاناتي',
          selected: current == 'mine',
          onTap: () => onChanged('mine'),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.transparent : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _PlayerAdCard extends ConsumerWidget {
  final PlayerAd ad;
  const _PlayerAdCard({required this.ad});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isLooking = ad.type == 'looking_team';
    final isCreator = ad.creatorId == ref.read(authStateProvider).userId;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  isLooking ? Icons.person_search : Icons.group_add,
                  size: 18,
                  color: isLooking ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isLooking ? 'أبحث عن فريق' : 'ناقصنا لاعبين',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isLooking ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
                if (!isLooking && ad.playersNeeded != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${ad.playersNeeded}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.primary),
                    ),
                  ),
                const SizedBox(width: 8),
                Text(_timeAgo(ad.createdAt), style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 10),
            if (isLooking) ...[
              if (ad.days.isNotEmpty)
                _InfoRow(icon: Icons.calendar_today, text: ad.days.map(_dayName).join(' - ')),
              if (ad.startTime != null)
                _InfoRow(icon: Icons.access_time, text: '${ad.startTime} - ${ad.endTime ?? ''}'),
              if (ad.facilityName != null && ad.facilityName!.isNotEmpty)
                _InfoRow(icon: Icons.place, text: ad.facilityName!),
              if (ad.position != null && ad.position!.isNotEmpty)
                _InfoRow(icon: Icons.sports, text: ad.position!),
            ] else ...[
              if (ad.date != null)
                _InfoRow(icon: Icons.event, text: ad.date!),
              if (ad.startTime != null)
                _InfoRow(icon: Icons.access_time, text: '${ad.startTime} - ${ad.endTime ?? ''}'),
              if (ad.facilityName != null && ad.facilityName!.isNotEmpty)
                _InfoRow(icon: Icons.place, text: ad.facilityName!),
            ],
            if (ad.notes != null && ad.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(ad.notes!, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(child: Text(isCreator ? 'إعلاني' : ad.creatorName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: scheme.onSurface))),
                if (isCreator) ...[
                  _ActionBtn(icon: Icons.edit_outlined, color: scheme.primary, onTap: () => _editAd(context, ref)),
                  const SizedBox(width: 4),
                  _ActionBtn(icon: Icons.delete_outline, color: scheme.error, onTap: () => _confirmDelete(context, ref)),
                ],
                if (!isCreator) ...[
                  _ActionBtn(icon: Icons.flag_outlined, color: scheme.onSurfaceVariant, onTap: () => _reportAd(context, ref)),
                  const SizedBox(width: 6),
                  _WhatsAppBtn(phone: ad.creatorPhone),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _dayName(String day) {
    switch (day) {
      case 'saturday': return 'سبت';
      case 'sunday': return 'أحد';
      case 'monday': return 'اثنين';
      case 'tuesday': return 'ثلاثاء';
      case 'wednesday': return 'أربعاء';
      case 'thursday': return 'خميس';
      case 'friday': return 'جمعة';
      default: return day;
    }
  }

  String _timeAgo(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    if (diff.inDays < 2) return 'منذ يوم';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} أيام';
    return '${dt.year}/${dt.month}/${dt.day}';
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الإعلان'),
        content: const Text('هل أنت متأكد من حذف هذا الإعلان؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(playerAdActionProvider.notifier).deleteAd(ad.id);
            },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _editAd(BuildContext context, WidgetRef ref) {
    final playersCtrl = TextEditingController(text: ad.playersNeeded?.toString() ?? '');
    final notesCtrl = TextEditingController(text: ad.notes ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل الإعلان'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ad.type == 'nakusna') ...[
                TextField(
                  controller: playersCtrl,
                  decoration: const InputDecoration(
                    labelText: 'عدد اللاعبين الناقصين',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final data = <String, dynamic>{};
              if (ad.type == 'nakusna') {
                final val = int.tryParse(playersCtrl.text.trim());
                if (val != null) data['p_players_needed'] = val;
              }
              if (notesCtrl.text.trim().isNotEmpty) {
                data['p_notes'] = notesCtrl.text.trim();
              }
              Navigator.pop(ctx);
              ref.read(playerAdActionProvider.notifier).updateAd(ad.id, data);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _reportAd(BuildContext context, WidgetRef ref) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الإبلاغ عن إعلان'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            hintText: 'سبب الإبلاغ...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);
              ref.read(playerAdActionProvider.notifier).reportAd(ad.id, reason);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم الإبلاغ، شكراً لك')),
              );
            },
            child: const Text('إبلاغ'),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class _WhatsAppBtn extends StatelessWidget {
  final String phone;
  const _WhatsAppBtn({required this.phone});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        final url = 'https://wa.me/${phone.replaceAll('+', '')}';
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF25D366),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone, size: 14, color: Colors.white),
            SizedBox(width: 4),
            Text('واتساب', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
