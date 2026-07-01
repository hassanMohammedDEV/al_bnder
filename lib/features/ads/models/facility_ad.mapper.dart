// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'facility_ad.dart';

class FacilityAdMapper extends ClassMapperBase<FacilityAd> {
  FacilityAdMapper._();

  static FacilityAdMapper? _instance;
  static FacilityAdMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = FacilityAdMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'FacilityAd';

  static String _$id(FacilityAd v) => v.id;
  static const Field<FacilityAd, String> _f$id = Field('id', _$id);
  static String _$facilityGroupId(FacilityAd v) => v.facilityGroupId;
  static const Field<FacilityAd, String> _f$facilityGroupId = Field(
    'facilityGroupId',
    _$facilityGroupId,
    key: r'facility_group_id',
  );
  static String _$title(FacilityAd v) => v.title;
  static const Field<FacilityAd, String> _f$title = Field('title', _$title);
  static String? _$description(FacilityAd v) => v.description;
  static const Field<FacilityAd, String> _f$description = Field(
    'description',
    _$description,
    opt: true,
  );
  static String? _$imageUrl(FacilityAd v) => v.imageUrl;
  static const Field<FacilityAd, String> _f$imageUrl = Field(
    'imageUrl',
    _$imageUrl,
    key: r'image_url',
    opt: true,
  );
  static String? _$linkUrl(FacilityAd v) => v.linkUrl;
  static const Field<FacilityAd, String> _f$linkUrl = Field(
    'linkUrl',
    _$linkUrl,
    key: r'link_url',
    opt: true,
  );
  static bool _$isActive(FacilityAd v) => v.isActive;
  static const Field<FacilityAd, bool> _f$isActive = Field(
    'isActive',
    _$isActive,
    key: r'is_active',
    opt: true,
    def: true,
  );
  static String? _$startsAt(FacilityAd v) => v.startsAt;
  static const Field<FacilityAd, String> _f$startsAt = Field(
    'startsAt',
    _$startsAt,
    key: r'starts_at',
    opt: true,
  );
  static String? _$endsAt(FacilityAd v) => v.endsAt;
  static const Field<FacilityAd, String> _f$endsAt = Field(
    'endsAt',
    _$endsAt,
    key: r'ends_at',
    opt: true,
  );
  static String _$createdAt(FacilityAd v) => v.createdAt;
  static const Field<FacilityAd, String> _f$createdAt = Field(
    'createdAt',
    _$createdAt,
    key: r'created_at',
  );
  static String _$updatedAt(FacilityAd v) => v.updatedAt;
  static const Field<FacilityAd, String> _f$updatedAt = Field(
    'updatedAt',
    _$updatedAt,
    key: r'updated_at',
  );
  static int _$sortOrder(FacilityAd v) => v.sortOrder;
  static const Field<FacilityAd, int> _f$sortOrder = Field(
    'sortOrder',
    _$sortOrder,
    key: r'sort_order',
    opt: true,
    def: 0,
  );

  @override
  final MappableFields<FacilityAd> fields = const {
    #id: _f$id,
    #facilityGroupId: _f$facilityGroupId,
    #title: _f$title,
    #description: _f$description,
    #imageUrl: _f$imageUrl,
    #linkUrl: _f$linkUrl,
    #isActive: _f$isActive,
    #startsAt: _f$startsAt,
    #endsAt: _f$endsAt,
    #createdAt: _f$createdAt,
    #updatedAt: _f$updatedAt,
    #sortOrder: _f$sortOrder,
  };

  static FacilityAd _instantiate(DecodingData data) {
    return FacilityAd(
      id: data.dec(_f$id),
      facilityGroupId: data.dec(_f$facilityGroupId),
      title: data.dec(_f$title),
      description: data.dec(_f$description),
      imageUrl: data.dec(_f$imageUrl),
      linkUrl: data.dec(_f$linkUrl),
      isActive: data.dec(_f$isActive),
      startsAt: data.dec(_f$startsAt),
      endsAt: data.dec(_f$endsAt),
      createdAt: data.dec(_f$createdAt),
      updatedAt: data.dec(_f$updatedAt),
      sortOrder: data.dec(_f$sortOrder),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static FacilityAd fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<FacilityAd>(map);
  }

  static FacilityAd fromJson(String json) {
    return ensureInitialized().decodeJson<FacilityAd>(json);
  }
}

mixin FacilityAdMappable {
  String toJson() {
    return FacilityAdMapper.ensureInitialized().encodeJson<FacilityAd>(
      this as FacilityAd,
    );
  }

  Map<String, dynamic> toMap() {
    return FacilityAdMapper.ensureInitialized().encodeMap<FacilityAd>(
      this as FacilityAd,
    );
  }

  FacilityAdCopyWith<FacilityAd, FacilityAd, FacilityAd> get copyWith =>
      _FacilityAdCopyWithImpl<FacilityAd, FacilityAd>(
        this as FacilityAd,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return FacilityAdMapper.ensureInitialized().stringifyValue(
      this as FacilityAd,
    );
  }

  @override
  bool operator ==(Object other) {
    return FacilityAdMapper.ensureInitialized().equalsValue(
      this as FacilityAd,
      other,
    );
  }

  @override
  int get hashCode {
    return FacilityAdMapper.ensureInitialized().hashValue(this as FacilityAd);
  }
}

extension FacilityAdValueCopy<$R, $Out>
    on ObjectCopyWith<$R, FacilityAd, $Out> {
  FacilityAdCopyWith<$R, FacilityAd, $Out> get $asFacilityAd =>
      $base.as((v, t, t2) => _FacilityAdCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class FacilityAdCopyWith<$R, $In extends FacilityAd, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? id,
    String? facilityGroupId,
    String? title,
    String? description,
    String? imageUrl,
    String? linkUrl,
    bool? isActive,
    String? startsAt,
    String? endsAt,
    String? createdAt,
    String? updatedAt,
  });
  FacilityAdCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _FacilityAdCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, FacilityAd, $Out>
    implements FacilityAdCopyWith<$R, FacilityAd, $Out> {
  _FacilityAdCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<FacilityAd> $mapper =
      FacilityAdMapper.ensureInitialized();
  @override
  $R call({
    String? id,
    String? facilityGroupId,
    String? title,
    Object? description = $none,
    Object? imageUrl = $none,
    Object? linkUrl = $none,
    bool? isActive,
    Object? startsAt = $none,
    Object? endsAt = $none,
    String? createdAt,
    String? updatedAt,
    int? sortOrder,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (facilityGroupId != null) #facilityGroupId: facilityGroupId,
      if (title != null) #title: title,
      if (description != $none) #description: description,
      if (imageUrl != $none) #imageUrl: imageUrl,
      if (linkUrl != $none) #linkUrl: linkUrl,
      if (isActive != null) #isActive: isActive,
      if (startsAt != $none) #startsAt: startsAt,
      if (endsAt != $none) #endsAt: endsAt,
      if (createdAt != null) #createdAt: createdAt,
      if (updatedAt != null) #updatedAt: updatedAt,
      if (sortOrder != null) #sortOrder: sortOrder,
    }),
  );
  @override
  FacilityAd $make(CopyWithData data) => FacilityAd(
    id: data.get(#id, or: $value.id),
    facilityGroupId: data.get(#facilityGroupId, or: $value.facilityGroupId),
    title: data.get(#title, or: $value.title),
    description: data.get(#description, or: $value.description),
    imageUrl: data.get(#imageUrl, or: $value.imageUrl),
    linkUrl: data.get(#linkUrl, or: $value.linkUrl),
    isActive: data.get(#isActive, or: $value.isActive),
    startsAt: data.get(#startsAt, or: $value.startsAt),
    endsAt: data.get(#endsAt, or: $value.endsAt),
    createdAt: data.get(#createdAt, or: $value.createdAt),
    updatedAt: data.get(#updatedAt, or: $value.updatedAt),
    sortOrder: data.get(#sortOrder, or: $value.sortOrder),
  );

  @override
  FacilityAdCopyWith<$R2, FacilityAd, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _FacilityAdCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

