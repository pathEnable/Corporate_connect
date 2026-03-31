import 'package:flutter/foundation.dart';

@immutable
class ProfileState {
  final Map<String, dynamic>? profileData;
  final bool isLoading;
  final bool hasE2eeKeys;
  final String? errorMessage;

  const ProfileState({
    this.profileData,
    this.isLoading = false,
    this.hasE2eeKeys = false,
    this.errorMessage,
  });

  ProfileState copyWith({
    Map<String, dynamic>? profileData,
    bool? isLoading,
    bool? hasE2eeKeys,
    String? errorMessage,
  }) {
    return ProfileState(
      profileData: profileData ?? this.profileData,
      isLoading: isLoading ?? this.isLoading,
      hasE2eeKeys: hasE2eeKeys ?? this.hasE2eeKeys,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
