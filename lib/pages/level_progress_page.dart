import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/constants.dart';
import '../core/palette.dart';
import '../core/rating.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'song_info_page.dart';

/// 等级完成进度页：选择标级区间，统计玩家在该等级段所有谱面的完成情况。
class LevelProgressPage extends StatefulWidget {
  const LevelProgressPage({super.key});

  @override
  State<LevelProgressPage> createState() => _LevelProgressPageState();
}

/// 标级（含 `+`），如 `13` / `13+`。
class _LevelKey implements Comparable<_LevelKey> {
  const _LevelKey(this.base, this.plus);

  /// 整数部分。
  final int base;

  /// 是否为 `+`。
  final bool plus;

  factory _LevelKey.parse(String level) {
    final text = level.trim();
    final hasPlus = text.endsWith('+');
    final digits = hasPlus ? text.substring(0, text.length - 1) : text;
    return _LevelKey(int.tryParse(digits) ?? 0, hasPlus);
  }

  String get label => '$base${plus ? '+' : ''}';

  /// 对应定数区间（与 RatingCalculator 标级表一致）。
  double get constant => RatingCalculator.levelToConstant(label);

  @override
  int compareTo(_LevelKey other) {
    final byBase = base.compareTo(other.base);
    if (byBase != 0) return byBase;
    if (plus == other.plus) return 0;
    return plus ? 1 : -1;
  }

  @override
  bool operator ==(Object other) =>
      other is _LevelKey && other.base == base && other.plus == plus;

  @override
  int get hashCode => Object.hash(base, plus);

  @override
  String toString() => label;
}

class _LevelProgressPageState extends State<LevelProgressPage> {
  final AppState _state = AppState.instance;

  List<SimpleScore> _scores = const [];
  bool _loading = false;
  String? _error;
  bool _queried = false;

  /// 当前选中的标级（null = 显示总览）。
  _LevelKey? _selected;

  @override
  void initState() {
    super.initState();
    if (_state.player != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _query());
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _query() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _state.api.fetchAllScores();
      if (!mounted) return;
      setState(() {
        _scores = raw
            .whereType<Map>()
            .map((e) => SimpleScore.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _queried = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 以 (id, type, levelIndex) 建立成绩索引。
  Map<String, SimpleScore> get _scoreIndex => {
    for (final s in _scores) '${s.id}:${s.type.value}:${s.levelIndex}': s,
  };

  /// 收集曲库中该标级的全部谱面（非宴会）。
  List<(Song, SongDifficulty, SimpleScore?)> _chartsOf(_LevelKey key) {
    final index = _scoreIndex;
    final out = <(Song, SongDifficulty, SimpleScore?)>[];
    for (final song in _state.songs) {
      for (final d in song.allDifficulties) {
        if (d.type == SongType.utage) continue;
        if (_LevelKey.parse(d.level) != key) continue;
        out.add((song, d, index['${song.id}:${d.type.value}:${d.difficulty}']));
      }
    }
    out.sort((a, b) => a.$1.id.compareTo(b.$1.id));
    return out;
  }

  /// 曲库中出现过哪些标级。
  List<_LevelKey> get _allLevels {
    final set = <_LevelKey>{};
    for (final song in _state.songs) {
      for (final d in song.allDifficulties) {
        if (d.type == SongType.utage) continue;
        set.add(_LevelKey.parse(d.level));
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final levels = _allLevels;

    return Scaffold(
      appBar: AppBar(title: const Text('等级完成进度')),
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
                        : '使用个人 Token 拉取自己的成绩',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _loading ? null : _query,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('刷新'),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: StateView(
              loading: _loading && _scores.isEmpty,
              error: _scores.isEmpty ? _error : null,
              onRetry: _query,
              empty: _scores.isEmpty,
              emptyText: _queried
                  ? '你还没有成绩'
                  : '点击刷新统计等级完成进度（曲库谱面 + 玩家成绩）',
              emptyIcon: Icons.stairs_rounded,
              child: Builder(
                builder: (context) {
                  final selected = _selected;
                  if (selected == null) {
                    return _buildOverview(theme, levels);
                  }
                  final charts = _chartsOf(selected);
                  final byRate = <String, int>{};
                  for (final chart in charts) {
                    final score = chart.$3;
                    if (score == null) continue;
                    final rate = score.rate ?? '';
                    byRate[rate] = (byRate[rate] ?? 0) + 1;
                  }
                  return _buildLevelDetail(theme, selected, charts, byRate);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 总览：每个标级一行进度条。
  Widget _buildOverview(ThemeData theme, List<_LevelKey> levels) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 30),
      itemCount: levels.length,
      itemBuilder: (context, index) {
        final key = levels[index];
        final charts = _chartsOf(key);
        final done = charts.where((e) => e.$3 != null).length;
        final ratio = charts.isEmpty ? 0.0 : done / charts.length;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _selected = key),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      key.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: 8,
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 8,
                              backgroundColor: theme
                                  .colorScheme
                                  .surfaceContainerHighest,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$done / ${charts.length}　${(ratio * 100).toStringAsFixed(1)}%',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 详情：该标级的全部谱面与成绩。
  Widget _buildLevelDetail(
    ThemeData theme,
    _LevelKey key,
    List<(Song, SongDifficulty, SimpleScore?)> charts,
    Map<String, int> byRate,
  ) {
    final done = charts.where((e) => e.$3 != null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _selected = null),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('返回总览'),
              ),
              const Spacer(),
              Text(
                '$key　完成 $done / ${charts.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final entry in const [
                ('sssp', 'SSS+'),
                ('sss', 'SSS'),
                ('ssp', 'SS+'),
                ('ss', 'SS'),
                ('sp', 'S+'),
                ('s', 'S'),
              ])
                if ((byRate[entry.$1] ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: RateBadge(
                      label: '${entry.$2} ×${byRate[entry.$1]}',
                      color: RatePalette.of(entry.$1),
                    ),
                  ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 30),
            itemCount: charts.length,
            itemBuilder: (context, index) {
              final (song, d, score) = charts[index];
              return _ChartRow(
                song: song,
                difficulty: d,
                score: score,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SongInfoPage(songId: song.id),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 谱面行：曲绘 + 难度 + 成绩。
class _ChartRow extends StatelessWidget {
  const _ChartRow({
    required this.song,
    required this.difficulty,
    required this.score,
    required this.onTap,
  });

  final Song song;
  final SongDifficulty difficulty;
  final SimpleScore? score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = score;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Jacket(songId: song.id, size: 42, radius: 8),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 17,
                      child: AutoMarqueeText(
                        text: song.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: s == null
                              ? theme.colorScheme.onSurfaceVariant
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        RateBadge(
                          label:
                              '${difficulty.type.label} ${difficulty.levelIndex.label}',
                          color: AppPalette.chartTag(
                            difficulty.type,
                            difficulty.difficulty,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          difficulty.level,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if (s != null) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          RateBadge(
                            label: RateType.labelOf(s.rate),
                            color: RatePalette.of(s.rate),
                          ),
                          if (s.fc != null)
                            RateBadge(
                              label: FcType.fromValue(s.fc)?.label ?? s.fc!,
                              color: MarkPalette.fc(s.fc),
                            ),
                          if (s.fs != null)
                            RateBadge(
                              label: FsType.fromValue(s.fs)?.label ?? s.fs!,
                              color: MarkPalette.fs(s.fs),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                s == null
                    ? Icons.radio_button_unchecked_rounded
                    : Icons.check_circle_rounded,
                size: 20,
                color: s == null
                    ? theme.colorScheme.outlineVariant
                    : const Color(0xFF66BB6A),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
