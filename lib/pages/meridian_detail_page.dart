import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/meridian.dart';
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
    this.initialView,
  });

  final Meridian meridian;

  /// 全部穴位；页面内部按 [Meridian.id] 过滤。
  final List<Acupoint> acupoints;
  final Set<String> favoriteIds;
  final String? initialView;

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

  List<String> get _availableViews {
    final views = <String>[];
    for (final route in _meridian.routes) {
      if (!views.contains(route.view)) views.add(route.view);
    }
    return views.isEmpty ? const ['front'] : views;
  }

  List<Acupoint> get _relatedPoints {
    final points = widget.acupoints
        .where((point) => point.meridianId == _meridian.id)
        .toList();
    points.sort((a, b) => _codeNumber(a.code).compareTo(_codeNumber(b.code)));
    return points;
  }

  static int _codeNumber(String code) {
    final match = RegExp(r'(\d+)').firstMatch(code);
    return match == null ? 0 : int.parse(match.group(1)!);
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

  String get _directionLabel =>
      _meridian.direction == 'reverse' ? '数据路径逆序流动' : '数据路径顺序流动';

  @override
  Widget build(BuildContext context) {
    final color = _meridian.color;
    final related = _relatedPoints;
    final viewPoints = related.where((point) => point.view == _view).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(_meridian.nameZh, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            _buildHeader(color),
            const SizedBox(height: 16),
            _buildDemo(color, viewPoints),
            const SizedBox(height: 22),
            _sectionTitle('经络说明'),
            const SizedBox(height: 10),
            _buildInfoCard(),
            const SizedBox(height: 22),
            _sectionTitle('相关穴位', trailing: '${related.length} 个穴位'),
            const SizedBox(height: 10),
            if (related.isEmpty) _buildEmptyPoints() else ...related.map((point) => _buildPointTile(point, color)),
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
          child: Text(_meridian.code, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_meridian.pinyin, style: const TextStyle(fontSize: 13, color: Color(0xFFA8BDB5))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Tag(label: _groupLabel),
                  if (_meridian.yinYang.isNotEmpty) _Tag(label: _meridian.yinYang),
                  _Tag(label: '${_meridian.routes.length} 段路径'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDemo(Color color, List<Acupoint> viewPoints) {
    final views = _availableViews;
    return Container(
      height: 360,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.35)),
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
                  meridians: [_meridian],
                  acupoints: viewPoints,
                  view: _view,
                  progress: _flowController.value,
                  reverse: _reverse,
                  showPoints: true,
                  activePointId: null,
                  onTapDown: (_) {},
                ),
              ),
            ),
          ),
          if (views.length > 1)
            Positioned(
              left: 12,
              top: 12,
              child: SegmentedButton<String>(
                segments: views
                    .map((view) => ButtonSegment(value: view, label: Text(view == 'front' ? '正面' : '背面')))
                    .toList(),
                selected: {_view},
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                onSelectionChanged: (value) => setState(() => _view = value.first),
              ),
            )
          else
            Positioned(
              left: 14,
              top: 14,
              child: Text(_view == 'front' ? '正面示意' : '背面示意',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFB7C9C1))),
            ),
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
                  icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
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
            child: Text(_reverse ? '反向演示' : _directionLabel,
                style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5))),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF121D20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF223236)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _meridian.summary.isEmpty ? '暂无经专业审校的说明文字。' : _meridian.summary,
            style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFFD0DAD5)),
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
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.45))),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 11, height: 1.45, color: Color(0xFFBFCDC7)))),
        ],
      ),
    );
  }

  Widget _buildPointTile(Acupoint point, Color color) {
    final isFavorite = widget.favoriteIds.contains(point.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFF131E21),
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
                Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${point.nameZh}  ${point.code}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('${point.pinyin} · ${point.view == 'front' ? '正面' : '背面'}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF91AAA3))),
                    ],
                  ),
                ),
                if (isFavorite) const Icon(Icons.star_rounded, size: 16, color: Color(0xFFE2C66E)),
                const SizedBox(width: 6),
                const Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF83958F)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPoints() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF121D20), borderRadius: BorderRadius.circular(14)),
      child: const Text('这条经络暂未录入穴位。', style: TextStyle(fontSize: 12, color: Color(0xFFB5C4BE))),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      '路径与穴位为界面演示数据，尚未完成教材校勘，仅供学习参考，不用于诊断或治疗。',
      style: TextStyle(fontSize: 10, height: 1.5, color: Colors.white.withOpacity(0.4)),
    );
  }

  Widget _sectionTitle(String title, {String? trailing}) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const Spacer(),
        if (trailing != null) Text(trailing, style: const TextStyle(fontSize: 11, color: Color(0xFF91AAA3))),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2729),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2C3D40)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFFBFD0CA))),
    );
  }
}
