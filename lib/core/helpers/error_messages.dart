import 'dart:convert';

import 'package:app_platform_core/core.dart';

extension UserFriendlyError on AppError {
  String get userMessage {
    final message = this.message;

    if (this is NoInternetError) return 'لا يوجد اتصال بالإنترنت';
    if (this is TimeoutError) return 'انتهت مهلة الطلب، حاول مرة أخرى';
    if (this is UnauthorizedError) return 'غير مصرح، يرجى تسجيل الدخول مرة أخرى';
    if (this is ForbiddenError) return 'ليس لديك صلاحية للوصول إلى هذا';
    if (this is NotFoundError) return 'المطلوب غير موجود';

    if (this is ValidationError) {
      final fields = (this as ValidationError).fields;
      if (fields != null && fields.isNotEmpty) {
        return fields.values.join('\n');
      }
      return _friendly(message);
    }

    if (this is ServerError) return _friendly(message);
    if (this is NetworkError) return _friendly(message);

    return _friendly(message);
  }
}

String _friendly(String raw) {
  if (raw.isEmpty) return 'حدث خطأ غير متوقع';

  // Try to parse JSON Supabase error
  try {
    final parsed = jsonDecode(raw);
    if (parsed is Map) {
      final msg = parsed['msg'] as String? ?? parsed['message'] as String? ?? parsed['error'] as String?;
      if (msg != null) return _mapMessage(msg);
    }
  } catch (_) {}

  return _mapMessage(raw);
}

String _mapMessage(String msg) {
  final m = msg.toLowerCase();

  if (m.contains('invalid login credentials') || m.contains('invalid_credentials')) {
    return 'رقم الجوال أو كلمة المرور غير صحيحة';
  }
  if (m.contains('email_not_confirmed') || m.contains('email not confirmed')) {
    return 'الحساب غير مفعل';
  }
  if (m.contains('user_already_exists') || m.contains('user already exists') || m.contains('already registered')) {
    return 'المستخدم موجود مسبقاً';
  }
  if (m.contains('user_not_found') || m.contains('user not found')) {
    return 'المستخدم غير موجود';
  }
  if (m.contains('new row violates row-level security')) {
    return 'ليس لديك صلاحية للقيام بهذه العملية';
  }
  if (m.contains('violates row-level security')) {
    return 'ليس لديك صلاحية للقيام بهذه العملية';
  }
  if (m.contains('duplicate key') || m.contains('already exists')) {
    return 'البيانات موجودة مسبقاً';
  }
  if (m.contains('not found') || m.contains('doesn\'t exist') || m.contains('does not exist')) {
    return 'العنصر المطلوب غير موجود';
  }
  if (m.contains('jwt') || m.contains('token')) {
    return 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مرة أخرى';
  }
  if (m.contains('rate limit') || m.contains('too many requests') || m.contains('429')) {
    return 'طلبات كثيرة، حاول بعد قليل';
  }
  if (m.contains('timeout') || m.contains('timed out')) {
    return 'انتهت مهلة الاتصال، حاول مرة أخرى';
  }
  if (m.contains('connection') || m.contains('network')) {
    return 'مشكلة في الاتصال بالخادم';
  }
  if (m.contains('permission denied') || m.contains('permission_denied')) {
    return 'ليس لديك صلاحية للقيام بهذه العملية';
  }
  if (m.contains('foreign key') || m.contains('violates foreign key')) {
    return 'العنصر مرتبط ببيانات أخرى';
  }
  if (m.contains('payment') || m.contains('wallet')) {
    return 'خطأ في عملية الدفع';
  }
  if (m.contains('phone') && m.contains('invalid')) {
    return 'رقم الجوال غير صحيح';
  }
  if (m.contains('password') && (m.contains('short') || m.contains('weak') || m.contains('length'))) {
    return 'كلمة المرور قصيرة جداً (6 أحرف على الأقل)';
  }

  return msg;
}
