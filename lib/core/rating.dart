import '../models/models.dart';

/// 定数与 Rating 计算。
///
/// 公式：`单谱 Rating = 定数 × 成绩系数`，向下取整；
/// 总 Rating = Best 35（旧版本谱面）+ Best 15（现版本谱面）。
class RatingCalculator {
  const RatingCalculator._();

  /// 标级 → 官方定数（当谱面没有 `level_value` 时兜底）。
  static const Map<String, double> _levelConstants = {
    '1': 1.0,
    '2': 2.0,
    '3': 3.0,
    '4': 4.0,
    '5': 5.0,
    '6': 6.0,
    '7': 7.0,
    '7+': 7.5,
    '8': 8.0,
    '8+': 8.5,
    '9': 9.0,
    '9+': 9.5,
    '10': 10.0,
    '10+': 10.5,
    '11': 11.0,
    '11+': 11.5,
    '12': 12.0,
    '12+': 12.5,
    '13': 13.0,
    '13+': 13.5,
    '14': 14.0,
    '14+': 14.5,
    '15': 15.0,
  };

  /// 标级对应的定数。
  static double levelToConstant(String level) =>
      _levelConstants[level.trim()] ?? 0;

  /// 谱面定数：优先取接口返回值，缺失时按标级兜底。
  static double constantOf(SongDifficulty difficulty) =>
      difficulty.levelValue > 0
      ? difficulty.levelValue
      : levelToConstant(difficulty.level);

  /// 达成率 → 成绩系数。
  static double coefficientOf(double achievements) {
    if (achievements >= 100.5) return 22.4;
    if (achievements >= 100) return 21.6;
    if (achievements >= 99.5) return 21.1;
    if (achievements >= 99) return 20.8;
    if (achievements >= 98) return 20.3;
    if (achievements >= 97) return 20.0;
    if (achievements >= 94) return 16.8;
    if (achievements >= 90) return 15.6;
    if (achievements >= 80) return 13.6;
    if (achievements >= 75) return 12.8;
    if (achievements >= 70) return 12.0;
    if (achievements >= 60) return 11.2;
    if (achievements >= 50) return 9.6;
    if (achievements >= 40) return 8.0;
    if (achievements >= 30) return 6.4;
    if (achievements >= 20) return 4.8;
    if (achievements >= 10) return 3.2;
    return 1.6;
  }

  /// 单谱 Rating（未取整）。
  static double singleRating(double constant, double achievements) =>
      constant * coefficientOf(achievements);

  /// 单谱 Rating（向下取整）。
  static int floorSingleRating(double constant, double achievements) =>
      singleRating(constant, achievements).floor();

  /// 由谱面与成绩计算单谱 Rating（向下取整）。
  static int ratingOfScore(SongDifficulty difficulty, double achievements) =>
      floorSingleRating(constantOf(difficulty), achievements);

  /// 由成绩计算单谱 Rating；曲库中找不到谱面时优先使用成绩自带的 dx_rating。
  static int ratingOfScoreWithSong(Score score, SongDifficulty? difficulty) {
    if (difficulty != null) {
      return ratingOfScore(difficulty, score.achievements);
    }
    return score.dxRating > 0 ? score.dxRating.floor() : 0;
  }

  /// 计算旧版本谱面（Standard）Best 35 总分。
  static int standardTotal(Iterable<int> ratings) => _sumTop(ratings, 35);

  /// 计算现版本谱面（DX）Best 15 总分。
  static int dxTotal(Iterable<int> ratings) => _sumTop(ratings, 15);

  /// 计算总 Rating。
  static int totalRating({
    required Iterable<int> standardRatings,
    required Iterable<int> dxRatings,
  }) => standardTotal(standardRatings) + dxTotal(dxRatings);

  /// 取最大的 [count] 个值求和。
  static int _sumTop(Iterable<int> ratings, int count) {
    final sorted = ratings.toList()..sort((a, b) => b.compareTo(a));
    var sum = 0;
    for (var i = 0; i < count && i < sorted.length; i++) {
      sum += sorted[i];
    }
    return sum;
  }

  /// 达成率对应的建议评价文案。
  static String suggestionFor(int rating, double constant) {
    if (constant <= 0) return '定数未知';
    if (rating <= 0) return '暂无成绩';
    final next = ((rating ~/ constant) + 1) * constant;
    return '当前约 ${rating / constant < 22.4 ? (rating / constant).toStringAsFixed(2) : '22.40'} 系数'
        '，理论上限 ${next.floor()}';
  }
}
