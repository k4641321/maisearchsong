import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:maisearchsong/models/models.dart';
import 'package:maisearchsong/services/b50_image_renderer.dart';

const _oldChart = SongDifficulty(
  type: SongType.standard,
  difficulty: 4,
  level: '14+',
  levelValue: 14.9,
  noteDesigner: '',
  version: 20000,
);

const _newChart = SongDifficulty(
  type: SongType.dx,
  difficulty: 4,
  level: '14+',
  levelValue: 14.9,
  noteDesigner: '',
  version: 27000,
);

SimpleScore _score(int id) => SimpleScore(
  id: id,
  songName: '测试歌曲 ${id.toString().padLeft(2, '0')} · Long song title',
  level: '14+',
  levelIndex: 4,
  type: id.isEven ? SongType.dx : SongType.standard,
  rate: 'sssp',
  fc: 'app',
  fs: 'fsd',
);

B50ImageDocument _specialDocument({int count = 50}) {
  final entries = [
    for (var i = 0; i < count; i++)
      B50ImageEntry.fromSimpleScore(
        _score(i + 1),
        difficulty: (i + 1).isEven ? _newChart : _oldChart,
        rating: 400 - i,
      ),
  ];
  return B50ImageDocument(
    title: 'AP 50',
    subtitle: '按当前榜单排序',
    estimatesRating: true,
    generatedAt: DateTime.utc(2026, 11, 18),
    sections: [
      B50ImageSection(
        title: 'AP 50',
        entries: entries,
        total: entries.fold<int>(0, (sum, e) => sum + e.rating),
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('普通 B50 保留 B35/B15，并使用真实达成率', () {
    const score = Score(
      id: 1,
      songName: '旧曲',
      level: '14+',
      levelIndex: 4,
      type: SongType.standard,
      achievements: 100.5,
      fc: 'app',
      fs: 'fsdp',
      dxRating: 220,
    );
    final document = B50ImageDocument.regular(
      bests: const BestScores(
        standardTotal: 333,
        dxTotal: 120,
        standard: [score],
        dx: [
          Score(
            id: 2,
            songName: '新曲',
            level: '14+',
            levelIndex: 4,
            type: SongType.dx,
            achievements: 99.5234,
            dxRating: 120,
          ),
        ],
      ),
      player: null,
      generatedAt: DateTime.utc(2026, 11, 18),
    );
    expect(document.sections, hasLength(2));
    expect(document.sections[0].entries.single.rating, 333);
    expect(document.sections[0].entries.single.achievements, 100.5);
    expect(document.sections[0].entries.single.score, isA<SimpleScore>());
    expect(document.sections[1].entries.single.rating, 120);
    expect(document.total, 453);
    expect(document.fileName, 'B50_Best 50_2026-11-18.png');
    expect(document.estimatesRating, isFalse);
  });

  test('特殊 B50 完整保留页面顺序、Rating 和缺失谱面', () {
    final document = _specialDocument();
    expect(document.entryCount, 50);
    expect(document.total, (400 + 351) * 50 ~/ 2);
    expect(document.estimatesRating, isTrue);
    expect(document.sections.single.entries.first.rating, 400);
    expect(document.sections.single.entries.last.rating, 351);
    expect(document.sections.single.entries.last.achievements, isNull);
    final unknown = B50ImageEntry.fromSimpleScore(_score(99), difficulty: null);
    expect(unknown.rating, 0);
    expect(unknown.levelLabel, '14+');
  });

  test('完整 50 条和普通双分组都能生成 PNG，无网络也能降级', () async {
    for (final document in [
      _specialDocument(),
      B50ImageDocument.regular(
        bests: const BestScores(),
        generatedAt: DateTime.utc(2026, 11, 18),
      ),
    ]) {
      final height = B50ImageRenderer.heightOf(document).round();
      final bytes = await B50ImageRenderer.draw(document);
      expect(bytes.sublist(0, 8), const [137, 80, 78, 71, 13, 10, 26, 10]);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, B50ImageRenderer.canvasWidth.round());
      expect(frame.image.height, height);
      frame.image.dispose();
      codec.dispose();
    }
    expect(B50ImageRenderer.heightOf(_specialDocument()), 2690);
  });

  test('按需写出测试预览图', () async {
    const path = String.fromEnvironment('B50_PREVIEW_PATH');
    if (path.isEmpty) return;
    final bytes = await B50ImageRenderer.draw(_specialDocument());
    await File(path).writeAsBytes(bytes, flush: true);
  });
}

