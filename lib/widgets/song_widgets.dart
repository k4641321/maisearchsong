import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/constants.dart';
import '../core/palette.dart';
import '../models/models.dart';
import 'common.dart';

/// 曲目列表卡片。
class SongCard extends StatelessWidget {
  const SongCard({
    super.key,
    required this.song,
    this.onTap,
    this.onFavorite,
    this.isFavorite = false,
    this.subtitle,
    this.trailing,
    this.highlight,
  });

  /// 曲目。
  final Song song;

  /// 点击回调。
  final VoidCallback? onTap;

  /// 收藏回调。
  final VoidCallback? onFavorite;

  /// 是否已收藏。
  final bool isFavorite;

  /// 附加副标题（例如别名）。
  final String? subtitle;

  /// 右侧内容。
  final Widget? trailing;

  /// 高亮关键词。
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = song.topDifficulty;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Jacket(songId: song.id, size: 62, radius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 20,
                      child: AutoMarqueeText(
                        text: song.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      height: 16,
                      child: AutoMarqueeText(
                        text: song.artist,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      SizedBox(
                        height: 16,
                        child: AutoMarqueeText(
                          text: subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    DifficultyRow(song: song, compact: true),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      children: [
                        _Meta(
                          icon: Icons.speed_rounded,
                          text: 'BPM ${song.bpm}',
                        ),
                        if (top != null && top.levelValue > 0)
                          _Meta(
                            icon: Icons.equalizer_rounded,
                            text: '定数 ${top.levelValue.toStringAsFixed(1)}',
                          ),
                        if (song.isUtage)
                          _Meta(
                            icon: Icons.celebration_rounded,
                            text: '宴会',
                            color: DifficultyPalette.utage,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  if (onFavorite != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: isFavorite ? '取消收藏' : '收藏',
                      onPressed: onFavorite,
                      icon: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFavorite ? Colors.pinkAccent : null,
                      ),
                    ),
                  ?trailing,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 3),
        Text(text, style: theme.textTheme.labelSmall?.copyWith(color: c)),
      ],
    );
  }
}

/// 成绩条目。
class ScoreTile extends StatelessWidget {
  const ScoreTile({
    super.key,
    required this.score,
    this.song,
    this.onTap,
    this.rank,
  });

  /// 成绩。
  final Score score;

  /// 对应曲目（可能不在曲库中）。
  final Song? song;

  /// 点击回调。
  final VoidCallback? onTap;

  /// 排名序号。
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              if (rank != null)
                SizedBox(
                  width: 30,
                  child: Text(
                    '#$rank',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              Jacket(songId: score.id, size: 48, radius: 8),
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
                          label: score.difficulty.label,
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
                    ScoreBadges(score: score),
                  ],
                ),
              ),
              Text(
                '${score.achievements.toStringAsFixed(4)}%',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: RatePalette.of(score.rate),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 分数区间筛选条。
class LevelFilterBar extends StatelessWidget {
  const LevelFilterBar({
    super.key,
    required this.state,
    required this.onChanged,
  });

  /// 应用状态。
  final AppState state;

  /// 变化回调。
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          FilterChip(
            label: const Text('全部'),
            selected: state.levelFilter < 0,
            onSelected: (_) {
              state.levelFilter = -1;
              onChanged();
            },
          ),
          const SizedBox(width: 6),
          for (final level in LevelIndex.values) ...[
            FilterChip(
              label: Text(level.label),
              avatar: CircleAvatar(
                backgroundColor: AppPalette.chartTag(SongType.standard, level.value),
                radius: 7,
              ),
              selected: state.levelFilter == level.value,
              onSelected: (_) {
                state.levelFilter = level.value;
                onChanged();
              },
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}
