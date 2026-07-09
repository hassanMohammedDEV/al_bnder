import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../announcements/providers/announcement_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../facilities/providers/facility_provider.dart';
import '../../../facilities/providers/selected_group_provider.dart';
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
    final groupsState = ref.watch(facilityGroupsProvider);
    final selectedGroupId = ref.watch(selectedGroupProvider);
    final groups = groupsState.data ?? [];
    final selectedGroup = groups.where((g) => g.id == selectedGroupId).firstOrNull;
    final managerPhone = selectedGroup?.phone;

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
                          if (auth.role != null && auth.role != 'user')
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
        // Admin section (hide when inShell — already in bottom nav)
        if (isAdmin && !inShell) ...[
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
        // Announcements (hide when inShell — bell icon already in AppBar)
        if (!inShell) ...[
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
        ],
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
        // Legal section
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
        // App info section
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
                onTap: () => Share.share(
                  'ملاعب البندر - تطبيق حجز الملاعب\nhttps://play.google.com/store/apps/details?id=com.al_bndr.app',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.info_outline, color: scheme.primary),
                title: const Text('الإصدار'),
                trailing: Text('1.0.0', style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
              const Divider(height: 1),
              if (managerPhone != null && managerPhone.isNotEmpty)
                ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.admin_panel_settings, color: Color(0xFF25D366)),
                  ),
                  title: const Text('تواصل مع مدير الملعب'),
                  subtitle: const Text('عبر واتساب لشحن المحفظة والاستفسار'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () async {
                    final digits = managerPhone.replaceAll(RegExp(r'\D'), '');
                    final url = Uri.parse(digits.startsWith('0')
                        ? 'https://wa.me/966${digits.substring(1)}'
                        : digits.startsWith('966')
                            ? 'https://wa.me/$digits'
                            : 'https://wa.me/$digits');
                    try {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } catch (_) {}
                  },
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
                subtitle: const Text('للإبلاغ عن الأخطاء أو الاقتراحات عبر واتساب'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () async {
                  final url = Uri.parse('https://wa.me/967730845718');
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.email_outlined, color: scheme.primary),
                ),
                title: const Text('البريد الإلكتروني'),
                subtitle: const Text('7assanwr@gmail.com'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () {
                  launchUrl(Uri.parse('mailto:7assanwr@gmail.com'));
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
        const SizedBox(height: 12),
        // Delete account button
        OutlinedButton.icon(
          onPressed: () async {
            final ctl = TextEditingController();
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => StatefulBuilder(
                builder: (ctx, setDialogState) {
                  final typed = ctl.text.trim();
                  final matched = typed == 'حذف';
                  return AlertDialog(
                    title: const Text('حذف الحساب'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('سيتم حذف جميع بياناتك نهائياً ولا يمكن التراجع.'),
                        const SizedBox(height: 8),
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'إذا كان لديك رصيد في المحفظة، سيتم فقدانه. تواصل مع الإدارة قبل حذف الحساب لاسترداد رصيدك.',
                                style: TextStyle(fontSize: 13, color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('للتأكيد، اكتب كلمة "حذف" في الحقل أدناه:', style: TextStyle(fontSize: 13)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: ctl,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'حذف',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            prefixIcon: matched
                                ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                                : const Icon(Icons.edit, size: 20),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                      FilledButton(
                        onPressed: matched ? () => Navigator.pop(ctx, true) : null,
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('حذف'),
                      ),
                    ],
                  );
                },
              ),
            );
            if (confirm == true) {
              if (context.mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final result = await ref.read(authActionProvider.notifier).deleteAccount();
              if (context.mounted) Navigator.of(context).pop();
              if (context.mounted) {
                result.when(
                  success: (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم حذف الحساب')),
                    );
                    context.go('/login');
                  },
                  failure: (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('فشل حذف الحساب: $e')),
                    );
                  },
                );
              }
            }
          },
          icon: const Icon(Icons.delete_forever, color: Colors.red),
          label: const Text('حذف الحساب', style: TextStyle(color: Colors.red)),
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
