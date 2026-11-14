import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/palette.dart';
import '../models/models.dart';

/// 曲绘。
///
/// 使用 `cached_network_image` 缓存落雪的曲绘资源；
/// 加载中显示占位骨架，失败时降级为音符图标。
class Jacket extends StatelessWidget {
  const Jacket({
    super.key,
    required this.songId,
    this.size = 64,
    this.radius = 10,
    this.heroTag,
  });

  /// 曲目 ID。
  final int songId;

  /// 边长。
  final double size;

  /// 圆角。
  final double radius;

  /// 共享元素标签。
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final child = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: _JacketImage(songId: songId),
      ),
    );
    if (heroTag == null) return child;
    return Hero(tag: heroTag!, child: child);
  }
}

class _JacketImage extends StatelessWidget {
  const _JacketImage({required this.songId});

  final int songId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Image.network(
      Utils.jacketUrl(songId),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stack) => ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Icon(
          Icons.music_note_rounded,
          color: scheme.onSurfaceVariant,
          size: 26,
        ),
      ),
    );
  }
}

/// 难度标签。
class DifficultyTag extends StatelessWidget {
  const DifficultyTag({
    super.key,
    required this.difficulty,
    this.selected = false,
    this.onTap,
    this.compact = false,
  });

  /// 谱面。
  final SongDifficulty difficulty;

  /// 是否选中。
  final bool selected;

  /// 点击回调。
  final VoidCallback? onTap;

  /// 紧凑模式（只显示标级）。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = AppPalette.chartTag(difficulty.type, difficulty.difficulty);
    final foreground = DifficultyPalette.onColor(difficulty.difficulty);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 3 : 6,
        ),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.8), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              difficulty.displayLevel,
              style: TextStyle(
                color: selected ? foreground : color,
                fontWeight: FontWeight.w700,
                fontSize: compact ? 12 : 13,
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(
                difficulty.levelValue > 0
                    ? difficulty.levelValue.toStringAsFixed(1)
                    : difficulty.level,
                style: TextStyle(
                  color: (selected ? foreground : color).withValues(alpha: 0.85),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 曲目的一整行难度标签。
class DifficultyRow extends StatelessWidget {
  const DifficultyRow({
    super.key,
    required this.song,
    this.selectedLevelIndex,
    this.onSelect,
    this.compact = false,
  });

  /// 曲目。
  final Song song;

  /// 当前选中难度。
  final int? selectedLevelIndex;

  /// 点击难度回调。
  final void Function(SongDifficulty difficulty)? onSelect;

  /// 紧凑模式。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final items = song.allDifficulties;
    if (items.isEmpty) {
      return Text('暂无谱面数据', style: Theme.of(context).textTheme.bodySmall);
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final d in items)
          DifficultyTag(
            difficulty: d,
            compact: compact,
            selected: selectedLevelIndex != null &&
                d.difficulty == selectedLevelIndex &&
                d.type != SongType.utage,
            onTap: onSelect == null ? null : () => onSelect!(d),
          ),
      ],
    );
  }
}

/// 评级 / FC / FS 角标。
class RateBadge extends StatelessWidget {
  const RateBadge({super.key, required this.label, required this.color});

  /// 文本。
  final String label;

  /// 颜色。
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.7)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
    ),
  );
}

/// 由成绩生成评级 / FC / FS 角标组。
class ScoreBadges extends StatelessWidget {
  const ScoreBadges({super.key, required this.score, this.showDxRating = true});

  /// 成绩。
  final Score score;

  /// 是否显示单谱 Rating。
  final bool showDxRating;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        RateBadge(
          label: score.rateLabel,
          color: RatePalette.of(score.rate),
        ),
        if (score.fc != null)
          RateBadge(label: FcType.fromValue(score.fc)?.label ?? score.fc!, color: MarkPalette.fc(score.fc)),
        if (score.fs != null)
          RateBadge(label: FsType.fromValue(score.fs)?.label ?? score.fs!, color: MarkPalette.fs(score.fs)),
        if (showDxRating)
          RateBadge(
            label: '${score.dxRatingFloor}',
            color: Theme.of(context).colorScheme.primary,
          ),
      ],
    );
  }
}

/// 统一的加载 / 错误 / 空态视图。
class StateView extends StatelessWidget {
  const StateView({
    super.key,
    required this.child,
    this.loading = false,
    this.error,
    this.empty = false,
    this.emptyText = '什么都没有',
    this.onRetry,
    this.emptyIcon = Icons.inbox_rounded,
  });

  /// 内容。
  final Widget child;

  /// 是否加载中。
  final bool loading;

  /// 错误信息。
  final String? error;

  /// 是否空态。
  final bool empty;

  /// 空态文案。
  final String emptyText;

  /// 重试回调。
  final VoidCallback? onRetry;

  /// 空态图标。
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 46,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 14),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重试'),
                ),
              ],
            ],
          ),
        ),
      );
    }
    if (empty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              emptyIcon,
              size: 46,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(emptyText, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      );
    }
    return child;
  }
}

/// 自动跑马灯文本。
///
/// 文本宽度未超出可用宽度时按普通文本渲染；
/// 超出时按 [velocity]（逻辑像素 / 秒）横向滚动。
class AutoMarqueeText extends StatelessWidget {
  const AutoMarqueeText({
    super.key,
    required this.text,
    this.style,
    this.velocity = 30,
    this.gap = 48,
  });

  /// 文本。
  final String text;

  /// 样式。
  final TextStyle? style;

  /// 滚动速度（逻辑像素 / 秒）。
  final double velocity;

  /// 首尾之间的间隔。
  final double gap;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final painter = TextPainter(
          text: TextSpan(text: text, style: effectiveStyle),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout();
        if (maxWidth <= 0 || painter.width <= maxWidth) {
          return Text(
            text,
            style: effectiveStyle,
            maxLines: 1,
            overflow: TextOverflow.clip,
          );
        }
        final span = painter.width + gap;
        return ClipRect(
          child: _Marquee(
            text: text,
            style: effectiveStyle,
            distance: span,
            duration: Duration(
              milliseconds: (span / velocity * 1000).round().clamp(1200, 30000),
            ),
          ),
        );
      },
    );
  }
}

class _Marquee extends StatefulWidget {
  const _Marquee({
    required this.text,
    required this.style,
    required this.distance,
    required this.duration,
  });

  final String text;
  final TextStyle style;
  final double distance;
  final Duration duration;

  @override
  State<_Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<_Marquee> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration)..repeat();

  @override
  void didUpdateWidget(covariant _Marquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
      _controller..reset()..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final t = _controller.value;
      // 前 85% 用来滚动，后 15% 停顿。
      final progress = t < 0.85 ? t / 0.85 : 1.0;
      return Transform.translate(
        offset: Offset(-progress * widget.distance, 0),
        child: child,
      );
    },
    child: Text(
      widget.text,
      style: widget.style,
      maxLines: 1,
      softWrap: false,
    ),
  );
}
