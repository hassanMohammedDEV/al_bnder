class AuthState {
  final String name;
  final String phone;
  final String password;
  final bool isLoggedIn;
  final bool isProfileLoaded;
  final bool phoneVerified;
  final bool needsPhoneVerification;
  final String? userId;
  final String? role;
  final String? facilityGroupId;

  const AuthState({
    this.name = '',
    this.phone = '',
    this.password = '',
    this.isLoggedIn = false,
    this.isProfileLoaded = false,
    this.phoneVerified = false,
    this.needsPhoneVerification = false,
    this.userId,
    this.role,
    this.facilityGroupId,
  });

  AuthState copyWith({
    String? name,
    String? phone,
    String? password,
    bool? isLoggedIn,
    bool? isProfileLoaded,
    bool? phoneVerified,
    bool? needsPhoneVerification,
    String? userId,
    String? role,
    String? facilityGroupId,
  }) {
    return AuthState(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      password: password ?? this.password,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isProfileLoaded: isProfileLoaded ?? this.isProfileLoaded,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      needsPhoneVerification: needsPhoneVerification ?? this.needsPhoneVerification,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      facilityGroupId: facilityGroupId ?? this.facilityGroupId,
    );
  }

  String get email => '${phone}@al-bndr.app';
}
