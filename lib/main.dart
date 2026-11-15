import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/app_preferences.dart';
import 'data/meridian_repository.dart';
import 'models/meridian.dart';
import 'pages/acupoint_detail_page.dart';
import 'pages/meridian_compare_page.dart';
import 'pages/meridian_detail_page.dart';
import 'pages/settings_page.dart';
import 'theme/atlas_theme.dart';
import 'widgets/acupoint_search_panel.dart';
import 'widgets/first_run_guide.dart';
import 'widgets/meridian_canvas.dart';

void main() {
  runApp(const MeridianAtlasApp());
}

class MeridianAtlasApp extends StatefulWidget {
  const MeridianAtlasApp({super.key});

  @override
  State<MeridianAtlasApp> createState() => _MeridianAtlasAppState();
}

class _MeridianAtlasAppState extends State<MeridianAtlasApp> {
  final AppPreferences _preferences = AppPreferences();
  late final Future<({List<Meridian> meridians, List<Acupoint> acupoints})>
      _data = const MeridianRepository().loadAll();
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _restoreThemeMode();
  }

  Future<void> _restoreThemeMode() async {
    try {
      final saved = await _preferences.loadThemeMode();
      if (mounted) setState(() => _themeMode = saved);
    } catch (_) {
      // 使用深色默认值；主题偏好读取失败不影响本地数据加载。
    }
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    try {
      await _preferences.saveThemeMode(mode);
    } catch (_) {
      // 当前会话仍采用所选主题；下次启动时恢复默认值。
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '经络图谱',
      theme: AtlasThemes.light(),
      darkTheme: AtlasThemes.dark(),
      themeMode: _themeMode,
      home:
          FutureBuilder<({List<Meridian> meridians, List<Acupoint> acupoints})>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _LoadError(message: snapshot.error.toString());
          }
          if (!snapshot.hasData) {
            return const _LoadingScreen();
          }
          return MeridianHomePage(
            meridians: snapshot.data!.meridians,
            acupoints: snapshot.data!.acupoints,
            themeMode: _themeMode,
            onThemeModeChanged: _setThemeMode,
          );
        },
      ),
    );
  }
}

class MeridianHomePage extends StatefulWidget {
  const MeridianHomePage({
    super.key,
    required this.meridians,
    required this.acupoints,
    this.themeMode = ThemeMode.dark,
    this.onThemeModeChanged,
  });

  final List<Meridian> meridians;
  final List<Acupoint> acupoints;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  @override
  State<MeridianHomePage> createState() => _MeridianHomePageState();
}

class _MeridianHomePageState extends State<MeridianHomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flowController;
  final Set<String> _selectedIds = {'LI'};
  String _view = 'front';
  String _figure = 'male';
  String _group = 'all';
  double _speed = 1.0;
  bool _playing = true;
  bool _reverse = false;
  bool _showPoints = true;
  Acupoint? _activePoint;
  final TextEditingController _pointSearchController = TextEditingController();
  final Set<String> _favoritePointIds = {};
  final Map<String, bool> _favoriteOverridesDuringLoad = {};
  Future<void> _favoriteSaveQueue = Future<void>.value();
  static const String _favoritesStorageKey = 'favorite_acupoint_ids';
  String _pointSearchQuery = '';
  String _pointMeridianFilter = 'all';
  bool _favoritesOnly = false;
  final Set<String> _efficacyFilter = {};
  bool _favoritesReady = false;
  final AppPreferences _preferences = AppPreferences();
  bool _onboardingShown = false;

  @override
  void initState() {
    super.initState();
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
    _loadFavorites();
  }

  @override
  void dispose() {
    _flowController.dispose();
    _pointSearchController.dispose();
    super.dispose();
  }

  List<Meridian> get _selectedMeridians => widget.meridians
      .where((meridian) => _selectedIds.contains(meridian.id))
      .toList();

  List<Meridian> get _groupMeridians => widget.meridians.where((meridian) {
        if (_group == 'all') return true;
        return meridian.group == _group;
      }).toList();

  List<Acupoint> get _selectedPoints => widget.acupoints
      .where((point) => _selectedIds.contains(point.meridianId))
      .toList();

  List<Acupoint> get _visiblePoints => widget.acupoints
      .where((point) =>
          point.view == _view && _selectedIds.contains(point.meridianId))
      .toList();

  Future<void> _loadFavorites() async {
    var shouldShowGuide = false;
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedIds =
          preferences.getStringList(_favoritesStorageKey) ?? const [];
      final study = await _preferences.loadStudyPreferences();
      if (!mounted) return;
      setState(() {
        _favoritePointIds.addAll(savedIds);
        for (final entry in _favoriteOverridesDuringLoad.entries) {
          if (entry.value) {
            _favoritePointIds.add(entry.key);
          } else {
            _favoritePointIds.remove(entry.key);
          }
        }
        _view = study.view;
        _figure = study.figure;
        _playing = study.animationsEnabled;
        _favoritesReady = true;
      });
      if (!_playing) _flowController.stop();
      shouldShowGuide = !study.hasSeenOnboarding;
      if (_favoriteOverridesDuringLoad.isNotEmpty) _saveFavorites();
    } catch (_) {
      if (!mounted) return;
      setState(() => _favoritesReady = true);
      shouldShowGuide = true;
      if (_favoriteOverridesDuringLoad.isNotEmpty) _saveFavorites();
    }
    if (shouldShowGuide) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showOnboarding());
    }
  }

  Future<void> _saveStudyPreferences({
    String? figure,
    String? view,
    bool? animationsEnabled,
  }) async {
    try {
      await _preferences.saveStudyPreferences(
        figure: figure,
        view: view,
        animationsEnabled: animationsEnabled,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设置无法保存；本次使用仍有效。')),
        );
      }
    }
  }

  Future<void> _showOnboarding({bool force = false}) async {
    if (!mounted || (_onboardingShown && !force)) return;
    _onboardingShown = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => FirstRunGuide(
        onFinish: () => Navigator.of(dialogContext).pop(),
      ),
    );
    try {
      await _preferences.markOnboardingSeen();
    } catch (_) {
      // 引导仍可正常关闭；下次启动可能再次显示。
    }
  }

  void _changeFigure(String figure) {
    HapticFeedback.selectionClick();
    setState(() => _figure = figure);
    unawaited(_saveStudyPreferences(figure: figure));
  }

  void _changeView(String view) {
    HapticFeedback.selectionClick();
    setState(() {
      _view = view;
      _activePoint = null;
    });
    unawaited(_saveStudyPreferences(view: view));
  }

  void _changeAnimationPreference(bool enabled) {
    HapticFeedback.selectionClick();
    setState(() => _playing = enabled);
    if (enabled) {
      _flowController.repeat();
    } else {
      _flowController.stop();
    }
    unawaited(_saveStudyPreferences(animationsEnabled: enabled));
  }

  void _resumeHomeAnimation() {
    if (mounted && _playing) _flowController.repeat();
  }

  Future<void> _openSettings() async {
    _flowController.stop();
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SettingsPage(
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged ?? (_) {},
        figure: _figure,
        onFigureChanged: _changeFigure,
        view: _view,
        onViewChanged: _changeView,
        animationsEnabled: _playing,
        onAnimationsChanged: _changeAnimationPreference,
        onReplayGuide: () => _showOnboarding(force: true),
      ),
    ));
    _resumeHomeAnimation();
  }

  Future<void> _saveFavorites() {
    final saved = _favoritePointIds.toList()..sort();
    _favoriteSaveQueue = _favoriteSaveQueue.then((_) async {
      try {
        final preferences = await SharedPreferences.getInstance();
        final success =
            await preferences.setStringList(_favoritesStorageKey, saved);
        if (!success && mounted) _showFavoritesSaveError();
      } catch (_) {
        if (mounted) _showFavoritesSaveError();
      }
    });
    return _favoriteSaveQueue;
  }

  void _showFavoritesSaveError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('收藏保存失败，请稍后重试。')),
    );
  }

  void _toggleFavorite(Acupoint point) {
    HapticFeedback.selectionClick();
    var isFavorite = false;
    setState(() {
      if (!_favoritePointIds.add(point.id)) _favoritePointIds.remove(point.id);
      isFavorite = _favoritePointIds.contains(point.id);
      if (!_favoritesReady) {
        _favoriteOverridesDuringLoad[point.id] = isFavorite;
      }
    });
    if (_favoritesReady) _saveFavorites();
  }

  void _selectSearchResult(Acupoint point) {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    setState(() {
      _view = point.view;
      _selectedIds.add(point.meridianId);
      _showPoints = true;
      _activePoint = point;
    });
  }

  Future<void> _openMeridianDetail(Meridian meridian) async {
    HapticFeedback.selectionClick();
    _flowController.stop();
    final picked = await Navigator.of(context).push<Acupoint>(
      MaterialPageRoute(
        builder: (_) => MeridianDetailPage(
          meridian: meridian,
          meridians: widget.meridians,
          acupoints: widget.acupoints,
          favoriteIds: _favoritePointIds,
          initialView: _view,
          figure: _figure,
        ),
      ),
    );
    _resumeHomeAnimation();
    if (!mounted || picked == null) return;
    _selectSearchResult(picked);
  }

  void _openCompare(List<Meridian> selected) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MeridianComparePage(
          meridians: widget.meridians,
          acupoints: widget.acupoints,
          initialLeftId: selected.isNotEmpty ? selected[0].id : null,
          initialRightId: selected.length > 1 ? selected[1].id : null,
          figure: _figure,
        ),
      ),
    );
  }

  void _setSpeed(double value) {
    setState(() => _speed = value);
    _flowController.duration = Duration(milliseconds: (4200 / value).round());
    if (_playing) _flowController.repeat();
  }

  void _togglePlay() {
    HapticFeedback.selectionClick();
    setState(() => _playing = !_playing);
    if (_playing) {
      _flowController.repeat();
    } else {
      _flowController.stop();
    }
  }

  void _toggleReverse() {
    HapticFeedback.selectionClick();
    setState(() => _reverse = !_reverse);
  }

  void _toggleShowPoints() {
    HapticFeedback.selectionClick();
    setState(() => _showPoints = !_showPoints);
  }

  void _resetAnimation() {
    HapticFeedback.selectionClick();
    _flowController.value = 0;
    if (_playing) _flowController.repeat();
  }

  void _toggleMeridian(Meridian meridian) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(meridian.id)) {
        _selectedIds.remove(meridian.id);
        if (_activePoint?.meridianId == meridian.id) _activePoint = null;
      } else {
        _selectedIds.add(meridian.id);
      }
    });
  }

  Future<void> _openPointDetail(Acupoint point) async {
    HapticFeedback.lightImpact();
    setState(() => _activePoint = point);
    final meridian =
        widget.meridians.firstWhere((m) => m.id == point.meridianId);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AcupointDetailPage(
        point: point,
        meridian: meridian,
        acupoints:
            widget.acupoints.where((p) => p.meridianId == meridian.id).toList(),
        figure: _figure,
        isFavorite: (p) => _favoritePointIds.contains(p.id),
        onFavoriteToggle: _toggleFavorite,
        onOpenMeridian: () {
          Navigator.of(context).pop();
          _openMeridianDetail(meridian);
        },
      ),
    ));
  }

  void _openFullscreen() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FullscreenAtlasPage(
        meridians: _selectedMeridians,
        acupoints: _selectedPoints,
        view: _view,
        figure: _figure,
        animation: _flowController,
        reverse: _reverse,
        onPointTap: _openPointDetail,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedMeridians;
    final palette = context.atlas;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final landscape = constraints.maxWidth >= 720 &&
              constraints.maxWidth > constraints.maxHeight;
          if (landscape) {
            return Padding(
              key: const Key('atlas_landscape_layout'),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 6,
                          child: SingleChildScrollView(
                            child: _buildCanvasSection(selected, palette),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          flex: 5,
                          child: SingleChildScrollView(
                            child: _buildExploreSection(selected),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          return SingleChildScrollView(
            key: const Key('atlas_portrait_layout'),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 26),
                _buildCanvasSection(selected, palette),
                const SizedBox(height: 24),
                _buildExploreSection(selected),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCanvasSection(List<Meridian> selected, AtlasPalette palette) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '探索人体经络',
            style: TextStyle(
                fontSize: 27, fontWeight: FontWeight.w700, letterSpacing: -0.6),
          ),
          const SizedBox(height: 6),
          Text('点选经络与穴位，查看标准化示意路径',
              style: TextStyle(fontSize: 14, color: palette.textSecondary)),
          const SizedBox(height: 18),
          _buildViewPicker(),
          const SizedBox(height: 12),
          _buildCanvas(selected),
          const SizedBox(height: 14),
          _buildAnimationControls(),
        ],
      );

  Widget _buildExploreSection(List<Meridian> selected) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeading('搜索穴位',
              trailing: '${widget.acupoints.length} 个穴位'),
          const SizedBox(height: 12),
          AcupointSearchPanel(
            points: widget.acupoints,
            meridians: widget.meridians,
            controller: _pointSearchController,
            query: _pointSearchQuery,
            onQueryChanged: (value) =>
                setState(() => _pointSearchQuery = value),
            selectedMeridianId: _pointMeridianFilter,
            onMeridianChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _pointMeridianFilter = value);
            },
            favoritesOnly: _favoritesOnly,
            onFavoritesOnlyChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _favoritesOnly = value);
            },
            favoriteIds: _favoritePointIds,
            favoritesReady: _favoritesReady,
            onFavoriteToggle: _toggleFavorite,
            onPointSelected: _selectSearchResult,
            selectedEfficacyTags: _efficacyFilter,
            onEfficacyTagToggled: (tag) {
              HapticFeedback.selectionClick();
              setState(() {
                if (!_efficacyFilter.add(tag)) _efficacyFilter.remove(tag);
              });
            },
            onEfficacyTagsCleared: () {
              HapticFeedback.selectionClick();
              setState(_efficacyFilter.clear);
            },
          ),
          const SizedBox(height: 24),
          _buildSectionHeading('选择经络', trailing: '${_selectedIds.length} 条已叠加'),
          const SizedBox(height: 12),
          _buildGroupPicker(),
          const SizedBox(height: 12),
          _buildMeridianChips(),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildDetailShortcuts(selected),
          ],
          const SizedBox(height: 16),
          if (_activePoint != null) _buildPointCard(_activePoint!),
          if (_activePoint == null) _buildHintCard(),
          const SizedBox(height: 14),
          _buildDisclaimer(),
        ],
      );

  Widget _buildHeader() {
    final palette = context.atlas;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: palette.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.hub_rounded, color: palette.accent, size: 23),
        ),
        const SizedBox(width: 11),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('经络图谱',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text('MERIDIAN ATLAS',
                style: TextStyle(fontSize: 9, letterSpacing: 1.2)),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: palette.surfaceMuted,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              Icon(Icons.school_outlined, size: 14, color: palette.accent),
              SizedBox(width: 5),
              Text('学习模式', style: TextStyle(fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: '设置',
          onPressed: _openSettings,
          icon: Icon(Icons.settings_outlined, color: palette.textSecondary),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildViewPicker() {
    return Row(
      children: [
        _ViewButton(
            label: '正面',
            selected: _view == 'front',
            onTap: () => _changeView('front')),
        const SizedBox(width: 8),
        _ViewButton(
            label: '背面',
            selected: _view == 'back',
            onTap: () => _changeView('back')),
        const SizedBox(width: 14),
        _ViewButton(
            label: '男',
            selected: _figure == 'male',
            onTap: () => _changeFigure('male')),
        const SizedBox(width: 6),
        _ViewButton(
            label: '女',
            selected: _figure == 'female',
            onTap: () => _changeFigure('female')),
        const Spacer(),
        TextButton.icon(
          onPressed: _toggleShowPoints,
          icon: Icon(
              _showPoints
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 16),
          label: Text(_showPoints ? '穴位' : '穴位',
              style: const TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
              foregroundColor: context.atlas.textSecondary,
              visualDensity: VisualDensity.compact),
        ),
      ],
    );
  }

  Widget _buildCanvas(List<Meridian> selected) {
    final screen = MediaQuery.sizeOf(context);
    final landscape = screen.width > screen.height;
    final height = math.min(640.0, screen.height * (landscape ? 0.76 : 0.68));
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF26383A)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF121619), Color(0xFF121619)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: MeridianCanvas(
              meridians: selected,
              acupoints: _selectedPoints,
              view: _view,
              figure: _figure,
              animation: _flowController,
              reverse: _reverse,
              showPoints: _showPoints,
              activePointId: _activePoint?.id,
              onPointTap: _openPointDetail,
            ),
          ),
          Positioned(
            left: 14,
            top: 14,
            child: _CanvasBadge(
                label: _view == 'front' ? '前侧视图' : '后侧视图',
                icon: Icons.person_outline_rounded),
          ),
          Positioned(
            right: 12,
            top: 54,
            child: IconButton.filledTonal(
              onPressed: _openFullscreen,
              tooltip: '全屏查看',
              icon: const Icon(Icons.fullscreen_rounded, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF26363A),
                foregroundColor: const Color(0xFFD7E5E0),
                fixedSize: const Size(36, 36),
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: IconButton.filledTonal(
              onPressed: _toggleReverse,
              tooltip: '切换流动方向',
              icon: Icon(
                  _reverse ? Icons.swap_horiz_rounded : Icons.swap_vert_rounded,
                  size: 18),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF26363A),
                foregroundColor: const Color(0xFFD7E5E0),
                fixedSize: const Size(36, 36),
              ),
            ),
          ),
          if (selected.isNotEmpty)
            const Positioned(left: 12, bottom: 34, child: MeridianLineLegend()),
          Positioned(
            left: 14,
            bottom: 13,
            child: Text(
              selected.isEmpty
                  ? '选择一条经络以开始'
                  : selected.map((item) => item.code).join('  ·  '),
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFFB7C9C1), letterSpacing: 0.5),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 13,
            child: Text('双指放大显示穴名 · 位置为示意',
                style: TextStyle(
                    fontSize: 10, color: Colors.white.withOpacity(0.45))),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimationControls() {
    final palette = context.atlas;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 9),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton.filled(
                onPressed: _togglePlay,
                icon: Icon(
                    _playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF72D6C2),
                  foregroundColor: const Color(0xFF10201D),
                  fixedSize: const Size(42, 42),
                ),
              ),
              const SizedBox(width: 10),
              Text(_playing ? '经络流动中' : '动画已暂停',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('循环播放',
                  style: TextStyle(fontSize: 11, color: palette.textMuted)),
              const SizedBox(width: 6),
              IconButton(
                onPressed: _resetAnimation,
                tooltip: '重置动画',
                icon: const Icon(Icons.restart_alt_rounded, size: 19),
                visualDensity: VisualDensity.compact,
                color: palette.textSecondary,
              ),
            ],
          ),
          Row(
            children: [
              Icon(Icons.speed_rounded, size: 17, color: palette.textMuted),
              const SizedBox(width: 8),
              Text('速度',
                  style: TextStyle(fontSize: 11, color: palette.textMuted)),
              Expanded(
                child: Slider(
                  value: _speed,
                  min: 0.5,
                  max: 2.5,
                  divisions: 4,
                  onChanged: _setSpeed,
                ),
              ),
              SizedBox(
                  width: 35,
                  child: Text('${_speed.toStringAsFixed(1)}×',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontSize: 11))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeading(String title, {String? trailing}) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const Spacer(),
        if (trailing != null)
          Text(trailing,
              style: const TextStyle(fontSize: 11, color: Color(0xFF91AAA3))),
      ],
    );
  }

  Widget _buildGroupPicker() {
    final palette = context.atlas;
    const options = [
      ('all', '全部'),
      ('hand', '手经'),
      ('foot', '足经'),
      ('extra', '奇经'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((option) {
          final selected = _group == option.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(option.$2),
              selected: selected,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _group = option.$1);
              },
              labelStyle: TextStyle(
                  fontSize: 12,
                  color: selected ? palette.accent : palette.textSecondary),
              selectedColor: palette.surfaceMuted,
              backgroundColor: palette.surface,
              side: BorderSide(
                  color: selected
                      ? palette.accent.withOpacity(0.65)
                      : palette.border),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 7),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMeridianChips() {
    final palette = context.atlas;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _groupMeridians.map((meridian) {
        final selected = _selectedIds.contains(meridian.id);
        return FilterChip(
          selected: selected,
          onSelected: (_) => _toggleMeridian(meridian),
          avatar: Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: meridian.color, shape: BoxShape.circle)),
          label: Text('${meridian.nameZh}  ${meridian.code}'),
          labelStyle: TextStyle(
              fontSize: 11,
              color: selected ? palette.textPrimary : palette.textSecondary),
          backgroundColor: palette.surfaceMuted,
          selectedColor:
              Color.lerp(palette.surfaceRaised, meridian.color, 0.17),
          side: BorderSide(
              color:
                  selected ? meridian.color.withOpacity(0.7) : palette.border),
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 6),
        );
      }).toList(),
    );
  }

  Widget _buildDetailShortcuts(List<Meridian> selected) {
    final palette = context.atlas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('经络详情与对比',
            style: TextStyle(fontSize: 11, color: palette.textMuted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              onPressed: () => _openCompare(selected),
              avatar: Icon(Icons.compare_arrows_rounded,
                  size: 15, color: palette.accent),
              label: const Text('对比两条经络'),
              labelStyle: TextStyle(fontSize: 11, color: palette.accent),
              backgroundColor: palette.surfaceMuted,
              side: BorderSide(color: palette.accent.withOpacity(0.5)),
              visualDensity: VisualDensity.compact,
            ),
            ...selected.map((meridian) {
              return ActionChip(
                onPressed: () => _openMeridianDetail(meridian),
                avatar: Icon(Icons.menu_book_rounded,
                    size: 14, color: meridian.color),
                label: Text(meridian.nameZh),
                labelStyle: TextStyle(fontSize: 11, color: palette.textPrimary),
                backgroundColor: palette.surface,
                side: BorderSide(color: meridian.color.withOpacity(0.45)),
                visualDensity: VisualDensity.compact,
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildPointCard(Acupoint point) {
    final palette = context.atlas;
    final meridian =
        widget.meridians.firstWhere((item) => item.id == point.meridianId);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: meridian.color.withOpacity(0.42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: meridian.color.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(12)),
                child:
                    Icon(Icons.adjust_rounded, color: meridian.color, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${point.nameZh}  ${point.code}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text('${point.pinyin}  ·  ${meridian.nameZh}',
                          style: TextStyle(
                              fontSize: 11, color: palette.textMuted)),
                    ]),
              ),
              IconButton(
                tooltip: _favoritePointIds.contains(point.id) ? '取消收藏' : '收藏穴位',
                onPressed: () => _toggleFavorite(point),
                icon: Icon(
                  _favoritePointIds.contains(point.id)
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: _favoritePointIds.contains(point.id)
                      ? const Color(0xFFE2C66E)
                      : const Color(0xFF83958F),
                ),
              ),
              IconButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _activePoint = null);
                },
                icon: const Icon(Icons.close_rounded, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 13),
          if (point.specialCategories.isNotEmpty) ...[
            Text(point.specialCategories.join(' · '),
                style: TextStyle(
                    fontSize: 11, color: meridian.color.withOpacity(0.9))),
            const SizedBox(height: 6),
          ],
          Text('定位：${point.location}',
              style: TextStyle(
                  fontSize: 12, height: 1.55, color: palette.textPrimary)),
          if (point.efficacyTags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: point.efficacyTags
                  .map((tag) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: meridian.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(tag,
                            style: TextStyle(
                                fontSize: 10, color: palette.textPrimary)),
                      ))
                  .toList(),
            ),
          ],
          if (point.indications.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('主治（学习资料）',
                style: TextStyle(fontSize: 11, color: palette.textMuted)),
            const SizedBox(height: 4),
            ...point.indications.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('· $item',
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: palette.textSecondary)),
                )),
          ],
          if (point.cautions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 14, color: Color(0xFFE2B86E)),
              const SizedBox(width: 5),
              Expanded(
                  child: Text(point.cautions,
                      style:
                          TextStyle(fontSize: 11, color: palette.warningText))),
            ]),
          ],
          const SizedBox(height: 10),
          Text('仅供学习参考，不作诊疗依据。',
              style: TextStyle(fontSize: 10, color: palette.textMuted)),
          const SizedBox(height: 4),
          Text('资料来源：${point.source}',
              style: TextStyle(
                  fontSize: 10, height: 1.45, color: palette.textMuted)),
          const SizedBox(height: 6),
          Wrap(spacing: 4, children: [
            TextButton.icon(
              onPressed: () => _openPointDetail(point),
              icon: const Icon(Icons.article_outlined, size: 15),
              label: const Text('穴位介绍', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                  foregroundColor: palette.accent,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openMeridianDetail(meridian),
                icon: const Icon(Icons.menu_book_rounded, size: 15),
                label: Text('查看${meridian.nameZh}详情',
                    style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                    foregroundColor: meridian.color,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildHintCard() {
    final palette = context.atlas;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
          color: palette.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(Icons.touch_app_outlined, size: 19, color: palette.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _showPoints ? '轻触穴位进入介绍，双指放大可看穴名' : '开启“穴位”后可点选穴位标记',
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            ),
          ),
          Text('${_visiblePoints.length} 个穴位',
              style: TextStyle(fontSize: 10, color: palette.textMuted)),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    final palette = context.atlas;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: palette.warningSurface,
        border: Border.all(color: palette.warningBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: palette.warningText),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '人体底图为 AI 生成的写实示意图；穴位位置按骨度分寸由体表标志推算，经络线按穴序连接（实线连同一面相邻的穴位，虚线表示中间穴位在另一面、跨面接续），均为学习示意，尚未完成专业校勘，不用于诊断、治疗或实际操作指导。',
              style: TextStyle(
                  fontSize: 10, height: 1.5, color: palette.warningText),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewButton extends StatelessWidget {
  const _ViewButton(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.atlas;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? palette.surfaceMuted : palette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? palette.accent : palette.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                color: selected ? palette.accent : palette.textSecondary)),
      ),
    );
  }
}

class _CanvasBadge extends StatelessWidget {
  const _CanvasBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
          color: const Color(0xCC0D1719),
          borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFFB5D4C9)),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Color(0xFFD0DDD7))),
        ],
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
          body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(),
        SizedBox(height: 14),
        Text('正在加载本地经络数据')
      ])));
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline,
                  size: 36, color: Color(0xFFE1BD71)),
              const SizedBox(height: 12),
              const Text('本地数据加载失败',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12, color: context.atlas.textSecondary)),
            ]),
          ),
        ),
      );
}

class _FullscreenAtlasPage extends StatefulWidget {
  const _FullscreenAtlasPage({
    required this.meridians,
    required this.acupoints,
    required this.view,
    required this.figure,
    required this.animation,
    required this.reverse,
    required this.onPointTap,
  });

  final List<Meridian> meridians;
  final List<Acupoint> acupoints;
  final String view;
  final String figure;
  final Animation<double> animation;
  final bool reverse;
  final ValueChanged<Acupoint> onPointTap;

  @override
  State<_FullscreenAtlasPage> createState() => _FullscreenAtlasPageState();
}

class _FullscreenAtlasPageState extends State<_FullscreenAtlasPage> {
  late String _view = widget.view;
  late String _figure = widget.figure;
  String? _active;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121619),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
            widget.meridians.isEmpty
                ? '人体图'
                : widget.meridians.map((m) => m.nameZh).join('、'),
            style: const TextStyle(fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _view = _view == 'front' ? 'back' : 'front');
            },
            child: Text(_view == 'front' ? '看背面' : '看正面'),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _figure = _figure == 'male' ? 'female' : 'male');
            },
            child: Text(_figure == 'male' ? '换女性' : '换男性'),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(children: [
          Positioned.fill(
            child: MeridianCanvas(
              meridians: widget.meridians,
              acupoints: widget.acupoints,
              view: _view,
              figure: _figure,
              animation: widget.animation,
              reverse: widget.reverse,
              showPoints: true,
              activePointId: _active,
              onPointTap: (p) {
                setState(() => _active = p.id);
                widget.onPointTap(p);
              },
            ),
          ),
          const Positioned(left: 12, bottom: 12, child: MeridianLineLegend()),
        ]),
      ),
    );
  }
}
