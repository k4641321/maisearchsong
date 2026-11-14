import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logger_rs/logger_rs.dart';

import 'constants.dart';

/// 接口调用异常。
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  /// 错误描述。
  final String message;

  /// HTTP 状态码（网络层错误时为 null）。
  final int? statusCode;

  @override
  String toString() => statusCode == null ? message : 'HTTP $statusCode：$message';
}

/// lxns（落雪咖啡屋）舞萌 DX 查分器 API 客户端。
///
/// 负责国服数据的读取：曲库、别名、收藏品、玩家信息、成绩、Rating 趋势。
/// 所有方法在失败时抛出 [ApiException]，由上层统一提示。
class LxnsApiClient {
  LxnsApiClient({http.Client? client, this.timeout = const Duration(seconds: 20)})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// 单次请求超时时间。
  final Duration timeout;

  /// 开发者 API Token（个人数据接口需要，可在设置中填写）。
  String? userToken;

  /// 默认请求头。
  Map<String, String> get _headers => {
    'User-Agent': '${AppInfo.appNameEn}/1.0 (Flutter)',
    'Accept': 'application/json',
    if (userToken != null && userToken!.isNotEmpty)
      'Authorization': 'Bearer $userToken',
  };

  /// 发起 GET 请求并解析 JSON。
  Future<dynamic> _get(String path, {Map<String, dynamic>? query}) async {
    final uri = Uri.parse('${AppInfo.apiBase}$path').replace(
      queryParameters: query?.map((k, v) => MapEntry(k, '$v')),
    );
    try {
      final response = await _client.get(uri, headers: _headers).timeout(timeout);
      if (response.statusCode != 200) {
        throw ApiException(
          _describeBody(response.body),
          statusCode: response.statusCode,
        );
      }
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('请求超时，请检查网络后重试');
    } on SocketException catch (e) {
      throw ApiException('网络不可用：${e.message}');
    } on FormatException {
      throw ApiException('响应内容解析失败');
    }
  }

  /// 把接口返回的错误体转成可读文案。
  String _describeBody(String body) {
    if (body.isEmpty) return '接口无响应内容';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final message = decoded['message'] ?? decoded['error'] ?? decoded['msg'];
        if (message != null) return message.toString();
      }
    } on FormatException {
      // 保持原始文本
    }
    return body.length > 160 ? '${body.substring(0, 160)}…' : body;
  }

  /// 获取曲目列表。
  ///
  /// [version] 为游戏版本号，默认 [AppInfo.defaultVersion]；
  /// [notes] 为是否包含谱面物量。
  Future<Map<String, dynamic>> fetchSongList({
    int version = AppInfo.defaultVersion,
    bool notes = true,
  }) async {
    final data = await _get(
      '/maimai/song/list',
      query: {'version': version, 'notes': notes},
    );
    if (data is! Map) throw ApiException('曲目列表格式异常');
    return Map<String, dynamic>.from(data);
  }

  /// 获取单曲信息。
  Future<Map<String, dynamic>> fetchSong(
    int songId, {
    int version = AppInfo.defaultVersion,
  }) async {
    final data = await _get(
      '/maimai/song/$songId',
      query: {'version': version},
    );
    if (data is! Map) throw ApiException('曲目信息格式异常');
    return Map<String, dynamic>.from(data);
  }

  /// 获取曲目别名列表。
  Future<Map<String, dynamic>> fetchAliasList() async {
    final data = await _get('/maimai/alias/list');
    if (data is! Map) throw ApiException('别名列表格式异常');
    return Map<String, dynamic>.from(data);
  }

  /// 获取收藏品分类列表。
  Future<Map<String, dynamic>> fetchCollectionGenres({
    int version = AppInfo.defaultVersion,
  }) async {
    final data = await _get(
      '/maimai/collection-genre/list',
      query: {'version': version},
    );
    if (data is! Map) throw ApiException('收藏品分类格式异常');
    return Map<String, dynamic>.from(data);
  }

  /// 获取收藏品列表。
  ///
  /// [type] 取值 `trophy`、`icon`、`plate`、`frame`。
  Future<Map<String, dynamic>> fetchCollectionList(
    String type, {
    int version = AppInfo.defaultVersion,
    bool required = true,
  }) async {
    final data = await _get(
      '/maimai/$type/list',
      query: {'version': version, 'required': required},
    );
    if (data is! Map) throw ApiException('收藏品列表格式异常');
    return Map<String, dynamic>.from(data);
  }

  /// 获取单个收藏品信息。
  Future<Map<String, dynamic>> fetchCollection(
    String type,
    int id, {
    int version = AppInfo.defaultVersion,
  }) async {
    final data = await _get(
      '/maimai/$type/$id',
      query: {'version': version},
    );
    if (data is! Map) throw ApiException('收藏品格式异常');
    return Map<String, dynamic>.from(data);
  }

  /// 获取玩家信息。
  Future<Map<String, dynamic>> fetchPlayer(int friendCode) async {
    final data = await _get('/maimai/player/$friendCode');
    if (data is! Map) throw ApiException('玩家信息格式异常');
    return Map<String, dynamic>.from(data);
  }

  /// 通过 QQ 号获取玩家信息。
  Future<Map<String, dynamic>> fetchPlayerByQq(int qq) async {
    final data = await _get('/maimai/player/qq/$qq');
    if (data is! Map) throw ApiException('玩家信息格式异常');
    return Map<String, dynamic>.from(data);
  }

  /// 获取玩家 Best 50。
  Future<Map<String, dynamic>> fetchBests(int friendCode) async {
    final data = await _get('/maimai/player/$friendCode/bests');
    if (data is! Map) throw ApiException('Best 50 格式异常');
    return Map<String, dynamic>.from(data);
  }

  /// 获取玩家 All Perfect 50。
  Future<Map<String, dynamic>> fetchApBests(int friendCode) async {
    final data = await _get('/maimai/player/$friendCode/bests/ap');
    if (data is! Map) throw ApiException('AP 50 格式异常');
    return Map<String, dynamic>.from(data);
  }

  /// 获取玩家 Recent 50。
  Future<List<dynamic>> fetchRecents(int friendCode) async {
    final data = await _get('/maimai/player/$friendCode/recents');
    if (data is! List) throw ApiException('Recent 50 格式异常');
    return data;
  }

  /// 获取玩家单曲最佳成绩。
  Future<Map<String, dynamic>> fetchSongBest({
    required int friendCode,
    required int songId,
    required int levelIndex,
    required SongType type,
  }) async {
    final data = await _get(
      '/maimai/player/$friendCode/best',
      query: {
        'song_id': songId,
        'level_index': levelIndex,
        'song_type': type.value,
      },
    );
    if (data is! Map) throw ApiException('成绩格式异常');
    return Map<String, dynamic>.from(data);
  }

  /// 获取玩家指定曲目在指定谱面类型下的全部难度成绩。
  Future<List<dynamic>> fetchSongScores({
    required int friendCode,
    required int songId,
    required SongType type,
  }) async {
    final data = await _get(
      '/maimai/player/$friendCode/bests',
      query: {'song_id': songId, 'song_type': type.value},
    );
    if (data is! List) throw ApiException('单曲成绩格式异常');
    return data;
  }

  /// 获取玩家全部最佳成绩（简化）。
  Future<List<dynamic>> fetchAllScores(int friendCode) async {
    final data = await _get('/maimai/player/$friendCode/scores');
    if (data is! List) throw ApiException('成绩列表格式异常');
    return data;
  }

  /// 获取玩家 Rating 趋势。
  Future<List<dynamic>> fetchRatingTrend(
    int friendCode, {
    int version = AppInfo.defaultVersion,
  }) async {
    final data = await _get(
      '/maimai/player/$friendCode/trend',
      query: {'version': version},
    );
    if (data is! List) throw ApiException('Rating 趋势格式异常');
    return data;
  }

  /// 获取玩家成绩上传历史。
  Future<List<dynamic>> fetchScoreHistory({
    required int friendCode,
    required int songId,
    required int levelIndex,
    required SongType type,
  }) async {
    final data = await _get(
      '/maimai/player/$friendCode/score/history',
      query: {
        'song_id': songId,
        'level_index': levelIndex,
        'song_type': type.value,
      },
    );
    if (data is! List) throw ApiException('成绩历史格式异常');
    return data;
  }

  /// 获取玩家成绩上传热力图（`YYYY-MM-DD` → 上传数量）。
  Future<Map<String, dynamic>> fetchHeatmap(int friendCode) async {
    final data = await _get('/maimai/player/$friendCode/heatmap');
    if (data is! Map) throw ApiException('热力图格式异常');
    return Map<String, dynamic>.from(data);
  }

  /// 获取玩家收藏品进度。
  Future<Map<String, dynamic>> fetchPlayerCollection({
    required int friendCode,
    required String type,
    required int id,
  }) async {
    final data = await _get('/maimai/player/$friendCode/$type/$id');
    if (data is! Map) throw ApiException('收藏品进度格式异常');
    return Map<String, dynamic>.from(data);
  }

  /// 关闭底层连接。
  void dispose() {
    Log.d('LxnsApiClient disposed');
    _client.close();
  }
}
