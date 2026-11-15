import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/atlas_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.figure,
    required this.onFigureChanged,
    required this.view,
    required this.onViewChanged,
    required this.animationsEnabled,
    required this.onAnimationsChanged,
    required this.onReplayGuide,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final String figure;
  final ValueChanged<String> onFigureChanged;
  final String view;
  final ValueChanged<String> onViewChanged;
  final bool animationsEnabled;
  final ValueChanged<bool> onAnimationsChanged;
  final VoidCallback onReplayGuide;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late ThemeMode _themeMode = widget.themeMode;
  late String _figure = widget.figure;
  late String _view = widget.view;
  late bool _animationsEnabled = widget.animationsEnabled;

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _themeMode = widget.themeMode;
    _figure = widget.figure;
    _view = widget.view;
    _animationsEnabled = widget.animationsEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.atlas;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          _sectionTitle(context, '外观'),
          _card(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('主题',
                    style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                          value: ThemeMode.system, label: Text('跟随系统')),
                      ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
                    ],
                    selected: {_themeMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      HapticFeedback.selectionClick();
                      final value = selection.first;
                      setState(() => _themeMode = value);
                      widget.onThemeModeChanged(value);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '人体画布保持深色背景，便于辨识经络与穴位标记。',
                  style: TextStyle(fontSize: 11, color: palette.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionTitle(context, '首页默认显示'),
          _card(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('人体底图',
                    style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'male', label: Text('男性示意图')),
                      ButtonSegment(value: 'female', label: Text('女性示意图')),
                    ],
                    selected: {_figure},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      HapticFeedback.selectionClick();
                      final value = selection.first;
                      setState(() => _figure = value);
                      widget.onFigureChanged(value);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text('默认视图',
                    style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'front', label: Text('正面')),
                      ButtonSegment(value: 'back', label: Text('背面')),
                    ],
                    selected: {_view},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      HapticFeedback.selectionClick();
                      final value = selection.first;
                      setState(() => _view = value);
                      widget.onViewChanged(value);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionTitle(context, '学习体验'),
          _card(
            context,
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text('首页动画', style: TextStyle(color: palette.textPrimary)),
              subtitle: Text('关闭后暂停首页的路径流动动画',
                  style: TextStyle(color: palette.textMuted)),
              value: _animationsEnabled,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _animationsEnabled = value);
                widget.onAnimationsChanged(value);
              },
            ),
          ),
          const SizedBox(height: 18),
          _card(
            context,
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.menu_book_outlined, color: palette.accent),
              title: Text('重看首次使用引导',
                  style: TextStyle(color: palette.textPrimary)),
              subtitle: Text('画布、搜索、收藏和对比的简要说明',
                  style: TextStyle(color: palette.textMuted)),
              trailing:
                  Icon(Icons.chevron_right_rounded, color: palette.textMuted),
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onReplayGuide();
              },
            ),
          ),
          const SizedBox(height: 18),
          _sectionTitle(context, '数据与使用范围'),
          _card(
            context,
            Text(
              '本应用使用本地学习数据。人体底图为 AI 生成的示意图，穴位位置与路线尚未完成专业校勘；内容仅供学习参考，不用于诊断、治疗或实际操作。未经核实的功效信息不会在设置页补写。',
              style: TextStyle(
                  fontSize: 12, height: 1.6, color: palette.textSecondary),
            ),
            color: palette.warningSurface,
            border: palette.warningBorder,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.atlas.textPrimary)),
      );

  Widget _card(BuildContext context, Widget child,
      {Color? color, Color? border}) {
    final palette = context.atlas;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color ?? palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border ?? palette.border),
      ),
      child: child,
    );
  }
}
