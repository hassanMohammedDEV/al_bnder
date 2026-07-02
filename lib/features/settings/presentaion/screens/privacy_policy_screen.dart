import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('سياسة الخصوصية')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('سياسة الخصوصية', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: scheme.onSurface)),
          const SizedBox(height: 8),
          Text('آخر تحديث: 2 يوليو 2026', style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          _Section(
            title: 'مقدمة',
            body: 'نحن في تطبيق "البندر" نلتزم بحماية خصوصيتك. توضح هذه السياسة كيفية جمع واستخدام وحماية معلوماتك الشخصية.',
          ),
          _Section(
            title: 'المعلومات التي نجمعها',
            body: '• الاسم الكامل\n• رقم الجوال\n• سجل الحجوزات والمعاملات\n• محتوى الإعلانات التي تنشرها',
          ),
          _Section(
            title: 'كيف نستخدم معلوماتك',
            body: '• إنشاء وإدارة حسابك\n• تمكين الحجوزات والمدفوعات\n• تحسين خدماتنا\n• التواصل معك بخصوص الخدمة',
          ),
          _Section(
            title: 'مشاركة المعلومات',
            body: 'لا نشارك معلوماتك الشخصية مع أطراف ثالثة إلا بالقدر اللازم لتقديم الخدمة (مثل بوابات الدفع) أو بموجب القانون.',
          ),
          _Section(
            title: 'تخزين البيانات وأمنها',
            body: 'نستخدم إجراءات أمنية معيارية لحماية بياناتك. البيانات مخزنة على خوادم آمنة مع تشفير.',
          ),
          _Section(
            title: 'حذف الحساب',
            body: 'يمكنك حذف حسابك وبياناتك في أي وقت من خلال:\n• الإعدادات > حذف الحساب (داخل التطبيق)\n• أو زيارة: https://7assanwr.github.io/al-bndr/data-deletion.html\n• أو مراسلة: 7assanwr@gmail.com',
          ),
          _Section(
            title: 'التواصل',
            body: 'للاستفسارات: 7assanwr@gmail.com أو عبر واتساب: 967730845718+',
          ),
          _Section(
            title: 'التعديلات',
            body: 'قد نقوم بتحديث سياسة الخصوصية هذه من وقت لآخر. سن notifyك بأي تغييرات جوهرية.',
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
