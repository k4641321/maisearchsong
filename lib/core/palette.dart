import 'package:flutter/material.dart';

import 'constants.dart';

/// 难度配色（对标游戏内难度色）。
class DifficultyPalette {
  const DifficultyPalette._();

  static const Map<LevelIndex, Color> _colors = {
    LevelIndex.basic: Color(0xFF4CAF50),
    LevelIndex.advanced: Color(0xFFFFC107),
    LevelIndex.expert: Color(0xFFF44336),
    LevelIndex.master: Color(0xFF9C27B0),
    LevelIndex.remaster: Color(0xFFE0E0E0),
  };

  /// 难度主色。
  static Color of(int levelIndex) =>
      _colors[LevelIndex.fromValue(levelIndex)] ?? const Color(0xFF9E9E9E);

  /// 宴会场谱面使用的强调色。
  static const Color utage = Color(0xFFFF6F00);

  /// 取难度前景色（白字或黑字）。
  static Color onColor(int levelIndex) {
    final color = of(levelIndex);
    return color.computeLuminance() > 0.6 ? Colors.black87 : Colors.white;
  }
}

/// 评级配色。
class RatePalette {
  const RatePalette._();

  static const Map<String, Color> _colors = {
    'sssp': Color(0xFF29B6F6),
    'sss': Color(0xFF26A69A),
    'ssp': Color(0xFF66BB6A),
    'ss': Color(0xFF9CCC65),
    'sp': Color(0xFFFFD54F),
    's': Color(0xFFFFB74D),
    'aaa': Color(0xFFFF8A65),
    'aa': Color(0xFFEF5350),
    'a': Color(0xFFBA68C8),
    'bbb': Color(0xFF9575CD),
    'bb': Color(0xFF7986CB),
    'b': Color(0xFF64B5F6),
    'c': Color(0xFF90A4AE),
    'd': Color(0xFF78909C),
  };

  /// 评级主色。
  static Color of(String? rate) =>
      _colors[rate ?? 'd'] ?? const Color(0xFF9E9E9E);
}

/// 称号配色。
class TrophyPalette {
  const TrophyPalette._();

  static const Map<String, Color> _colors = {
    'Normal': Color(0xFF9E9E9E),
    'Bronze': Color(0xFFB87333),
    'Silver': Color(0xFFB0BEC5),
    'Gold': Color(0xFFFFD54F),
    'Rainbow': Color(0xFF7C4DFF),
  };

  /// 称号颜色。
  static Color of(String? color) =>
      _colors[color ?? 'Normal'] ?? const Color(0xFF9E9E9E);
}

/// 成绩标记（FC / FS）配色。
class MarkPalette {
  const MarkPalette._();

  /// FULL COMBO 颜色。
  static Color fc(String? fc) {
    return switch (fc) {
      'app' => const Color(0xFFFF7043),
      'ap' => const Color(0xFFFFB300),
      'fcp' => const Color(0xFF42A5F5),
      'fc' => const Color(0xFF66BB6A),
      _ => Colors.transparent,
    };
  }

  /// FULL SYNC 颜色。
  static Color fs(String? fs) {
    return switch (fs) {
      'fsdp' => const Color(0xFFFF7043),
      'fsd' => const Color(0xFFAB47BC),
      'fsp' => const Color(0xFF42A5F5),
      'fs' => const Color(0xFF26A69A),
      'sync' => const Color(0xFF78909C),
      _ => Colors.transparent,
    };
  }
}

/// 主题配色。
class AppPalette {
  const AppPalette._();

  /// 品牌主色（舞萌紫粉）。
  static const Color seed = Color(0xFFFF5FA2);

  /// 深色背景。
  static const Color darkBackground = Color(0xFF121216);

  /// 卡片圆角。
  static const double cardRadius = 14;

  /// 由难度与类型给出谱面标签色。
  static Color chartTag(SongType type, int levelIndex) =>
      type == SongType.utage ? DifficultyPalette.utage : DifficultyPalette.of(levelIndex);
}
