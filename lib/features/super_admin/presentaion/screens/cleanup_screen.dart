import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/api_client_provider.dart';

class CleanupScreen extends ConsumerWidget {
  const CleanupScreen({super.key});

  static const _actions = [
    _CleanupAction('expired_otp', 'أكواد OTP منتهية', Icons.timer_off, 'حذف أكواد التحقق منتهية الصلاحية'),
    _CleanupAction('old_player_ads', 'إعلانات قديمة', Icons.campaign, 'حذف إعلانات ملغية/منتهية أقدم من 3 أشهر'),
    _CleanupAction('old_notifications', 'إشعارات قديمة', Icons.notifications_off, 'حذف إشعارات أقدم من 6 أشهر'),
    _CleanupAction('old_cancelled_instances', 'مواعيد ملغية قديمة', Icons.event_busy, 'حذف مواعيد ملغية أقدم من 6 أشهر'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(Icons.cleaning_services, size: 20, color: scheme.onSurface),
            const SizedBox(width: 8),
            Text('تنظيف البيانات', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface,
            )),
          ],
        ),
        const SizedBox(height: 4),
        Text('هذه العمليات لا تؤثر على بيانات الحجوزات أو المحفظة', style: TextStyle(
          fontSize: 13, color: scheme.onSurfaceVariant,
        )),
        const SizedBox(height: 16),
        ..._actions.map((a) => _CleanupCard(action: a, scheme: scheme, ref: ref)),
      ],
    );
  }
}

class _CleanupAction {
  final String type;
  final String title;
  final IconData icon;
  final String description;
  const _CleanupAction(this.type, this.title, this.icon, this.description);
}

class _CleanupCard extends StatelessWidget {
  final _CleanupAction action;
  final ColorScheme scheme;
  final WidgetRef ref;

  const _CleanupCard({
    required this.action,
    required this.scheme,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withAlpha(80),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(action.icon, color: scheme.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(action.title, style: TextStyle(
                    fontWeight: FontWeight.w600, color: scheme.onSurface,
                  )),
                  const SizedBox(height: 4),
                  Text(action.description, style: TextStyle(
                    fontSize: 13, color: scheme.onSurfaceVariant,
                  )),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _confirmAndRun(context, ref),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('تنظيف'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange.withAlpha(30),
                foregroundColor: Colors.orange.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndRun(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تنظيف: ${action.title}'),
        content: Text('${action.description}.\n\nهل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('تنظيف'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final api = ref.read(apiClientProvider);
    final result = await api.post<Map<String, dynamic>>(
      'rpc/admin_cleanup',
      body: {'p_type': action.type},
      parser: (json) => json as Map<String, dynamic>,
    );

    if (!context.mounted) return;
    result.when(
      success: (data) {
        final msg = data['message'] as String? ?? 'تم التنظيف';
        final count = (data['data'] as Map<String, dynamic>?)?['deleted_count'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$msg ($count)'),
          backgroundColor: Colors.green.shade700,
        ));
      },
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('فشل: $e'),
          backgroundColor: Colors.red,
        ));
      },
    );
  }
}
