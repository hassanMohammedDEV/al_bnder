import 'package:app_platform_core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ads/models/facility_ad.dart';
import '../../../ads/providers/ads_provider.dart';
import '../../../../core/helpers/error_helper.dart';

class CreateEditAdScreen extends ConsumerStatefulWidget {
  final String facilityGroupId;
  final FacilityAd? ad;

  const CreateEditAdScreen({
    super.key,
    required this.facilityGroupId,
    this.ad,
  });

  @override
  ConsumerState<CreateEditAdScreen> createState() => _CreateEditAdScreenState();
}

class _CreateEditAdScreenState extends ConsumerState<CreateEditAdScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _imageUrlCtrl;
  late final TextEditingController _linkUrlCtrl;
  late final TextEditingController _sortOrderCtrl;
  DateTime? _startsAt;
  DateTime? _endsAt;

  bool get _isEditing => widget.ad != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.ad?.title ?? '');
    _descCtrl = TextEditingController(text: widget.ad?.description ?? '');
    _imageUrlCtrl = TextEditingController(text: widget.ad?.imageUrl ?? '');
    _linkUrlCtrl = TextEditingController(text: widget.ad?.linkUrl ?? '');
    _sortOrderCtrl = TextEditingController(text: (widget.ad?.sortOrder ?? 0).toString());
    _startsAt = widget.ad?.startsAt != null ? DateTime.tryParse(widget.ad!.startsAt!) : null;
    _endsAt = widget.ad?.endsAt != null ? DateTime.tryParse(widget.ad!.endsAt!) : null;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _imageUrlCtrl.dispose();
    _linkUrlCtrl.dispose();
    _sortOrderCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final initial = isStart ? (_startsAt ?? now) : (_endsAt ?? _startsAt ?? now);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !context.mounted) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startsAt = dt;
      } else {
        _endsAt = dt;
      }
    });
  }

  String _formatDt(DateTime? dt) {
    if (dt == null) return 'اختياري';
    final d = '${dt.day}/${dt.month}/${dt.year}';
    final t = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$d $t';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleCtrl.text.trim();
    final description = _descCtrl.text.trim();
    final imageUrl = _imageUrlCtrl.text.trim();
    final linkUrl = _linkUrlCtrl.text.trim();
    final sortOrder = int.tryParse(_sortOrderCtrl.text.trim()) ?? 0;

    final Result<void> result;
    if (_isEditing) {
      result = await ref.read(adActionProvider.notifier).updateAd(
        adId: widget.ad!.id,
        title: title,
        description: description.isNotEmpty ? description : null,
        imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
        linkUrl: linkUrl.isNotEmpty ? linkUrl : null,
        startsAt: _startsAt?.toUtc().toIso8601String(),
        endsAt: _endsAt?.toUtc().toIso8601String(),
        sortOrder: sortOrder,
      );
    } else {
      result = await ref.read(adActionProvider.notifier).createAd(
        facilityGroupId: widget.facilityGroupId,
        title: title,
        description: description.isNotEmpty ? description : null,
        imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
        linkUrl: linkUrl.isNotEmpty ? linkUrl : null,
        startsAt: _startsAt?.toUtc().toIso8601String(),
        endsAt: _endsAt?.toUtc().toIso8601String(),
        sortOrder: sortOrder,
      );
    }

    if (!context.mounted) return;
    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? 'تم تحديث الإعلان' : 'تم إضافة الإعلان')),
        );
        context.pop();
      },
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(translateError(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final actionState = ref.watch(adActionProvider);
    final isSaving = actionState.isLoading('create') || actionState.isLoading('update');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل الإعلان' : 'إعلان جديد'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'العنوان',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 16),
              validator: (v) => v == null || v.trim().isEmpty ? 'الرجاء إدخال العنوان' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'الوصف',
                hintText: 'نص الإعلان (اختياري)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _imageUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'رابط الصورة (اختياري)',
                hintText: 'https://example.com/image.jpg',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 16),
            ),
            if (_imageUrlCtrl.text.isNotEmpty && _imageUrlCtrl.text.startsWith('http'))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _imageUrlCtrl.text,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: 150,
                      color: scheme.errorContainer,
                      child: Center(
                        child: Text('فشل تحميل الصورة', style: TextStyle(color: scheme.onErrorContainer)),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _linkUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'رابط الضغط (اختياري)',
                hintText: 'https://example.com',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sortOrderCtrl,
              decoration: const InputDecoration(
                labelText: 'الترتيب',
                hintText: '0 = الأول',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Text('تاريخ البدء والانتهاء', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurface,
            )),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(true),
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'البداية',
                        border: const OutlineInputBorder(),
                        suffixIcon: const Icon(Icons.date_range),
                        labelStyle: TextStyle(color: _startsAt != null ? null : scheme.onSurfaceVariant),
                      ),
                      child: Text(
                        _formatDt(_startsAt),
                        style: TextStyle(color: _startsAt != null ? null : scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(false),
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'الانتهاء',
                        border: const OutlineInputBorder(),
                        suffixIcon: const Icon(Icons.date_range),
                        labelStyle: TextStyle(color: _endsAt != null ? null : scheme.onSurfaceVariant),
                      ),
                      child: Text(
                        _formatDt(_endsAt),
                        style: TextStyle(color: _endsAt != null ? null : scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: isSaving ? null : _save,
              icon: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(isSaving ? 'جاري الحفظ...' : (_isEditing ? 'حفظ التعديلات' : 'إضافة الإعلان')),
            ),
          ],
        ),
      ),
    );
  }
}
