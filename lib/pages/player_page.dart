import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_state.dart';
import '../core/constants.dart';
import '../core/palette.dart';
import '../core/rating.dart';
import '../models/models.dart';
import '../services/b50_image_renderer.dart';
import '../widgets/common.dart';
import '../widgets/song_widgets.dart';
import 'b50_image_page.dart';
import 'song_info_page.dart';

/// 玩家查询页：概览 / 吃分建议 / Rating 趋势。
///
/// 使用个人 Token 查询 Token 所属玩家自己的数据。
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, this.initialTab = 0});

  /// 初始标签页。
  final int initialTab;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage>
    with SingleTickerProviderStateMixin {
  final AppState _state = AppState.instance;
  late final TabController _tabs = TabController(
    length: 3,
    initialIndex: widget.initialTab,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _state.addListener(_onChanged);
    // 已设置个人 Token 且未加载过玩家时自动拉一次。
    if (_state.player == null &&
        (_state.settings.userToken?.trim().isNotEmpty ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _query());
    }
  }

  @override
  void dispose() {
    _state.removeListener(_onChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _query() async {
    await _state.loadPlayer();
    if (!mounted) return;
    final error = _state.error;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = _state.player;
    return Scaffold(
      appBar: AppBar(
        title: const Text('玩家查询'),
        actions: [
          if (player != null)
            IconButton(
              key: const Key('regular-b50-image-button'),
              tooltip: '生成 Best 50 图片',
              icon: const Icon(Icons.photo_library_rounded),
              onPressed: () {
                final bests = _state.bests;
                if (bests == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请先加载 Best 50 数据')),
                  );
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => B50ImagePage(
                      document: B50ImageDocument.regular(
                        bests: bests,
                        player: player,
                        songById: _state.songById,
                      ),
                    ),
                  ),
                );
              },
            ),
          if (player != null)
            IconButton(
              tooltip: '在落雪查看',
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: () => launchUrl(
                Uri.parse(
                  '${AppInfo.lxnsWeb}/maimai/player/${player.friendCode}',
                ),
                mode: LaunchMode.externalApplication,
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: '概览'),
            Tab(text: '吃分建议'),
            Tab(text: 'Rating 趋势'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _state.player != null
                        ? '已绑定 ${_state.player!.name}（个人 Token）'
                        : '使用个人 Token 查询自己的成绩',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _state.loading ? null : _query,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('刷新'),
                ),
              ],
            ),
          ),
          if (_state.loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _OverviewTab(player: player),
                _SuggestionTab(player: player),
                _TrendTab(player: player),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 概览：玩家信息卡 + Best 35 / Best 15。
class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.player});

  final Player? player;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final bests = state.bests;
    if (player == null) {
      return StateView(
        error: state.error,
        empty: true,
        emptyIcon: Icons.person_search_rounded,
        emptyText: '设置个人 Token 后查询自己的成绩',
        onRetry: () => state.loadPlayer(),
        child: const SizedBox.shrink(),
      );
    }
    if (bests == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        _PlayerCard(player: player!),
        _SectionHeader(
          'Standard Best 35',
          trailing: '小计 ${bests.standardTotal}',
        ),
        for (var i = 0; i < bests.standard.length; i++)
          _ScoreRow(score: bests.standard[i], rank: i + 1),
        _SectionHeader('DX Best 15', trailing: '小计 ${bests.dxTotal}'),
        for (var i = 0; i < bests.dx.length; i++)
          _ScoreRow(score: bests.dx[i], rank: i + 1),
        if (bests.standardSelections.isNotEmpty ||
            bests.dxSelections.isNotEmpty) ...[
          const _SectionHeader('候选谱面', trailing: '用于替补的下一档'),
          for (final s in [...bests.standardSelections, ...bests.dxSelections])
            _ScoreRow(score: s),
        ],
      ],
    );
  }
}

/// 玩家信息卡。
class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trophyColor = TrophyPalette.of(player.trophy?.color);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    Utils.collectionUrl('icon', player.icon?.id ?? 1),
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 58,
                      height: 58,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.person_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          RateBadge(
                            label: 'RATING ${player.rating}',
                            color: theme.colorScheme.primary,
                          ),
                          if (player.trophy != null)
                            RateBadge(
                              label: player.trophy!.name,
                              color: trophyColor,
                            ),
                          RateBadge(
                            label: '★${player.star}',
                            color: Colors.amber.shade600,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(label: '好友码', value: '${player.friendCode}'),
                _Chip(label: '段位', value: '${player.classRank}'),
                _Chip(label: '课程', value: '${player.courseRank}'),
                if (player.namePlate != null)
                  _Chip(label: '姓名框', value: player.namePlate!.name),
                if (player.frame != null)
                  _Chip(label: '背景', value: player.frame!.name),
                if (player.uploadTime.isNotEmpty)
                  _Chip(label: '更新于', value: player.uploadTime),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label $value', style: theme.textTheme.labelSmall),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
    child: Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppPalette.seed,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(trailing!, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.score, this.rank});

  final Score score;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final song = AppState.instance.songById(score.id);
    return ScoreTile(
      score: score,
      song: song,
      rank: rank,
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => SongInfoPage(songId: score.id))),
    );
  }
}

/// 吃分建议：单谱 Rating 从低到高，指出收益最大的谱面。
class _SuggestionTab extends StatelessWidget {
  const _SuggestionTab({required this.player});

  final Player? player;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final bests = state.bests;
    if (player == null || bests == null) {
      return const StateView(
        empty: true,
        emptyIcon: Icons.emoji_events_rounded,
        emptyText: '先查询玩家成绩，再查看吃分建议',
        child: SizedBox.shrink(),
      );
    }

    final entries = <(_SuggestionItem, int)>[];
    for (final score in bests.all) {
      final song = state.songById(score.id);
      final difficulty = song?.difficultyOf(score.type, score.levelIndex);
      if (difficulty == null) continue;
      final current = RatingCalculator.ratingOfScore(
        difficulty,
        score.achievements,
      );
      final constant = RatingCalculator.constantOf(difficulty);
      // 推到 100.5% 的收益上限。
      final best = RatingCalculator.floorSingleRating(constant, 100.5);
      entries.add((
        _SuggestionItem(score: score, difficulty: difficulty, current: current),
        best - current,
      ));
    }
    entries.sort((a, b) => b.$2.compareTo(a.$2));

    if (entries.isEmpty) {
      return const StateView(
        empty: true,
        emptyText: '曲库尚未载入，无法计算',
        child: SizedBox.shrink(),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 6, bottom: 40),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 10, 18, 2),
          child: Text(
            '按「推到 100.5% 的 Rating 增益」排序，优先打收益最高的谱面。',
            style: TextStyle(fontSize: 12),
          ),
        ),
        for (final entry in entries.take(50))
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Jacket(songId: entry.$1.score.id, size: 48, radius: 8),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.$1.score.songName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${entry.$1.difficulty.displayLevel}'
                          ' ${entry.$1.difficulty.level}'
                          '　定数 ${entry.$1.difficulty.levelValue.toStringAsFixed(1)}'
                          '　当前 ${entry.$1.current}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  RateBadge(
                    label: '+${entry.$2}',
                    color: entry.$2 > 0
                        ? const Color(0xFF66BB6A)
                        : Theme.of(context).colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SuggestionItem {
  const _SuggestionItem({
    required this.score,
    required this.difficulty,
    required this.current,
  });

  final Score score;
  final SongDifficulty difficulty;
  final int current;
}

/// Rating 趋势折线图。
class _TrendTab extends StatelessWidget {
  const _TrendTab({required this.player});

  final Player? player;

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final trend = state.trend;
    if (player == null) {
      return const StateView(
        empty: true,
        emptyIcon: Icons.insights_rounded,
        emptyText: '先查询玩家，再查看 Rating 趋势',
        child: SizedBox.shrink(),
      );
    }
    if (trend.isEmpty) {
      return const StateView(
        empty: true,
        emptyIcon: Icons.show_chart_rounded,
        emptyText: '该玩家还没有可用的 Rating 趋势数据',
        child: SizedBox.shrink(),
      );
    }

    final points = trend.length > 40 ? trend.sublist(trend.length - 40) : trend;
    final values = points.map((e) => e.total.toDouble()).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final padding = ((maxValue - minValue) * 0.2).clamp(10, 400).toDouble();

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 40),
      children: [
        SizedBox(
          height: 260,
          child: LineChart(
            LineChartData(
              minY: minValue - padding,
              maxY: maxValue + padding,
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 48),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: (points.length / 4).ceilToDouble().clamp(1, 99),
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= points.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          points[index].date,
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots
                      .map(
                        (s) => LineTooltipItem(
                          '${points[s.x.toInt()].date}\n'
                          '总 ${points[s.x.toInt()].total}',
                          const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < values.length; i++)
                      FlSpot(i.toDouble(), values[i]),
                  ],
                  isCurved: true,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  color: Theme.of(context).colorScheme.primary,
                  belowBarData: BarAreaData(
                    show: true,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.16),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final point in points.reversed.take(12))
          ListTile(
            dense: true,
            leading: const Icon(Icons.calendar_today_rounded, size: 18),
            title: Text(point.date),
            trailing: Text(
              '总 ${point.total}　旧 ${point.standardTotal}　新 ${point.dxTotal}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: point.date));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已复制日期')));
            },
          ),
      ],
    );
  }
}

