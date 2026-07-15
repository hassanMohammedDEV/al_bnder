import 'package:dart_mappable/dart_mappable.dart';

part 'announcement.mapper.dart';

@MappableClass(caseStyle: CaseStyle.snakeCase)
class Announcement with AnnouncementMappable {
  final String id;
  final String senderId;
  final String senderName;
  final String title;
  final String body;
  final String createdAt;
  final bool isRead;
  final DateTime? readAt;
  final int readCount;

  const Announcement({
    required this.id,
    required this.senderId,
    this.senderName = '',
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.readAt,
    this.readCount = 0,
  });

  static const fromMap = AnnouncementMapper.fromMap;
}
