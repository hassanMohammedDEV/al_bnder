import 'package:app_platform_state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_fields.dart';
import 'auth_provider.dart';

final authValidationProvider = NotifierProvider<AuthValidationNotifier, FormValidationState<AuthFields>>(
  AuthValidationNotifier.new,
);

class AuthValidationNotifier extends ValidationController<AuthFields> {
  @override
  FormValidationState<AuthFields> build() {
    init(validators: {
      AuthFields.name: (ctx) {
        final name = ctx.read(authStateProvider).name.trim();
        if (name.isEmpty) return 'الاسم مطلوب';
        if (name.length < 2) return 'الاسم قصير جداً';
        return null;
      },
      AuthFields.phone: (ctx) {
        final phone = ctx.read(authStateProvider).phone.trim();
        if (phone.isEmpty) return 'رقم الجوال مطلوب';
        if (phone.length != 9) return 'رقم الجوال يجب أن يكون 9 أرقام';
        return null;
      },
      AuthFields.password: (ctx) {
        final password = ctx.read(authStateProvider).password;
        if (password.isEmpty) return 'كلمة المرور مطلوبة';
        if (password.length < 6) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
        return null;
      },
      AuthFields.code: (ctx) => null,
    });
    return state;
  }

  void validateName() => validate(AuthFields.name);
  void validatePhone() => validate(AuthFields.phone);
  void validatePassword() => validate(AuthFields.password);
}
