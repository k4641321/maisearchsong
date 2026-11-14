import 'package:flutter/material.dart';

import '../core/app_state.dart';
import 'favorites_page.dart';
import 'search_page.dart';
import 'settings_page.dart';
import 'tools_page.dart';

/// 主框架：底部导航 + 四个主页面。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  static const List<Widget> _pages = [
    SearchPage(),
    FavoritesPage(),
    ToolsPage(),
    SettingsTabPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.search_rounded),
            selectedIcon: Icon(Icons.search_rounded),
            label: '查歌',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: state.favorites.values.any((e) => e.isNotEmpty),
              label: Text('${state.favorites.values.fold<int>(0, (a, b) => a + b.length)}'),
              child: const Icon(Icons.favorite_border_rounded),
            ),
            selectedIcon: const Icon(Icons.favorite_rounded),
            label: '收藏',
          ),
          const NavigationDestination(
            icon: Icon(Icons.handyman_outlined),
            selectedIcon: Icon(Icons.handyman_rounded),
            label: '工具',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
