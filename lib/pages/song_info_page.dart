import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_state.dart';
import '../core/constants.dart';
import '../core/palette.dart';
import '../core/rating.dart';
import '../models/models.dart';
import '../widgets/common.dart';

/// 曲目详情页。
class SongInfoPage extends StatefulWidget {
  const SongInfoPage({super.key, required this.songId});

  /// 曲目 ID。
  final int songId;

  @override
  State<SongInfoPage> createState() => _SongInfoPageState();
}

class _SongInfoPageState extends State<SongInfoPage> {
  final AppState _state = AppState.instance;
  final AudioPlayer _player = AudioPlayer();

  SongDifficulty? _selected;
  Score? _best;
  bool _loadingBest = false;
  List<Score> _history = [];
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  final List<StreamSubscription<dynamic>> _subs = [];

  Song? get _song => _state.songById(widget.songId);

  @override
  void initState() {
    super.initState();
    _state.addListener(_onChanged);
    _subs.addAll([
      _player.onPlayerStateChanged.listen((s) {
        if (mounted) setState(() => _playerState = s);
      }),
      _player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      }),
      _player.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      }),
      _player.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _playerState = PlayerState.stopped;
            _position = Duration.zero;
          });
        }
      }),
    ]);
    final song = _song;
    if (song != null) {
      _selected = song.topDifficulty;
      _loadBest();
      if (_state.settings.musicAutoplay) {
        unawaited(_togglePlay());
      }
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    _state.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// 取当前玩家在该谱面的最佳成绩与成绩历史。
  Future<void> _loadBest() async {
    final friendCode = _state.player?.friendCode;
    final difficulty = _selected;
    if (friendCode == null || difficulty == null) return;
    setState(() => _loadingBest = true);
    try {
      final data = await _state.api.fetchSongBest(
        friendCode: friendCode,
        songId: widget.songId,
        levelIndex: difficulty.difficulty,
        type: difficulty.type,
      );
      if (mounted) setState(() => _best = Score.fromJson(data));
    } catch (_) {
      if (mounted) setState(() => _best = null);
    } finally {
      if (mounted) setState(() => _loadingBest = false);
    }
    unawaited(_loadHistory());
  }

  /// 成绩历史（按上传时间倒序），仅用于详情页曲线展示。
  Future<void> _loadHistory() async {
    final friendCode = _state.player?.friendCode;
    final difficulty = _selected;
    if (friendCode == null || difficulty == null) return;
    try {
      final data = await _state.api.fetchScoreHistory(
        friendCode: friendCode,
        songId: widget.songId,
        levelIndex: difficulty.difficulty,
        type: difficulty.type,
      );
      if (!mounted) return;
      setState(() {
        _history = [
          for (final item in data)
            if (item is Map<String, dynamic>)
              Score.fromJson(Map<String, dynamic>.from(item)),
        ];
      });
    } catch (_) {
      // 历史是锦上添花：拉不到就安静地不画曲线。
      if (mounted) setState(() => _history = []);
    }
  }

  Future<void> _togglePlay() async {
    if (_playerState == PlayerState.playing) {
      await _player.pause();
      return;
    }
    if (_playerState == PlayerState.paused) {
      await _player.resume();
      return;
    }
    try {
      await _player.play(UrlSource(Utils.musicUrl(widget.songId)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('试听失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final song = _song;
    if (song == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('曲目详情')),
        body: StateView(
          loading: _state.loading,
          error: _state.loading ? null : '曲库中没有找到 id 为 ${widget.songId} 的曲目',
          onRetry: () => _state.refresh(force: true),
          child: const SizedBox.shrink(),
        ),
      );
    }

    final difficulty = _selected ?? song.topDifficulty;
    final favorites =
        _state.favorites[_state.currentFavoritesFolder] ?? const <int>[];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 280,
            title: Text(song.title, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                tooltip: favorites.contains(song.id) ? '取消收藏' : '收藏',
                onPressed: () => _state.toggleFavorite(song.id),
                icon: Icon(
                  favorites.contains(song.id)
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
              ),
              IconButton(
                tooltip: '分享',
                onPressed: () => _share(song, difficulty),
                icon: const Icon(Icons.share_rounded),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'copy':
                      await Clipboard.setData(
                        ClipboardData(text: '${song.title} - ${song.artist}'),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已复制曲目信息')),
                        );
                      }
                    case 'lxns':
                      await launchUrl(
                        Uri.parse('${AppInfo.lxnsWeb}/song/${song.id}'),
                        mode: LaunchMode.externalApplication,
                      );
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'copy', child: Text('复制曲目信息')),
                  PopupMenuItem(value: 'lxns', child: Text('在落雪打开')),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _Header(song: song, onTapJacket: () => _showJacket(song)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(icon: Icons.category_rounded, text: song.genre),
                  _InfoChip(icon: Icons.speed_rounded, text: 'BPM ${song.bpm}'),
                  _InfoChip(
                    icon: Icons.new_releases_rounded,
                    text: _state.versions
                            .where((v) => v.version == song.version)
                            .map((v) => v.title)
                            .firstOrNull ??
                        '版本 ${song.version}',
                  ),
                  _InfoChip(
                    icon: Icons.tag_rounded,
                    text: 'ID ${song.id}',
                  ),
                  if (song.locked)
                    const _InfoChip(
                      icon: Icons.lock_rounded,
                      text: '需解禁',
                      color: Colors.orangeAccent,
                    ),
                ],
              ),
            ),
          ),
          if (song.aliases.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '别名',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final alias in song.aliases)
                              ActionChip(
                                label: Text(alias),
                                onPressed: () => Clipboard.setData(
                                  ClipboardData(text: alias),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                '谱面',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DifficultyRow(
                song: song,
                selectedLevelIndex: difficulty?.difficulty,
                onSelect: (d) {
                  setState(() {
                    _selected = d;
                    _best = null;
                    _history = [];
                  });
                  _loadBest();
                },
              ),
            ),
          ),
          if (difficulty != null)
            SliverToBoxAdapter(
              child: _ChartPanel(
                song: song,
                difficulty: difficulty,
                best: _best,
                loadingBest: _loadingBest,
                hasPlayer: _state.player != null,
                history: _history,
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
              child: Text(
                '试听',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton.filled(
                        onPressed: _togglePlay,
                        icon: Icon(
                          _playerState == PlayerState.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(
                              value: _duration.inMilliseconds == 0
                                  ? 0
                                  : (_position.inMilliseconds /
                                            _duration.inMilliseconds)
                                        .clamp(0.0, 1.0),
                              minHeight: 4,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_fmt(_position)} / ${_fmt(_duration)}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '停止',
                        onPressed: () => _player.stop(),
                        icon: const Icon(Icons.stop_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  void _showJacket(Song song) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Jacket(songId: song.id, size: MediaQuery.sizeOf(context).width - 80, radius: 0),
            ListTile(
              title: Text(song.title),
              subtitle: Text(song.artist),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share(Song song, SongDifficulty? difficulty) async {
    final buffer = StringBuffer()
      ..writeln('【${AppInfo.appName}】')
      ..writeln('${song.title} - ${song.artist}')
      ..writeln('分类：${song.genre}　BPM：${song.bpm}');
    if (difficulty != null) {
      buffer
        ..writeln(
          '难度：${difficulty.type.label} ${difficulty.level}'
          '（定数 ${RatingCalculator.constantOf(difficulty).toStringAsFixed(1)}）',
        )
        ..writeln(
          '物量：${difficulty.notes.total}'
          '（TAP ${difficulty.notes.tap} / HOLD ${difficulty.notes.hold}'
          ' / SLIDE ${difficulty.notes.slide} / TOUCH ${difficulty.notes.touch}'
          ' / BREAK ${difficulty.notes.breakCount}）',
        );
      if (difficulty.noteDesigner.isNotEmpty) {
        buffer.writeln('谱师：${difficulty.noteDesigner}');
      }
    }
    await SharePlus.instance.share(
      ShareParams(text: buffer.toString(), subject: song.title),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.song, required this.onTapJacket});

  final Song song;
  final VoidCallback onTapJacket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.surfaceContainerHighest,
                theme.colorScheme.surface,
              ],
            ),
          ),
        ),
        Positioned.fill(
          bottom: 40,
          child: Center(
            child: GestureDetector(
              onTap: onTapJacket,
              child: Hero(
                tag: 'jacket-${song.id}',
                child: Jacket(songId: song.id, size: 170, radius: 16),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChartPanel extends StatelessWidget {
  const _ChartPanel({
    required this.song,
    required this.difficulty,
    required this.best,
    required this.loadingBest,
    required this.hasPlayer,
    required this.history,
  });

  final Song song;
  final SongDifficulty difficulty;
  final Score? best;
  final bool loadingBest;
  final bool hasPlayer;

  /// 成绩上传历史（倒序），长度 ≥ 2 时绘制达成率曲线。
  final List<Score> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final constant = RatingCalculator.constantOf(difficulty);
    final color = AppPalette.chartTag(difficulty.type, difficulty.difficulty);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      difficulty.type == SongType.utage
                          ? difficulty.displayLevel
                          : difficulty.levelIndex.label,
                      style: TextStyle(
                        color: DifficultyPalette.onColor(difficulty.difficulty),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    difficulty.level,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (constant > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '定数 ${constant.toStringAsFixed(1)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (difficulty.isBuddy)
                    const _InfoChip(
                      icon: Icons.people_alt_rounded,
                      text: 'BUDDY',
                    ),
                ],
              ),
              if (difficulty.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  difficulty.description,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const Divider(height: 24),
              _KeyValue('谱师', difficulty.noteDesigner.isEmpty ? '—' : difficulty.noteDesigner),
              _KeyValue('物量', '${difficulty.notes.total}'),
              _KeyValue(
                '详细',
                'TAP ${difficulty.notes.tap} · HOLD ${difficulty.notes.hold} · '
                    'SLIDE ${difficulty.notes.slide} · TOUCH ${difficulty.notes.touch} · '
                    'BREAK ${difficulty.notes.breakCount}',
              ),
              if (difficulty.notes.total > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _NotesBar(notes: difficulty.notes),
                ),
              const Divider(height: 24),
              Text(
                '我的成绩',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (!hasPlayer)
                Text(
                  '在「工具 → 玩家查询」中绑定落雪 ID 后可在此查看成绩',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else if (loadingBest)
                const LinearProgressIndicator(minHeight: 3)
              else if (best == null)
                Text(
                  '暂无该谱面成绩',
                  style: theme.textTheme.bodySmall,
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${best!.achievements.toStringAsFixed(4)}%',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: RatePalette.of(best!.rate),
                          ),
                        ),
                        const SizedBox(width: 10),
                        RateBadge(
                          label: '单谱 ${best!.dxRatingFloor}',
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ScoreBadges(score: best!),
                    if (best!.lastPlayedTime.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '最近游玩：${best!.lastPlayedTime}',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                    if (history.length >= 2) ...[
                      const SizedBox(height: 14),
                      _HistoryChart(history: history),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 成绩历史曲线（按上传时间从旧到新排列）。
///
/// 数据来自 `/score/history`，本身按 `upload_time` 倒序返回，
/// 画图前先反转成时间正序。
class _HistoryChart extends StatelessWidget {
  const _HistoryChart({required this.history});

  final List<Score> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = history.reversed.toList();
    if (points.length < 2) return const SizedBox.shrink();
    final values = points.map((e) => e.achievements).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final padding = ((maxValue - minValue) * 0.25).clamp(0.2, 3).toDouble();
    final minY = (minValue - padding).clamp(80, 101).toDouble();
    final maxY = (maxValue + padding).clamp(minY + 0.2, 101).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '成绩历史（${points.length} 次记录）',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: (((maxY - minY) / 2).clamp(0.1, 20)).toDouble(),
                    getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        value.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: (points.length / 3).ceilToDouble().clamp(1, 99),
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= points.length) {
                        return const SizedBox.shrink();
                      }
                      final time = points[index].uploadTime;
                      final label = time.length >= 10
                          ? time.substring(5, 10)
                          : time;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(label, style: const TextStyle(fontSize: 10)),
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
                          '${points[s.x.toInt()].achievements.toStringAsFixed(4)}%',
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
                    for (var i = 0; i < points.length; i++)
                      FlSpot(i.toDouble(), points[i].achievements),
                  ],
                  isCurved: true,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  color: theme.colorScheme.primary,
                  belowBarData: BarAreaData(
                    show: true,
                    color: theme.colorScheme.primary.withValues(alpha: 0.16),
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

class _NotesBar extends StatelessWidget {
  const _NotesBar({required this.notes});

  final Notes notes;

  @override
  Widget build(BuildContext context) {
    final total = notes.total == 0 ? 1 : notes.total;
    final segments = <(String, int, Color)>[
      ('TAP', notes.tap, const Color(0xFF42A5F5)),
      ('HOLD', notes.hold, const Color(0xFF66BB6A)),
      ('SLIDE', notes.slide, const Color(0xFFFFCA28)),
      ('TOUCH', notes.touch, const Color(0xFFAB47BC)),
      ('BREAK', notes.breakCount, const Color(0xFFEF5350)),
    ];
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                for (final (_, count, color) in segments)
                  if (count > 0)
                    Expanded(
                      flex: count,
                      child: ColoredBox(color: color),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [
            for (final (label, count, color) in segments)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$label ${(count / total * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (color ?? theme.colorScheme.primary).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 4),
          Text(text, style: theme.textTheme.labelMedium?.copyWith(color: c)),
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
