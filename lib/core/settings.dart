import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_db/flutter_local_db.dart';
import 'package:logger_rs/logger_rs.dart';
import 'package:path_provider/path_provider.dart';

import 'constants.dart';

/// 应用设置项。
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.useDynamicColor = true,
    this.seedColorValue = 0xFFFF5FA2,
    this.userToken = '',
    this.version = AppInfo.defaultVersion,
    this.musicAutoplay = false,
    this.proxyEnabled = false,
    this.fontScale = 1.0,
  });

  /// 主题模式。
  final ThemeMode themeMode;

  /// 是否使用系统取色（Material You）。
  final bool useDynamicColor;

  /// 品牌主色。
  final int seedColorValue;

  /// lxns 个人 API Token（账号详情页生成）。
  final String userToken;

  /// 默认曲库版本号。
  final int version;

  /// 进入曲目详情是否自动试听。
  final bool musicAutoplay;

  /// 是否启用内置代理（sing-box）。
  final bool proxyEnabled;

  /// 字号缩放。
  final double fontScale;

  /// 品牌主色。
  Color get seedColor => Color(seedColorValue);

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? useDynamicColor,
    int? seedColorValue,
    String? userToken,
    int? version,
    bool? musicAutoplay,
    bool? proxyEnabled,
    double? fontScale,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    useDynamicColor: useDynamicColor ?? this.useDynamicColor,
    seedColorValue: seedColorValue ?? this.seedColorValue,
    userToken: userToken ?? this.userToken,
    version: version ?? this.version,
    musicAutoplay: musicAutoplay ?? this.musicAutoplay,
    proxyEnabled: proxyEnabled ?? this.proxyEnabled,
    fontScale: fontScale ?? this.fontScale,
  );

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.name,
    'useDynamicColor': useDynamicColor,
    'seedColorValue': seedColorValue,
    'userToken': userToken,
    'version': version,
    'musicAutoplay': musicAutoplay,
    'proxyEnabled': proxyEnabled,
    'fontScale': fontScale,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    themeMode: ThemeMode.values.firstWhere(
      (e) => e.name == json['themeMode'],
      orElse: () => ThemeMode.system,
    ),
    useDynamicColor: json['useDynamicColor'] as bool? ?? true,
    seedColorValue: (json['seedColorValue'] as num?)?.toInt() ?? 0xFFFF5FA2,
    userToken: json['userToken'] as String? ?? '',
    version: (json['version'] as num?)?.toInt() ?? AppInfo.defaultVersion,
    musicAutoplay: json['musicAutoplay'] as bool? ?? false,
    proxyEnabled: json['proxyEnabled'] as bool? ?? false,
    fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
  );
}

/// 设置与本地数据的持久化。
///
/// 首选 [LocalDB]（flutter_local_db，原生 LMDB / Web IndexedDB）；
/// 在其不可用时自动回退到应用目录下的 JSON 文件，保证任何平台都能启动。
class SettingsStore {
  SettingsStore._();

  static final SettingsStore instance = SettingsStore._();

  static const String _settingsKey = 'app_settings';
  static const String _favoritePrefix = 'fav:';
  static const String _songCacheKey = 'song_list_cache';

  AppSettings _settings = const AppSettings();
  bool _useFileBackend = false;
  File? _file;

  /// 当前设置。
  AppSettings get settings => _settings;

  /// 是否正在使用文件后端（LocalDB 不可用）。
  bool get isFileBackend => _useFileBackend;

  /// 初始化存储后端并载入设置。
  ///
  /// 依次尝试 LocalDB → 可写目录下的 JSON 文件。任何一步失败都会降级到
  /// 下一级，保证应用在任何权限环境下都能启动并记住设置。
  Future<AppSettings> load() async {
    final baseDir = await _resolveWritableDir();

    if (baseDir != null) {
      try {
        final result = await LocalDB.init(
          path: '${baseDir.path}${Platform.pathSeparator}local_database',
        );
        final failed = result.when(ok: (_) => false, err: (e) => true);
        if (failed || !LocalDB.isInitialized) {
          Log.w('本地数据库不可用，改用文件存储');
          _useFileBackend = true;
        } else {
          Log.i('本地数据库就绪：${baseDir.path}');
        }
      } catch (e) {
        Log.w('LocalDB 初始化失败，改用文件存储：$e');
        _useFileBackend = true;
      }
    } else {
      _useFileBackend = true;
    }

    if (_useFileBackend) {
      await _initFileBackend(baseDir);
    }

    final raw = await _read(_settingsKey);
    if (raw != null) {
      _settings = AppSettings.fromJson(raw);
    }
    return _settings;
  }

  /// 写入设置。
  Future<void> save(AppSettings value) async {
    _settings = value;
    await _write(_settingsKey, value.toJson());
  }

  /// 读取缓存曲库（原始 JSON）。
  Future<Map<String, dynamic>?> readSongCache() => _read(_songCacheKey);

  /// 写入曲库缓存。
  Future<void> writeSongCache(Map<String, dynamic> payload) =>
      _write(_songCacheKey, {
        'saved_at': DateTime.now().toIso8601String(),
        'payload': payload,
      });

  /// 读取全部收藏夹：`文件夹名 -> 曲目 id 列表`。
  Future<Map<String, List<int>>> readFavorites() async {
    final result = <String, List<int>>{};
    final all = await _readAll();
    for (final entry in all.entries) {
      if (!entry.key.startsWith(_favoritePrefix)) continue;
      final name = entry.key.substring(_favoritePrefix.length);
      final raw = entry.value['ids'];
      if (raw is List) {
        result[name] = raw.map((e) => (e as num).toInt()).toList();
      }
    }
    return result;
  }

  /// 保存单个收藏夹。
  Future<void> writeFavorite(String folder, List<int> ids) =>
      _write('$_favoritePrefix$folder', {'ids': ids});

  /// 删除收藏夹。
  Future<void> deleteFavorite(String folder) => _delete('$_favoritePrefix$folder');

  /// 清空全部本地记录。
  Future<void> clearAll() async {
    if (_useFileBackend) {
      final f = _file;
      if (f != null && await f.exists()) await f.delete();
      return;
    }
    await LocalDB.ClearData();
  }

  // ---------------------------------------------------------------- 内部实现

  /// 找一个真正可写的存储目录。
  ///
  /// 某些受限环境（比如被沙箱包装的桌面进程）里 `path_provider` 返回的
  /// 应用支持目录建不出来，这里按优先级逐个探测：应用支持目录 →
  /// 应用文档目录 → 可执行文件旁 → 系统临时目录。全部不可写时返回
  /// `null`，由调用方退化为纯内存存储。
  Future<Directory?> _resolveWritableDir() async {
    final candidates = <Directory>[];

    Future<void> tryAdd(Future<Directory> Function() getter) async {
      try {
        candidates.add(await getter());
      } catch (e) {
        Log.d('目录候选不可用：$e');
      }
    }

    await tryAdd(getApplicationSupportDirectory);
    await tryAdd(getApplicationDocumentsDirectory);
    try {
      // 放在可执行文件旁的 userdata/，避免和 Flutter 的 data/flutter_assets 混用。
      candidates.add(Directory(
        '${File(Platform.resolvedExecutable).parent.path}'
        '${Platform.pathSeparator}userdata',
      ));
    } catch (_) {}
    try {
      candidates.add(Directory.systemTemp);
    } catch (_) {}

    for (final dir in candidates) {
      final target = Directory(
        '${dir.path}${Platform.pathSeparator}${AppInfo.storageFolderName}',
      );
      try {
        if (!await target.exists()) {
          await target.create(recursive: true);
        }
        // 真正写一次，避免 exists() 通过但写入被拒的情况。
        final probe = File(
          '${target.path}${Platform.pathSeparator}.write_probe',
        );
        await probe.writeAsString('ok');
        await probe.delete();
        Log.i('存储目录：${target.path}');
        return target;
      } catch (e) {
        Log.d('存储目录不可写：${target.path}（$e）');
      }
    }
    return null;
  }

  Future<void> _initFileBackend(Directory? baseDir) async {
    if (baseDir == null) {
      Log.w('没有可写的存储目录，设置将仅在本次运行内保留');
      _file = null;
      return;
    }
    try {
      _file = File('${baseDir.path}${Platform.pathSeparator}maisearchsong.json');
      if (!await _file!.exists()) {
        await _file!.writeAsString('{}');
      }
    } catch (e) {
      Log.w('文件存储不可用，设置将仅在本次运行内保留：$e');
      _file = null;
    }
  }

  Future<Map<String, Map<String, dynamic>>> _readAll() async {
    if (_useFileBackend) {
      final f = _file;
      if (f == null || !await f.exists()) return {};
      try {
        final decoded = jsonDecode(await f.readAsString());
        if (decoded is Map) {
          return decoded.map(
            (k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)),
          );
        }
      } catch (e) {
        Log.w('本地文件损坏，已忽略：$e');
      }
      return {};
    }

    try {
      final result = await LocalDB.GetAll();
      return result.when(
        ok: (records) => {
          for (final r in records) r.id: r.data,
        },
        err: (e) {
          Log.w('读取本地数据库失败：$e');
          return <String, Map<String, dynamic>>{};
        },
      );
    } catch (e) {
      Log.e('读取本地数据库异常', error: e);
      return {};
    }
  }

  Future<Map<String, dynamic>?> _read(String key) async {
    if (_useFileBackend) {
      final all = await _readAll();
      return all[key];
    }
    try {
      final result = await LocalDB.GetById(key);
      return result.when(ok: (model) => model?.data, err: (e) {
        Log.w('读取 $key 失败：$e');
        return null;
      });
    } catch (e) {
      Log.e('读取 $key 异常', error: e);
      return null;
    }
  }

  Future<void> _write(String key, Map<String, dynamic> data) async {
    if (_useFileBackend) {
      final all = await _readAll();
      all[key] = data;
      await _file?.writeAsString(jsonEncode(all));
      return;
    }
    try {
      final result = await LocalDB.Post(key, data);
      result.when(
        ok: (_) {},
        err: (e) => Log.w('写入 $key 失败：$e'),
      );
    } catch (e) {
      Log.e('写入 $key 异常', error: e);
    }
  }

  Future<void> _delete(String key) async {
    if (_useFileBackend) {
      final all = await _readAll();
      all.remove(key);
      await _file?.writeAsString(jsonEncode(all));
      return;
    }
    try {
      await LocalDB.Delete(key);
    } catch (e) {
      Log.e('删除 $key 异常', error: e);
    }
  }
}
