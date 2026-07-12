import 'package:app_platform_core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/helpers/error_helper.dart';
import '../../../../presentaion/shared/time_picker_dialog.dart';
import '../../../facilities/providers/selected_group_provider.dart';
import '../../../facilities/providers/facility_provider.dart';
import '../../models/wallet.dart';
import '../../providers/wallet_provider.dart';

String _whatsappUrl(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0')) {
    return 'https://wa.me/966${digits.substring(1)}';
  }
  if (digits.startsWith('966')) {
    return 'https://wa.me/$digits';
  }
  return 'https://wa.me/$digits';
}

class WalletScreen extends ConsumerStatefulWidget {
  final bool inShell;
  const WalletScreen({super.key, this.inShell = false});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  Future<void> _refresh() async {
    final notifier = ref.read(walletInfoProvider.notifier);
    final selected = ref.read(selectedGroupProvider);
    if (selected != null) {
      notifier.load(facilityGroupId: selected);
    }
    ref.invalidate(facilityGroupsProvider);
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedGroup = ref.watch(selectedGroupProvider);
    final groupsState = ref.watch(facilityGroupsProvider);
    final groups = groupsState.data ?? [];

    // Sync group changes
    if (selectedGroup != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(walletInfoProvider.notifier).setGroupId(selectedGroup);
      });
    }

    Widget body;
    if (selectedGroup == null) {
      body = groups.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Center(child: Text('اختر مجموعة ملاعب', style: TextStyle(color: scheme.onSurfaceVariant)));
    } else {
      body = _WalletBody(groupId: selectedGroup, groups: groups, scheme: scheme);
    }

    if (widget.inShell) {
      return RefreshIndicator(onRefresh: _refresh, child: body);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('المحفظة')),
      body: RefreshIndicator(onRefresh: _refresh, child: body),
    );
  }
}

class _WalletBody extends ConsumerWidget {
  final String groupId;
  final List<dynamic> groups;
  final ColorScheme scheme;

  const _WalletBody({
    required this.groupId,
    required this.groups,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(walletInfoProvider);

    final activeGroups = groups.where((g) => g.isActive).toList();
    final selected = groups.where((g) => g.id == groupId).firstOrNull;
    final phone = selected?.phone;

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
                Icon(Icons.error_outline, size: 48, color: scheme.error),
                const SizedBox(height: 16),
                Text(translateError(state.error!), style: TextStyle(color: scheme.error)),
                ElevatedButton.icon(
                  onPressed: () => ref.read(walletInfoProvider.notifier).load(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ]);
      case LoadStatus.success:
        final wallet = state.data!;
        return _WalletPaginatedList(
          wallet: wallet,
          activeGroups: activeGroups,
          groupId: groupId,
          phone: phone,
          scheme: scheme,
          onRefresh: () => ref.read(walletInfoProvider.notifier).load(),
          onLoadMore: () => ref.read(walletInfoProvider.notifier).loadMore(),
          onGroupSelected: (id) => ref.read(selectedGroupProvider.notifier).select(id),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _WalletPaginatedList extends StatefulWidget {
  final WalletPaginatedState wallet;
  final List<dynamic> activeGroups;
  final String groupId;
  final String? phone;
  final ColorScheme scheme;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final void Function(String id) onGroupSelected;

  const _WalletPaginatedList({
    required this.wallet,
    required this.activeGroups,
    required this.groupId,
    required this.phone,
    required this.scheme,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onGroupSelected,
  });

  @override
  State<_WalletPaginatedList> createState() => _WalletPaginatedListState();
}

class _WalletPaginatedListState extends State<_WalletPaginatedList> {
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
    final txs = widget.wallet.transactions;
    final isLoadingMore = txs.isLoadingMore;
    final hasMore = txs.hasNext;
    final allTxs = txs.items;
    final totalCount = allTxs.length + (txs.pagination.page * txs.pagination.limit);

    // Build header items
    List<Widget> headers = [];

    headers.add(
      Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [widget.scheme.primary, widget.scheme.primary.withValues(alpha: 0.8)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Text('الرصيد الحالي', style: TextStyle(
              color: widget.scheme.onPrimary.withValues(alpha: 0.8),
              fontSize: 14,
            )),
            const SizedBox(height: 8),
            Text('${widget.wallet.balance.toStringAsFixed(0)} ر.ي', style: TextStyle(
              color: widget.scheme.onPrimary,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            )),
          ],
        ),
      ),
    );

    if (widget.phone != null && widget.phone!.isNotEmpty) {
      headers.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            onPressed: () async {
              final url = Uri.parse(_whatsappUrl(widget.phone!));
              try {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } catch (_) {}
            },
            icon: Icon(Icons.chat, color: const Color(0xFF25D366)),
            label: Text(
              'للشحن تواصل واتساب: ${widget.phone}',
              style: TextStyle(color: const Color(0xFF25D366)),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF25D366)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      );
    }

    if (widget.activeGroups.length > 1) {
      headers.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.activeGroups.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final g = widget.activeGroups[i];
                return FilterChip(
                  label: Text(g.name, style: const TextStyle(fontSize: 13)),
                  selected: g.id == widget.groupId,
                  onSelected: (_) => widget.onGroupSelected(g.id),
                );
              },
            ),
          ),
        ),
      );
    }

    headers.add(const SizedBox(height: 16));
    headers.add(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text('الحركات', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: widget.scheme.onSurface,
            )),
            const Spacer(),
            Text('$totalCount حركة', style: TextStyle(
              color: widget.scheme.onSurfaceVariant, fontSize: 13,
            )),
          ],
        ),
      ),
    );
    headers.add(const SizedBox(height: 8));

    final headerCount = headers.length;
    final itemCount = headerCount + allTxs.length + (hasMore || isLoadingMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: itemCount,
        itemBuilder: (_, i) {
          if (i < headerCount) {
            return headers[i];
          }
          final txnIndex = i - headerCount;
          if (txnIndex >= allTxs.length) {
            if (txs.paginationError != null) {
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
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _TransactionTile(txn: allTxs[txnIndex], scheme: widget.scheme),
          );
        },
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final WalletTransaction txn;
  final ColorScheme scheme;

  const _TransactionTile({required this.txn, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final isCredit = txn.type == 'deposit' || txn.type == 'refund';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              color: isCredit ? Colors.green : scheme.error,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(txn.description ?? (isCredit ? 'إيداع' : 'سحب'),
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text(formatDateTime12(DateTime.parse(txn.createdAt)),
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Text(
              '${isCredit ? '+' : '-'}${txn.amount.toStringAsFixed(0)} ر.ي',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isCredit ? Colors.green : scheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
