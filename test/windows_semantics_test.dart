import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maisearchsong/pages/search_page.dart';

void main() {
  testWidgets('切换 IndexedStack 时保留搜索状态', (tester) async {
    final tab = ValueNotifier<int>(0);
    addTearDown(tab.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: ValueListenableBuilder<int>(
          valueListenable: tab,
          builder: (context, index, _) => IndexedStack(
            index: index,
            children: const [
              SearchPage(),
              Scaffold(body: Text('其它页面')),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), '保留这次搜索');
    await tester.pump(const Duration(milliseconds: 300));

    tab.value = 1;
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('其它页面'), findsOneWidget);

    tab.value = 0;
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, '保留这次搜索');
  });
}
