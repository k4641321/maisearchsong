// 用真实曲库快照驱动各页面的渲染测试，确认界面在真实数据下可用。
//
// 断言方式是"抓取所有渲染出的文本 + 检查关键行数量"，既不依赖网络，
// 也能发现空列表、解析失败之类只在真实数据下暴露的问题。

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger_rs/logger_rs.dart';

import 'package:maisearchsong/core/app_state.dart';
import 'package:maisearchsong/models/models.dart';
import 'package:maisearchsong/pages/collection_page.dart';
import 'package:maisearchsong/pages/favorites_page.dart';
import 'package:maisearchsong/pages/player_page.dart';
import 'package:maisearchsong/pages/rating_calc_page.dart';
import 'package:maisearchsong/pages/search_page.dart';
import 'package:maisearchsong/pages/song_info_page.dart';
import 'package:maisearchsong/pages/tools_page.dart';

/// 读取仓库里的真实曲库快照。
SongListData loadSnapshot() {
  final f = File('_ref/songlist.json');
  expect(f.existsSync(), isTrue, reason: '缺少曲库快照 _ref/songlist.json');
  return SongListData.fromJson(
    Map<String, dynamic>.from(jsonDecode(f.readAsStringSync()) as Map),
  );
}

/// 把曲库灌进全局状态，跳过网络请求。
void primeState(SongListData data) {
  final state = AppState.instance;
  state.applySongList(data);
  state.loading = false;
  state.error = null;
}

/// 收集整棵树里所有可读文本。
List<String> allTexts(WidgetTester tester) {
  final out = <String>[];
  for (final w in tester.widgetList<Text>(find.byType(Text))) {
    final t = w.data ?? w.textSpan?.toPlainText();
    if (t != null && t.trim().isNotEmpty) out.add(t.trim());
  }
  return out;
}

Future<void> pumpPage(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  late SongListData data;

  setUpAll(() {
    Log.init(level: Level.SEVERE);
    data = loadSnapshot();
  });

  setUp(() => primeState(data));

  testWidgets('曲库快照解析出足量曲目与筛选元数据', (tester) async {
    expect(data.songs.length, greaterThan(1000));
    expect(data.genres, isNotEmpty);
    expect(data.versions, isNotEmpty);

    final first = data.songs.first;
    expect(first.id, greaterThan(0));
    expect(first.title, isNotEmpty);
    expect(first.allDifficulties, isNotEmpty);
  });

  testWidgets('查歌页渲染曲目卡片', (tester) async {
    await pumpPage(tester, const SearchPage());
    final texts = allTexts(tester);
    expect(texts, isNotEmpty);
    // 首页应当直接铺出可滚动的曲目列表。
    expect(find.byType(ListView).evaluate().isNotEmpty ||
        find.byType(CustomScrollView).evaluate().isNotEmpty, isTrue);
    expect(find.byType(Card).evaluate().length, greaterThan(3));
  });

  testWidgets('收藏页空态提示可见', (tester) async {
    AppState.instance.favorites = {};
    await pumpPage(tester, const FavoritesPage());
    final texts = allTexts(tester);
    expect(texts, isNotEmpty);
  });

  testWidgets('工具页列出全部入口', (tester) async {
    await pumpPage(tester, const ToolsPage());
    // 工具页是长列表，逐段下滑收集，避免只看到首屏被懒加载裁掉的项。
    final seen = <String>{};
    for (var i = 0; i < 8; i++) {
      seen.addAll(allTexts(tester));
      await tester.drag(find.byType(ListView).first, const Offset(0, -320));
      await tester.pump(const Duration(milliseconds: 50));
    }
    seen.addAll(allTexts(tester));

    for (final label in [
      '玩家查询',
      'Rating 趋势',
      '吃分建议',
      '随机歌曲 / 出勤转盘',
      '单曲 Rating 计算器',
      '容错计算',
      '称号查询',
      '头像查询',
    ]) {
      expect(
        seen.any((t) => t.contains(label)),
        isTrue,
        reason: '缺少入口：$label',
      );
    }
  });

  testWidgets('曲目详情页能显示真实曲目信息', (tester) async {
    final song = data.songs.firstWhere((s) => s.allDifficulties.length >= 4);
    await pumpPage(tester, SongInfoPage(songId: song.id));
    final texts = allTexts(tester);
    expect(texts, isNotEmpty);
    expect(texts.any((t) => t.contains(song.title)), isTrue,
        reason: '详情页未显示曲名 ${song.title}');
  });

  testWidgets('单曲 Rating 计算器可输入并出结果', (tester) async {
    await pumpPage(tester, const RatingCalcPage());
    final fields = find.byType(TextField);
    expect(fields.evaluate(), isNotEmpty);
    await tester.enterText(fields.first, '14.5');
    await tester.pump(const Duration(milliseconds: 50));
    final texts = allTexts(tester);
    expect(texts, isNotEmpty);
  });

  testWidgets('玩家页无数据时给出提示而非崩溃', (tester) async {
    await pumpPage(tester, const PlayerPage());
    expect(find.byType(PlayerPage), findsOneWidget);
    expect(allTexts(tester), isNotEmpty);
  });

  testWidgets('收藏品页能打开并渲染', (tester) async {
    await pumpPage(tester, const CollectionPage(type: CollectionType.trophy));
    expect(find.byType(CollectionPage), findsOneWidget);
  });
}
