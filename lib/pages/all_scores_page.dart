import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/constants.dart';
import '../core/palette.dart';
import '../core/rating.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'song_info_page.dart';

/// 所有成绩预览页：拉取玩家全部最佳成绩并多维筛选、统计。
class AllScoresPage extends StatefulWidget {
  const AllScoresPage({super.key});

  @override
  State<AllScoresPage> createState() => _AllScoresPageState();
}

/// 成绩排序方式。
enum _ScoreSort { id, title, level, constant, rate, fc }

extension _ScoreSortLabel on _ScoreSort {
  String get label => switch (this) {
    _ScoreSort.id => '默认',
    _ScoreSort.title => '曲名',
    _ScoreSort.level => '难度',
    _ScoreSort.constant => '定数',
    _ScoreSort.rate => '评级',
    _ScoreSort.fc => 'FC',
  };
}

class _AllScoresPageState extends State<AllScoresPage> {
  final AppState _state = AppState.instance;
  final TextEditingController _code = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;

  /// 评级由高到低。
  static const List<String> _rateOrder = [
    'sssp', 'sss', 'ssp', 'ss', 'sp', 's',
    'aaa', 'aa', 'a', 'bbb', 'bb', 'b', 'c', 'd',
  ];

  static const Map<String, String> _fcOptions = {
    '': '全部',
    'none': '无 FC',
    'app': 'AP+',
    'ap': 'AP',
    'fcp': 'FC+',
    'fc': 'FC',
  };

  static const Map<int, String> _levelOptions = {
    -1: '全部',
    0: 'BASIC',
    1: 'ADVANCED',
    2: 'EXPERT',
    3: 'MASTER',
    4: 'Re:MASTER',
  };

  static const Map<int, String> _typeOptions = {0: '全部', 1: '标准', 2: 'DX'};

  List<SimpleScore> _scores = const [];
  bool _loading = false;
  String? _error;
  int? _loadedCode;
  bool _queried = false;

  _ScoreSort _sort = _ScoreSort.id;
  int _levelFilter = -1;
  int _typeFilter = 0;
  String _fcFilter = '';
  String _keyword = '';
  int _visible = 60;

  @override
  void initState() {
    super.initState();
    _code.text = _state.player?.friendCode.toString() ?? '';
    _scroll.addListener(_onScroll);
    // 已绑定玩家时自动拉一次，进入页面即可看到成绩。
    if (_state.player != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _query());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _code.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
      setState(() => _visible += 60);
    }
  }

  int _rateRank(String? rate) {
    if (rate == null || rate.isEmpty) return -1;
    final i = _rateOrder.indexOf(rate);
    return i < 0 ? -1 : _rateOrder.length - i;
  }

  int _fcRank(String? fc) => switch (fc) {
    'app' => 4,
    'ap' => 3,
    'fcp' => 2,
    'fc' => 1,
    _ => 0,
  };

  double _constantOf(SimpleScore s) {
    final d = _state.songById(s.id)?.difficultyOf(s.type, s.levelIndex);
    if (d == null) return 0;
    return RatingCalculator.constantOf(d);
  }

  Future<void> _query() async {
    final code = int.tryParse(_code.text.trim());
    if (code == null || code <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入正确的好友码')));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _state.api.fetchAllScores(code);
      if (!mounted) return;
      setState(() {
        _scores = raw
            .whereType<Map>()
            .map((e) => SimpleScore.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _loadedCode = code;
        _queried = true;
        _visible = 60;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<SimpleScore> _filtered() {
    final keyword = _keyword.trim();
    final result = _scores.where((s) {
      if (_levelFilter >= 0 && s.levelIndex != _levelFilter) return false;
      if (_typeFilter == 1 && s.type != SongType.standard) return false;
      if (_typeFilter == 2 && s.type != SongType.dx) return false;
      if (_fcFilter == 'none' && s.fc != null) return false;
      if (_fcFilter.isNotEmpty && _fcFilter != 'none' && s.fc != _fcFilter) {
        return false;
      }
      if (keyword.isNotEmpty && !Utils.fuzzyContains(s.songName, keyword)) {
        return false;
      }
      return true;
    }).toList();

    result.sort((a, b) {
      switch (_sort) {
        case _ScoreSort.id:
          final byId = a.id.compareTo(b.id);
          return byId != 0
              ? byId
              : _compareLevelKey(a, b);
        case _ScoreSort.title:
          final byTitle = a.songName.compareTo(b.songName);
          return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
        case _ScoreSort.level:
          final byLevel = b.levelIndex.compareTo(a.levelIndex);
          return byLevel != 0 ? byLevel : a.id.compareTo(b.id);
        case _ScoreSort.constant:
          final byConstant = _constantOf(b).compareTo(_constantOf(a));
          return byConstant != 0 ? byConstant : a.id.compareTo(b.id);
        case _ScoreSort.rate:
          final byRate = _rateRank(b.rate).compareTo(_rateRank(a.rate));
          return byRate != 0 ? byRate : a.id.compareTo(b.id);
        case _ScoreSort.fc:
          final byFc = _fcRank(b.fc).compareTo(_fcRank(a.fc));
          return byFc != 0 ? byFc : a.id.compareTo(b.id);
      }
    });
    return result;
  }

  int _compareLevelKey(SimpleScore a, SimpleScore b) {
    final byType = a.type.index.compareTo(b.type.index);
    if (byType != 0) return byType;
    return a.levelIndex.compareTo(b.levelIndex);
  }

  void _onKeywordChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _keyword = value;
        _visible = 60;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasData = _scores.isNotEmpty;
    final results = _filtered();
    final shown = results.take(_visible).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('所有成绩')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _query(),
                    decoration: const InputDecoration(
                      hintText: '输入好友码 / Friend Code',
                      prefixIcon: Icon(Icons.pin_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _loading ? null : _query,
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text('查询'),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (hasData) ...[
            _StatsCard(scores: _scores),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _popupChip<_ScoreSort>(
                    icon: Icons.sort_rounded,
                    label: '排序：${_sort.label}',
                    current: _sort,
                    options: {
                      for (final v in _ScoreSort.values) v: v.label,
                    },
                    onSelected: (v) => setState(() => _sort = v),
                  ),
                  _popupChip<int>(
                    icon: Icons.signal_cellular_alt_rounded,
                    label: '难度：${_levelOptions[_levelFilter] ?? '全部'}',
                    current: _levelFilter,
                    options: _levelOptions,
                    onSelected: (v) => setState(() => _levelFilter = v),
                  ),
                  _popupChip<int>(
                    icon: Icons.category_rounded,
                    label: '类型：${_typeOptions[_typeFilter] ?? '全部'}',
                    current: _typeFilter,
                    options: _typeOptions,
                    onSelected: (v) => setState(() => _typeFilter = v),
                  ),
                  _popupChip<String>(
                    icon: Icons.military_tech_rounded,
                    label: 'FC：${_fcOptions[_fcFilter] ?? '全部'}',
                    current: _fcFilter,
                    options: _fcOptions,
                    onSelected: (v) => setState(() => _fcFilter = v),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
              child: SizedBox(
                height: 42,
                child: TextField(
                  onChanged: _onKeywordChanged,
                  decoration: const InputDecoration(
                    hintText: '按曲名筛选',
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                    isDense: true,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                children: [
                  Text(
                    '共 ${results.length} 条',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (_loadedCode != null)
                    Text(
                      '好友码 $_loadedCode',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ),
          ],
          Expanded(
            child: StateView(
              loading: _loading && _scores.isEmpty,
              error: _scores.isEmpty ? _error : null,
              onRetry: _query,
              empty: !hasData || shown.isEmpty,
              emptyText: hasData
                  ? '没有符合条件的成绩'
                  : (_queried ? '该玩家还没有成绩' : '输入好友码后拉取全部成绩'),
              emptyIcon: Icons.playlist_play_rounded,
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.only(bottom: 30),
                itemCount: shown.length,
                itemBuilder: (context, index) =>
                    _ScoreTileRow(score: shown[index], rank: index + 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 弹出菜单式筛选片。
  Widget _popupChip<T>({
    required IconData icon,
    required String label,
    required T current,
    required Map<T, String> options,
    required ValueChanged<T> onSelected,
  }) {
    return PopupMenuButton<T>(
      initialValue: current,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final entry in options.entries)
          PopupMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      child: InputChip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// 成绩统计卡。
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.scores});

  final List<SimpleScore> scores;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = scores.length;
    final fc = scores.where((s) => s.fc != null).length;
    final ap = scores
        .where((s) => s.fc == 'app' || s.fc == 'ap')
        .length;
    final sssp = scores.where((s) => s.rate == 'sssp').length;
    final sss = scores.where((s) => s.rate == 'sss').length;
    final ssp = scores.where((s) => s.rate == 'ssp').length;

    Widget stat(String label, String value, Color? color) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 18,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            stat('总成绩', '$total', null),
            stat('FC', '$fc', MarkPalette.fc('fc')),
            stat('AP', '$ap', MarkPalette.fc('ap')),
            stat('SSS+', '$sssp', RatePalette.of('sssp')),
            stat('SSS', '$sss', RatePalette.of('sss')),
            stat('SS+', '$ssp', RatePalette.of('ssp')),
          ],
        ),
      ),
    );
  }
}

/// 单条成绩行。
class _ScoreTileRow extends StatelessWidget {
  const _ScoreTileRow({required this.score, this.rank});

  final SimpleScore score;

  final int? rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final song = AppState.instance.songById(score.id);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SongInfoPage(songId: score.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              if (rank != null)
                SizedBox(
                  width: 34,
                  child: Text(
                    '#$rank',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              Jacket(songId: score.id, size: 44, radius: 8),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 18,
                      child: AutoMarqueeText(
                        text: score.songName.isEmpty
                            ? (song?.title ?? '未知曲目')
                            : score.songName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        RateBadge(
                          label: '${score.type.label} ${score.difficulty.label}',
                          color: AppPalette.chartTag(
                            score.type,
                            score.levelIndex,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          score.level,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        RateBadge(
                          label: RateType.labelOf(score.rate),
                          color: RatePalette.of(score.rate),
                        ),
                        if (score.fc != null)
                          RateBadge(
                            label: FcType.fromValue(score.fc)?.label ??
                                score.fc!,
                            color: MarkPalette.fc(score.fc),
                          ),
                        if (score.fs != null)
                          RateBadge(
                            label: FsType.fromValue(score.fs)?.label ??
                                score.fs!,
                            color: MarkPalette.fs(score.fs),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
