import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudyPreferences {
  const StudyPreferences({
    this.figure = 'male',
    this.view = 'front',
    this.animationsEnabled = true,
    this.hasSeenOnboarding = false,
  });

  final String figure;
  final String view;
  final bool animationsEnabled;
  final bool hasSeenOnboarding;
}

class AppPreferences {
  static const _themeModeKey = 'atlas_theme_mode';
  static const _figureKey = 'atlas_default_figure';
  static const _viewKey = 'atlas_default_view';
  static const _animationsKey = 'atlas_animations_enabled';
  static const _onboardingKey = 'atlas_has_seen_onboarding';

  Future<ThemeMode> loadThemeMode() async {
    final value =
        (await SharedPreferences.getInstance()).getString(_themeModeKey);
    return switch (value) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
    };
    await (await SharedPreferences.getInstance())
        .setString(_themeModeKey, value);
  }

  Future<StudyPreferences> loadStudyPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final figure = prefs.getString(_figureKey);
    final view = prefs.getString(_viewKey);
    return StudyPreferences(
      figure: figure == 'female' ? 'female' : 'male',
      view: view == 'back' ? 'back' : 'front',
      animationsEnabled: prefs.getBool(_animationsKey) ?? true,
      hasSeenOnboarding: prefs.getBool(_onboardingKey) ?? false,
    );
  }

  Future<void> saveStudyPreferences({
    String? figure,
    String? view,
    bool? animationsEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (figure != null) await prefs.setString(_figureKey, figure);
    if (view != null) await prefs.setString(_viewKey, view);
    if (animationsEnabled != null) {
      await prefs.setBool(_animationsKey, animationsEnabled);
    }
  }

  Future<void> markOnboardingSeen() async {
    await (await SharedPreferences.getInstance()).setBool(_onboardingKey, true);
  }
}
