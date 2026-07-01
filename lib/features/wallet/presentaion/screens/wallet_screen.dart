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
    final selected = ref.read(selectedGroupProvider);
    if (selected != null) {
      ref.invalidate(walletInfoFamilyProvider(selected));
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

    Widget body;
    if (selectedGroup == null) {
      body = groups.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Center(child: Text('اختر مجموعة ملاعب', style: TextStyle(color: scheme.onSurfaceVariant)));
    } else {
      body = _WalletBody(groupId: selectedGroup, groups: groups, scheme: scheme);
    }

    final scaffold = Scaffold(
      appBar: AppBar(title: const Text('المحفظة')),
      body: RefreshIndicator(onRefresh: _refresh, child: body),
    );
    if (widget.inShell) {
      return RefreshIndicator(onRefresh: _refresh, child: body);
    }
    return scaffold;
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
    final walletAsync = ref.watch(walletInfoFamilyProvider(groupId));
    final activeGroups = groups.where((g) => g.isActive).toList();

    final selected = groups.where((g) => g.id == groupId).firstOrNull;
    final phone = selected?.phone;

    return walletAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: scheme.error),
            const SizedBox(height: 16),
            Text(translateError(e), style: TextStyle(color: scheme.error)),
          ],
        ),
      ),
      data: (wallet) => ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Balance card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.primary.withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text('الرصيد الحالي', style: TextStyle(
                  color: scheme.onPrimary.withValues(alpha: 0.8),
                  fontSize: 14,
                )),
                const SizedBox(height: 8),
                Text('${wallet.balance.toStringAsFixed(0)} ر.ي', style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                )),
              ],
            ),
          ),
          // WhatsApp contact
          if (phone != null && phone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: () async {
                  final url = Uri.parse(_whatsappUrl(phone));
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                },
                icon: Icon(Icons.chat, color: const Color(0xFF25D366)),
                label: Text(
                  'تواصل واتساب: $phone',
                  style: TextStyle(color: const Color(0xFF25D366)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF25D366)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          // Group selector (active only)
          if (activeGroups.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: activeGroups.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final g = activeGroups[i];
                    return FilterChip(
                      label: Text(g.name, style: const TextStyle(fontSize: 13)),
                      selected: g.id == groupId,
                      onSelected: (_) => ref.read(selectedGroupProvider.notifier).select(g.id),
                    );
                  },
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Transactions header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('الحركات', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface,
                )),
                const Spacer(),
                Text('${wallet.transactions.length} حركة', style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: 13,
                )),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (wallet.transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text('لا توجد حركات', style: TextStyle(color: scheme.onSurfaceVariant))),
            )
          else
            ...wallet.transactions.map((txn) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _TransactionTile(txn: txn, scheme: scheme),
            )),
        ],
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
