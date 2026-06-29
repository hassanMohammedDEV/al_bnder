import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedGroupNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedGroupProvider = NotifierProvider<SelectedGroupNotifier, String?>(
  SelectedGroupNotifier.new,
);
