import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../announcements/providers/announcement_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  final bool inShell;
  const SettingsScreen({super.key, this.inShell = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final themeMode = ref.watch(themeModeProvider);
    final auth = ref.watch(authStateProvider);
    final isAdmin = auth.role == 'facility_admin' || auth.role == 'super_admin';

    Widget content = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Profile section
        Card(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(Icons.person, color: scheme.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(auth.name.isNotEmpty ? auth.name : 'مستخدم',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          Text(auth.phone,
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
                          if (auth.role != null)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(_roleLabel(auth.role!),
                                style: TextStyle(fontSize: 12, color: scheme.onSecondaryContainer)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Admin section
        if (isAdmin) ...[
          Card(
            child: ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.admin_panel_settings, color: Colors.orange),
              ),
              title: const Text('لوحة الإدارة'),
              subtitle: Text('إدارة الملاعب والحجوزات', style: TextStyle(color: scheme.onSurfaceVariant)),
              trailing: Icon(Icons.arrow_forward_ios, color: scheme.onSurfaceVariant),
              onTap: () => context.go('/admin/dashboard'),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Announcements
        Card(
          child: ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.campaign, color: scheme.primary),
            ),
            title: const Text('الإشعارات'),
            trailing: Builder(builder: (_) {
              final count = ref.watch(unreadCountProvider);
              if (count > 0) {
                return Badge(
                  label: Text('$count'),
                  child: Icon(Icons.arrow_forward_ios, color: scheme.onSurfaceVariant),
                );
              }
              return Icon(Icons.arrow_forward_ios, color: scheme.onSurfaceVariant);
            }),
            onTap: () => context.push('/announcements'),
          ),
        ),
        const SizedBox(height: 16),
        // Available slots
        Card(
          child: ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.schedule, color: Colors.green),
            ),
            title: const Text('الأوقات المتاحة'),
            subtitle: Text('عرض ومشاركة الأوقات الفارغة', style: TextStyle(color: scheme.onSurfaceVariant)),
            trailing: Icon(Icons.arrow_forward_ios, color: scheme.onSurfaceVariant),
            onTap: () => context.push('/available-slots'),
          ),
        ),
        const SizedBox(height: 16),
        // Theme section
        Card(
          child: SwitchListTile(
            title: const Text('الوضع الداكن'),
            subtitle: Text(
              themeMode == ThemeMode.dark ? 'مفعل' : 'غير مفعل',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            value: themeMode == ThemeMode.dark,
            onChanged: (v) {
              if (v) {
                ref.read(themeModeProvider.notifier).setDark();
              } else {
                ref.read(themeModeProvider.notifier).setLight();
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        // App info section
        Text('معلومات التطبيق', style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant,
        )),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.info_outline, color: scheme.primary),
                title: const Text('الإصدار'),
                trailing: Text('1.0.0', style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.code, color: scheme.primary),
                title: const Text('البندر - نظام حجز الملاعب'),
                subtitle: const Text('تم التطوير باستخدام Flutter + Supabase'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chat, color: Color(0xFF25D366)),
                ),
                title: const Text('تواصل مع المطور'),
                subtitle: const Text('عبر واتساب'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () async {
                  final url = Uri.parse('https://wa.me/967730845718');
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Logout button
        OutlinedButton.icon(
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('تسجيل الخروج'),
                content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('تسجيل الخروج'),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              ref.read(authStateProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            }
          },
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );

    if (inShell) return content;
    return Scaffold(appBar: AppBar(title: const Text('الإعدادات')), body: content);
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'super_admin': return 'مشرف عام';
      case 'facility_admin': return 'مدير ملاعب';
      case 'facility_viewer': return 'مشاهد';
      default: return 'مستخدم';
    }
  }
}
