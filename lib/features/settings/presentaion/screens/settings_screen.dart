import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
