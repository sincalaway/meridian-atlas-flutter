import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/meridian_repository.dart';
import 'models/meridian.dart';
import 'pages/meridian_compare_page.dart';
import 'pages/meridian_detail_page.dart';
import 'widgets/acupoint_search_panel.dart';
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
  late final Future<({List<Meridian> meridians, List<Acupoint> acupoints})> _data =
      const MeridianRepository().loadAll();

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF0B1215);
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ink,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF72D6C2),
        brightness: Brightness.dark,
        surface: const Color(0xFF121D21),
      ),
      sliderTheme: const SliderThemeData(trackHeight: 3),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '经络图谱',
      theme: theme,
      home: FutureBuilder<({List<Meridian> meridians, List<Acupoint> acupoints})>(
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
  });

  final List<Meridian> meridians;
  final List<Acupoint> acupoints;

  @override
  State<MeridianHomePage> createState() => _MeridianHomePageState();
}

class _MeridianHomePageState extends State<MeridianHomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flowController;
  final Set<String> _selectedIds = {'LI'};
  String _view = 'front';
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

  List<Meridian> get _selectedMeridians =>
      widget.meridians.where((meridian) => _selectedIds.contains(meridian.id)).toList();

  List<Meridian> get _groupMeridians => widget.meridians.where((meridian) {
        if (_group == 'all') return true;
        return meridian.group == _group;
      }).toList();

  List<Acupoint> get _visiblePoints => widget.acupoints
      .where((point) => point.view == _view && _selectedIds.contains(point.meridianId))
      .toList();

  Future<void> _loadFavorites() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedIds = preferences.getStringList(_favoritesStorageKey) ?? const [];
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
        _favoritesReady = true;
      });
      if (_favoriteOverridesDuringLoad.isNotEmpty) _saveFavorites();
    } catch (_) {
      if (!mounted) return;
      setState(() => _favoritesReady = true);
      if (_favoriteOverridesDuringLoad.isNotEmpty) _saveFavorites();
    }
  }

  Future<void> _saveFavorites() {
    final saved = _favoritePointIds.toList()..sort();
    _favoriteSaveQueue = _favoriteSaveQueue.then((_) async {
      try {
        final preferences = await SharedPreferences.getInstance();
        final success = await preferences.setStringList(_favoritesStorageKey, saved);
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
    final picked = await Navigator.of(context).push<Acupoint>(
      MaterialPageRoute(
        builder: (_) => MeridianDetailPage(
          meridian: meridian,
          acupoints: widget.acupoints,
          favoriteIds: _favoritePointIds,
          initialView: _view,
        ),
      ),
    );
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

  void _handleCanvasTap(TapDownDetails details) {
    // Use the canvas' own geometry so hit testing remains aligned with letterboxing.
    final canvasContext = _canvasKey.currentContext;
    final canvasBox = canvasContext?.findRenderObject() as RenderBox?;
    if (canvasBox == null) return;
    final size = canvasBox.size;
    final scale = (size.width / 1000).clamp(0.0, size.height / 1600);
    if (scale <= 0) return;
    final left = (size.width - 1000 * scale) / 2;
    final top = (size.height - 1600 * scale) / 2;
    final point = Offset(
      (details.localPosition.dx - left) / scale,
      (details.localPosition.dy - top) / scale,
    );
    Acupoint? nearest;
    var nearestDistance = double.infinity;
    for (final candidate in _visiblePoints) {
      final distance = (Offset(candidate.x, candidate.y) - point).distance;
      if (distance < nearestDistance) {
        nearest = candidate;
        nearestDistance = distance;
      }
    }
    if (nearest != null && nearestDistance < 58) {
      HapticFeedback.lightImpact();
      setState(() => _activePoint = nearest);
    }
  }

  final GlobalKey _canvasKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final selected = _selectedMeridians;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 26),
              const Text(
                '探索人体经络',
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700, letterSpacing: -0.6),
              ),
              const SizedBox(height: 6),
              Text(
                '点选经络与穴位，查看标准化示意路径',
                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.58)),
              ),
              const SizedBox(height: 18),
              _buildViewPicker(),
              const SizedBox(height: 12),
              _buildCanvas(selected),
              const SizedBox(height: 14),
              _buildAnimationControls(),
              const SizedBox(height: 24),
              _buildSectionHeading('搜索穴位', trailing: '${widget.acupoints.length} 个示例点'),
              const SizedBox(height: 12),
              AcupointSearchPanel(
                points: widget.acupoints,
                meridians: widget.meridians,
                controller: _pointSearchController,
                query: _pointSearchQuery,
                onQueryChanged: (value) => setState(() => _pointSearchQuery = value),
                selectedMeridianId: _pointMeridianFilter,
                onMeridianChanged: (value) => setState(() => _pointMeridianFilter = value),
                favoritesOnly: _favoritesOnly,
                onFavoritesOnlyChanged: (value) => setState(() => _favoritesOnly = value),
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
                onEfficacyTagsCleared: () => setState(_efficacyFilter.clear),
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
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF18302F),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.hub_rounded, color: Color(0xFF72D6C2), size: 23),
        ),
        const SizedBox(width: 11),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('经络图谱', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text('MERIDIAN ATLAS', style: TextStyle(fontSize: 9, letterSpacing: 1.2, color: Color(0xFF8EAAA7))),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF23302D),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF42514A)),
          ),
          child: const Row(
            children: [
              Icon(Icons.school_outlined, size: 14, color: Color(0xFFA8C1B2)),
              SizedBox(width: 5),
              Text('学习模式', style: TextStyle(fontSize: 11, color: Color(0xFFCFDED5))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildViewPicker() {
    return Row(
      children: [
        _ViewButton(label: '正面', selected: _view == 'front', onTap: () => setState(() {
          _view = 'front';
          _activePoint = null;
        })),
        const SizedBox(width: 8),
        _ViewButton(label: '背面', selected: _view == 'back', onTap: () => setState(() {
          _view = 'back';
          _activePoint = null;
        })),
        const Spacer(),
        TextButton.icon(
          onPressed: () => setState(() => _showPoints = !_showPoints),
          icon: Icon(_showPoints ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 16),
          label: Text(_showPoints ? '显示穴位' : '隐藏穴位', style: const TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFB3C6C0), visualDensity: VisualDensity.compact),
        ),
      ],
    );
  }

  Widget _buildCanvas(List<Meridian> selected) {
    return Container(
      height: 390,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF26383A)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF172326), Color(0xFF10191C), Color(0xFF182221)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _flowController,
                builder: (context, _) => MeridianCanvas(
                  key: _canvasKey,
                  meridians: selected,
                  acupoints: _visiblePoints,
                  view: _view,
                  progress: _flowController.value,
                  reverse: _reverse,
                  showPoints: _showPoints,
                  activePointId: _activePoint?.id,
                  onTapDown: _handleCanvasTap,
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: 14,
            child: _CanvasBadge(label: _view == 'front' ? '前侧视图' : '后侧视图', icon: Icons.person_outline_rounded),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: IconButton.filledTonal(
              onPressed: () => setState(() => _reverse = !_reverse),
              tooltip: '切换流动方向',
              icon: Icon(_reverse ? Icons.swap_horiz_rounded : Icons.swap_vert_rounded, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF26363A),
                foregroundColor: const Color(0xFFD7E5E0),
                fixedSize: const Size(36, 36),
              ),
            ),
          ),
          Positioned(
            left: 14,
            bottom: 13,
            child: Text(
              selected.isEmpty ? '选择一条经络以开始' : selected.map((item) => item.code).join('  ·  '),
              style: const TextStyle(fontSize: 11, color: Color(0xFFB7C9C1), letterSpacing: 0.5),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 13,
            child: Text('示意坐标 0–1000', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.38))),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimationControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 9),
      decoration: BoxDecoration(
        color: const Color(0xFF121D20),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF223236)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton.filled(
                onPressed: _togglePlay,
                icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF72D6C2),
                  foregroundColor: const Color(0xFF10201D),
                  fixedSize: const Size(42, 42),
                ),
              ),
              const SizedBox(width: 10),
              Text(_playing ? '经络流动中' : '动画已暂停', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('循环播放', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.48))),
              const SizedBox(width: 6),
              IconButton(
                onPressed: _resetAnimation,
                tooltip: '重置动画',
                icon: const Icon(Icons.restart_alt_rounded, size: 19),
                visualDensity: VisualDensity.compact,
                color: const Color(0xFFB6C8C2),
              ),
            ],
          ),
          Row(
            children: [
              Icon(Icons.speed_rounded, size: 17, color: Colors.white.withOpacity(0.55)),
              const SizedBox(width: 8),
              Text('速度', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.55))),
              Expanded(
                child: Slider(
                  value: _speed,
                  min: 0.5,
                  max: 2.5,
                  divisions: 4,
                  onChanged: _setSpeed,
                ),
              ),
              SizedBox(width: 35, child: Text('${_speed.toStringAsFixed(1)}×', textAlign: TextAlign.end, style: const TextStyle(fontSize: 11))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeading(String title, {String? trailing}) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const Spacer(),
        if (trailing != null) Text(trailing, style: const TextStyle(fontSize: 11, color: Color(0xFF91AAA3))),
      ],
    );
  }

  Widget _buildGroupPicker() {
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
              onSelected: (_) => setState(() => _group = option.$1),
              labelStyle: TextStyle(fontSize: 12, color: selected ? const Color(0xFFBDECE0) : const Color(0xFFA6B4B1)),
              selectedColor: const Color(0xFF1E3734),
              backgroundColor: const Color(0xFF141F22),
              side: BorderSide(color: selected ? const Color(0xFF47796D) : const Color(0xFF273539)),
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _groupMeridians.map((meridian) {
        final selected = _selectedIds.contains(meridian.id);
        return FilterChip(
          selected: selected,
          onSelected: (_) => _toggleMeridian(meridian),
          avatar: Container(width: 8, height: 8, decoration: BoxDecoration(color: meridian.color, shape: BoxShape.circle)),
          label: Text('${meridian.nameZh}  ${meridian.code}'),
          labelStyle: TextStyle(fontSize: 11, color: selected ? const Color(0xFFE5F1EB) : const Color(0xFFAAB7B3)),
          backgroundColor: const Color(0xFF131E21),
          selectedColor: Color.lerp(const Color(0xFF172326), meridian.color, 0.17),
          side: BorderSide(color: selected ? meridian.color.withOpacity(0.7) : const Color(0xFF263538)),
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 6),
        );
      }).toList(),
    );
  }

  Widget _buildDetailShortcuts(List<Meridian> selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('经络详情与对比', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              onPressed: () => _openCompare(selected),
              avatar: const Icon(Icons.compare_arrows_rounded, size: 15, color: Color(0xFF72D6C2)),
              label: const Text('对比两条经络'),
              labelStyle: const TextStyle(fontSize: 11, color: Color(0xFFBDECE0)),
              backgroundColor: const Color(0xFF17292A),
              side: const BorderSide(color: Color(0xFF3D6B61)),
              visualDensity: VisualDensity.compact,
            ),
            ...selected.map((meridian) {
            return ActionChip(
              onPressed: () => _openMeridianDetail(meridian),
              avatar: Icon(Icons.menu_book_rounded, size: 14, color: meridian.color),
              label: Text(meridian.nameZh),
              labelStyle: const TextStyle(fontSize: 11, color: Color(0xFFD5E2DD)),
              backgroundColor: const Color(0xFF141F22),
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
    final meridian = widget.meridians.firstWhere((item) => item.id == point.meridianId);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF172322),
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
                decoration: BoxDecoration(color: meridian.color.withOpacity(0.16), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.adjust_rounded, color: meridian.color, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${point.nameZh}  ${point.code}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text('${point.pinyin}  ·  ${meridian.nameZh}', style: const TextStyle(fontSize: 11, color: Color(0xFFA8BDB5))),
                ]),
              ),
              IconButton(
                tooltip: _favoritePointIds.contains(point.id) ? '取消收藏' : '收藏穴位',
                onPressed: () => _toggleFavorite(point),
                icon: Icon(
                  _favoritePointIds.contains(point.id) ? Icons.star_rounded : Icons.star_border_rounded,
                  color: _favoritePointIds.contains(point.id) ? const Color(0xFFE2C66E) : const Color(0xFF83958F),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _activePoint = null),
                icon: const Icon(Icons.close_rounded, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(point.location, style: const TextStyle(fontSize: 12, height: 1.55, color: Color(0xFFD0DAD5))),
          if (point.efficacyTags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: point.efficacyTags
                  .map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: meridian.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(tag, style: const TextStyle(fontSize: 10, color: Color(0xFFD5E2DD))),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 10),
          Text('资料状态：${point.source}', style: TextStyle(fontSize: 10, height: 1.45, color: Colors.white.withOpacity(0.44))),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _openMeridianDetail(meridian),
              icon: const Icon(Icons.menu_book_rounded, size: 15),
              label: Text('查看${meridian.nameZh}详情', style: const TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: meridian.color, padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHintCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(color: const Color(0xFF121D20), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.touch_app_outlined, size: 19, color: Color(0xFF72D6C2)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _showPoints ? '轻触人体上的标记查看穴位示例' : '开启“显示穴位”后可点选示例标记',
              style: const TextStyle(fontSize: 12, color: Color(0xFFB5C4BE)),
            ),
          ),
          Text('${_visiblePoints.length} 个示例点', style: const TextStyle(fontSize: 10, color: Color(0xFF77918A))),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF211F19),
        border: Border.all(color: const Color(0xFF49402B)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFE1BD71)),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              '当前路径与穴位位置为界面演示素材，尚未完成专业校勘，不用于诊断、治疗或实际操作指导。',
              style: TextStyle(fontSize: 10, height: 1.5, color: Color(0xFFC6B98F)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewButton extends StatelessWidget {
  const _ViewButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1D3532) : const Color(0xFF121D20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? const Color(0xFF4A8275) : const Color(0xFF28373A)),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: selected ? const Color(0xFFC5E9DD) : const Color(0xFFA8B6B2))),
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
      decoration: BoxDecoration(color: const Color(0xCC0D1719), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFFB5D4C9)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFFD0DDD7))),
        ],
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 14), Text('正在加载本地经络数据')])));
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
              const Icon(Icons.error_outline, size: 36, color: Color(0xFFE1BD71)),
              const SizedBox(height: 12),
              const Text('本地数据加载失败', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.white60)),
            ]),
          ),
        ),
      );
}
