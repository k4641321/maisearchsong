import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/palette.dart';
import '../core/rating.dart';
import '../widgets/common.dart';

/// 单曲 Rating 计算器 + 容错计算。
class RatingCalcPage extends StatefulWidget {
  const RatingCalcPage({super.key, this.initialTab = 0});

  /// 初始标签页（0 计算器 / 1 容错）。
  final int initialTab;

  @override
  State<RatingCalcPage> createState() => _RatingCalcPageState();
}

class _RatingCalcPageState extends State<RatingCalcPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 2,
    initialIndex: widget.initialTab,
    vsync: this,
  );

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('计算工具'),
      bottom: TabBar(
        controller: _tabs,
        tabs: const [
          Tab(text: '焦 Rating 计算器'),
          Tab(text: '容错计算'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabs,
      children: const [_SingleRatingTab(), _FaultToleranceTab()],
    ),
  );
}

/// 单谱 Rating 计算器。
class _SingleRatingTab extends StatefulWidget {
  const _SingleRatingTab();

  @override
  State<_SingleRatingTab> createState() => _SingleRatingTabState();
}

class _SingleRatingTabState extends State<_SingleRatingTab> {
  final TextEditingController _constant = TextEditingController(text: '14.0');
  final TextEditingController _achievements = TextEditingController(
    text: '100.0000',
  );
  double _constantValue = 14;
  double _achievementsValue = 100;

  @override
  void dispose() {
    _constant.dispose();
    _achievements.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rating = RatingCalculator.singleRating(
      _constantValue,
      _achievementsValue,
    );
    final floor = rating.floor();
    final rate = RateType.fromAchievements(_achievementsValue);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        TextField(
          controller: _constant,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '谱面定数',
            hintText: '例如 14.0',
          ),
          onChanged: (value) => setState(
            () => _constantValue = double.tryParse(value) ?? _constantValue,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _achievements,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '达成率（%）',
            hintText: '例如 100.5000',
          ),
          onChanged: (value) => setState(
            () =>
                _achievementsValue = double.tryParse(value) ?? _achievementsValue,
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '单谱 Rating',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$floor',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppPalette.seed,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '（${rating.toStringAsFixed(2)} 向下取整）',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    RateBadge(
                      label: RateType.labelOf(rate),
                      color: RatePalette.of(rate),
                    ),
                    RateBadge(
                      label: '系数 ×${RatingCalculator.coefficientOf(_achievementsValue)}',
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '系数速查（该定数下各达成率对应的单谱 Rating）',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                for (final row in const [
                  ('SSS+', 100.5),
                  ('SSS', 100.0),
                  ('SS+', 99.5),
                  ('SS', 99.0),
                  ('S+', 98.0),
                  ('S', 97.0),
                  ('AAA', 94.0),
                  ('AA', 90.0),
                  ('A', 80.0),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 46,
                          child: Text(
                            row.$1,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: Text('${row.$2.toStringAsFixed(1)}%'),
                        ),
                        Text(
                          '${RatingCalculator.floorSingleRating(_constantValue, row.$2)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 容错计算：按物量推算 AP / FC / SSS 允许的失误。
class _FaultToleranceTab extends StatefulWidget {
  const _FaultToleranceTab();

  @override
  State<_FaultToleranceTab> createState() => _FaultToleranceTabState();
}

class _FaultToleranceTabState extends State<_FaultToleranceTab> {
  final TextEditingController _total = TextEditingController(text: '1000');
  int _totalValue = 1000;

  @override
  void dispose() {
    _total.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalValue.clamp(1, 100000);
    // 舞萌 DX 中 TAP/HOLD/SLIDE/TOUCH 基础分 500，BREAK 基础分 2500 且占 1/5 权重。
    // 这里按「BREAK 约占总数 1/6、其余平均」的常见分布做保守估算。
    final breakCount = (total / 6).floor();
    final normalCount = total - breakCount;

    final rows = <(String, String)>[
      ('AP（理论值）', '100.5000%　不允许任何失误'),
      ('SSS', '100.0000%　任何 1 个非 BREAK 失误都会掉到 99.9% 以下'),
      ('SSS 安全线', '允许约 ${_allowed(total, 0.0)} 个非 BREAK 失误'),
      ('SS+', '允许约 ${_allowed(total, 0.5)} 个非 BREAK 失误'),
      ('SS', '允许约 ${_allowed(total, 1.0)} 个非 BREAK 失误'),
      ('S+', '允许约 ${_allowed(total, 2.0)} 个非 BREAK 失误'),
      ('S', '允许约 ${_allowed(total, 3.0)} 个非 BREAK 失误'),
      ('FC 允许 1 次 MISS', '约 ${_allowed(total, 0.0) + 1} 个判定失误'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        TextField(
          controller: _total,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '谱面总物量',
            hintText: '从谱面信息里的 total 读取',
          ),
          onChanged: (value) =>
              setState(() => _totalValue = int.tryParse(value) ?? _totalValue),
        ),
        const SizedBox(height: 8),
        Text(
          '估算分布：TAP/HOLD/SLIDE/TOUCH 共 $normalCount 个（500 分），'
          'BREAK 约 $breakCount 个（2500 分，占 1/5 权重）。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              for (final row in rows)
                ListTile(
                  dense: true,
                  title: Text(row.$1),
                  subtitle: Text(row.$2),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '容错仅作参考：BREAK 的分数权重更高，实际失误位置会影响结果。',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  /// 按达成率下限推算允许的失误数（单次失误损失约 0.1% / 500 分）。
  int _allowed(int total, double tolerance) {
    final loss = total * 0.001;
    if (loss <= 0) return 0;
    return (tolerance / 0.1 * total / 100).floor() == 0
        ? 0
        : ((tolerance / 0.1) * (total / 100)).floor();
  }
}
