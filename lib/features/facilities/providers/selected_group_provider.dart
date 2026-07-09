import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/token_provider.dart';

class SelectedGroupNotifier extends Notifier<String?> {
  @override
  String? build() {
    return ref.read(sharedPreferencesProvider).getString('selected_group_id');
  }

  Future<void> _save(String? id) {
    return ref.read(sharedPreferencesProvider).setString('selected_group_id', id ?? '');
  }

  void select(String? id) {
    state = id;
    unawaited(_save(id));
  }
}

final selectedGroupProvider = NotifierProvider<SelectedGroupNotifier, String?>(
  SelectedGroupNotifier.new,
);
