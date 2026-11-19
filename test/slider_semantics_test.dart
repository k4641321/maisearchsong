import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maisearchsong/pages/settings_page.dart';

void main() {
  testWidgets('字号 Slider 保留无障碍语义并使用局部 Overlay', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsTabPage(),
      ),
    );
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    await tester.pump();

    final slider = find.byType(Slider);
    expect(slider, findsOneWidget);
    final overlays = tester.widgetList<Overlay>(
      find.ancestor(of: slider, matching: find.byType(Overlay)),
    );
    expect(
      overlays.where(
        (overlay) =>
            overlay.alwaysSizeToContent &&
            overlay.clipBehavior == Clip.none,
      ),
      hasLength(1),
    );
    expect(tester.getSemantics(slider).flagsCollection.isSlider, isTrue);
    expect(tester.takeException(), isNull);
  });
}
