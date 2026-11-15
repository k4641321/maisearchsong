import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/constants.dart';
import '../core/palette.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'song_info_page.dart';

/// 友人对战页：两位玩家的全部成绩按 (曲目, 类型, 难度) 匹配并比较。
class FriendBattlePage extends StatefulWidget {
  const FriendBattlePage({super.key});

  @override
  State<FriendBattlePage> createState() => _FriendBattlePageState();
}

/// 对战结果筛选。
enum _BattleFilter { all, win, lose, draw }

extension on _BattleFilter {
  String get label => switch (this) {
    _BattleFilter.all => '全部',
    _BattleFilter.win => '我赢',
    _BattleFilter.lose => '对方赢',
    _BattleFilter.draw => '平局',
  };
}

/// 一局对战的比对结果。
class _BattleItem {
  const _BattleItem({
    required this.mine,
    required this.theirs,
    required this.outcome,
  });

  final SimpleScore mine;

  final SimpleScore theirs;

  /// -1 对方赢，0 平局，1 我赢。
  final int outcome;
}

class _FriendBattlePageState extends State<FriendBattlePage> {
  final AppState _state = AppState.instance;
  final TextEditingController _mine = TextEditingController();
  final TextEditingController _theirs = TextEditingController();

  List<_BattleItem> _items = const [];
  bool _loading = false;
  String? _error;
  bool _queried = false;
  _BattleFilter _filter = _BattleFilter.all;
  int? _myCode;
  int? _theirCode;

  /// SimpleScore 没有 achievements，用 rate 排名比较（越高越强）。
  static const List<String> _rateOrder = [
    'sssp', 'sss', 'ssp', 'ss', 'sp', 's',
    'aaa', 'aa', 'a', 'bbb', 'bb', 'b', 'c', 'd',
  ];

  @override
  void initState() {
    super.initState();
    _mine.text = _state.player?.friendCode.toString() ?? '';
  }

  @override
  void dispose() {
    _mine.dispose();
    _theirs.dispose();
    super.dispose();
  }

  int _rateRank(String? rate) {
    if (rate == null || rate.isEmpty) return -1;
    final i = _rateOrder.indexOf(rate);
    return i < 0 ? -1 : _rateOrder.length - i;
  }

  /// 综合强度：评级排名优先，其次 FC 档位。
  int _strength(SimpleScore s) => _rateRank(s.rate) * 10 + _fcRank(s.fc);

  int _fcRank(String? fc) => switch (fc) {
    'app' => 4,
    'ap' => 3,
    'fcp' => 2,
    'fc' => 1,
    _ => 0,
  };

  Future<void> _battle() async {
    final myCode = int.tryParse(_mine.text.trim());
    final theirCode = int.tryParse(_theirs.text.trim());
    if (myCode == null || myCode <= 0 || theirCode == null || theirCode <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入两个正确的好友码')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _state.api.fetchAllScores(myCode),
        _state.api.fetchAllScores(theirCode),
      ]);
      if (!mounted) return;
      List<SimpleScore> parse(dynamic raw) => (raw as List)
          .whereType<Map>()
          .map((e) => SimpleScore.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final mine = parse(results[0]);
      final theirs = parse(results[1]);

      String keyOf(SimpleScore s) =>
          '${s.id}:${s.type.value}:${s.levelIndex}';
      final theirMap = {
        for (final s in theirs) keyOf(s): s,
      };

      // 双方都有的谱面才算一局。
      final items = <_BattleItem>[];
      for (final m in mine) {
        final t = theirMap[keyOf(m)];
        if (t == null) continue;
        final mineStrength = _strength(m);
        final theirStrength = _strength(t);
        items.add(_BattleItem(
          mine: m,
          theirs: t,
          outcome: mineStrength == theirStrength
              ? 0
              : (mineStrength > theirStrength ? 1 : -1),
        ));
      }

      setState(() {
        _items = items;
        _myCode = myCode;
        _theirCode = theirCode;
        _queried = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_BattleItem> get _filtered => switch (_filter) {
    _BattleFilter.all => _items,
    _BattleFilter.win => _items.where((e) => e.outcome > 0).toList(),
    _BattleFilter.lose => _items.where((e) => e.outcome < 0).toList(),
    _BattleFilter.draw => _items.where((e) => e.outcome == 0).toList(),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wins = _items.where((e) => e.outcome > 0).length;
    final loses = _items.where((e) => e.outcome < 0).length;
    final draws = _items.length - wins - loses;

    return Scaffold(
      appBar: AppBar(title: const Text('友人对战')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _mine,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: '我的好友码',
                          prefixIcon: Icon(Icons.person_rounded),
                          isDense: true,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(Icons.close_rounded),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _theirs,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: '对方好友码',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _battle,
                    icon: const Icon(Icons.sports_kabaddi_rounded, size: 18),
                    label: const Text('开战'),
                  ),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_items.isNotEmpty) ...[
            _ResultBanner(
              myCode: _myCode,
              theirCode: _theirCode,
              wins: wins,
              loses: loses,
              draws: draws,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
              child: Wrap(
                spacing: 6,
                children: [
                  for (final f in _BattleFilter.values)
                    ChoiceChip(
                      label: Text(f.label),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '共 ${_filtered.length} 局',
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
          ],
          Expanded(
            child: StateView(
              loading: _loading && _items.isEmpty,
              error: _items.isEmpty ? _error : null,
              onRetry: _battle,
              empty: _items.isEmpty,
              emptyText: _queried
                  ? '两人没有共同谱面成绩'
                  : '输入双方好友码，比较共同谱面的成绩档位',
              emptyIcon: Icons.groups_rounded,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 30),
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final item = _filtered[index];
                  return _BattleRow(item: item);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 战绩总结横幅。
class _ResultBanner extends StatelessWidget {
  const _ResultBanner({
    required this.myCode,
    required this.theirCode,
    required this.wins,
    required this.loses,
    required this.draws,
  });

  final int? myCode;
  final int? theirCode;
  final int wins;
  final int loses;
  final int draws;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final win = wins > loses;
    final total = wins + loses + draws;
    final myRatio = total == 0 ? 0.0 : wins / total;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$myCode',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                RateBadge(
                  label: win ? '胜利' : (wins == loses ? '平手' : '惜败'),
                  color: win
                      ? const Color(0xFF66BB6A)
                      : (wins == loses
                            ? Colors.grey
                            : const Color(0xFFEF5350)),
                ),
                Text(
                  '$theirCode',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 10,
                child: Stack(
                  children: [
                    ColoredBox(
                      color: const Color(0xFFEF5350).withValues(alpha: 0.6),
                      child: const SizedBox.expand(),
                    ),
                    FractionallySizedBox(
                      widthFactor: myRatio.clamp(0.0, 1.0),
                      child: const ColoredBox(
                        color: Color(0xFF66BB6A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$wins 胜 / $loses 负 / $draws 平',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// 单局对战行。
class _BattleRow extends StatelessWidget {
  const _BattleRow({required this.item});

  final _BattleItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = item.mine;
    final theirs = item.theirs;
    final song = AppState.instance.songById(mine.id);

    Color colorOf(int outcome) => switch (outcome) {
      1 => const Color(0xFF66BB6A),
      -1 => const Color(0xFFEF5350),
      _ => Colors.grey,
    };
    IconData iconOf(int outcome) => switch (outcome) {
      1 => Icons.arrow_forward_rounded,
      -1 => Icons.arrow_back_rounded,
      _ => Icons.remove_rounded,
    };

    Widget sideTile(SimpleScore s, int outcome, bool left) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: colorOf(outcome).withValues(alpha: 0.08),
          borderRadius: BorderRadius.horizontal(
            left: left ? const Radius.circular(8) : Radius.zero,
            right: left ? Radius.zero : const Radius.circular(8),
          ),
        ),
        child: Column(
          crossAxisAlignment: left
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (left)
                  Icon(iconOf(outcome), size: 14, color: colorOf(outcome))
                else
                  RateBadge(
                    label: RateType.labelOf(s.rate),
                    color: RatePalette.of(s.rate),
                  ),
                const SizedBox(width: 4),
                if (left)
                  RateBadge(
                    label: RateType.labelOf(s.rate),
                    color: RatePalette.of(s.rate),
                  )
                else
                  Icon(iconOf(outcome), size: 14, color: colorOf(outcome)),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              s.fc == null ? '—' : (FcType.fromValue(s.fc)?.label ?? s.fc!),
              style: theme.textTheme.labelSmall?.copyWith(
                color: s.fc == null
                    ? theme.colorScheme.outline
                    : MarkPalette.fc(s.fc),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SongInfoPage(songId: mine.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                children: [
                  Jacket(songId: mine.id, size: 40, radius: 8),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 17,
                      child: AutoMarqueeText(
                        text: mine.songName.isEmpty
                            ? (song?.title ?? '未知曲目')
                            : mine.songName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  RateBadge(
                    label:
                        '${mine.type.label} ${mine.difficulty.label} ${mine.level}',
                    color: AppPalette.chartTag(mine.type, mine.levelIndex),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  sideTile(mine, item.outcome, true),
                  const SizedBox(width: 4),
                  sideTile(theirs, -item.outcome, false),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
