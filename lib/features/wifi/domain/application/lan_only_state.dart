class LanOnlyState {
  bool isActive;
  bool isLoading;
  bool isCableConnected;
  String? ipAddress;
  String? macAddress;
  String? errorMessage;

  static const Object _unset = Object();

  LanOnlyState({
    this.isActive = false,
    this.isLoading = false,
    this.isCableConnected = false,
    this.ipAddress,
    this.macAddress,
    this.errorMessage,
  });

  LanOnlyState copyWith({
    bool? isActive,
    bool? isLoading,
    bool? isCableConnected,
    Object? ipAddress = _unset,
    Object? macAddress = _unset,
    Object? errorMessage = _unset,
  }) {
    return LanOnlyState(
      isActive: isActive ?? this.isActive,
      isLoading: isLoading ?? this.isLoading,
      isCableConnected: isCableConnected ?? this.isCableConnected,
      ipAddress: identical(ipAddress, _unset) ? this.ipAddress : ipAddress as String?,
      macAddress: identical(macAddress, _unset) ? this.macAddress : macAddress as String?,
      errorMessage:
          identical(errorMessage, _unset) ? this.errorMessage : errorMessage as String?,
    );
  }
}
