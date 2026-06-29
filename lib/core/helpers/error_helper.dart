import 'package:app_platform_core/core.dart';

import 'error_messages.dart';

String translateError(Object error) {
  if (error is AppError) return error.userMessage;
  return '$error';
}
