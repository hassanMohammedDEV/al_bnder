import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';

class SimpleSettingsScreen extends ConsumerWidget {
  const SimpleSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final themeMode = ref.watch(themeModeProvider);
    final auth = ref.watch(authStateProvider);

    final content = ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_outlined, color: scheme.primary),
                      onPressed: () => context.push('/edit-profile'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
        Text('القانونية', style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant,
        )),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.privacy_tip_outlined, color: scheme.primary),
                title: const Text('سياسة الخصوصية'),
                trailing: Icon(Icons.arrow_forward_ios, color: scheme.onSurfaceVariant),
                onTap: () => context.push('/privacy'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.description_outlined, color: scheme.primary),
                title: const Text('شروط الاستخدام'),
                trailing: Icon(Icons.arrow_forward_ios, color: scheme.onSurfaceVariant),
                onTap: () => context.push('/terms'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('معلومات التطبيق', style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant,
        )),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.share_outlined, color: scheme.primary),
                title: const Text('مشاركة التطبيق'),
                subtitle: const Text('أرسل رابط التطبيق لأصدقائك'),
                trailing: Icon(Icons.arrow_forward_ios, color: scheme.onSurfaceVariant),
                onTap: () {
                  Share.share(
                    'ملاعب البندر - تطبيق حجز الملاعب\nhttps://play.google.com/store/apps/details?id=com.al_bndr.app',
                    subject: 'ملاعب البندر',
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.info_outline, color: scheme.primary),
                title: const Text('الإصدار'),
                trailing: Text('1.0.40', style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
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

    return content;
  }
}
