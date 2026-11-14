import 'dart:convert';

import 'package:crypto/crypto.dart';

/// lxns / 舞萌 DX 相关的静态常量与工具。
class AppInfo {
  const AppInfo._();

  /// 应用展示名。
  static const String appName = '乌蒙查歌';

  /// 英文名 / 拼音代号。
  static const String appNameEn = 'WumengSearchSong';

  /// 当前接入的游戏版本号（舞萌 DX 2025）。
  static const int defaultVersion = 25500;

  /// 国服数据源（落雪咖啡屋 maimai DX 查分器）。
  static const String lxnsWeb = 'https://maimai.lxns.net';

  /// lxns API 根地址。
  static const String apiBase = 'https://maimai.lxns.net/api/v0';

  /// 游戏资源（曲绘 / 音频 / 头像 / 姓名框 / 背景）根地址。
  static const String assetsBase = 'https://assets2.lxns.net/maimai';

  /// 项目仓库地址。
  static const String repoUrl = 'https://github.com/k4641321/chusearchsong_flutter';

  /// 本地数据目录名（设置、收藏、曲库缓存）。
  static const String storageFolderName = 'WumengSearchSong';

  /// 打歌数据查询站。
  static const String chunirecUrl = 'https://www.diving-fish.com/maimaidx/prober/';
}

/// 随应用打包的资源路径。
class Assets {
  const Assets._();

  /// 应用图标。
  static const String icon = 'res/icon.png';

  /// 内置 sing-box 代理配置（参考项目同款依赖，默认不使用）。
  static const String proxyConfig = 'res/maimaiproxy.json';
}

/// 谱面类型。
enum SongType {
  standard('standard', '标准'),
  dx('dx', 'DX'),
  utage('utage', '宴会');

  const SongType(this.value, this.label);

  /// API 中的字符串值。
  final String value;

  /// 中文显示名。
  final String label;

  /// 由 API 字符串解析。
  static SongType fromValue(String? value) {
    return SongType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SongType.standard,
    );
  }
}

/// 难度等级。
enum LevelIndex {
  basic(0, 'BASIC', '绿'),
  advanced(1, 'ADVANCED', '黄'),
  expert(2, 'EXPERT', '红'),
  master(3, 'MASTER', '紫'),
  remaster(4, 'Re:MASTER', '白');

  const LevelIndex(this.value, this.label, this.colorName);

  /// API 中的整数值。
  final int value;

  /// 显示名。
  final String label;

  /// 配色名。
  final String colorName;

  /// 由 API 整数解析。
  static LevelIndex fromValue(int? value) {
    return LevelIndex.values.firstWhere(
      (e) => e.value == value,
      orElse: () => LevelIndex.basic,
    );
  }
}

/// FULL COMBO 类型。
enum FcType {
  app('app', 'AP+'),
  ap('ap', 'AP'),
  fcp('fcp', 'FC+'),
  fc('fc', 'FC');

  const FcType(this.value, this.label);

  final String value;
  final String label;

  static FcType? fromValue(String? value) {
    if (value == null) return null;
    for (final e in FcType.values) {
      if (e.value == value) return e;
    }
    return null;
  }
}

/// FULL SYNC 类型。
enum FsType {
  fsdp('fsdp', 'FDX+'),
  fsd('fsd', 'FDX'),
  fsp('fsp', 'FS+'),
  fs('fs', 'FS'),
  sync('sync', 'SYNC');

  const FsType(this.value, this.label);

  final String value;
  final String label;

  static FsType? fromValue(String? value) {
    if (value == null) return null;
    for (final e in FsType.values) {
      if (e.value == value) return e;
    }
    return null;
  }
}

/// 评级类型。
enum RateType {
  sssp('sssp', 'SSS+'),
  sss('sss', 'SSS'),
  ssp('ssp', 'SS+'),
  ss('ss', 'SS'),
  sp('sp', 'S+'),
  s('s', 'S'),
  aaa('aaa', 'AAA'),
  aa('aa', 'AA'),
  a('a', 'A'),
  bbb('bbb', 'BBB'),
  bb('bb', 'BB'),
  b('b', 'B'),
  c('c', 'C'),
  d('d', 'D');

  const RateType(this.value, this.label);

  final String value;
  final String label;

  static String labelOf(String? value) {
    if (value == null) return '—';
    for (final e in RateType.values) {
      if (e.value == value) return e.label;
    }
    return value;
  }

  /// 由达成率推导评级（用于本地成绩没有 rate 字段时的兜底）。
  static String fromAchievements(double achievements) {
    if (achievements >= 100.5) return sssp.value;
    if (achievements >= 100) return sss.value;
    if (achievements >= 99.5) return ssp.value;
    if (achievements >= 99) return ss.value;
    if (achievements >= 98) return sp.value;
    if (achievements >= 97) return s.value;
    if (achievements >= 94) return aaa.value;
    if (achievements >= 90) return aa.value;
    if (achievements >= 80) return a.value;
    if (achievements >= 75) return bbb.value;
    if (achievements >= 70) return bb.value;
    if (achievements >= 60) return b.value;
    if (achievements >= 50) return c.value;
    return d.value;
  }
}

/// 称号颜色。
enum TrophyColor {
  normal('Normal', '普通'),
  bronze('Bronze', '铜'),
  silver('Silver', '银'),
  gold('Gold', '金'),
  rainbow('Rainbow', '虹');

  const TrophyColor(this.value, this.label);

  final String value;
  final String label;

  static String labelOf(String? value) {
    if (value == null) return '普通';
    for (final e in TrophyColor.values) {
      if (e.value == value) return e.label;
    }
    return '普通';
  }
}

/// 通用小工具。
class Utils {
  const Utils._();

  /// 曲绘 / 头像 / 姓名框 / 背景的资源地址。
  static String jacketUrl(int songId) => '${AppInfo.assetsBase}/jacket/$songId.png';

  /// 曲目试听音频地址。
  static String musicUrl(int songId) => '${AppInfo.assetsBase}/music/$songId.mp3';

  /// 收藏品资源地址。
  static String collectionUrl(String type, int id) {
    final path = switch (type) {
      'icon' => 'icon',
      'plate' => 'plate',
      'frame' => 'frame',
      _ => 'icon',
    };
    return '${AppInfo.assetsBase}/$path/$id.png';
  }

  /// 达成率格式化为 `100.1234%`。
  static String formatAchievements(double value) => '${value.toStringAsFixed(4)}%';

  /// 达成率短格式化为 `100.1234%` 或 `100%`。
  static String formatAchievementsShort(double value) {
    final text = value.toStringAsFixed(4);
    return '${text.endsWith('0000') ? value.toStringAsFixed(0) : text}%';
  }

  /// 计算指定的 djb2 字符串哈希（用于本地缓存键）。
  static String md5Of(String input) =>
      md5.convert(utf8.encode(input)).toString();

  /// 让输入串对大小写、全半角、假名清浊不敏感，便于搜索匹配。
  static String normalize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      var ch = String.fromCharCode(rune);
      // 全角转半角
      if (rune >= 0xFF01 && rune <= 0xFF5E) {
        ch = String.fromCharCode(rune - 0xFEE0);
      } else if (rune == 0x3000) {
        ch = ' ';
      }
      // 假名清浊音
      const kanaMap = {
        'が': 'か', 'ぎ': 'き', 'ぐ': 'く', 'げ': 'け', 'ご': 'こ',
        'ざ': 'さ', 'じ': 'し', 'ず': 'す', 'ぜ': 'せ', 'ぞ': 'そ',
        'だ': 'た', 'ぢ': 'ち', 'づ': 'つ', 'で': 'て', 'ど': 'と',
        'ば': 'は', 'び': 'ひ', 'ぶ': 'ふ', 'べ': 'へ', 'ぼ': 'ほ',
        'ぱ': 'は', 'ぴ': 'ひ', 'ぷ': 'ふ', 'ぺ': 'へ', 'ぽ': 'ほ',
      };
      ch = kanaMap[ch] ?? ch;
      buffer.write(ch);
    }
    return buffer.toString().replaceAll(RegExp(r'[\s\u3000]+'), ' ').trim();
  }

  /// 判断 [text] 是否包含关键词 [keyword]（已做归一化处理）。
  static bool fuzzyContains(String text, String keyword) {
    if (keyword.trim().isEmpty) return true;
    return normalize(text).contains(normalize(keyword));
  }
}
