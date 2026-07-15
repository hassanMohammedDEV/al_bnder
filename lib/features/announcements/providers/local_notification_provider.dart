import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/token_provider.dart';

class LocalNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;

  const LocalNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'body': body,
    'created_at': createdAt.toIso8601String(),
  };

  factory LocalNotification.fromJson(Map<String, dynamic> json) => LocalNotification(
    id: json['id'] as String,
    type: json['type'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

final localNotificationsProvider = NotifierProvider<LocalNotificationsNotifier, List<LocalNotification>>(
  LocalNotificationsNotifier.new,
);

class LocalNotificationsNotifier extends Notifier<List<LocalNotification>> {
  @override
  List<LocalNotification> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getString('local_notifications');
    if (raw == null) return;
    final list = (jsonDecode(raw) as List).map((e) => LocalNotification.fromJson(e as Map<String, dynamic>)).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = list;
  }

  Future<void> _save() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString('local_notifications', raw);
  }

  Future<void> add(LocalNotification notification) async {
    state = [notification, ...state];
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((e) => e.id != id).toList();
    await _save();
  }

  Future<void> clear() async {
    state = [];
    await _save();
  }
}
