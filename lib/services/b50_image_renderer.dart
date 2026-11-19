import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../core/palette.dart';
import '../core/rating.dart';
import '../models/models.dart';

/// 统一存放普通成绩与特殊榜单所需的可绘制信息。
@immutable
class B50ImageEntry {
  B50ImageEntry.fromScore(Score score, {required SongDifficulty? difficulty})
    : this(
        score: SimpleScore(
          id: score.id,
          songName: score.songName,
          level: score.level,
          levelIndex: score.levelIndex,
          type: score.type,
          fc: score.fc,
          fs: score.fs,
          rate: score.rate,
        ),
        difficulty: difficulty,
        achievements: score.achievements,
        rating: RatingCalculator.ratingOfScoreWithSong(score, difficulty),
        fcOverride: score.fc,
        fsOverride: score.fs,
      );

  B50ImageEntry.fromSimpleScore(
    SimpleScore score, {
    required SongDifficulty? difficulty,
    int? rating,
  }) : this(
         score: score,
         difficulty: difficulty,
         rating:
             rating ??
             (difficulty == null
                 ? 0
                 : RatingCalculator.floorSingleRating(
                     RatingCalculator.constantOf(difficulty),
                     estimatedAchievementsOf(score.rate),
                   )),
       );

  const B50ImageEntry({
    required this.score,
    required this.difficulty,
    required this.rating,
    this.achievements,
    this.fcOverride,
    this.fsOverride,
  });

  final SimpleScore score;
  final SongDifficulty? difficulty;
  final int rating;

  /// 服务端提供的真实达成率；特殊榜单为空，不冒充实际达成率。
  final double? achievements;
  final String? fcOverride;
  final String? fsOverride;

  String? get fc => fcOverride ?? score.fc;
  String? get fs => fsOverride ?? score.fs;
  String? get fcLabel => FcType.fromValue(fc)?.label;
  String? get fsLabel => FsType.fromValue(fs)?.label;
  String get levelLabel {
    if (score.type == SongType.utage) return '宴 ${difficulty?.level ?? '?'}';
    final level = difficulty?.level ?? score.level;
    final diff = difficulty;
    if (diff != null) {
      final constant = RatingCalculator.constantOf(diff);
      if (constant > 0) return '$level (${constant.toStringAsFixed(1)})';
    }
    return level;
  }

  /// 特殊成绩接口不含达成率，按现有榜单规则从 rate 取阈值。
  static double estimatedAchievementsOf(String? rate) => switch (rate) {
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
}

@immutable
class B50ImageSection {
  const B50ImageSection({
    required this.title,
    required this.entries,
    this.total,
  });

  final String title;
  final List<B50ImageEntry> entries;
  final int? total;
}

/// 描述一张成绩长图；条目顺序就是导出图片中的榜单顺序。
@immutable
class B50ImageDocument {
  B50ImageDocument({
    required this.title,
    required this.subtitle,
    required this.sections,
    this.player,
    this.estimatesRating = false,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();

  factory B50ImageDocument.regular({
    required BestScores bests,
    Player? player,
    Song? Function(int id) songById = _missingSong,
    DateTime? generatedAt,
  }) => B50ImageDocument(
    generatedAt: generatedAt,
    title: 'Best 50',
    subtitle: '常规成绩 · TOTAL ${bests.standardTotal + bests.dxTotal}',
    player: player,
    sections: [
      B50ImageSection(
        title: 'B35 · 旧版本 Rating ${bests.standardTotal}',
        entries: [
          for (final s in bests.standard)
            B50ImageEntry.fromScore(
              s,
              difficulty: songById(s.id)?.difficultyOf(s.type, s.levelIndex),
            ),
        ],
        total: bests.standardTotal,
      ),
      B50ImageSection(
        title: 'B15 · 新版本 Rating ${bests.dxTotal}',
        entries: [
          for (final s in bests.dx)
            B50ImageEntry.fromScore(
              s,
              difficulty: songById(s.id)?.difficultyOf(s.type, s.levelIndex),
            ),
        ],
        total: bests.dxTotal,
      ),
    ],
  );

  final String title;
  final String subtitle;
  final List<B50ImageSection> sections;
  final Player? player;
  final bool estimatesRating;
  final DateTime generatedAt;

  int get total =>
      sections.fold(0, (sum, section) => sum + (section.total ?? 0));

  int get entryCount => sections.fold(0, (sum, s) => sum + s.entries.length);

  String get fileName {
    final who = player?.name.trim();
    final stamp = generatedAt.toIso8601String().substring(0, 10);
    final raw = [
      'B50',
      if (who != null && who.isNotEmpty) who,
      title,
      stamp,
    ].join('_').replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return '$raw.png';
  }
}

/// 将成绩绘制为独立于屏幕尺寸的 1200px 宽 PNG 长图。
abstract final class B50ImageRenderer {
  static const double canvasWidth = 1200;
  static const double _cardHeight = 88;
  static const double _rowGap = 8;
  static const double _headerHeight = 212;
  static const double _sectionHeader = 50;
  static const double _footerHeight = 54;

  static double heightOf(B50ImageDocument document) => _layoutHeight(document);

  /// 使用已加载的图片离线绘制，便于测试曲绘加载失败时的布局。
  static Future<Uint8List> draw(
    B50ImageDocument document, {
    Map<String, ui.Image> images = const {},
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final height = _paint(canvas, document, images);
    final picture = recorder.endRecording();
    ui.Image? image;
    try {
      image = await picture.toImage(canvasWidth.round(), height.round());
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('图片编码失败，请重试');
      return data.buffer.asUint8List();
    } finally {
      image?.dispose();
      picture.dispose();
    }
  }

  /// 下载曲绘并绘制。单张图加载失败时使用占位图，不影响导出。
  static Future<Uint8List> generate(
    B50ImageDocument document, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final client = http.Client();
    try {
      final urls = <String>{
        for (final s in document.sections)
          for (final e in s.entries) Utils.jacketUrl(e.score.id),
        if (document.player?.icon != null)
          Utils.collectionUrl('icon', document.player!.icon!.id),
      };
      final images = <String, ui.Image>{};
      var completed = 0;
      try {
        onProgress?.call(0, urls.length);
        await _forEachConcurrent(urls, 6, (url) async {
          try {
            final image = await _download(client, url);
            if (image != null) images[url] = image;
          } finally {
            completed++;
            onProgress?.call(completed, urls.length);
          }
        });
        return await draw(document, images: images);
      } finally {
        for (final image in images.values) {
          image.dispose();
        }
      }
    } finally {
      client.close();
    }
  }

  static Future<ui.Image?> _download(http.Client client, String url) async {
    try {
      final response = await client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;
      final codec = await ui.instantiateImageCodec(
        response.bodyBytes,
        targetWidth: 160,
        targetHeight: 160,
        allowUpscaling: false,
      );
      try {
        return (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  static Future<void> _forEachConcurrent(
    Iterable<String> urls,
    int limit,
    Future<void> Function(String) action,
  ) async {
    final queue = Queue.of(urls);
    await Future.wait([
      for (var i = 0; i < limit; i++)
        () async {
          while (queue.isNotEmpty) {
            await action(queue.removeFirst());
          }
        }(),
    ]);
  }

  static double _paint(
    Canvas canvas,
    B50ImageDocument document, [
    Map<String, ui.Image> images = const {},
  ]) {
    final background = Paint()..color = const Color(0xFFF4F2FC);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasWidth, _layoutHeight(document)),
      background,
    );
    final accent = Paint()..color = const Color(0xFF51347A);
    canvas.drawRect(const Rect.fromLTWH(0, 0, canvasWidth, 8), accent);
    if (document.player?.icon case final icon?) {
      final avatar = images[Utils.collectionUrl('icon', icon.id)];
      final rect = const Rect.fromLTWH(72, 65, 112, 112);
      _drawCover(canvas, rect, avatar);
    }
    final nameX = document.player?.icon != null ? 200.0 : 64.0;
    _text(
      canvas,
      document.player?.name ?? AppInfo.appName,
      Offset(nameX, 55),
      38,
      FontWeight.w800,
      const Color(0xFF51347A),
      canvasWidth - nameX - 60,
    );
    _text(
      canvas,
      document.player == null
          ? document.title
          : '${document.title} · RATING ${document.total}',
      Offset(nameX, 103),
      26,
      FontWeight.w600,
      const Color(0xFF45405C),
      canvasWidth - nameX - 60,
    );
    _text(
      canvas,
      document.subtitle,
      Offset(nameX, 144),
      20,
      FontWeight.normal,
      const Color(0xFF787186),
      canvasWidth - nameX - 60,
    );
    var y = _headerHeight;
    for (final section in document.sections) {
      _text(
        canvas,
        section.title,
        Offset(64, y),
        27,
        FontWeight.w700,
        const Color(0xFF51347A),
        860,
      );
      _rightText(
        canvas,
        '${section.entries.length} 首',
        Offset(1136, y + 6),
        19,
        const Color(0xFF787186),
      );
      y += _sectionHeader;
      final rows = (section.entries.length / 2).ceil();
      for (var row = 0; row < rows; row++) {
        for (var column = 0; column < 2; column++) {
          final index = row * 2 + column;
          if (index >= section.entries.length) break;
          _drawCard(
            canvas,
            Rect.fromLTWH(64 + column * 563, y, 556, _cardHeight),
            section.entries[index],
            index + 1,
            images[Utils.jacketUrl(section.entries[index].score.id)],
          );
        }
        y += _cardHeight + _rowGap;
      }
      if (section.entries.isEmpty) {
        _text(
          canvas,
          '暂无成绩',
          Offset(64, y),
          20,
          FontWeight.normal,
          const Color(0xFF787186),
          1072,
        );
        y += 30;
      }
      if (section.entries.isNotEmpty) y -= _rowGap;
      y += 22;
    }
    final stamp = document.generatedAt.toLocal().toIso8601String();
    _text(
      canvas,
      '${AppInfo.appName} · 生成于 ${stamp.substring(0, 16).replaceFirst('T', ' ')}'
      '${document.estimatesRating ? '· 特殊 Rating 由 Rate 估算' : ''}',
      Offset(64, y + 4),
      18,
      FontWeight.normal,
      const Color(0xFF787186),
      1072,
    );
    return y + _footerHeight;
  }

  static void _drawCard(
    Canvas canvas,
    Rect rect,
    B50ImageEntry entry,
    int rank,
    ui.Image? jacket,
  ) {
    final corner = Radius.circular(14);
    final outline = RRect.fromRectAndRadius(rect, corner);
    canvas.drawRRect(
      outline.shift(const Offset(0, 2)),
      Paint()..color = const Color(0x10514274),
    );
    canvas.drawRRect(outline, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipRRect(outline);
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top, 6, rect.height),
      Paint()..color = DifficultyPalette.of(entry.score.levelIndex),
    );
    _drawCover(
      canvas,
      Rect.fromLTWH(rect.left + 13, rect.top + 13, 62, 62),
      jacket,
    );
    final x = rect.left + 86;
    _text(
      canvas,
      '#$rank',
      Offset(x, rect.top + 10),
      20,
      FontWeight.w700,
      const Color(0xFF787186),
      60,
    );
    _text(
      canvas,
      '${entry.score.type == SongType.dx ? 'DX ' : ''}${entry.levelLabel}',
      Offset(x + 55, rect.top + 10),
      20,
      FontWeight.w700,
      DifficultyPalette.of(entry.score.levelIndex),
      180,
    );
    _rightText(
      canvas,
      '${entry.rating}',
      Offset(rect.right - 14, rect.top + 7),
      32,
      const Color(0xFF51347A),
    );
    final titleWidth = entry.fcLabel == null && entry.fsLabel == null
        ? 250.0
        : 210.0;
    _text(
      canvas,
      entry.score.songName,
      Offset(x, rect.top + 37),
      21,
      FontWeight.w600,
      const Color(0xFF272035),
      titleWidth,
    );
    final achievements = entry.achievements;
    final achievementLabel = achievements != null
        ? Utils.formatAchievements(achievements)
        : RateType.labelOf(entry.score.rate);
    _text(
      canvas,
      achievementLabel,
      Offset(rect.right - 137, rect.bottom - 34),
      22,
      FontWeight.w700,
      RatePalette.of(
        achievements == null
            ? entry.score.rate
            : RateType.fromAchievements(achievements),
      ),
      124,
    );
    var badgesRight = rect.right - 141;
    for (final badge in [entry.fsLabel, entry.fcLabel].whereType<String>()) {
      final width = _badgeWidth(badge);
      badgesRight -= width;
      _badge(
        canvas,
        badge,
        Rect.fromLTWH(badgesRight, rect.bottom - 31, width, 22),
        entry.fcLabel == badge
            ? MarkPalette.fc(entry.fc)
            : MarkPalette.fs(entry.fs),
      );
      badgesRight -= 5;
    }
    canvas.restore();
  }

  static double _badgeWidth(String label) => label.length * 10.0 + 16;

  static void _badge(Canvas canvas, String label, Rect rect, Color color) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..color = color,
    );
    _text(
      canvas,
      label,
      Offset(rect.center.dx - _badgeWidth(label) / 2 + 7, rect.top + 3),
      13,
      FontWeight.w700,
      Colors.white,
      rect.width - 14,
    );
  }

  static void _drawCover(Canvas canvas, Rect rect, ui.Image? image) {
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)));
    if (image == null) {
      _drawJacket(canvas, rect, null);
    } else {
      _drawJacket(canvas, rect, image);
    }
    canvas.restore();
  }

  static void _drawJacket(Canvas canvas, Rect rect, ui.Image? image) {
    if (image == null) {
      canvas.drawRect(rect, Paint()..color = const Color(0xFFE4DFF1));
      _text(
        canvas,
        '♪',
        Offset(rect.left + 16, rect.top + 4),
        40,
        FontWeight.w600,
        const Color(0xFF51347A),
        rect.width,
      );
      return;
    }
    final source = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final side = source.shortestSide;
    final crop = Rect.fromCenter(
      center: source.center,
      width: side,
      height: side,
    );
    canvas.drawImageRect(
      image,
      crop,
      rect,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  static void _text(
    Canvas canvas,
    String text,
    Offset offset,
    double size,
    FontWeight weight,
    Color color,
    double maxWidth, [
    TextAlign align = TextAlign.left,
  ]) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: size, fontWeight: weight, color: color),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
    painter.dispose();
  }

  static void _rightText(
    Canvas canvas,
    String text,
    Offset offset,
    double size,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(offset.dx - painter.width, offset.dy));
    painter.dispose();
  }

  static double _layoutHeight(B50ImageDocument document) {
    var height = _headerHeight;
    for (final section in document.sections) {
      height += _sectionHeader;
      if (section.entries.isEmpty) {
        height += 30;
      } else {
        height +=
            (section.entries.length / 2).ceil() * (_cardHeight + _rowGap) -
            _rowGap;
      }
      height += 22;
    }
    return height + _footerHeight;
  }
}

Song? _missingSong(int id) => null;
