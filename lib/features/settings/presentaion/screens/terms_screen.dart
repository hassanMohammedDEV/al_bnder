import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('شروط الاستخدام')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('شروط الاستخدام', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: scheme.onSurface)),
          const SizedBox(height: 8),
          Text('آخر تحديث: 2 يوليو 2026', style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          _Section(
            title: 'القبول',
            body: 'باستخدامك لتطبيق "البندر" فإنك توافق على هذه الشروط. إذا كنت لا توافق، يرجى عدم استخدام التطبيق.',
          ),
          _Section(
            title: 'الحساب',
            body: '• يجب أن تقدم معلومات دقيقة عند التسجيل\n• أنت مسؤول عن الحفاظ على سرية كلمة المرور\n• يُمنع إنشاء أكثر من حساب لنفس الشخص',
          ),
          _Section(
            title: 'الحجوزات',
            body: '• الحجز ملزم بعد التأكيد\n• تطبق سياسة الإلغاء حسب إعدادات المنشأة\n• المبالغ المدفوعة غير قابلة للاسترداد إلا حسب سياسة المنشأة',
          ),
          _Section(
            title: 'السلوك',
            body: '• يمنع إساءة استخدام التطبيق\n• يمنع نشر محتوى غير لائق\n• يحق للإدارة حظر المخالفين',
          ),
          _Section(
            title: 'الملكية الفكرية',
            body: 'جميع حقوق التطبيق محفوظة. لا يجوز نسخ أو إعادة استخدام أي جزء من التطبيق دون إذن.',
          ),
          _Section(
            title: 'تحديد المسؤولية',
            body: 'التطبيق يقدم الخدمة "كما هي". نحن غير مسؤولين عن أي أضرار غير مباشرة تنجم عن استخدام الخدمة.',
          ),
          _Section(
            title: 'التواصل',
            body: 'للاستفسارات: 7assanwr@gmail.com أو عبر واتساب: 967730845718+',
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: scheme.primary)),
          const SizedBox(height: 6),
          Text(body, style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant, height: 1.6)),
        ],
      ),
    );
  }
}
