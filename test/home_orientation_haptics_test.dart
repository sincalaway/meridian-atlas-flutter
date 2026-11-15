import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meridian_atlas/main.dart';
import 'package:meridian_atlas/models/meridian.dart';
import 'package:meridian_atlas/theme/atlas_theme.dart';
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

  Future<void> pumpHome(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'atlas_has_seen_onboarding': true});
    await tester.pumpWidget(MaterialApp(
      theme: AtlasThemes.light(),
      darkTheme: AtlasThemes.dark(),
      home: MeridianHomePage(meridians: meridians, acupoints: acupoints),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('首页随设备方向切换布局，横竖屏均无布局异常', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHome(tester);
    expect(find.byKey(const Key('atlas_landscape_layout')), findsOneWidget);
    expect(find.text('选择经络'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(844, 390);
    await tester.pump();
    expect(find.byKey(const Key('atlas_landscape_layout')), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(600, 1000);
    await tester.pump();
    expect(find.byKey(const Key('atlas_portrait_layout')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('正背面切换会发送轻触反馈', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await pumpHome(tester);
    await tester.tap(find.text('背面').first);
    await tester.pump();

    expect(
      calls.any((call) =>
          call.method == 'HapticFeedback.vibrate' &&
          call.arguments == 'HapticFeedbackType.selectionClick'),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
