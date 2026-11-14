// 曲库数据自检工具。
//
// 用法：dart run tool/check_api.dart
//
// 直接调用 [LxnsApiClient] 拉取国服曲库并交给 [SongListData] 解析，
// 用来确认「接口字段 → 模型」这条链路与线上数据保持一致。

import 'dart:io';

import 'package:maisearchsong/core/api_client.dart';
import 'package:maisearchsong/core/constants.dart';
import 'package:maisearchsong/models/models.dart';

Future<void> main() async {
  final client = LxnsApiClient();
  var failures = 0;

  void check(String name, bool ok, [String? detail]) {
    stdout.writeln('${ok ? '  ok  ' : ' FAIL '} $name${detail == null ? '' : ' → $detail'}');
    if (!ok) failures++;
  }

  stdout.writeln('== 曲库 ==');
  final SongListData list;
  try {
    list = SongListData.fromJson(await client.fetchSongList());
  } on ApiException catch (e) {
    stdout.writeln('拉取曲库失败：$e');
    exitCode = 1;
    return;
  }

  check('曲目数量', list.songs.isNotEmpty, '${list.songs.length} 首');
  check('分类数量', list.genres.isNotEmpty, '${list.genres.length} 类');
  check('版本数量', list.versions.isNotEmpty, '${list.versions.length} 个');

  final withStandard = list.songs.where((s) => s.standard.isNotEmpty).length;
  final withDx = list.songs.where((s) => s.dx.isNotEmpty).length;
  final withUtage = list.songs.where((s) => s.utage.isNotEmpty).length;
  check('标准谱面曲目', withStandard > 0, '$withStandard 首');
  check('DX 谱面曲目', withDx > 0, '$withDx 首');
  check('宴会谱面曲目', withUtage > 0, '$withUtage 首');

  // 物量数据是否被正确读入。
  final noted = list.songs
      .expand((s) => [...s.standard, ...s.dx])
      .where((d) => d.notes.total > 0)
      .toList();
  check('物量数据', noted.isNotEmpty, '${noted.length} 个谱面');

  // 定数（level_value）是否读入。
  final leveled = list.songs
      .expand((s) => [...s.standard, ...s.dx])
      .where((d) => d.levelValue > 0)
      .toList();
  check('定数数据', leveled.isNotEmpty, '${leveled.length} 个谱面');

  final highest = leveled.isEmpty
      ? null
      : leveled.reduce((a, b) => a.levelValue >= b.levelValue ? a : b);
  if (highest != null) {
    check('最高定数', highest.levelValue >= 14, '${highest.level} (${highest.levelValue})');
  }

  final sample = list.songs.firstWhere(
    (s) => s.dx.isNotEmpty,
    orElse: () => list.songs.first,
  );
  stdout.writeln(
    '     样例：${sample.title} / ${sample.artist} / BPM ${sample.bpm} / ${sample.genre}',
  );
  final diff = (sample.dx.isNotEmpty ? sample.dx : sample.standard).last;
  stdout.writeln(
    '     ${diff.type.label} ${diff.levelIndex.label} 定数 ${diff.level}'
    ' 物量 ${diff.notes.total}（tap ${diff.notes.tap} / hold ${diff.notes.hold}'
    ' / slide ${diff.notes.slide} / touch ${diff.notes.touch} / break ${diff.notes.breakCount}）',
  );

  stdout.writeln('== 别名 ==');
  try {
    final data = await client.fetchAliasList();
    final aliases = (data['aliases'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => SongAlias.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    check('别名条目', aliases.isNotEmpty, '${aliases.length} 首');
    final withAlias = aliases.where((a) => a.aliases.isNotEmpty).length;
    check('存在别名的曲目', withAlias > 0, '$withAlias 首');
  } on ApiException catch (e) {
    check('别名接口', false, '$e');
  }

  stdout.writeln('== 收藏品 ==');
  try {
    final genres = await client.fetchCollectionGenres();
    final raw = genres['collectionGenres'] ?? genres['collection_genres'];
    final parsed = (raw as List? ?? const [])
        .whereType<Map>()
        .map((e) => CollectionGenre.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    check('收藏品分类', parsed.isNotEmpty, '${parsed.length} 类');
  } on ApiException catch (e) {
    check('收藏品分类接口', false, '$e');
  }

  const collectionKeys = {
    'trophy': 'trophies',
    'icon': 'icons',
    'plate': 'plates',
    'frame': 'frames',
  };
  for (final entry in collectionKeys.entries) {
    try {
      final data = await client.fetchCollectionList(entry.key);
      final list = (data[entry.value] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Collection.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      check('${entry.key} 列表', list.isNotEmpty, '${list.length} 个');
    } on ApiException catch (e) {
      check('${entry.key} 列表', false, '$e');
    }
  }

  stdout.writeln('== 资源地址 ==');
  try {
    final uri = Uri.parse(Utils.jacketUrl(sample.id));
    final request = await HttpClient().getUrl(uri);
    final response = await request.close();
    await response.drain<void>();
    check('曲绘可访问', response.statusCode == 200, '${response.statusCode} $uri');
  } catch (e) {
    check('曲绘可访问', false, '$e');
  }

  stdout.writeln('== 单曲 & 搜索 ==');
  try {
    final one = Song.fromJson(await client.fetchSong(sample.id));
    check('单曲详情', one.id == sample.id, one.title);
  } on ApiException catch (e) {
    check('单曲详情', false, '$e');
  }

  final keyword = sample.title.split(' ').first;
  final matched = list.songs.where((s) => Utils.fuzzyContains(s.title, keyword)).length;
  check('关键词检索', matched > 0, '「$keyword」命中 $matched 首');

  client.dispose();
  stdout.writeln(failures == 0 ? '\n全部检查通过' : '\n$failures 项检查失败');
  if (failures > 0) exitCode = 1;
}
