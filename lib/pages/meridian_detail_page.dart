import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/meridian.dart';
import '../theme/atlas_theme.dart';
import 'meridian_compare_page.dart';
import '../widgets/meridian_canvas.dart';

/// 经络详情页：文字说明 + 单经流动演示 + 相关穴位列表。
///
/// 选中穴位后通过 [Navigator.pop] 返回该 [Acupoint]，由首页定位并打开穴位卡片。
class MeridianDetailPage extends StatefulWidget {
  const MeridianDetailPage({
    super.key,
    required this.meridian,
    required this.acupoints,
    required this.favoriteIds,
    this.meridians = const [],
    this.initialView,
    this.figure = 'male',
  });

  final Meridian meridian;

  /// 全部穴位；页面内部按 [Meridian.id] 过滤。
  final List<Acupoint> acupoints;

  /// 全部经络；提供时可从详情页直接进入双经络对比。
  final List<Meridian> meridians;
  final Set<String> favoriteIds;
  final String? initialView;
  final String figure;

  @override
  State<MeridianDetailPage> createState() => _MeridianDetailPageState();
}

class _MeridianDetailPageState extends State<MeridianDetailPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flowController;
  late String _view;
  bool _playing = true;
  bool _reverse = false;

  Meridian get _meridian => widget.meridian;
  bool get _effectiveReverse => (_meridian.direction == 'reverse') != _reverse;

  List<String> get _availableViews {
    final set = <String>{
      ...widget.acupoints
          .where((p) => p.meridianId == _meridian.id)
          .map((p) => p.view),
      ..._meridian.routes.map((route) => route.view),
    };
    final views = [
      for (final v in const ['front', 'back'])
        if (set.contains(v)) v
    ];
    return views.isEmpty ? const ['front'] : views;
  }

  List<Acupoint> get _relatedPoints {
    final points = widget.acupoints
        .where((point) => point.meridianId == _meridian.id)
        .toList();
    points.sort((a, b) => _codeNumber(a.code).compareTo(_codeNumber(b.code)));
    return points;
  }

  /// 穴序号；国标新增穴（如印堂 GV24+）排在 GV24 之后、GV25 之前。
  static double _codeNumber(String code) {
    final match = RegExp(r'(\d+)(\+?)').firstMatch(code);
    if (match == null) return 0;
    return int.parse(match.group(1)!) + (match.group(2)!.isEmpty ? 0 : 0.5);
  }

  @override
  void initState() {
    super.initState();
    final views = _availableViews;
    _view = (widget.initialView != null && views.contains(widget.initialView))
        ? widget.initialView!
        : views.first;
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

  void _togglePlay() {
    HapticFeedback.selectionClick();
    setState(() => _playing = !_playing);
    if (_playing) {
      _flowController.repeat();
    } else {
      _flowController.stop();
    }
  }

  String get _groupLabel {
    switch (_meridian.group) {
      case 'hand':
        return '手经';
      case 'foot':
        return '足经';
      default:
        return '奇经';
    }
  }

  String get _directionLabel => _effectiveReverse ? '数据路径逆序播放' : '数据路径顺序播放';

  void _openCompare() {
    if (widget.meridians.length < 2) return;
    final other =
        widget.meridians.firstWhere((item) => item.id != _meridian.id);
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MeridianComparePage(
        meridians: widget.meridians,
        acupoints: widget.acupoints,
        initialLeftId: _meridian.id,
        initialRightId: other.id,
        figure: widget.figure,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final color = _meridian.color;
    final related = _relatedPoints;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(_meridian.nameZh,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            _buildHeader(color),
            const SizedBox(height: 16),
            _buildDemo(color),
            const SizedBox(height: 22),
            _sectionTitle('经络说明'),
            const SizedBox(height: 10),
            _buildInfoCard(),
            if (widget.meridians.length > 1) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _openCompare,
                icon: const Icon(Icons.compare_arrows_rounded, size: 18),
                label: const Text('与其他经络对比'),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  foregroundColor: color,
                  side: BorderSide(color: color.withOpacity(0.45)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
            const SizedBox(height: 22),
            _sectionTitle('相关穴位', trailing: '${related.length} 个穴位'),
            const SizedBox(height: 10),
            if (related.isEmpty)
              _buildEmptyPoints()
            else
              ...related.map((point) => _buildPointTile(point, color)),
            const SizedBox(height: 16),
            _buildDisclaimer(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color color) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withOpacity(0.16),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Text(_meridian.code,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_meridian.pinyin,
                  style:
                      TextStyle(fontSize: 13, color: context.atlas.textMuted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Tag(label: _groupLabel),
                  if (_meridian.yinYang.isNotEmpty)
                    _Tag(label: _meridian.yinYang),
                  _Tag(
                      label:
                          '${_availableViews.length == 2 ? '正面 + 背面' : (_availableViews.first == 'front' ? '正面' : '背面')}'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDemo(Color color) {
    final views = _availableViews;
    final positionedPoints = _relatedPoints
        .where((point) =>
            point.view == _view && point.positionsFor(widget.figure).isNotEmpty)
        .length;
    final usingRouteFallback = positionedPoints == 0 &&
        _meridian.routes
            .any((route) => route.view == _view && route.points.length > 1);
    return Container(
      height: 360,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.35)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF121619), Color(0xFF121619)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: MeridianCanvas(
                meridians: [_meridian],
                acupoints: _relatedPoints,
                view: _view,
                figure: widget.figure,
                animation: _flowController,
                reverse: _reverse,
                showPoints: true,
                activePointId: null,
                onPointTap: (point) => Navigator.of(context).pop(point),
              ),
            ),
          ),
          if (views.length > 1)
            Positioned(
              left: 12,
              top: 12,
              child: SegmentedButton<String>(
                segments: views
                    .map((view) => ButtonSegment(
                        value: view,
                        label: Text(view == 'front' ? '正面' : '背面')))
                    .toList(),
                selected: {_view},
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                onSelectionChanged: (value) =>
                    setState(() => _view = value.first),
              ),
            )
          else
            Positioned(
              left: 14,
              top: 14,
              child: Text(_view == 'front' ? '正面示意' : '背面示意',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFFB7C9C1))),
            ),
          if (usingRouteFallback)
            Positioned(
              left: 12,
              top: views.length > 1 ? 54 : 40,
              child: const Text(
                '预置示意路径 · 暂无底图穴位定位',
                style: TextStyle(fontSize: 10, color: Color(0xFFD5C39A)),
              ),
            ),
          const Positioned(left: 10, bottom: 10, child: MeridianLineLegend()),
          Positioned(
            right: 10,
            bottom: 10,
            child: Row(
              children: [
                IconButton.filledTonal(
                  tooltip: '切换流动方向',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _reverse = !_reverse);
                  },
                  icon: const Icon(Icons.swap_vert_rounded, size: 18),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  tooltip: _playing ? '暂停' : '播放',
                  onPressed: _togglePlay,
                  icon: Icon(_playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: const Color(0xFF10201D),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 14,
            bottom: 16,
            child: Text(_reverse ? '已切换 · $_directionLabel' : _directionLabel,
                style: TextStyle(
                    fontSize: 10, color: Colors.white.withOpacity(0.5))),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final palette = context.atlas;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _meridian.summary.isEmpty ? '暂无经专业审校的说明文字。' : _meridian.summary,
            style: TextStyle(
                fontSize: 13, height: 1.6, color: palette.textPrimary),
          ),
          const SizedBox(height: 12),
          _infoRow('国际代码', _meridian.code),
          _infoRow('分类', '$_groupLabel · ${_meridian.yinYang}'),
          _infoRow('资料来源', _meridian.source.isEmpty ? '未标注' : _meridian.source),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    final palette = context.atlas;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(label,
                style: TextStyle(fontSize: 11, color: palette.textMuted)),
          ),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: palette.textSecondary))),
        ],
      ),
    );
  }

  Widget _buildPointTile(Acupoint point, Color color) {
    final palette = context.atlas;
    final isFavorite = widget.favoriteIds.contains(point.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop(point);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Row(
              children: [
                Container(
                    width: 9,
                    height: 9,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${point.nameZh}  ${point.code}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                          '${point.pinyin} · ${point.view == 'front' ? '正面' : '背面'}',
                          style: TextStyle(
                              fontSize: 10, color: palette.textMuted)),
                    ],
                  ),
                ),
                if (isFavorite)
                  const Icon(Icons.star_rounded,
                      size: 16, color: Color(0xFFE2C66E)),
                const SizedBox(width: 6),
                Icon(Icons.my_location_rounded,
                    size: 16, color: palette.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPoints() {
    final palette = context.atlas;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: palette.surface, borderRadius: BorderRadius.circular(14)),
      child: Text('这条经络暂未录入穴位。',
          style: TextStyle(fontSize: 12, color: palette.textSecondary)),
    );
  }

  Widget _buildDisclaimer() {
    final palette = context.atlas;
    return Text(
      '路径与穴位位置为界面演示数据，尚未完成教材校勘；流动动画仅按数据路径顺序播放，不代表生理流向。仅供学习参考，不用于诊断、治疗或实际操作。',
      style: TextStyle(fontSize: 10, height: 1.5, color: palette.textMuted),
    );
  }

  Widget _sectionTitle(String title, {String? trailing}) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const Spacer(),
        if (trailing != null)
          Text(trailing,
              style: const TextStyle(fontSize: 11, color: Color(0xFF91AAA3))),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.atlas;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: palette.textSecondary)),
    );
  }
}
