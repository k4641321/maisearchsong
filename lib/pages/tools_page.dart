import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/constants.dart';
import '../core/palette.dart';
import '../core/rating.dart';
import '../models/models.dart';
import 'all_scores_page.dart';
import 'collection_page.dart';
import 'friend_battle_page.dart';
import 'level_progress_page.dart';
import 'player_page.dart';
import 'random_song_page.dart';
import 'rating_calc_page.dart';
import 'special_b50_page.dart';

/// 工具页：查分、收藏品、计算器与资料表。
class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final player = state.player;

    return Scaffold(
      appBar: AppBar(title: const Text('工具')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 90),
        children: [
          _PlayerBanner(player: player, loading: state.loading),
          const _SectionTitle('玩家与成绩'),
          _ToolTile(
            icon: Icons.person_search_rounded,
            title: '玩家查询',
            subtitle: '输入好友码，查看 Rating、Best 50 与成绩曲线',
            onTap: () => _push(context, const PlayerPage()),
          ),
          _ToolTile(
            icon: Icons.insights_rounded,
            title: 'Rating 趋势',
            subtitle: '查看总 Rating 与 Best 35 + Best 15 的变化',
            onTap: () => _push(context, const PlayerPage(initialTab: 2)),
          ),
          _ToolTile(
            icon: Icons.emoji_events_rounded,
            title: '吃分建议',
            subtitle: '按单谱 Rating 从低到高排出可提升的谱面',
            onTap: () => _push(context, const PlayerPage(initialTab: 1)),
          ),
          _ToolTile(
            icon: Icons.auto_awesome_motion_rounded,
            title: '特殊 Best 50',
            subtitle: 'AP50 / FC50 / 随机 50 / 分类 · 版本 · 曲师 50',
            onTap: () => _push(context, const SpecialB50Page()),
          ),
          _ToolTile(
            icon: Icons.layers_rounded,
            title: '等级完成进度',
            subtitle: '按标级统计已打过的谱面与达成率档位',
            onTap: () => _push(context, const LevelProgressPage()),
          ),
          _ToolTile(
            icon: Icons.format_list_bulleted_rounded,
            title: '所有成绩',
            subtitle: '分页浏览玩家的全部最佳成绩',
            onTap: () => _push(context, const AllScoresPage()),
          ),
          _ToolTile(
            icon: Icons.sports_kabaddi_rounded,
            title: '友人对战',
            subtitle: '对比两位玩家的成绩，逐谱分出胜负',
            onTap: () => _push(context, const FriendBattlePage()),
          ),
          const _SectionTitle('曲目工具'),
          _ToolTile(
            icon: Icons.casino_rounded,
            title: '随机歌曲 / 出勤转盘',
            subtitle: '按分类、版本与难度随机抽歌',
            onTap: () => _push(context, const RandomSongPage()),
          ),
          _ToolTile(
            icon: Icons.calculate_rounded,
            title: '单曲 Rating 计算器',
            subtitle: '输入定数与达成率，换算单谱 Rating 与评级',
            onTap: () => _push(context, const RatingCalcPage()),
          ),
          _ToolTile(
            icon: Icons.healing_rounded,
            title: '容错计算',
            subtitle: '按物量推算 AP / FC 允许的失误数',
            onTap: () => _push(context, const RatingCalcPage(initialTab: 1)),
          ),
          const _SectionTitle('收藏品'),
          _ToolTile(
            icon: Icons.workspace_premium_rounded,
            title: '称号查询',
            subtitle: '${state.collectionCount('trophy')} 个称号与达成条件',
            onTap: () => _push(
              context,
              const CollectionPage(type: CollectionType.trophy),
            ),
          ),
          _ToolTile(
            icon: Icons.badge_rounded,
            title: '头像查询',
            subtitle: '${state.collectionCount('icon')} 个头像',
            onTap: () => _push(
              context,
              const CollectionPage(type: CollectionType.icon),
            ),
          ),
          _ToolTile(
            icon: Icons.crop_16_9_rounded,
            title: '姓名框查询',
            subtitle: '${state.collectionCount('plate')} 个姓名框',
            onTap: () => _push(
              context,
              const CollectionPage(type: CollectionType.plate),
            ),
          ),
          _ToolTile(
            icon: Icons.filter_frames_rounded,
            title: '背景框查询',
            subtitle: '${state.collectionCount('frame')} 个背景框',
            onTap: () => _push(
              context,
              const CollectionPage(type: CollectionType.frame),
            ),
          ),
          const _SectionTitle('资料表'),
          const _RankTable(),
          const _RatingColorTable(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: Text(
              '数据来源：落雪咖啡屋 maimai.lxns.net　·　本应用仅作查询展示。',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  static void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

/// 顶部玩家简要卡。
class _PlayerBanner extends StatelessWidget {
  const _PlayerBanner({required this.player, required this.loading});

  final Player? player;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = player;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppPalette.cardRadius),
        onTap: () => ToolsPage._push(context, const PlayerPage()),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (p == null)
                CircleAvatar(
                  radius: 26,
                  backgroundColor: scheme.surfaceContainerHighest,
                  child: Icon(
                    loading ? Icons.hourglass_top_rounded : Icons.person_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                ClipOval(
                  child: Image.network(
                    Utils.collectionUrl('icon', p.icon?.id ?? 1),
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => CircleAvatar(
                      radius: 26,
                      backgroundColor: scheme.surfaceContainerHighest,
                      child: const Icon(Icons.person_rounded),
                    ),
                  ),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p?.name ?? (loading ? '正在读取…' : '尚未查询玩家'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p == null
                          ? '点击输入好友码查询国服成绩'
                          : 'RATING ${p.rating}　·　好友码 ${p.friendCode}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
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
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AppPalette.seed,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: CircleAvatar(
      radius: 18,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: 0.6),
      child: Icon(icon, size: 19),
    ),
    title: Text(title),
    subtitle: Text(subtitle, maxLines: 2),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

/// 等级划分与判定表。
class _RankTable extends StatelessWidget {
  const _RankTable();

  static const List<(String, String)> _rows = [
    ('SSS+', '100.5000% 及以上'),
    ('SSS', '100.0000% ~ 100.4999%'),
    ('SS+', '99.5000% ~ 99.9999%'),
    ('SS', '99.0000% ~ 99.4999%'),
    ('S+', '98.0000% ~ 98.9999%'),
    ('S', '97.0000% ~ 97.9999%'),
    ('AAA', '94.0000% ~ 96.9999%'),
    ('AA', '90.0000% ~ 93.9999%'),
    ('A', '80.0000% ~ 89.9999%'),
    ('BBB', '75.0000% ~ 79.9999%'),
    ('BB', '70.0000% ~ 74.9999%'),
    ('B', '60.0000% ~ 69.9999%'),
    ('C', '50.0000% ~ 59.9999%'),
    ('D', '50.0000% 以下'),
  ];

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: ExpansionTile(
      shape: const Border(),
      leading: const Icon(Icons.leaderboard_rounded),
      title: const Text('等级划分与判定'),
      subtitle: const Text('达成率 → 评价等级 → Rating 系数'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        for (final row in _rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 54,
                  child: Text(
                    row.$1,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: RatePalette.of(
                        RateType.values
                            .firstWhere(
                              (e) => e.label == row.$1,
                              orElse: () => RateType.d,
                            )
                            .value,
                      ),
                    ),
                  ),
                ),
                Expanded(child: Text(row.$2)),
                Text(
                  '×${RatingCalculator.coefficientOf(double.parse(row.$2.split('%')[0]))}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Rating 颜色对照表。
class _RatingColorTable extends StatelessWidget {
  const _RatingColorTable();

  static const List<(String, int, Color)> _rows = [
    ('白', 0, Color(0xFFE0E0E0)),
    ('蓝', 1000, Color(0xFF64B5F6)),
    ('绿', 2000, Color(0xFF66BB6A)),
    ('黄', 4000, Color(0xFFFFD54F)),
    ('红', 7000, Color(0xFFEF5350)),
    ('紫', 10000, Color(0xFFAB47BC)),
    ('铜', 12000, Color(0xFFB87333)),
    ('银', 13000, Color(0xFFB0BEC5)),
    ('金', 14000, Color(0xFFFFC107)),
    ('铂金', 14500, Color(0xFF80DEEA)),
    ('虹', 15000, Color(0xFF7C4DFF)),
  ];

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: ExpansionTile(
      shape: const Border(),
      leading: const Icon(Icons.palette_rounded),
      title: const Text('Rating 颜色'),
      subtitle: const Text('总 Rating 对应的段位颜色'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final row in _rows)
              Chip(
                avatar: CircleAvatar(backgroundColor: row.$3, radius: 7),
                label: Text('${row.$1} ${row.$2}'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ],
    ),
  );
}
