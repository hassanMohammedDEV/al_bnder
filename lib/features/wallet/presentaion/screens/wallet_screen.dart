import 'package:app_platform_ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../facilities/providers/facility_provider.dart';
import '../../models/wallet.dart';
import '../../providers/wallet_provider.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final groupsState = ref.read(facilityGroupsProvider);
      if (groupsState.data?.isNotEmpty == true) {
        _loadWallet(groupsState.data!.first.id);
      }
    });
  }

  void _loadWallet(String groupId) {
    setState(() => _selectedGroupId = groupId);
    ref.read(walletInfoProvider.notifier).load(groupId);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final walletState = ref.watch(walletInfoProvider);
    final groupsState = ref.watch(facilityGroupsProvider);
    final groups = groupsState.data ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('المحفظة')),
      body: AsyncView<WalletInfo>(
        status: walletState.status,
        data: walletState.data,
        error: walletState.error,
        onLoading: () => const Center(child: CircularProgressIndicator()),
        onError: (e) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: scheme.error),
              const SizedBox(height: 16),
              Text(e.message),
              ElevatedButton(
                onPressed: () {
                  if (_selectedGroupId != null) _loadWallet(_selectedGroupId!);
                },
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        onSuccess: (wallet) => Column(
          children: [
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
                  Text('${wallet.balance.toStringAsFixed(0)} ر.س', style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  )),
                ],
              ),
            ),
            if (groups.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: groups.map((g) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(g.name, style: const TextStyle(fontSize: 12)),
                        selected: _selectedGroupId == g.id,
                        onSelected: (_) => _loadWallet(g.id),
                      ),
                    ),
                  )).toList(),
                ),
              ),
            const SizedBox(height: 16),
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
            Expanded(
              child: wallet.transactions.isEmpty
                  ? Center(child: Text('لا توجد حركات', style: TextStyle(color: scheme.onSurfaceVariant)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: wallet.transactions.length,
                      itemBuilder: (_, i) => _TransactionTile(
                        txn: wallet.transactions[i],
                        scheme: scheme,
                      ),
                    ),
            ),
          ],
        ),
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
    final isDeposit = txn.type == 'deposit';
    final dateFmt = DateFormat('yyyy/MM/dd HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
              color: isDeposit ? Colors.green : scheme.error,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(txn.description ?? (isDeposit ? 'إيداع' : 'سحب'),
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text(dateFmt.format(DateTime.parse(txn.createdAt)),
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Text(
              '${isDeposit ? '+' : '-'}${txn.amount.toStringAsFixed(0)} ر.س',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDeposit ? Colors.green : scheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
