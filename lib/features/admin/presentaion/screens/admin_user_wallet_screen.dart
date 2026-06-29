import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../presentaion/shared/time_picker_dialog.dart';
import '../../repositories/admin_repository_impl.dart';
import '../../../../core/helpers/error_helper.dart';

class AdminUserWalletScreen extends ConsumerStatefulWidget {
  final String userId;
  final String groupId;
  final String userName;

  const AdminUserWalletScreen({
    super.key,
    required this.userId,
    required this.groupId,
    required this.userName,
  });

  @override
  ConsumerState<AdminUserWalletScreen> createState() => _AdminUserWalletScreenState();
}

class _AdminUserWalletScreenState extends ConsumerState<AdminUserWalletScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final result = await ref.read(adminRepositoryProvider).getUserWallet(
      targetUserId: widget.userId,
      facilityGroupId: widget.groupId,
    );
    if (!mounted) return;
    result.when(
      success: (data) => setState(() { _data = data; _loading = false; }),
      failure: (e) => setState(() { _error = translateError(e); _loading = false; }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('محفظة ${widget.userName}')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: TextStyle(color: scheme.error)))
                : _buildContent(scheme),
      ),
    );
  }

  Widget _buildContent(ColorScheme scheme) {
    final balance = (_data!['balance'] as num?)?.toDouble() ?? 0;
    final transactions = (_data!['transactions'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return ListView(
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
              Text('${balance.toStringAsFixed(0)} ر.ي', style: TextStyle(
                color: scheme.onPrimary,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              )),
            ],
          ),
        ),
        // Transactions header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('الحركات', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface,
              )),
              const Spacer(),
              Text('${transactions.length} حركة', style: TextStyle(
                color: scheme.onSurfaceVariant, fontSize: 13,
              )),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (transactions.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: Text('لا توجد حركات', style: TextStyle(color: scheme.onSurfaceVariant))),
          )
        else
          ...transactions.map((txn) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _txnTile(txn, scheme),
          )),
      ],
    );
  }

  Widget _txnTile(Map<String, dynamic> txn, ColorScheme scheme) {
    final type = txn['type'] as String? ?? '';
    final isDeposit = type == 'deposit';
    final amount = (txn['amount'] as num?)?.toDouble() ?? 0;
    final description = txn['description'] as String?;
    final createdAt = txn['created_at'] as String? ?? '';

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
                  Text(description ?? (isDeposit ? 'إيداع' : 'سحب'),
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                  if (createdAt.isNotEmpty)
                    Text(formatDateTime12(DateTime.parse(createdAt)),
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Text(
              '${isDeposit ? '+' : '-'}${amount.toStringAsFixed(0)} ر.ي',
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
