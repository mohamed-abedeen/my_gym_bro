import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds user selections made during the onboarding flow.
class OnboardingData {
  final String? gender;
  final String? goal;
  final String? experience;
  final DateTime? birthday;
  final double? weightKg;
  final double? heightCm;
  final Set<String> targetZones;
  final bool useMetric;
  final String? selectedLanguage;

  const OnboardingData({
    this.gender,
    this.goal,
    this.experience,
    this.birthday,
    this.weightKg,
    this.heightCm,
    this.targetZones = const {},
    this.useMetric = true,
    this.selectedLanguage,
  });

  OnboardingData copyWith({
    String? gender,
    String? goal,
    String? experience,
    DateTime? birthday,
    double? weightKg,
    double? heightCm,
    Set<String>? targetZones,
    bool? useMetric,
    String? selectedLanguage,
  }) =>
      OnboardingData(
        gender: gender ?? this.gender,
        goal: goal ?? this.goal,
        experience: experience ?? this.experience,
        birthday: birthday ?? this.birthday,
        weightKg: weightKg ?? this.weightKg,
        heightCm: heightCm ?? this.heightCm,
        targetZones: targetZones ?? this.targetZones,
        useMetric: useMetric ?? this.useMetric,
        selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      );
}

class OnboardingNotifier extends StateNotifier<OnboardingData> {
  OnboardingNotifier() : super(const OnboardingData());

  void setGender(String gender) => state = state.copyWith(gender: gender);
  void setGoal(String goal) => state = state.copyWith(goal: goal);
  void setExperience(String exp) => state = state.copyWith(experience: exp);
  void setBirthday(DateTime date) => state = state.copyWith(birthday: date);
  void setWeight(double kg) => state = state.copyWith(weightKg: kg);
  void setHeight(double cm) => state = state.copyWith(heightCm: cm);
  void setUseMetric(bool metric) => state = state.copyWith(useMetric: metric);
  void toggleTargetZone(String zone) {
    final zones = Set<String>.from(state.targetZones);
    if (zone == 'all') {
      if (zones.contains('all')) {
        zones.clear();
      } else {
        zones
          ..clear()
          ..add('all');
      }
    } else {
      zones.remove('all');
      if (zones.contains(zone)) {
        zones.remove(zone);
      } else {
        zones.add(zone);
      }
    }
    state = state.copyWith(targetZones: zones);
  }

  void setLanguage(String lang) =>
      state = state.copyWith(selectedLanguage: lang);
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingData>(
  (ref) => OnboardingNotifier(),
);
