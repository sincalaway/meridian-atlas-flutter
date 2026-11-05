import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/meridian.dart';
import '../widgets/meridian_canvas.dart';

enum CompareLayout { sideBySide, overlay }

/// 对比模式：同时查看两条经络，共用一个动画时钟，可并排或叠加显示。
class MeridianComparePage extends StatefulWidget {
  const MeridianComparePage({
    super.key,
    required this.meridians,
    required this.acupoints,
    this.initialLeftId,
    this.initialRightId,
  });

  final List<Meridian> meridians;
  final List<Acupoint> acupoints;
  final String? initialLeftId;
  final String? initialRightId;

  /// 对照表的行：标签 + 两侧取值。纯函数，便于测试。
  static List<(String, String, String)> comparisonRows(
    Meridian a,
    Meridian b,
    List<Acupoint> acupoints,
  ) {
    String group(Meridian m) => switch (m.group) { 'hand' => '手经', 'foot' => '足经', _ => '奇经' };
    String views(Meridian m) {
      final set = m.routes.map((r) => r.view).toSet();
      return [if (set.contains('front')) '正面', if (set.contains('back')) '背面'].join(' / ');
    }
    String pointCount(Meridian m) => '${acupoints.where((p) => p.meridianId == m.id).length}';
    return [
      ('国际代码', a.code, b.code),
      ('拼音', a.pinyin, b.pinyin),
      ('手足分类', group(a), group(b)),
      ('阴阳', a.yinYang, b.yinYang),
      ('路径段数', '${a.routes.length}', '${b.routes.length}'),
      ('路径所在面', views(a), views(b)),
      ('示例穴位', pointCount(a), pointCount(b)),
    ];
  }

  @override
  State<MeridianComparePage> createState() => _MeridianComparePageState();
}

class _MeridianComparePageState extends State<MeridianComparePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flowController;
  late String _leftId;
  late String _rightId;
  String _view = 'front';
  CompareLayout _layout = CompareLayout.sideBySide;
  bool _playing = true;
  bool _showPoints = true;

  @override
  void initState() {
    super.initState();
    final ids = widget.meridians.map((m) => m.id).toList();
    _leftId = (widget.initialLeftId != null && ids.contains(widget.initialLeftId))
        ? widget.initialLeftId!
        : ids.first;
    final rightCandidate = widget.initialRightId;
    _rightId = (rightCandidate != null && ids.contains(rightCandidate) && rightCandidate != _leftId)
        ? rightCandidate
        : ids.firstWhere((id) => id != _leftId, orElse: () => _leftId);
    _view = _preferredView();
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    _flowController.dispose();
    super.dispose();
  }

  Meridian _byId(String id) => widget.meridians.firstWhere((m) => m.id == id);
  Meridian get _left => _byId(_leftId);
  Meridian get _right => _byId(_rightId);

  static bool hasView(Meridian meridian, String view) =>
      meridian.routes.any((route) => route.view == view);

  /// 优先选两条经络都有路径的视图，其次选任一有路径的视图。
  String _preferredView() {
    for (final view in const ['front', 'back']) {
      if (hasView(_left, view) && hasView(_right, view)) return view;
    }
    for (final view in const ['front', 'back']) {
      if (hasView(_left, view) || hasView(_right, view)) return view;
    }
    return 'front';
  }

  List<Acupoint> _pointsFor(Iterable<String> meridianIds) {
    final ids = meridianIds.toSet();
    return widget.acupoints
        .where((point) => point.view == _view && ids.contains(point.meridianId))
        .toList();
  }

  void _pick({required bool left, required String id}) {
    HapticFeedback.selectionClick();
    setState(() {
      if (left) {
        if (id == _rightId) _rightId = _leftId;
        _leftId = id;
      } else {
        if (id == _leftId) _leftId = _rightId;
        _rightId = id;
      }
      if (!hasView(_left, _view) && !hasView(_right, _view)) _view = _preferredView();
    });
  }

  void _swap() {
    HapticFeedback.selectionClick();
    setState(() {
      final temp = _leftId;
      _leftId = _rightId;
      _rightId = temp;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('经络对比', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            _buildPickers(),
            const SizedBox(height: 14),
            _buildToolbar(),
            const SizedBox(height: 12),
            _layout == CompareLayout.sideBySide ? _buildSideBySide() : _buildOverlay(),
            const SizedBox(height: 22),
            const Text('属性对照', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            _buildComparisonTable(),
            const SizedBox(height: 16),
            Text(
              '路径与穴位为界面演示数据，尚未完成教材校勘，仅供学习参考。',
              style: TextStyle(fontSize: 10, height: 1.5, color: Colors.white.withOpacity(0.4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickers() {
    return Row(
      children: [
        Expanded(child: _picker(left: true)),
        IconButton(
          tooltip: '交换',
          onPressed: _swap,
          icon: const Icon(Icons.swap_horiz_rounded),
          color: const Color(0xFFB6C8C2),
        ),
        Expanded(child: _picker(left: false)),
      ],
    );
  }

  Widget _picker({required bool left}) {
    final current = left ? _left : _right;
    return DropdownButtonFormField<String>(
      key: ValueKey(left ? 'compare-left' : 'compare-right'),
      value: current.id,
      isExpanded: true,
      icon: const Icon(Icons.expand_more_rounded, size: 18),
      dropdownColor: const Color(0xFF172326),
      style: const TextStyle(fontSize: 12, color: Color(0xFFD8E3DE)),
      decoration: InputDecoration(
        labelText: left ? '经络 A' : '经络 B',
        labelStyle: const TextStyle(fontSize: 11, color: Color(0xFF92A69F)),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(14),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: current.color, shape: BoxShape.circle),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        filled: true,
        fillColor: const Color(0xFF121D20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: current.color.withOpacity(0.45)),
        ),
      ),
      items: widget.meridians
          .map((m) => DropdownMenuItem(
                value: m.id,
                child: Text('${m.nameZh} ${m.code}', overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (value) {
        if (value != null) _pick(left: left, id: value);
      },
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'front', label: Text('正面')),
            ButtonSegment(value: 'back', label: Text('背面')),
          ],
          selected: {_view},
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          onSelectionChanged: (value) => setState(() => _view = value.first),
        ),
        const Spacer(),
        IconButton(
          tooltip: _layout == CompareLayout.sideBySide ? '叠加显示' : '并排显示',
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() => _layout =
                _layout == CompareLayout.sideBySide ? CompareLayout.overlay : CompareLayout.sideBySide);
          },
          icon: Icon(_layout == CompareLayout.sideBySide ? Icons.layers_outlined : Icons.view_column_outlined),
          color: const Color(0xFFB6C8C2),
        ),
        IconButton(
          tooltip: _showPoints ? '隐藏穴位' : '显示穴位',
          onPressed: () => setState(() => _showPoints = !_showPoints),
          icon: Icon(_showPoints ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 20),
          color: const Color(0xFFB6C8C2),
        ),
        IconButton.filled(
          tooltip: _playing ? '暂停' : '播放',
          onPressed: _togglePlay,
          icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF72D6C2),
            foregroundColor: const Color(0xFF10201D),
          ),
        ),
      ],
    );
  }

  Widget _canvasFrame({required List<Meridian> meridians, required Color border, required double height, String? caption}) {
    final visible = meridians.where((m) => hasView(m, _view)).toList();
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF172326), Color(0xFF10191C)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _flowController,
                builder: (context, _) => MeridianCanvas(
                  meridians: meridians,
                  acupoints: _pointsFor(meridians.map((m) => m.id)),
                  view: _view,
                  progress: _flowController.value,
                  reverse: false,
                  showPoints: _showPoints,
                  activePointId: null,
                  onTapDown: (_) {},
                ),
              ),
            ),
          ),
          if (caption != null)
            Positioned(
              left: 10,
              top: 10,
              child: Text(caption, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFD0DDD7))),
            ),
          if (visible.length < meridians.length)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Text(
                '${meridians.where((m) => !hasView(m, _view)).map((m) => m.nameZh).join('、')}在此面无路径数据',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSideBySide() {
    return Row(
      children: [
        Expanded(
          child: _canvasFrame(
            meridians: [_left],
            border: _left.color.withOpacity(0.45),
            height: 320,
            caption: _left.code,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _canvasFrame(
            meridians: [_right],
            border: _right.color.withOpacity(0.45),
            height: 320,
            caption: _right.code,
          ),
        ),
      ],
    );
  }

  Widget _buildOverlay() {
    return Column(
      children: [
        _canvasFrame(meridians: [_left, _right], border: const Color(0xFF26383A), height: 380),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legend(_left),
            const SizedBox(width: 16),
            _legend(_right),
          ],
        ),
      ],
    );
  }

  Widget _legend(Meridian meridian) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 3, color: meridian.color),
        const SizedBox(width: 6),
        Text(meridian.nameZh, style: const TextStyle(fontSize: 11, color: Color(0xFFBFCDC7))),
      ],
    );
  }

  Widget _buildComparisonTable() {
    final rows = MeridianComparePage.comparisonRows(_left, _right, widget.acupoints);
    TextStyle head(Color c) => TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c);
    const label = TextStyle(fontSize: 11, color: Color(0xFF8EA39C));
    const cell = TextStyle(fontSize: 12, color: Color(0xFFD5E2DD));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF121D20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF223236)),
      ),
      child: Table(
        columnWidths: const {0: FlexColumnWidth(1.1), 1: FlexColumnWidth(1.4), 2: FlexColumnWidth(1.4)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(children: [
            const SizedBox(height: 34),
            Text(_left.nameZh, style: head(_left.color)),
            Text(_right.nameZh, style: head(_right.color)),
          ]),
          ...rows.map((row) {
            final same = row.$2 == row.$3;
            return TableRow(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF1E2C2F)))),
              children: [
                Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Text(row.$1, style: label)),
                Text(row.$2, style: cell),
                Text(row.$3, style: same ? cell : cell.copyWith(color: const Color(0xFFE8D58F))),
              ],
            );
          }),
        ],
      ),
    );
  }
}
