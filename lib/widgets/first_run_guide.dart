import 'package:flutter/material.dart';

import '../theme/atlas_theme.dart';

class FirstRunGuide extends StatefulWidget {
  const FirstRunGuide({super.key, required this.onFinish});

  final VoidCallback onFinish;

  @override
  State<FirstRunGuide> createState() => _FirstRunGuideState();
}

class _FirstRunGuideState extends State<FirstRunGuide> {
  static const _steps = [
    _GuideStep(
      icon: Icons.accessibility_new_rounded,
      title: '先认识人体画布',
      description: '切换正面或背面、男性或女性示意图；双指缩放后可查看标记。轻触穴位可打开介绍页。',
    ),
    _GuideStep(
      icon: Icons.search_rounded,
      title: '搜索、收藏与比较',
      description: '可用中文名、拼音或代码查找穴位，按经络筛选并收藏；选择经络后可打开详情，或进入双经络并排/叠加对比。',
    ),
    _GuideStep(
      icon: Icons.info_outline_rounded,
      title: '请把内容当作学习示意',
      description:
          '人体底图为 AI 生成示意图，穴位定位与路线尚未完成专业校勘。动画仅按演示数据路径顺序播放，不代表生理流向；内容不用于诊断、治疗或实际操作。',
    ),
  ];

  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.atlas;
    final last = _index == _steps.length - 1;
    return Dialog(
      backgroundColor: palette.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: palette.border),
      ),
      child: SizedBox(
        height: 410,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Text('使用指南',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary)),
                  const Spacer(),
                  Text('${_index + 1} / ${_steps.length}',
                      style: TextStyle(fontSize: 11, color: palette.textMuted)),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _steps.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) =>
                      _stepContent(context, _steps[index]),
                ),
              ),
              Row(
                children: [
                  TextButton(
                      onPressed: widget.onFinish, child: const Text('跳过')),
                  const Spacer(),
                  if (_index > 0)
                    TextButton(
                      onPressed: () => _controller.previousPage(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                      ),
                      child: const Text('上一步'),
                    ),
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    onPressed: last
                        ? widget.onFinish
                        : () => _controller.nextPage(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                            ),
                    icon: Icon(
                        last
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                        size: 17),
                    label: Text(last ? '开始探索' : '继续'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepContent(BuildContext context, _GuideStep step) {
    final palette = context.atlas;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: palette.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(step.icon, color: palette.accent, size: 28),
          ),
          const SizedBox(height: 22),
          Text(step.title,
              style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary)),
          const SizedBox(height: 12),
          Text(step.description,
              style: TextStyle(
                  fontSize: 14, height: 1.65, color: palette.textSecondary)),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _steps.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: index == _index ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: index == _index ? palette.accent : palette.border,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideStep {
  const _GuideStep(
      {required this.icon, required this.title, required this.description});

  final IconData icon;
  final String title;
  final String description;
}
