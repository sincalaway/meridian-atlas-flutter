import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meridian_atlas/pages/settings_page.dart';
import 'package:meridian_atlas/theme/atlas_theme.dart';

void main() {
  testWidgets('主题、底图、正背面与动画设置能更新', (tester) async {
    var themeMode = ThemeMode.dark;
    var figure = 'male';
    var view = 'front';
    var animationsEnabled = true;
    var replayCount = 0;

    await tester.pumpWidget(MaterialApp(
      theme: AtlasThemes.light(),
      darkTheme: AtlasThemes.dark(),
      home: SettingsPage(
        themeMode: themeMode,
        onThemeModeChanged: (value) => themeMode = value,
        figure: figure,
        onFigureChanged: (value) => figure = value,
        view: view,
        onViewChanged: (value) => view = value,
        animationsEnabled: animationsEnabled,
        onAnimationsChanged: (value) => animationsEnabled = value,
        onReplayGuide: () => replayCount++,
      ),
    ));

    await tester.tap(find.text('浅色'));
    await tester.pump();
    expect(themeMode, ThemeMode.light);

    await tester.tap(find.text('女性示意图'));
    await tester.pump();
    expect(figure, 'female');

    await tester.tap(find.text('背面'));
    await tester.pump();
    expect(view, 'back');

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(animationsEnabled, isFalse);

    await tester.scrollUntilVisible(find.text('重看首次使用引导'), 200);
    await tester.tap(find.text('重看首次使用引导'));
    expect(replayCount, 1);
    expect(tester.takeException(), isNull);
  });
}
