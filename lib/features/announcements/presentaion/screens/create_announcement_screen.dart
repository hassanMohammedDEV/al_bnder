import 'package:app_platform_core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/announcement_provider.dart';

class CreateAnnouncementScreen extends ConsumerStatefulWidget {
  const CreateAnnouncementScreen({super.key});

  @override
  ConsumerState<CreateAnnouncementScreen> createState() => _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends ConsumerState<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final result = await ref.read(announcementActionProvider.notifier).createAnnouncement(
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
    );

    if (!mounted) return;
    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال الإشعار')),
        );
        context.pop();
      },
      failure: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is NetworkError ? e.message : 'فشل الإرسال')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(announcementActionProvider);
    final isSending = actionState.isLoading('create');

    return Scaffold(
      appBar: AppBar(title: const Text('إرسال إشعار')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'العنوان',
                  hintText: 'عنوان الإشعار',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'أدخل العنوان' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bodyCtrl,
                decoration: const InputDecoration(
                  labelText: 'النص',
                  hintText: 'نص الإشعار',
                ),
                maxLines: 6,
                validator: (v) => v == null || v.trim().isEmpty ? 'أدخل النص' : null,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: isSending ? null : _submit,
                icon: isSending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(isSending ? 'جار الإرسال...' : 'إرسال'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
