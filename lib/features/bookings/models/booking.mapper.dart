// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'booking.dart';

class BookingMapper extends ClassMapperBase<Booking> {
  BookingMapper._();

  static BookingMapper? _instance;
  static BookingMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = BookingMapper._());
      BookingInstanceMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'Booking';

  static String _$id(Booking v) => v.id;
  static const Field<Booking, String> _f$id = Field('id', _$id);
  static String _$userId(Booking v) => v.userId;
  static const Field<Booking, String> _f$userId = Field(
    'userId',
    _$userId,
    key: r'user_id',
  );
  static String _$facilityId(Booking v) => v.facilityId;
  static const Field<Booking, String> _f$facilityId = Field(
    'facilityId',
    _$facilityId,
    key: r'facility_id',
  );
  static String _$facilityName(Booking v) => v.facilityName;
  static const Field<Booking, String> _f$facilityName = Field(
    'facilityName',
    _$facilityName,
    key: r'facility_name',
  );
  static String _$groupId(Booking v) => v.groupId;
  static const Field<Booking, String> _f$groupId = Field(
    'groupId',
    _$groupId,
    key: r'group_id',
  );
  static String _$groupName(Booking v) => v.groupName;
  static const Field<Booking, String> _f$groupName = Field(
    'groupName',
    _$groupName,
    key: r'group_name',
  );
  static double _$totalPrice(Booking v) => v.totalPrice;
  static const Field<Booking, double> _f$totalPrice = Field(
    'totalPrice',
    _$totalPrice,
    key: r'total_price',
  );
  static double _$paidAmount(Booking v) => v.paidAmount;
  static const Field<Booking, double> _f$paidAmount = Field(
    'paidAmount',
    _$paidAmount,
    key: r'paid_amount',
    opt: true,
    def: 0,
  );
  static String _$status(Booking v) => v.status;
  static const Field<Booking, String> _f$status = Field('status', _$status);
  static String _$paymentStatus(Booking v) => v.paymentStatus;
  static const Field<Booking, String> _f$paymentStatus = Field(
    'paymentStatus',
    _$paymentStatus,
    key: r'payment_status',
    opt: true,
    def: 'unpaid',
  );
  static bool _$isRecurring(Booking v) => v.isRecurring;
  static const Field<Booking, bool> _f$isRecurring = Field(
    'isRecurring',
    _$isRecurring,
    key: r'is_recurring',
    opt: true,
    def: false,
  );
  static Map<String, dynamic>? _$recurringRule(Booking v) => v.recurringRule;
  static const Field<Booking, Map<String, dynamic>> _f$recurringRule = Field(
    'recurringRule',
    _$recurringRule,
    key: r'recurring_rule',
    opt: true,
  );
  static String _$createdAt(Booking v) => v.createdAt;
  static const Field<Booking, String> _f$createdAt = Field(
    'createdAt',
    _$createdAt,
    key: r'created_at',
  );
  static bool _$isAdminBooking(Booking v) => v.isAdminBooking;
  static const Field<Booking, bool> _f$isAdminBooking = Field(
    'isAdminBooking',
    _$isAdminBooking,
    key: r'is_admin_booking',
    opt: true,
    def: false,
  );
  static List<BookingInstance>? _$instances(Booking v) => v.instances;
  static const Field<Booking, List<BookingInstance>> _f$instances = Field(
    'instances',
    _$instances,
    opt: true,
  );

  @override
  final MappableFields<Booking> fields = const {
    #id: _f$id,
    #userId: _f$userId,
    #facilityId: _f$facilityId,
    #facilityName: _f$facilityName,
    #groupId: _f$groupId,
    #groupName: _f$groupName,
    #totalPrice: _f$totalPrice,
    #paidAmount: _f$paidAmount,
    #status: _f$status,
    #paymentStatus: _f$paymentStatus,
    #isRecurring: _f$isRecurring,
    #recurringRule: _f$recurringRule,
    #createdAt: _f$createdAt,
    #isAdminBooking: _f$isAdminBooking,
    #instances: _f$instances,
  };

  static Booking _instantiate(DecodingData data) {
    return Booking(
      id: data.dec(_f$id),
      userId: data.dec(_f$userId),
      facilityId: data.dec(_f$facilityId),
      facilityName: data.dec(_f$facilityName),
      groupId: data.dec(_f$groupId),
      groupName: data.dec(_f$groupName),
      totalPrice: data.dec(_f$totalPrice),
      paidAmount: data.dec(_f$paidAmount),
      status: data.dec(_f$status),
      paymentStatus: data.dec(_f$paymentStatus),
      isRecurring: data.dec(_f$isRecurring),
      recurringRule: data.dec(_f$recurringRule),
      createdAt: data.dec(_f$createdAt),
      isAdminBooking: data.dec(_f$isAdminBooking),
      instances: data.dec(_f$instances),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Booking fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Booking>(map);
  }

  static Booking fromJson(String json) {
    return ensureInitialized().decodeJson<Booking>(json);
  }
}

mixin BookingMappable {
  String toJson() {
    return BookingMapper.ensureInitialized().encodeJson<Booking>(
      this as Booking,
    );
  }

  Map<String, dynamic> toMap() {
    return BookingMapper.ensureInitialized().encodeMap<Booking>(
      this as Booking,
    );
  }

  BookingCopyWith<Booking, Booking, Booking> get copyWith =>
      _BookingCopyWithImpl<Booking, Booking>(
        this as Booking,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return BookingMapper.ensureInitialized().stringifyValue(this as Booking);
  }

  @override
  bool operator ==(Object other) {
    return BookingMapper.ensureInitialized().equalsValue(
      this as Booking,
      other,
    );
  }

  @override
  int get hashCode {
    return BookingMapper.ensureInitialized().hashValue(this as Booking);
  }
}

extension BookingValueCopy<$R, $Out> on ObjectCopyWith<$R, Booking, $Out> {
  BookingCopyWith<$R, Booking, $Out> get $asBooking =>
      $base.as((v, t, t2) => _BookingCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class BookingCopyWith<$R, $In extends Booking, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  MapCopyWith<$R, String, dynamic, ObjectCopyWith<$R, dynamic, dynamic>?>?
  get recurringRule;
  ListCopyWith<
    $R,
    BookingInstance,
    BookingInstanceCopyWith<$R, BookingInstance, BookingInstance>
  >?
  get instances;
  $R call({
    String? id,
    String? userId,
    String? facilityId,
    String? facilityName,
    String? groupId,
    String? groupName,
    double? totalPrice,
    double? paidAmount,
    String? status,
    String? paymentStatus,
    bool? isRecurring,
    Map<String, dynamic>? recurringRule,
    String? createdAt,
    bool? isAdminBooking,
    List<BookingInstance>? instances,
  });
  BookingCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _BookingCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, Booking, $Out>
    implements BookingCopyWith<$R, Booking, $Out> {
  _BookingCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Booking> $mapper =
      BookingMapper.ensureInitialized();
  @override
  MapCopyWith<$R, String, dynamic, ObjectCopyWith<$R, dynamic, dynamic>?>?
  get recurringRule => $value.recurringRule != null
      ? MapCopyWith(
          $value.recurringRule!,
          (v, t) => ObjectCopyWith(v, $identity, t),
          (v) => call(recurringRule: v),
        )
      : null;
  @override
  ListCopyWith<
    $R,
    BookingInstance,
    BookingInstanceCopyWith<$R, BookingInstance, BookingInstance>
  >?
  get instances => $value.instances != null
      ? ListCopyWith(
          $value.instances!,
          (v, t) => v.copyWith.$chain(t),
          (v) => call(instances: v),
        )
      : null;
  @override
  $R call({
    String? id,
    String? userId,
    String? facilityId,
    String? facilityName,
    String? groupId,
    String? groupName,
    double? totalPrice,
    double? paidAmount,
    String? status,
    String? paymentStatus,
    bool? isRecurring,
    Object? recurringRule = $none,
    String? createdAt,
    bool? isAdminBooking,
    Object? instances = $none,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (userId != null) #userId: userId,
      if (facilityId != null) #facilityId: facilityId,
      if (facilityName != null) #facilityName: facilityName,
      if (groupId != null) #groupId: groupId,
      if (groupName != null) #groupName: groupName,
      if (totalPrice != null) #totalPrice: totalPrice,
      if (paidAmount != null) #paidAmount: paidAmount,
      if (status != null) #status: status,
      if (paymentStatus != null) #paymentStatus: paymentStatus,
      if (isRecurring != null) #isRecurring: isRecurring,
      if (recurringRule != $none) #recurringRule: recurringRule,
      if (createdAt != null) #createdAt: createdAt,
      if (isAdminBooking != null) #isAdminBooking: isAdminBooking,
      if (instances != $none) #instances: instances,
    }),
  );
  @override
  Booking $make(CopyWithData data) => Booking(
    id: data.get(#id, or: $value.id),
    userId: data.get(#userId, or: $value.userId),
    facilityId: data.get(#facilityId, or: $value.facilityId),
    facilityName: data.get(#facilityName, or: $value.facilityName),
    groupId: data.get(#groupId, or: $value.groupId),
    groupName: data.get(#groupName, or: $value.groupName),
    totalPrice: data.get(#totalPrice, or: $value.totalPrice),
    paidAmount: data.get(#paidAmount, or: $value.paidAmount),
    status: data.get(#status, or: $value.status),
    paymentStatus: data.get(#paymentStatus, or: $value.paymentStatus),
    isRecurring: data.get(#isRecurring, or: $value.isRecurring),
    recurringRule: data.get(#recurringRule, or: $value.recurringRule),
    createdAt: data.get(#createdAt, or: $value.createdAt),
    isAdminBooking: data.get(#isAdminBooking, or: $value.isAdminBooking),
    instances: data.get(#instances, or: $value.instances),
  );

  @override
  BookingCopyWith<$R2, Booking, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _BookingCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class BookingInstanceMapper extends ClassMapperBase<BookingInstance> {
  BookingInstanceMapper._();

  static BookingInstanceMapper? _instance;
  static BookingInstanceMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = BookingInstanceMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'BookingInstance';

  static String _$id(BookingInstance v) => v.id;
  static const Field<BookingInstance, String> _f$id = Field('id', _$id);
  static String _$startAt(BookingInstance v) => v.startAt;
  static const Field<BookingInstance, String> _f$startAt = Field(
    'startAt',
    _$startAt,
    key: r'start_at',
  );
  static String _$endAt(BookingInstance v) => v.endAt;
  static const Field<BookingInstance, String> _f$endAt = Field(
    'endAt',
    _$endAt,
    key: r'end_at',
  );
  static String _$status(BookingInstance v) => v.status;
  static const Field<BookingInstance, String> _f$status = Field(
    'status',
    _$status,
  );
  static String? _$qrToken(BookingInstance v) => v.qrToken;
  static const Field<BookingInstance, String> _f$qrToken = Field(
    'qrToken',
    _$qrToken,
    key: r'qr_token',
    opt: true,
  );

  @override
  final MappableFields<BookingInstance> fields = const {
    #id: _f$id,
    #startAt: _f$startAt,
    #endAt: _f$endAt,
    #status: _f$status,
    #qrToken: _f$qrToken,
  };

  static BookingInstance _instantiate(DecodingData data) {
    return BookingInstance(
      id: data.dec(_f$id),
      startAt: data.dec(_f$startAt),
      endAt: data.dec(_f$endAt),
      status: data.dec(_f$status),
      qrToken: data.dec(_f$qrToken),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static BookingInstance fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<BookingInstance>(map);
  }

  static BookingInstance fromJson(String json) {
    return ensureInitialized().decodeJson<BookingInstance>(json);
  }
}

mixin BookingInstanceMappable {
  String toJson() {
    return BookingInstanceMapper.ensureInitialized()
        .encodeJson<BookingInstance>(this as BookingInstance);
  }

  Map<String, dynamic> toMap() {
    return BookingInstanceMapper.ensureInitialized().encodeMap<BookingInstance>(
      this as BookingInstance,
    );
  }

  BookingInstanceCopyWith<BookingInstance, BookingInstance, BookingInstance>
  get copyWith =>
      _BookingInstanceCopyWithImpl<BookingInstance, BookingInstance>(
        this as BookingInstance,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return BookingInstanceMapper.ensureInitialized().stringifyValue(
      this as BookingInstance,
    );
  }

  @override
  bool operator ==(Object other) {
    return BookingInstanceMapper.ensureInitialized().equalsValue(
      this as BookingInstance,
      other,
    );
  }

  @override
  int get hashCode {
    return BookingInstanceMapper.ensureInitialized().hashValue(
      this as BookingInstance,
    );
  }
}

extension BookingInstanceValueCopy<$R, $Out>
    on ObjectCopyWith<$R, BookingInstance, $Out> {
  BookingInstanceCopyWith<$R, BookingInstance, $Out> get $asBookingInstance =>
      $base.as((v, t, t2) => _BookingInstanceCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class BookingInstanceCopyWith<$R, $In extends BookingInstance, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? id,
    String? startAt,
    String? endAt,
    String? status,
    String? qrToken,
  });
  BookingInstanceCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _BookingInstanceCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, BookingInstance, $Out>
    implements BookingInstanceCopyWith<$R, BookingInstance, $Out> {
  _BookingInstanceCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<BookingInstance> $mapper =
      BookingInstanceMapper.ensureInitialized();
  @override
  $R call({
    String? id,
    String? startAt,
    String? endAt,
    String? status,
    Object? qrToken = $none,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (startAt != null) #startAt: startAt,
      if (endAt != null) #endAt: endAt,
      if (status != null) #status: status,
      if (qrToken != $none) #qrToken: qrToken,
    }),
  );
  @override
  BookingInstance $make(CopyWithData data) => BookingInstance(
    id: data.get(#id, or: $value.id),
    startAt: data.get(#startAt, or: $value.startAt),
    endAt: data.get(#endAt, or: $value.endAt),
    status: data.get(#status, or: $value.status),
    qrToken: data.get(#qrToken, or: $value.qrToken),
  );

  @override
  BookingInstanceCopyWith<$R2, BookingInstance, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _BookingInstanceCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

