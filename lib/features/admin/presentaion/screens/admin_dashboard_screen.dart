import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('لوحة الإدارة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MenuItem(
            icon: Icons.pending_actions,
            title: 'حجوزات معلقة',
            subtitle: 'عرض وتأكيد الحجوزات المعلقة',
            color: Colors.orange,
            onTap: () => context.go('/admin/pending'),
          ),
          _MenuItem(
            icon: Icons.stadium_outlined,
            title: 'إدارة الملاعب',
            subtitle: 'إضافة وتعديل الملاعب',
            color: scheme.primary,
            onTap: () => context.go('/admin/facilities'),
          ),
          _MenuItem(
            icon: Icons.campaign_outlined,
            title: 'الإعلانات',
            subtitle: 'إدارة الإعلانات الممولة',
            color: Colors.purple,
            onTap: () => context.go('/admin/ads'),
          ),
          _MenuItem(
            icon: Icons.account_balance_wallet,
            title: 'شحن المحافظ',
            subtitle: 'إضافة رصيد للمستخدمين',
            color: Colors.green,
            onTap: () {
              // Will navigate to deposit screen
            },
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600,
                    )),
                    Text(subtitle, style: TextStyle(
                      fontSize: 13, color: scheme.onSurfaceVariant,
                    )),
                  ],
                ),
              ),
              Icon(Icons.chevron_left, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
