import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maisearchsong/core/app_state.dart';
import 'package:maisearchsong/core/constants.dart';
import 'package:maisearchsong/models/models.dart';
import 'package:maisearchsong/pages/random_song_page.dart';

void _primeState() {
  final state = AppState.instance;
  state.favorites = {};
  state.applySongList(
    SongListData(
      songs: List.generate(
        40,
        (index) => Song(
          id: index + 1,
          title: '测试歌曲 ${index + 1}',
          artist: '测试曲师',
          genre: index < 20 ? 'POPS' : 'GAME',
          bpm: 120,
          version: index < 20 ? 10000 : 20000,
          standard: const [
            SongDifficulty(
              type: SongType.standard,
              difficulty: 3,
              level: '12',
              levelValue: 12.0,
              noteDesigner: '-',
              version: 10000,
            ),
          ],
        ),
      ),
      genres: [
        const Genre(id: 1, title: '流行 / 动漫', genre: 'POPS'),
        const Genre(id: 2, title: '游戏 & 其他', genre: 'GAME'),
        for (var i = 3; i <= 8; i++)
          Genre(id: i, title: '测试分类 $i', genre: 'GENRE$i'),
      ],
      versions: List.generate(
        30,
        (index) => VersionInfo(
          id: index + 1,
          title: switch (index) {
            0 => '初始版本',
            1 => '新版本',
            _ => '测试版本 $index',
          },
          version: (index + 1) * 10000,
        ),
      ),
    ),
  );
}

void _usePhoneSize(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 640);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _pumpPage(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: RandomSongPage()));
  await tester.pump();
}

void main() {
  setUp(_primeState);

  testWidgets('窄屏大量筛选项不会挤掉可滚动的抽取历史', (tester) async {
    _usePhoneSize(tester);
    await _pumpPage(tester);

    expect(find.text('候选 40 首'), findsOneWidget);
    expect(find.text('全部分类'), findsNothing);
    expect(find.text('设置条件后点击「抽一首」'), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (var i = 0; i < 12; i++) {
      await tester.tap(find.text('抽一首'));
      await tester.pump();
    }

    final list = find.byType(ListView);
    expect(list, findsOneWidget);
    final scrollable = find.descendant(
      of: list,
      matching: find.byType(Scrollable),
    );
    await tester.drag(list, const Offset(0, -300));
    await tester.pump();

    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(0),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('筛选弹层可滚动且应用分类后更新候选数量', (tester) async {
    _usePhoneSize(tester);
    await _pumpPage(tester);

    await tester.tap(find.byTooltip('筛选'));
    await tester.pumpAndSettle();
    expect(find.text('筛选条件'), findsOneWidget);

    await tester.tap(find.text('流行 / 动漫'));
    await tester.pump();

    final sheetScrollable = find.descendant(
      of: find.byType(DraggableScrollableSheet),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('应用筛选'),
      240,
      scrollable: sheetScrollable,
    );
    await tester.tap(find.text('应用筛选'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('分类：流行 / 动漫'), findsOneWidget);
    expect(find.text('候选 20 首'), findsOneWidget);
    expect(find.text('设置条件后点击「抽一首」'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
