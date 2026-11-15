import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meridian_atlas/models/meridian.dart';
import 'package:meridian_atlas/pages/settings_page.dart';
import 'package:meridian_atlas/theme/atlas_theme.dart';
import 'package:meridian_atlas/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final meridians =
      (jsonDecode(File('assets/data/meridians.json').readAsStringSync())
              as List)
          .map((row) => Meridian.fromJson(row as Map<String, dynamic>))
          .toList();
  final acupoints =
      (jsonDecode(File('assets/data/acupoints.json').readAsStringSync())
              as List)
          .map((row) => Acupoint.fromJson(row as Map<String, dynamic>))
          .toList();

  testWidgets('首次启动显示引导，完成后可从首页打开设置', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(
      theme: AtlasThemes.light(),
      darkTheme: AtlasThemes.dark(),
      home: MeridianHomePage(meridians: meridians, acupoints: acupoints),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('使用指南'), findsOneWidget);

    await tester.tap(find.text('跳过'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('atlas_has_seen_onboarding'), isTrue);

    await tester.tap(find.byTooltip('设置'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('主题'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
