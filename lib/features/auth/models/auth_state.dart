class AuthState {
  final String phone;
  final String password;
  final bool isLoggedIn;
  final String? userId;
  final String? role;
  final String? facilityGroupId;

  const AuthState({
    this.phone = '',
    this.password = '',
    this.isLoggedIn = false,
    this.userId,
    this.role,
    this.facilityGroupId,
  });

  AuthState copyWith({
    String? phone,
    String? password,
    bool? isLoggedIn,
    String? userId,
    String? role,
    String? facilityGroupId,
  }) {
    return AuthState(
      phone: phone ?? this.phone,
      password: password ?? this.password,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      facilityGroupId: facilityGroupId ?? this.facilityGroupId,
    );
  }
}
