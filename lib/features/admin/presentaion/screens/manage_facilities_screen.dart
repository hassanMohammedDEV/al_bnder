import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../repositories/admin_repository_impl.dart';
import '../../../../core/helpers/error_helper.dart';

final adminFacilitiesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) async {
  final result = await ref.read(adminRepositoryProvider).adminGetFacilities(groupId);
  return result.when(
    success: (data) => data,
    failure: (e) => throw Exception(e.message),
  );
});

class ManageFacilitiesScreen extends ConsumerWidget {
  const ManageFacilitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authStateProvider);
    final groupId = auth.facilityGroupId;

    if (groupId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('إدارة الملاعب')),
        body: Center(child: Text('لم يتم تحديد مجموعة', style: TextStyle(color: scheme.onSurfaceVariant))),
      );
    }

    final facilitiesAsync = ref.watch(adminFacilitiesProvider(groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الملاعب')),
      body: facilitiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e', style: TextStyle(color: scheme.error))),
        data: (facilities) {
          if (facilities.isEmpty) {
            return Center(child: Text('لا توجد ملاعب', style: TextStyle(color: scheme.onSurfaceVariant)));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminFacilitiesProvider(groupId)),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: facilities.length,
              itemBuilder: (_, i) => _FacilityCard(facility: facilities[i]),
            ),
          );
        },
      ),
    );
  }
}

class _FacilityCard extends ConsumerWidget {
  final Map<String, dynamic> facility;
  const _FacilityCard({required this.facility});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final name = facility['name'] as String? ?? '';
    final description = facility['description'] as String?;
    final price = (facility['price_per_hour'] as num?)?.toDouble() ?? 0;
    final isActive = facility['is_active'] as bool? ?? true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.green.withAlpha(38) : scheme.error.withAlpha(38),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(isActive ? 'نشط' : 'متوقف',
                            style: TextStyle(fontSize: 11, color: isActive ? Colors.green : scheme.error)),
                      ),
                    ],
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(description, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                  ],
                  const SizedBox(height: 4),
                  Text('$price ر.ي / ساعة',
                      style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showEditDialog(context, ref, facility),
            ),
          ],
        ),
      ),
    );
  }
}

void _showEditDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> facility) {
  final id = facility['id'] as String;
  final nameCtl = TextEditingController(text: facility['name'] as String? ?? '');
  final descCtl = TextEditingController(text: facility['description'] as String? ?? '');
  final priceCtl = TextEditingController(
    text: (facility['price_per_hour'] as num?)?.toStringAsFixed(0) ?? '',
  );
  final formKey = GlobalKey<FormState>();
  var saving = false;
  var isActive = facility['is_active'] as bool? ?? true;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('تعديل بيانات الملعب', style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'اسم الملعب'),
                      controller: nameCtl,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'الحقل مطلوب' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'الوصف'),
                      controller: descCtl,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'السعر لكل ساعة'),
                      controller: priceCtl,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'الحقل مطلوب';
                        if (double.tryParse(v) == null) return 'رجاء أدخل رقم صحيح';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('الملعب نشط'),
                      value: isActive,
                      onChanged: (v) => setSheetState(() => isActive = v),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSheetState(() => saving = true);
                              final price = double.parse(priceCtl.text.trim());
                              final result = await ref.read(adminRepositoryProvider).updateFacility(
                                    facilityId: id,
                                    name: nameCtl.text.trim(),
                                    description: descCtl.text.trim().isEmpty ? null : descCtl.text.trim(),
                                    pricePerHour: price,
                                    isActive: isActive,
                                  );
                              if (!ctx.mounted) return;
                              setSheetState(() => saving = false);
                              result.when(
                                success: (_) {
                                  Navigator.of(ctx).pop();
                                  ref.invalidate(adminFacilitiesProvider(
                                      ref.read(authStateProvider).facilityGroupId!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('تم حفظ التعديلات')),
                                  );
                                },
                                failure: (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(translateError(e))),
                                  );
                                },
                              );
                            },
                      child: saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('حفظ'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
