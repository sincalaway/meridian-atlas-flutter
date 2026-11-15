import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meridian_atlas/data/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('默认主题为深色，主题选择可以持久化', () async {
    final preferences = AppPreferences();
    expect(await preferences.loadThemeMode(), ThemeMode.dark);
    await preferences.saveThemeMode(ThemeMode.light);
    expect(await preferences.loadThemeMode(), ThemeMode.light);
    await preferences.saveThemeMode(ThemeMode.system);
    expect(await preferences.loadThemeMode(), ThemeMode.system);
  });

  test('首页偏好和首次引导状态可读写', () async {
    final preferences = AppPreferences();
    final defaults = await preferences.loadStudyPreferences();
    expect(defaults.figure, 'male');
    expect(defaults.view, 'front');
    expect(defaults.animationsEnabled, isTrue);
    expect(defaults.hasSeenOnboarding, isFalse);

    await preferences.saveStudyPreferences(
      figure: 'female',
      view: 'back',
      animationsEnabled: false,
    );
    var study = await preferences.loadStudyPreferences();
    expect(study.figure, 'female');
    expect(study.view, 'back');
    expect(study.animationsEnabled, isFalse);
    expect(study.hasSeenOnboarding, isFalse);

    await preferences.markOnboardingSeen();
    study = await preferences.loadStudyPreferences();
    expect(study.hasSeenOnboarding, isTrue);
  });
}
