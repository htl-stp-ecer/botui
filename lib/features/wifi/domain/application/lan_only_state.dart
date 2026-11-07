class LanOnlyState {
  bool isActive;
  bool isLoading;
  bool isCableConnected;
  String? ipAddress;
  String? macAddress;
  String? errorMessage;

  /// How Ethernet Mode was set up: "client" or "host" (null before it was
  /// enabled or from an older server).
  String? role;

  static const Object _unset = Object();

  LanOnlyState({
    this.isActive = false,
    this.isLoading = false,
    this.isCableConnected = false,
    this.ipAddress,
    this.macAddress,
    this.errorMessage,
    this.role,
  });

  LanOnlyState copyWith({
    bool? isActive,
    bool? isLoading,
    bool? isCableConnected,
    Object? ipAddress = _unset,
    Object? macAddress = _unset,
    Object? errorMessage = _unset,
    Object? role = _unset,
  }) {
    return LanOnlyState(
      isActive: isActive ?? this.isActive,
      isLoading: isLoading ?? this.isLoading,
      isCableConnected: isCableConnected ?? this.isCableConnected,
      ipAddress: identical(ipAddress, _unset) ? this.ipAddress : ipAddress as String?,
      macAddress: identical(macAddress, _unset) ? this.macAddress : macAddress as String?,
      errorMessage:
          identical(errorMessage, _unset) ? this.errorMessage : errorMessage as String?,
      role: identical(role, _unset) ? this.role : role as String?,
    );
  }
}
