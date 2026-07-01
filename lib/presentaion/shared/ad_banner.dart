import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/ads/models/facility_ad.dart';
import '../../features/ads/providers/ads_provider.dart';
import '../../features/facilities/providers/facility_provider.dart';
import '../../features/facilities/providers/selected_group_provider.dart';

class AdBanner extends ConsumerStatefulWidget {
  const AdBanner({super.key});

  @override
  ConsumerState<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends ConsumerState<AdBanner> with WidgetsBindingObserver {
  final _pageCtrl = PageController();
  Timer? _timer;
  int _currentPage = 0;
  int _lastTotal = 0;
  int _foregroundKey = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(activeAdsProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _timer?.cancel();
      _lastTotal = 0;
      _foregroundKey++;
      _currentPage = 0;
      _pageCtrl.jumpToPage(0);
      setState(() {});
    }
  }

  void _startAutoScroll(int total) {
    if (_lastTotal == total) return;
    _lastTotal = total;
    _timer?.cancel();
    if (total <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % total;
      _pageCtrl.animateToPage(next, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final adsAsync = ref.watch(activeAdsProvider);

    return adsAsync.when(
      loading: () => const SizedBox(height: 130, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, _) => const SizedBox.shrink(),
      data: (ads) {
        if (ads.isEmpty) return _EmptyAdSpace();
        final total = ads.length;
        WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll(total));
        return SizedBox(
          height: 146,
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: total,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (_, i) => _AdCard(ad: ads[i], key: ValueKey('${ads[i].id}-$_foregroundKey')),
                ),
              ),
              if (total > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(total, (i) {
                      final isCurrent = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isCurrent ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyAdSpace extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final groups = ref.watch(facilityGroupsProvider).data ?? [];
    final selectedId = ref.watch(selectedGroupProvider);
    final group = groups.where((g) => g.id == selectedId).firstOrNull;
    final phone = group?.phone;

    return GestureDetector(
      onTap: () {
        final number = phone ?? '+967730845718';
        final msg = 'مرحباً، أرغب في الإعلان في تطبيق البندر';
        final url = 'https://wa.me/${number.replaceAll('+', '')}?text=${Uri.encodeComponent(msg)}';
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
      child: Container(
        height: 130,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant, width: 1.5),
          color: scheme.surfaceContainerHighest,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.campaign_outlined, size: 36, color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
              const SizedBox(height: 8),
              Text('مساحة إعلانية',
                style: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 15)),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone, size: 14, color: const Color(0xFF25D366)),
                  const SizedBox(width: 4),
                  Text('للإعلان تواصل معنا',
                    style: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final _colors = [
  const Color(0xFF6A1B9A),
  const Color(0xFFC62828),
  const Color(0xFF00695C),
  const Color(0xFFE65100),
  const Color(0xFF2E7D32),
  const Color(0xFF283593),
  const Color(0xFFAD1457),
];

class _AdCard extends StatelessWidget {
  final FacilityAd ad;
  const _AdCard({super.key, required this.ad});

  void _openLink(BuildContext context) {
    if (ad.linkUrl == null || ad.linkUrl!.isEmpty) return;
    final url = ad.linkUrl!.startsWith('http') ? ad.linkUrl! : 'https://${ad.linkUrl!}';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final colorIndex = ad.title.hashCode.abs() % _colors.length;
    final color = _colors[colorIndex];
    final hasLink = ad.linkUrl != null && ad.linkUrl!.isNotEmpty;
    final hasImage = ad.imageUrl != null && ad.imageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: hasLink ? () => _openLink(context) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              Image.network(
                ad.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  );
                },
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            if (hasImage)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withValues(alpha: 0.1), Colors.black.withValues(alpha: 0.6)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('ممول',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                    if (hasLink) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.open_in_new, color: Colors.white.withValues(alpha: 0.7), size: 14),
                    ],
                  ]),
                  const SizedBox(height: 8),
                  Text(ad.title,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  if (ad.description != null && ad.description!.isNotEmpty)
                    Text(ad.description!,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
