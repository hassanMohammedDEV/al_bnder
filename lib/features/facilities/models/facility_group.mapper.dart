// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'facility_group.dart';

class FacilityGroupMapper extends ClassMapperBase<FacilityGroup> {
  FacilityGroupMapper._();

  static FacilityGroupMapper? _instance;
  static FacilityGroupMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = FacilityGroupMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'FacilityGroup';

  static String _$id(FacilityGroup v) => v.id;
  static const Field<FacilityGroup, String> _f$id = Field('id', _$id);
  static String _$name(FacilityGroup v) => v.name;
  static const Field<FacilityGroup, String> _f$name = Field('name', _$name);
  static String? _$description(FacilityGroup v) => v.description;
  static const Field<FacilityGroup, String> _f$description = Field(
    'description',
    _$description,
    opt: true,
  );
  static String? _$logoUrl(FacilityGroup v) => v.logoUrl;
  static const Field<FacilityGroup, String> _f$logoUrl = Field(
    'logoUrl',
    _$logoUrl,
    key: r'logo_url',
    opt: true,
  );
  static String? _$phone(FacilityGroup v) => v.phone;
  static const Field<FacilityGroup, String> _f$phone = Field(
    'phone',
    _$phone,
    opt: true,
  );
  static bool _$isActive(FacilityGroup v) => v.isActive;
  static const Field<FacilityGroup, bool> _f$isActive = Field(
    'isActive',
    _$isActive,
    key: r'is_active',
    opt: true,
    def: true,
  );

  @override
  final MappableFields<FacilityGroup> fields = const {
    #id: _f$id,
    #name: _f$name,
    #description: _f$description,
    #logoUrl: _f$logoUrl,
    #phone: _f$phone,
    #isActive: _f$isActive,
  };

  static FacilityGroup _instantiate(DecodingData data) {
    return FacilityGroup(
      id: data.dec(_f$id),
      name: data.dec(_f$name),
      description: data.dec(_f$description),
      logoUrl: data.dec(_f$logoUrl),
      phone: data.dec(_f$phone),
      isActive: data.dec(_f$isActive),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static FacilityGroup fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<FacilityGroup>(map);
  }

  static FacilityGroup fromJson(String json) {
    return ensureInitialized().decodeJson<FacilityGroup>(json);
  }
}

mixin FacilityGroupMappable {
  String toJson() {
    return FacilityGroupMapper.ensureInitialized().encodeJson<FacilityGroup>(
      this as FacilityGroup,
    );
  }

  Map<String, dynamic> toMap() {
    return FacilityGroupMapper.ensureInitialized().encodeMap<FacilityGroup>(
      this as FacilityGroup,
    );
  }

  FacilityGroupCopyWith<FacilityGroup, FacilityGroup, FacilityGroup>
  get copyWith => _FacilityGroupCopyWithImpl<FacilityGroup, FacilityGroup>(
    this as FacilityGroup,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return FacilityGroupMapper.ensureInitialized().stringifyValue(
      this as FacilityGroup,
    );
  }

  @override
  bool operator ==(Object other) {
    return FacilityGroupMapper.ensureInitialized().equalsValue(
      this as FacilityGroup,
      other,
    );
  }

  @override
  int get hashCode {
    return FacilityGroupMapper.ensureInitialized().hashValue(
      this as FacilityGroup,
    );
  }
}

extension FacilityGroupValueCopy<$R, $Out>
    on ObjectCopyWith<$R, FacilityGroup, $Out> {
  FacilityGroupCopyWith<$R, FacilityGroup, $Out> get $asFacilityGroup =>
      $base.as((v, t, t2) => _FacilityGroupCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class FacilityGroupCopyWith<$R, $In extends FacilityGroup, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? id,
    String? name,
    String? description,
    String? logoUrl,
    String? phone,
    bool? isActive,
  });
  FacilityGroupCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _FacilityGroupCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, FacilityGroup, $Out>
    implements FacilityGroupCopyWith<$R, FacilityGroup, $Out> {
  _FacilityGroupCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<FacilityGroup> $mapper =
      FacilityGroupMapper.ensureInitialized();
  @override
  $R call({
    String? id,
    String? name,
    Object? description = $none,
    Object? logoUrl = $none,
    Object? phone = $none,
    bool? isActive,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (name != null) #name: name,
      if (description != $none) #description: description,
      if (logoUrl != $none) #logoUrl: logoUrl,
      if (phone != $none) #phone: phone,
      if (isActive != null) #isActive: isActive,
    }),
  );
  @override
  FacilityGroup $make(CopyWithData data) => FacilityGroup(
    id: data.get(#id, or: $value.id),
    name: data.get(#name, or: $value.name),
    description: data.get(#description, or: $value.description),
    logoUrl: data.get(#logoUrl, or: $value.logoUrl),
    phone: data.get(#phone, or: $value.phone),
    isActive: data.get(#isActive, or: $value.isActive),
  );

  @override
  FacilityGroupCopyWith<$R2, FacilityGroup, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _FacilityGroupCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

