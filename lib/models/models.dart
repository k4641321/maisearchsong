import '../core/constants.dart';

/// 数值安全读取工具。
int _asInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

double _asDouble(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

String _asString(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  return v.toString();
}

bool _asBool(dynamic v, [bool fallback = false]) {
  if (v == null) return fallback;
  if (v is bool) return v;
  return v.toString() == 'true';
}

/// 曲目分类。
class Genre {
  const Genre({required this.id, required this.title, required this.genre});

  final int id;

  /// 分类标题（中文）。
  final String title;

  /// 分类标题（日文）。
  final String genre;

  factory Genre.fromJson(Map<String, dynamic> json) => Genre(
    id: _asInt(json['id']),
    title: _asString(json['title']),
    genre: _asString(json['genre']),
  );
}

/// 曲目版本。
class VersionInfo {
  const VersionInfo({
    required this.id,
    required this.title,
    required this.version,
  });

  final int id;

  /// 版本标题。
  final String title;

  /// 版本号，例如 25500。
  final int version;

  factory VersionInfo.fromJson(Map<String, dynamic> json) => VersionInfo(
    id: _asInt(json['id']),
    title: _asString(json['title']),
    version: _asInt(json['version']),
  );
}

/// 谱面物量。
class Notes {
  const Notes({
    required this.total,
    required this.tap,
    required this.hold,
    required this.slide,
    required this.touch,
    required this.breakCount,
  });

  final int total;
  final int tap;
  final int hold;
  final int slide;
  final int touch;
  final int breakCount;

  static const Notes empty = Notes(
    total: 0,
    tap: 0,
    hold: 0,
    slide: 0,
    touch: 0,
    breakCount: 0,
  );

  factory Notes.fromJson(Map<String, dynamic> json) => Notes(
    total: _asInt(json['total']),
    tap: _asInt(json['tap']),
    hold: _asInt(json['hold']),
    slide: _asInt(json['slide']),
    touch: _asInt(json['touch']),
    breakCount: _asInt(json['break']),
  );

  Map<String, dynamic> toJson() => {
    'total': total,
    'tap': tap,
    'hold': hold,
    'slide': slide,
    'touch': touch,
    'break': breakCount,
  };
}

/// 单个谱面难度。
class SongDifficulty {
  const SongDifficulty({
    required this.type,
    required this.difficulty,
    required this.level,
    required this.levelValue,
    required this.noteDesigner,
    required this.version,
    this.notes = Notes.empty,
    this.kanji = '',
    this.description = '',
    this.isBuddy = false,
  });

  /// 谱面类型。
  final SongType type;

  /// 难度索引。
  final int difficulty;

  /// 难度标级，例如 `14+`。
  final String level;

  /// 谱面定数。
  final double levelValue;

  /// 谱师。
  final String noteDesigner;

  /// 谱面首次出现版本。
  final int version;

  /// 物量。
  final Notes notes;

  /// 宴会场谱面属性。
  final String kanji;

  /// 宴会场谱面描述。
  final String description;

  /// 是否为 BUDDY 谱面。
  final bool isBuddy;

  /// 难度枚举。
  LevelIndex get levelIndex => LevelIndex.fromValue(difficulty);

  /// 展示用难度名；宴会场优先显示属性。
  String get displayLevel => kanji.isNotEmpty ? kanji : levelIndex.label;

  /// 是否为宴会场谱面。
  bool get isUtage => type == SongType.utage;

  factory SongDifficulty.fromJson(Map<String, dynamic> json, SongType type) {
    final rawNotes = json['notes'];
    return SongDifficulty(
      type: SongType.fromValue(_asString(json['type'], type.value)),
      difficulty: _asInt(json['difficulty']),
      level: _asString(json['level'], '?'),
      levelValue: _asDouble(json['level_value']),
      noteDesigner: _asString(json['note_designer'], '-'),
      version: _asInt(json['version']),
      notes: rawNotes is Map
          ? Notes.fromJson(Map<String, dynamic>.from(rawNotes))
          : Notes.empty,
      kanji: _asString(json['kanji']),
      description: _asString(json['description']),
      isBuddy: _asBool(json['is_buddy']),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.value,
    'difficulty': difficulty,
    'level': level,
    'level_value': levelValue,
    'note_designer': noteDesigner,
    'version': version,
    'notes': notes.toJson(),
    if (kanji.isNotEmpty) 'kanji': kanji,
    if (description.isNotEmpty) 'description': description,
    if (isBuddy) 'is_buddy': true,
  };
}

/// 曲目。
class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.genre,
    required this.bpm,
    required this.version,
    this.map = '',
    this.rights = '',
    this.locked = false,
    this.disabled = false,
    this.standard = const [],
    this.dx = const [],
    this.utage = const [],
    this.aliases = const [],
  });

  final int id;
  final String title;
  final String artist;

  /// 曲目分类（日文键，如 `POPSアニメ`）。
  final String genre;
  final int bpm;

  /// 曲目所属区域，可能为空。
  final String map;

  /// 首次出现版本号。
  final int version;

  /// 版权信息。
  final String rights;

  /// 是否需要解锁。
  final bool locked;

  /// 是否被禁用（禁用曲目不进入 Best 50）。
  final bool disabled;

  final List<SongDifficulty> standard;
  final List<SongDifficulty> dx;
  final List<SongDifficulty> utage;

  /// 曲目别名。
  final List<String> aliases;

  /// 是否宴会场曲目。
  bool get isUtage => id > 100000;

  /// 全部谱面（标准 → DX → 宴会）。
  List<SongDifficulty> get allDifficulties => [...standard, ...dx, ...utage];

  /// 代表曲绘难度：取最高难度的谱面。
  SongDifficulty? get topDifficulty {
    final all = allDifficulties;
    if (all.isEmpty) return null;
    return all.reduce((a, b) => a.levelValue >= b.levelValue ? a : b);
  }

  /// 取指定类型与难度索引的谱面（找不到返回 null）。
  SongDifficulty? difficultyOf(SongType type, int levelIndex) {
    final list = switch (type) {
      SongType.standard => standard,
      SongType.dx => dx,
      SongType.utage => utage,
    };
    for (final d in list) {
      if (d.difficulty == levelIndex) return d;
    }
    return null;
  }

  /// 返回带别名的拷贝。
  Song withAliases(List<String> value) => Song(
    id: id,
    title: title,
    artist: artist,
    genre: genre,
    bpm: bpm,
    version: version,
    map: map,
    rights: rights,
    locked: locked,
    disabled: disabled,
    standard: standard,
    dx: dx,
    utage: utage,
    aliases: value,
  );

  factory Song.fromJson(Map<String, dynamic> json, {bool withNotes = true}) {
    final difficulties = json['difficulties'];
    final standard = <SongDifficulty>[];
    final dx = <SongDifficulty>[];
    final utage = <SongDifficulty>[];

    if (difficulties is Map) {
      final map = Map<String, dynamic>.from(difficulties);
      for (final raw in (map['standard'] as List? ?? const [])) {
        if (raw is Map) {
          standard.add(
            SongDifficulty.fromJson(
              Map<String, dynamic>.from(raw),
              SongType.standard,
            ),
          );
        }
      }
      for (final raw in (map['dx'] as List? ?? const [])) {
        if (raw is Map) {
          dx.add(
            SongDifficulty.fromJson(Map<String, dynamic>.from(raw), SongType.dx),
          );
        }
      }
      for (final raw in (map['utage'] as List? ?? const [])) {
        if (raw is Map) {
          utage.add(
            SongDifficulty.fromJson(
              Map<String, dynamic>.from(raw),
              SongType.utage,
            ),
          );
        }
      }
    }

    return Song(
      id: _asInt(json['id']),
      title: _asString(json['title']),
      artist: _asString(json['artist']),
      genre: _asString(json['genre']),
      bpm: _asInt(json['bpm']),
      version: _asInt(json['version']),
      map: _asString(json['map']),
      rights: _asString(json['rights']),
      locked: _asBool(json['locked']),
      disabled: _asBool(json['disabled']),
      standard: standard,
      dx: dx,
      utage: utage,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'genre': genre,
    'bpm': bpm,
    'version': version,
    if (map.isNotEmpty) 'map': map,
    if (rights.isNotEmpty) 'rights': rights,
    if (locked) 'locked': true,
    if (disabled) 'disabled': true,
    'difficulties': {
      'standard': standard.map((e) => e.toJson()).toList(),
      'dx': dx.map((e) => e.toJson()).toList(),
      if (utage.isNotEmpty) 'utage': utage.map((e) => e.toJson()).toList(),
    },
  };
}

/// 曲目别名。
class SongAlias {
  const SongAlias({required this.songId, required this.aliases});

  final int songId;
  final List<String> aliases;

  factory SongAlias.fromJson(Map<String, dynamic> json) => SongAlias(
    songId: _asInt(json['song_id']),
    aliases: (json['aliases'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
  );
}

/// 完整曲库响应。
class SongListData {
  const SongListData({
    required this.songs,
    required this.genres,
    required this.versions,
  });

  final List<Song> songs;
  final List<Genre> genres;
  final List<VersionInfo> versions;

  factory SongListData.fromJson(Map<String, dynamic> json) => SongListData(
    songs: (json['songs'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Song.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    genres: (json['genres'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Genre.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    versions: (json['versions'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => VersionInfo.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

/// 玩家信息中的收藏品（仅含 id / name / genre，称号额外含 color）。
class PlayerCollection {
  const PlayerCollection({
    required this.id,
    required this.name,
    this.genre = '',
    this.color,
  });

  final int id;
  final String name;
  final String genre;
  final String? color;

  factory PlayerCollection.fromJson(Map<String, dynamic> json) =>
      PlayerCollection(
        id: _asInt(json['id']),
        name: _asString(json['name']),
        genre: _asString(json['genre']),
        color: json['color'] == null ? null : _asString(json['color']),
      );
}

/// 玩家。
class Player {
  const Player({
    required this.name,
    required this.rating,
    required this.friendCode,
    this.courseRank = 0,
    this.classRank = 0,
    this.star = 0,
    this.trophy,
    this.icon,
    this.namePlate,
    this.frame,
    this.uploadTime = '',
  });

  final String name;
  final int rating;
  final int friendCode;

  /// 段位 ID。
  final int courseRank;

  /// 阶级 ID。
  final int classRank;

  /// 搭档觉醒数。
  final int star;

  final PlayerCollection? trophy;
  final PlayerCollection? icon;
  final PlayerCollection? namePlate;
  final PlayerCollection? frame;

  /// 同步时间（UTC）。
  final String uploadTime;

  factory Player.fromJson(Map<String, dynamic> json) {
    PlayerCollection? sub(String key) {
      final raw = json[key];
      if (raw is Map) {
        return PlayerCollection.fromJson(Map<String, dynamic>.from(raw));
      }
      return null;
    }

    return Player(
      name: _asString(json['name']),
      rating: _asInt(json['rating']),
      friendCode: _asInt(json['friend_code']),
      courseRank: _asInt(json['course_rank']),
      classRank: _asInt(json['class_rank']),
      star: _asInt(json['star']),
      trophy: sub('trophy'),
      icon: sub('icon'),
      namePlate: sub('name_plate'),
      frame: sub('frame'),
      uploadTime: _asString(json['upload_time']),
    );
  }
}

/// 游玩成绩。
class Score {
  const Score({
    required this.id,
    required this.levelIndex,
    required this.type,
    this.songName = '',
    this.level = '',
    this.achievements = 0,
    this.fc,
    this.fs,
    this.dxScore = 0,
    this.dxStar = 0,
    this.dxRating = 0,
    this.rate,
    this.playTime = '',
    this.uploadTime = '',
    this.lastPlayedTime = '',
  });

  final int id;
  final String songName;

  /// 难度标级，如 `14+`。
  final String level;

  final int levelIndex;
  final SongType type;
  final double achievements;
  final String? fc;
  final String? fs;
  final int dxScore;
  final int dxStar;
  final double dxRating;
  final String? rate;
  final String playTime;
  final String uploadTime;
  final String lastPlayedTime;

  LevelIndex get difficulty => LevelIndex.fromValue(levelIndex);

  /// 评级（缺失时按达成率推导）。
  String get rateLabel =>
      rate == null || rate!.isEmpty
      ? RateType.labelOf(RateType.fromAchievements(achievements))
      : RateType.labelOf(rate);

  /// DX Rating（向下取整）。
  int get dxRatingFloor => dxRating.floor();

  factory Score.fromJson(Map<String, dynamic> json) => Score(
    id: _asInt(json['id']),
    songName: _asString(json['song_name']),
    level: _asString(json['level']),
    levelIndex: _asInt(json['level_index']),
    type: SongType.fromValue(_asString(json['type'])),
    achievements: _asDouble(json['achievements']),
    fc: json['fc'] == null ? null : _asString(json['fc']),
    fs: json['fs'] == null ? null : _asString(json['fs']),
    dxScore: _asInt(json['dx_score']),
    dxStar: _asInt(json['dx_star']),
    dxRating: _asDouble(json['dx_rating']),
    rate: json['rate'] == null ? null : _asString(json['rate']),
    playTime: _asString(json['play_time']),
    uploadTime: _asString(json['upload_time']),
    lastPlayedTime: _asString(json['last_played_time']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'song_name': songName,
    'level': level,
    'level_index': levelIndex,
    'type': type.value,
    'achievements': achievements,
    if (fc != null) 'fc': fc,
    if (fs != null) 'fs': fs,
    'dx_score': dxScore,
    'dx_star': dxStar,
    'dx_rating': dxRating,
    if (rate != null) 'rate': rate,
    if (playTime.isNotEmpty) 'play_time': playTime,
    if (uploadTime.isNotEmpty) 'upload_time': uploadTime,
    if (lastPlayedTime.isNotEmpty) 'last_played_time': lastPlayedTime,
  };
}

/// 简化成绩（`/scores` 接口用）。
class SimpleScore {
  const SimpleScore({
    required this.id,
    required this.songName,
    required this.level,
    required this.levelIndex,
    required this.type,
    this.fc,
    this.fs,
    this.rate,
  });

  final int id;
  final String songName;
  final String level;
  final int levelIndex;
  final SongType type;
  final String? fc;
  final String? fs;
  final String? rate;

  LevelIndex get difficulty => LevelIndex.fromValue(levelIndex);

  factory SimpleScore.fromJson(Map<String, dynamic> json) => SimpleScore(
    id: _asInt(json['id']),
    songName: _asString(json['song_name']),
    level: _asString(json['level']),
    levelIndex: _asInt(json['level_index']),
    type: SongType.fromValue(_asString(json['type'])),
    fc: json['fc'] == null ? null : _asString(json['fc']),
    fs: json['fs'] == null ? null : _asString(json['fs']),
    rate: json['rate'] == null ? null : _asString(json['rate']),
  );
}

/// Best 50 结果。
class BestScores {
  const BestScores({
    this.standardTotal = 0,
    this.dxTotal = 0,
    this.standard = const [],
    this.dx = const [],
    this.standardSelections = const [],
    this.dxSelections = const [],
  });

  final int standardTotal;
  final int dxTotal;
  final List<Score> standard;
  final List<Score> dx;
  final List<Score> standardSelections;
  final List<Score> dxSelections;

  int get total => standardTotal + dxTotal;

  List<Score> get all => [...standard, ...dx];

  factory BestScores.fromJson(Map<String, dynamic> json) {
    List<Score> list(String key) => (json[key] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Score.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return BestScores(
      standardTotal: _asInt(json['standard_total']),
      dxTotal: _asInt(json['dx_total']),
      standard: list('standard'),
      dx: list('dx'),
      standardSelections: list('standard_selections'),
      dxSelections: list('dx_selections'),
    );
  }
}

/// 收藏品要求曲目。
class CollectionRequiredSong {
  const CollectionRequiredSong({
    required this.id,
    required this.title,
    required this.type,
    this.completed,
    this.completedDifficulties = const [],
  });

  final int id;
  final String title;
  final SongType type;
  final bool? completed;
  final List<int> completedDifficulties;

  factory CollectionRequiredSong.fromJson(Map<String, dynamic> json) =>
      CollectionRequiredSong(
        id: _asInt(json['id']),
        title: _asString(json['title']),
        type: SongType.fromValue(_asString(json['type'])),
        completed: json['completed'] == null
            ? null
            : _asBool(json['completed']),
        completedDifficulties: (json['completed_difficulties'] as List? ?? const [])
            .map((e) => _asInt(e))
            .toList(),
      );
}

/// 收藏品要求。
class CollectionRequired {
  const CollectionRequired({
    this.difficulties = const [],
    this.rate,
    this.fc,
    this.fs,
    this.songs = const [],
    this.completed,
  });

  final List<int> difficulties;
  final String? rate;
  final String? fc;
  final String? fs;
  final List<CollectionRequiredSong> songs;
  final bool? completed;

  factory CollectionRequired.fromJson(Map<String, dynamic> json) =>
      CollectionRequired(
        difficulties: (json['difficulties'] as List? ?? const [])
            .map((e) => _asInt(e))
            .toList(),
        rate: json['rate'] == null ? null : _asString(json['rate']),
        fc: json['fc'] == null ? null : _asString(json['fc']),
        fs: json['fs'] == null ? null : _asString(json['fs']),
        songs: (json['songs'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => CollectionRequiredSong.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        completed: json['completed'] == null ? null : _asBool(json['completed']),
      );
}

/// 收藏品。
class Collection {
  const Collection({
    required this.id,
    required this.name,
    this.color,
    this.description = '',
    this.genre = '',
    this.required = const [],
  });

  final int id;
  final String name;
  final String? color;
  final String description;
  final String genre;
  final List<CollectionRequired> required;

  factory Collection.fromJson(Map<String, dynamic> json) => Collection(
    id: _asInt(json['id']),
    name: _asString(json['name']),
    color: json['color'] == null ? null : _asString(json['color']),
    description: _asString(json['description']),
    genre: _asString(json['genre']),
    required: (json['required'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => CollectionRequired.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

/// 收藏品分类。
class CollectionGenre {
  const CollectionGenre({
    required this.id,
    required this.title,
    required this.genre,
  });

  final int id;
  final String title;
  final String genre;

  factory CollectionGenre.fromJson(Map<String, dynamic> json) =>
      CollectionGenre(
        id: _asInt(json['id']),
        title: _asString(json['title']),
        genre: _asString(json['genre']),
      );
}

/// DX Rating 趋势点。
class RatingTrend {
  const RatingTrend({
    required this.total,
    required this.standardTotal,
    required this.dxTotal,
    required this.date,
  });

  final int total;
  final int standardTotal;
  final int dxTotal;
  final String date;

  factory RatingTrend.fromJson(Map<String, dynamic> json) => RatingTrend(
    total: _asInt(json['total']),
    standardTotal: _asInt(json['standard_total']),
    dxTotal: _asInt(json['dx_total']),
    date: _asString(json['date']),
  );
}
