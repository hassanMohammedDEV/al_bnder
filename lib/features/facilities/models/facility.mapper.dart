// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'facility.dart';

class FacilityMapper extends ClassMapperBase<Facility> {
  FacilityMapper._();

  static FacilityMapper? _instance;
  static FacilityMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = FacilityMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'Facility';

  static String _$id(Facility v) => v.id;
  static const Field<Facility, String> _f$id = Field('id', _$id);
  static String _$groupId(Facility v) => v.groupId;
  static const Field<Facility, String> _f$groupId = Field(
    'groupId',
    _$groupId,
    key: r'group_id',
  );
  static String _$name(Facility v) => v.name;
  static const Field<Facility, String> _f$name = Field('name', _$name);
  static String? _$description(Facility v) => v.description;
  static const Field<Facility, String> _f$description = Field(
    'description',
    _$description,
    opt: true,
  );
  static String? _$location(Facility v) => v.location;
  static const Field<Facility, String> _f$location = Field(
    'location',
    _$location,
    opt: true,
  );
  static List<String>? _$images(Facility v) => v.images;
  static const Field<Facility, List<String>> _f$images = Field(
    'images',
    _$images,
    opt: true,
  );
  static double _$pricePerHour(Facility v) => v.pricePerHour;
  static const Field<Facility, double> _f$pricePerHour = Field(
    'pricePerHour',
    _$pricePerHour,
    key: r'price_per_hour',
    opt: true,
    def: 0,
  );
  static bool _$isActive(Facility v) => v.isActive;
  static const Field<Facility, bool> _f$isActive = Field(
    'isActive',
    _$isActive,
    key: r'is_active',
    opt: true,
    def: true,
  );

  @override
  final MappableFields<Facility> fields = const {
    #id: _f$id,
    #groupId: _f$groupId,
    #name: _f$name,
    #description: _f$description,
    #location: _f$location,
    #images: _f$images,
    #pricePerHour: _f$pricePerHour,
    #isActive: _f$isActive,
  };

  static Facility _instantiate(DecodingData data) {
    return Facility(
      id: data.dec(_f$id),
      groupId: data.dec(_f$groupId),
      name: data.dec(_f$name),
      description: data.dec(_f$description),
      location: data.dec(_f$location),
      images: data.dec(_f$images),
      pricePerHour: data.dec(_f$pricePerHour),
      isActive: data.dec(_f$isActive),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Facility fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Facility>(map);
  }

  static Facility fromJson(String json) {
    return ensureInitialized().decodeJson<Facility>(json);
  }
}

mixin FacilityMappable {
  String toJson() {
    return FacilityMapper.ensureInitialized().encodeJson<Facility>(
      this as Facility,
    );
  }

  Map<String, dynamic> toMap() {
    return FacilityMapper.ensureInitialized().encodeMap<Facility>(
      this as Facility,
    );
  }

  FacilityCopyWith<Facility, Facility, Facility> get copyWith =>
      _FacilityCopyWithImpl<Facility, Facility>(
        this as Facility,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return FacilityMapper.ensureInitialized().stringifyValue(this as Facility);
  }

  @override
  bool operator ==(Object other) {
    return FacilityMapper.ensureInitialized().equalsValue(
      this as Facility,
      other,
    );
  }

  @override
  int get hashCode {
    return FacilityMapper.ensureInitialized().hashValue(this as Facility);
  }
}

extension FacilityValueCopy<$R, $Out> on ObjectCopyWith<$R, Facility, $Out> {
  FacilityCopyWith<$R, Facility, $Out> get $asFacility =>
      $base.as((v, t, t2) => _FacilityCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class FacilityCopyWith<$R, $In extends Facility, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>? get images;
  $R call({
    String? id,
    String? groupId,
    String? name,
    String? description,
    String? location,
    List<String>? images,
    double? pricePerHour,
    bool? isActive,
  });
  FacilityCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _FacilityCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, Facility, $Out>
    implements FacilityCopyWith<$R, Facility, $Out> {
  _FacilityCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Facility> $mapper =
      FacilityMapper.ensureInitialized();
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>? get images =>
      $value.images != null
      ? ListCopyWith(
          $value.images!,
          (v, t) => ObjectCopyWith(v, $identity, t),
          (v) => call(images: v),
        )
      : null;
  @override
  $R call({
    String? id,
    String? groupId,
    String? name,
    Object? description = $none,
    Object? location = $none,
    Object? images = $none,
    double? pricePerHour,
    bool? isActive,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (groupId != null) #groupId: groupId,
      if (name != null) #name: name,
      if (description != $none) #description: description,
      if (location != $none) #location: location,
      if (images != $none) #images: images,
      if (pricePerHour != null) #pricePerHour: pricePerHour,
      if (isActive != null) #isActive: isActive,
    }),
  );
  @override
  Facility $make(CopyWithData data) => Facility(
    id: data.get(#id, or: $value.id),
    groupId: data.get(#groupId, or: $value.groupId),
    name: data.get(#name, or: $value.name),
    description: data.get(#description, or: $value.description),
    location: data.get(#location, or: $value.location),
    images: data.get(#images, or: $value.images),
    pricePerHour: data.get(#pricePerHour, or: $value.pricePerHour),
    isActive: data.get(#isActive, or: $value.isActive),
  );

  @override
  FacilityCopyWith<$R2, Facility, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _FacilityCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

