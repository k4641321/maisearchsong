import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logger_rs/logger_rs.dart';

import '../models/models.dart';
import 'api_client.dart';
import 'constants.dart';
import 'proxy.dart';
import 'settings.dart';

/// 曲库排序方式。
enum SongSort {
  id('默认', '按曲目 ID'),
  title('曲名', '按曲名字典序'),
  version('版本', '按版本从新到旧'),
  bpm('BPM', '按 BPM 从高到低'),
  level('定数', '按最高定数从高到低');

  const SongSort(this.label, this.description);

  /// 显示名。
  final String label;

  /// 说明。
  final String description;
}

/// 全局应用状态。
class AppState extends ChangeNotifier {
  AppState._();

  /// 单例。
  static final AppState instance = AppState._();

  final LxnsApiClient api = LxnsApiClient();

  /// 设置。
  AppSettings settings = const AppSettings();

  /// 曲库。
  List<Song> songs = const [];

  /// 曲目分类。
  List<Genre> genres = const [];

  /// 版本列表。
  List<VersionInfo> versions = const [];

  /// 收藏夹：文件夹名 → 曲目 ID。
  Map<String, List<int>> favorites = {};

  /// 当前玩家。
  Player? player;

  /// Best 50。
  BestScores? bests;

  /// Rating 趋势。
  List<RatingTrend> trend = const [];

  /// 收藏品缓存：`trophy` / `icon` / `plate` / `frame` → 列表。
  final Map<String, List<Collection>> collections = {};

  /// 玩家全部成绩（`/scores`）。
  List<SimpleScore> allScores = const [];

  /// 曲库是否正在加载。
  bool loading = false;

  /// 是否已完成至少一次加载。
  bool loaded = false;

  /// 错误信息。
  String? error;

  /// 曲库缓存时间。
  DateTime? cacheTime;

  /// 曲目 ID → 曲目。
  final Map<int, Song> _byId = {};

  /// 难度选择（-1 表示不限）。
  int levelFilter = -1;

  /// 类型选择（null 表示不限）。
  SongType? typeFilter;

  /// 定数下限。
  double? constantMin;

  /// 定数上限。
  double? constantMax;

  /// 版本筛选（0 表示不限）。
  int versionFilter = 0;

  /// 分类筛选（空表示不限）。
  String genreFilter = '';

  /// 排序方式。
  SongSort sort = SongSort.id;

  /// 是否有可用的缓存曲库。
  bool get hasCache => songs.isNotEmpty;

  /// 按 ID 取曲目。
  Song? songById(int id) => _byId[id];

  /// 当前选中的收藏夹名。
  String get currentFavoritesFolder =>
      favorites.keys.isEmpty ? '默认' : favorites.keys.last;

  /// 初始化：载入设置、缓存曲库，并尝试后台刷新。
  Future<void> bootstrap() async {
    settings = await SettingsStore.instance.load();
    api.userToken = settings.userToken;
    favorites = await SettingsStore.instance.readFavorites();
    if (settings.proxyEnabled) {
      unawaited(ProxyManager.instance.init());
    }
    notifyListeners();

    final cache = await SettingsStore.instance.readSongCache();
    if (cache != null) {
      try {
        final payload = cache['payload'];
        if (payload is Map) {
          _applySongList(
            SongListData.fromJson(Map<String, dynamic>.from(payload)),
            fromCache: true,
          );
          final savedAt = cache['saved_at'];
          if (savedAt is String) {
            cacheTime = DateTime.tryParse(savedAt);
          }
          notifyListeners();
        }
      } catch (e) {
        Log.w('曲库缓存解析失败：$e');
      }
    }

    unawaited(refresh(force: true));
  }

  /// 拉取曲库（[force] 为 false 且已有缓存时跳过）。
  Future<void> refresh({bool force = false}) async {
    if (loading) return;
    if (!force && loaded && songs.isNotEmpty) return;

    loading = true;
    error = null;
    notifyListeners();

    try {
      final data = await api.fetchSongList(version: settings.version);
      final listData = SongListData.fromJson(data);

      List<SongAlias> aliases = const [];
      try {
        final rawAlias = await api.fetchAliasList();
        aliases = (rawAlias['aliases'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => SongAlias.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (e) {
        Log.w('别名列表获取失败：$e');
      }

      _applySongList(listData, aliases: aliases);
      loaded = true;
      cacheTime = DateTime.now();
      unawaited(SettingsStore.instance.writeSongCache(data));
      Log.i('曲库载入完成：${songs.length} 首');
    } on ApiException catch (e) {
      error = e.toString();
      Log.e('曲库载入失败', error: e);
    } catch (e) {
      error = '$e';
      Log.e('曲库载入异常', error: e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// 应用曲库数据。
  void _applySongList(
    SongListData data, {
    List<SongAlias> aliases = const [],
    bool fromCache = false,
  }) {
    final aliasMap = {
      for (final a in aliases) a.songId: a.aliases,
    };

    applySongList(SongListData(
      songs: data.songs
          .map(
            (s) => aliasMap.containsKey(s.id)
                ? s.withAliases(aliasMap[s.id]!)
                : s,
          )
          .toList(growable: false),
      genres: data.genres,
      versions: data.versions,
    ));
  }

  /// 用一份曲库数据整体替换内存中的曲库，并重建 ID 索引。
  ///
  /// 供缓存载入、离线快照与测试直接注入使用。
  void applySongList(SongListData data) {
    songs = data.songs;
    genres = data.genres;
    versions = data.versions;

    _byId
      ..clear()
      ..addEntries(songs.map((s) => MapEntry(s.id, s)));
    loaded = true;
  }

  /// 载入本地收藏夹里的曲目。
  List<Song> favoriteSongs(String folder) =>
      (favorites[folder] ?? const [])
          .map((id) => _byId[id])
          .whereType<Song>()
          .toList();

  /// 曲目是否已被任意收藏夹收藏。
  bool isFavorite(int songId) =>
      favorites.values.any((ids) => ids.contains(songId));

  /// 按分类名取分类 id（找不到返回 0）。
  int genreIdOf(String genre) {
    for (final g in genres) {
      if (g.genre == genre) return g.id;
    }
    return 0;
  }

  /// 按版本号取版本名。
  String versionTitleOf(int version) {
    for (final v in versions) {
      if (v.version == version) return v.title;
    }
    return '$version';
  }

  /// 切换收藏状态。
  Future<void> toggleFavorite(int songId, {String? folder}) async {
    final name = folder ?? currentFavoritesFolder;
    final ids = List<int>.from(favorites[name] ?? const []);
    if (ids.contains(songId)) {
      ids.remove(songId);
    } else {
      ids.add(songId);
    }
    favorites[name] = ids;
    await SettingsStore.instance.writeFavorite(name, ids);
    notifyListeners();
  }

  /// 新建收藏夹。
  Future<void> createFolder(String name) async {
    if (favorites.containsKey(name)) return;
    favorites[name] = const [];
    await SettingsStore.instance.writeFavorite(name, const []);
    notifyListeners();
  }

  /// 删除收藏夹。
  Future<void> removeFolder(String name) async {
    favorites.remove(name);
    await SettingsStore.instance.deleteFavorite(name);
    notifyListeners();
  }

  /// 更新设置。
  Future<void> updateSettings(AppSettings value) async {
    settings = value;
    api.userToken = value.userToken;
    await SettingsStore.instance.save(value);
    notifyListeners();
  }

  /// 拉取玩家信息与 Best 50（个人 Token 所属玩家）。
  Future<void> loadPlayer() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final rawPlayer = await api.fetchPlayer();
      final rawBests = await api.fetchBests();
      player = Player.fromJson(rawPlayer);
      bests = BestScores.fromJson(rawBests);
      try {
        final rawTrend = await api.fetchRatingTrend();
        trend = rawTrend
            .whereType<Map>()
            .map((e) => RatingTrend.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (e) {
        Log.w('Rating 趋势获取失败：$e');
      }
    } on ApiException catch (e) {
      error = e.toString();
      player = null;
      bests = null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// 清空本地缓存与收藏。
  Future<void> clearLocalData() async {
    await SettingsStore.instance.clearAll();
    favorites = {};
    notifyListeners();
  }

  /// 拉取指定类型的收藏品列表（带内存缓存）。
  Future<List<Collection>> loadCollections(String type) async {
    final cached = collections[type];
    if (cached != null) return cached;
    final raw = await api.fetchCollectionList(type, version: settings.version);
    final list = (raw[switch (type) {
              'trophy' => 'trophies',
              'icon' => 'icons',
              'plate' => 'plates',
              'frame' => 'frames',
              _ => type,
            }] as List? ??
            const [])
        .whereType<Map>()
        .map((e) => Collection.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    collections[type] = list;
    notifyListeners();
    return list;
  }

  /// 已缓存的收藏品数量（未加载时为 0）。
  int collectionCount(String type) => collections[type]?.length ?? 0;

  /// 拉取玩家全部成绩（个人 Token 所属玩家）。
  Future<void> loadAllScores() async {
    loading = true;
    notifyListeners();
    try {
      final raw = await api.fetchAllScores();
      allScores = raw
          .whereType<Map>()
          .map((e) => SimpleScore.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on ApiException catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// 导出收藏夹为 JSON 文本。
  String exportFavorites() => const JsonEncoder.withIndent('  ').convert({
    'app': AppInfo.appNameEn,
    'exported_at': DateTime.now().toIso8601String(),
    'favorites': favorites,
  });

  /// 从 JSON 文本导入收藏夹。
  Future<int> importFavorites(String text) async {
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw const FormatException('不是合法的收藏夹文件');
    final raw = decoded['favorites'];
    if (raw is! Map) throw const FormatException('缺少 favorites 字段');
    var count = 0;
    for (final entry in raw.entries) {
      final ids = (entry.value as List).map((e) => (e as num).toInt()).toList();
      favorites[entry.key.toString()] = ids;
      await SettingsStore.instance.writeFavorite(entry.key.toString(), ids);
      count += ids.length;
    }
    notifyListeners();
    return count;
  }
}
