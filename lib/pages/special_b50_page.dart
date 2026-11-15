import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/constants.dart';
import '../core/palette.dart';
import '../core/rating.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'song_info_page.dart';

/// 特殊 Best 50 页：基于玩家全部成绩生成 AP50 / FC50 / 随机 50 / 分类 50 等榜单。
class SpecialB50Page extends StatefulWidget {
  const SpecialB50Page({super.key});

  @override
  State<SpecialB50Page> createState() => _SpecialB50PageState();
}

/// 榜单类型。
enum _B50Type {
  ap('AP50', '全连 Perfect 的 Best 50（本地计算）'),
  fc('FC50', 'FULL COMBO 及以上的 Best 50'),
  random('随机50', '从全部成绩里随机抽 50 谱'),
  genre('分类50', '指定分类下的 Best 50'),
  version('版本50', '指定版本下的 Best 50'),
  artist('曲师50', '指定曲师名下的 Best 50');

  const _B50Type(this.label, this.hint);

  final String label;
  final String hint;
}

/// 单条榜内条目。
class _Entry {
  const _Entry({
    required this.score,
    required this.difficulty,
    required this.rating,
    required this.order,
  });

  final SimpleScore score;

  /// 曲库中匹配到的谱面（可为 null，如曲目已下架）。
  final SongDifficulty? difficulty;
  final int rating;

  /// 在原始成绩列表中的下标（随机模式用）。
  final int order;
}

class _SpecialB50PageState extends State<SpecialB50Page> {
  final AppState _state = AppState.instance;
  final TextEditingController _code = TextEditingController();
  final math.Random _random = math.Random();

  List<SimpleScore> _scores = const [];
  bool _loading = false;
  String? _error;
  bool _queried = false;

  _B50Type _type = _B50Type.ap;
  String? _genre;
  String? _version;
  String? _artist;

  /// 随机 50 的当前抽签序列（保持稳定直到重新抽签）。
  List<int> _randomOrder = const [];

  @override
  void initState() {
    super.initState();
    _code.text = _state.player?.friendCode.toString() ?? '';
    if (_state.player != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _query());
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
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
        _randomOrder = const [];
        _queried = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 重新抽签。
  void _reshuffle() {
    setState(() {
      final indices = List<int>.generate(_scores.length, (i) => i);
      indices.shuffle(_random);
      _randomOrder = indices;
    });
  }

  /// 由成绩估算单谱 Rating：优先用接口返回的评级反推达成率，再套公式；
  /// 没有评级时按 100% 计。
  int _ratingOf(SimpleScore score, SongDifficulty? difficulty) {
    if (difficulty == null) return 0;
    final constant = RatingCalculator.constantOf(difficulty);
    if (constant <= 0) return 0;
    final achievements = switch (score.rate) {
      'sssp' => 100.5,
      'sss' => 100.0,
      'ssp' => 99.5,
      'ss' => 99.0,
      'sp' => 98.0,
      's' => 97.0,
      'aaa' => 94.0,
      'aa' => 90.0,
      'a' => 80.0,
      'bbb' => 75.0,
      'bb' => 70.0,
      'b' => 60.0,
      'c' => 50.0,
      'd' => 40.0,
      _ => 100.0,
    };
    return RatingCalculator.floorSingleRating(constant, achievements);
  }

  /// 由类型筛选出候选成绩并计算榜内条目。
  List<_Entry> _entries() {
    // 版本号映射：选中版本的标题 → 版本号。
    int? versionNumber;
    if (_type == _B50Type.version && _version != null) {
      for (final v in _state.versions) {
        if (v.title == _version) {
          versionNumber = v.version;
          break;
        }
      }
    }

    final out = <_Entry>[];
    for (final score in _scores) {
      // 宴会场不参与。
      if (score.type == SongType.utage) continue;
      final song = _state.songById(score.id);
      final difficulty = song?.difficultyOf(score.type, score.levelIndex);
      switch (_type) {
        case _B50Type.ap:
          if (score.fc != 'ap' && score.fc != 'app') continue;
        case _B50Type.fc:
          if (score.fc == null) continue;
        case _B50Type.random:
          break;
        case _B50Type.genre:
          if (song == null || song.genre != _genre) continue;
        case _B50Type.version:
          if (song == null || song.version != versionNumber) continue;
        case _B50Type.artist:
          if (song == null || song.artist != _artist) continue;
      }
      final rating = _ratingOf(score, difficulty);
      final index = _scores.indexOf(score);
      out.add(
        _Entry(
          score: score,
          difficulty: difficulty,
          rating: rating,
          order: index,
        ),
      );
    }

    if (_type == _B50Type.random) {
      // 按抽签顺序取前 50。
      if (_randomOrder.length == out.length) {
        final orderOf = <int, int>{};
        for (var i = 0; i < _randomOrder.length; i++) {
          orderOf[_randomOrder[i]] = i;
        }
        out.sort(
          (a, b) => (orderOf[a.order] ?? 0).compareTo(orderOf[b.order] ?? 0),
        );
      }
      return out.take(50).toList();
    }
    out.sort((a, b) => b.rating.compareTo(a.rating));
    return out.take(50).toList();
  }

  /// 所有可选分类。
  List<String> get _genres => _state.genres.map((g) => g.genre).toList();

  /// 所有可选版本（按版本号倒序）。
  List<String> get _versionTitles {
    final list = _state.versions.toList()
      ..sort((a, b) => b.version.compareTo(a.version));
    return list.map((v) => v.title).toList();
  }

  /// 所有可选曲师（出现次数多的排前面）。
  List<String> get _artists {
    final counter = <String, int>{};
    for (final s in _scores) {
      final song = _state.songById(s.id);
      if (song == null) continue;
      counter[song.artist] = (counter[song.artist] ?? 0) + 1;
    }
    final entries = counter.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => e.key).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _scores.isEmpty ? const <_Entry>[] : _entries();

    return Scaffold(
      appBar: AppBar(title: const Text('特殊 Best 50')),
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
          if (_scores.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in _B50Type.values)
                    ChoiceChip(
                      label: Text(t.label),
                      selected: _type == t,
                      onSelected: (_) => setState(() {
                        _type = t;
                        _randomOrder = const [];
                      }),
                    ),
                ],
              ),
            ),
            if (_type == _B50Type.genre)
              _SelectorRow(
                label: '分类',
                value: _genre,
                options: _genres,
                onChanged: (v) => setState(() => _genre = v),
              ),
            if (_type == _B50Type.version)
              _SelectorRow(
                label: '版本',
                value: _version,
                options: _versionTitles,
                onChanged: (v) => setState(() => _version = v),
              ),
            if (_type == _B50Type.artist)
              _SelectorRow(
                label: '曲师',
                value: _artist,
                options: _artists,
                onChanged: (v) => setState(() => _artist = v),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _type.hint,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (_type == _B50Type.random)
                    TextButton.icon(
                      onPressed: _reshuffle,
                      icon: const Icon(Icons.casino_rounded, size: 16),
                      label: const Text('重抽'),
                    ),
                ],
              ),
            ),
            if (entries.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                child: Row(
                  children: [
                    Text(
                      '共 ${entries.length} 条',
                      style: theme.textTheme.labelSmall,
                    ),
                    const Spacer(),
                    Text(
                      '合计 ${entries.fold<int>(0, (a, e) => a + e.rating)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
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
              empty: _scores.isEmpty || entries.isEmpty,
              emptyText: _scores.isEmpty
                  ? (_queried ? '该玩家还没有成绩' : '输入好友码后生成特殊 B50')
                  : '该筛选条件下没有成绩',
              emptyIcon: Icons.auto_awesome_motion_rounded,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 30),
                itemCount: entries.length,
                itemBuilder: (context, index) => _EntryTile(
                  entry: entries[index],
                  rank: index + 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单条榜单条目。
class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.rank});

  final _Entry entry;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = entry.score;
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
                        text: score.songName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        RateBadge(
                          label: '${score.type.label} ${score.difficulty.label}',
                          color: AppPalette.chartTag(
                            score.type,
                            score.levelIndex,
                          ),
                        ),
                        if (entry.difficulty != null)
                          RateBadge(
                            label: '定数 '
                                '${RatingCalculator.constantOf(
                                  entry.difficulty!,
                                ).toStringAsFixed(1)}',
                            color: theme.colorScheme.secondary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${entry.rating}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 横向选择器行（分类 / 版本 / 曲师）。
class _SelectorRow extends StatelessWidget {
  const _SelectorRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  /// 选项列表是否为空（空时禁用输入避免无谓渲染）。
  bool get _hasOptions => options.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_hasOptions) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: SizedBox(
        height: 42,
        child: Autocomplete<String>(
          initialValue: TextEditingValue(text: value ?? ''),
          optionsBuilder: (textEditingValue) {
            final text = textEditingValue.text;
            if (text.isEmpty) return const Iterable<String>.empty();
            return options
                .where(
                  (o) => o.toLowerCase().contains(text.toLowerCase()),
                )
                .take(12);
          },
          onSelected: onChanged,
          fieldViewBuilder: (
            context,
            controller,
            focusNode,
            onFieldSubmitted,
          ) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: label,
                isDense: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_drop_down_rounded),
                  onPressed: () => _showPicker(context),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final option in options)
              ListTile(
                dense: true,
                title: Text(option),
                selected: option == value,
                onTap: () {
                  Navigator.of(context).pop();
                  onChanged(option);
                },
              ),
          ],
        ),
      ),
    );
  }
}
