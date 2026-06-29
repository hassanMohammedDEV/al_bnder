// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'announcement.dart';

class AnnouncementMapper extends ClassMapperBase<Announcement> {
  AnnouncementMapper._();

  static AnnouncementMapper? _instance;
  static AnnouncementMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = AnnouncementMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'Announcement';

  static String _$id(Announcement v) => v.id;
  static const Field<Announcement, String> _f$id = Field('id', _$id);
  static String _$senderId(Announcement v) => v.senderId;
  static const Field<Announcement, String> _f$senderId = Field(
    'senderId',
    _$senderId,
    key: r'sender_id',
  );
  static String _$senderName(Announcement v) => v.senderName;
  static const Field<Announcement, String> _f$senderName = Field(
    'senderName',
    _$senderName,
    key: r'sender_name',
    opt: true,
    def: '',
  );
  static String _$title(Announcement v) => v.title;
  static const Field<Announcement, String> _f$title = Field('title', _$title);
  static String _$body(Announcement v) => v.body;
  static const Field<Announcement, String> _f$body = Field('body', _$body);
  static String _$createdAt(Announcement v) => v.createdAt;
  static const Field<Announcement, String> _f$createdAt = Field(
    'createdAt',
    _$createdAt,
    key: r'created_at',
  );
  static bool _$isRead(Announcement v) => v.isRead;
  static const Field<Announcement, bool> _f$isRead = Field(
    'isRead',
    _$isRead,
    key: r'is_read',
    opt: true,
    def: false,
  );
  static DateTime? _$readAt(Announcement v) => v.readAt;
  static const Field<Announcement, DateTime> _f$readAt = Field(
    'readAt',
    _$readAt,
    key: r'read_at',
    opt: true,
  );

  @override
  final MappableFields<Announcement> fields = const {
    #id: _f$id,
    #senderId: _f$senderId,
    #senderName: _f$senderName,
    #title: _f$title,
    #body: _f$body,
    #createdAt: _f$createdAt,
    #isRead: _f$isRead,
    #readAt: _f$readAt,
  };

  static Announcement _instantiate(DecodingData data) {
    return Announcement(
      id: data.dec(_f$id),
      senderId: data.dec(_f$senderId),
      senderName: data.dec(_f$senderName),
      title: data.dec(_f$title),
      body: data.dec(_f$body),
      createdAt: data.dec(_f$createdAt),
      isRead: data.dec(_f$isRead),
      readAt: data.dec(_f$readAt),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Announcement fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Announcement>(map);
  }

  static Announcement fromJson(String json) {
    return ensureInitialized().decodeJson<Announcement>(json);
  }
}

mixin AnnouncementMappable {
  String toJson() {
    return AnnouncementMapper.ensureInitialized().encodeJson<Announcement>(
      this as Announcement,
    );
  }

  Map<String, dynamic> toMap() {
    return AnnouncementMapper.ensureInitialized().encodeMap<Announcement>(
      this as Announcement,
    );
  }

  AnnouncementCopyWith<Announcement, Announcement, Announcement> get copyWith =>
      _AnnouncementCopyWithImpl<Announcement, Announcement>(
        this as Announcement,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return AnnouncementMapper.ensureInitialized().stringifyValue(
      this as Announcement,
    );
  }

  @override
  bool operator ==(Object other) {
    return AnnouncementMapper.ensureInitialized().equalsValue(
      this as Announcement,
      other,
    );
  }

  @override
  int get hashCode {
    return AnnouncementMapper.ensureInitialized().hashValue(
      this as Announcement,
    );
  }
}

extension AnnouncementValueCopy<$R, $Out>
    on ObjectCopyWith<$R, Announcement, $Out> {
  AnnouncementCopyWith<$R, Announcement, $Out> get $asAnnouncement =>
      $base.as((v, t, t2) => _AnnouncementCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class AnnouncementCopyWith<$R, $In extends Announcement, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? id,
    String? senderId,
    String? senderName,
    String? title,
    String? body,
    String? createdAt,
    bool? isRead,
    DateTime? readAt,
  });
  AnnouncementCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _AnnouncementCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, Announcement, $Out>
    implements AnnouncementCopyWith<$R, Announcement, $Out> {
  _AnnouncementCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Announcement> $mapper =
      AnnouncementMapper.ensureInitialized();
  @override
  $R call({
    String? id,
    String? senderId,
    String? senderName,
    String? title,
    String? body,
    String? createdAt,
    bool? isRead,
    Object? readAt = $none,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (senderId != null) #senderId: senderId,
      if (senderName != null) #senderName: senderName,
      if (title != null) #title: title,
      if (body != null) #body: body,
      if (createdAt != null) #createdAt: createdAt,
      if (isRead != null) #isRead: isRead,
      if (readAt != $none) #readAt: readAt,
    }),
  );
  @override
  Announcement $make(CopyWithData data) => Announcement(
    id: data.get(#id, or: $value.id),
    senderId: data.get(#senderId, or: $value.senderId),
    senderName: data.get(#senderName, or: $value.senderName),
    title: data.get(#title, or: $value.title),
    body: data.get(#body, or: $value.body),
    createdAt: data.get(#createdAt, or: $value.createdAt),
    isRead: data.get(#isRead, or: $value.isRead),
    readAt: data.get(#readAt, or: $value.readAt),
  );

  @override
  AnnouncementCopyWith<$R2, Announcement, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _AnnouncementCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

