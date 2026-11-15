import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/song_widgets.dart';
import 'song_info_page.dart';

/// 收藏夹页：多文件夹管理 + 导入导出。
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final AppState _state = AppState.instance;
  String _folder = '';

  @override
  void initState() {
    super.initState();
    _state.addListener(_onChanged);
    _folder = _state.currentFavoritesFolder;
  }

  @override
  void dispose() {
    _state.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {
      if (!_state.favorites.containsKey(_folder)) {
        _folder = _state.currentFavoritesFolder;
      }
    });
  }

  List<Song> get _songs => _state.favoriteSongs(_folder);

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final folders = state.favorites.keys.toList();
    if (folders.isNotEmpty && !folders.contains(_folder)) {
      _folder = folders.first;
    }
    final total = state.favorites.values.fold<int>(0, (a, b) => a + b.length);

    return Scaffold(
      appBar: AppBar(
        title: const Text('收藏夹'),
        actions: [
          IconButton(
            tooltip: '新建收藏夹',
            onPressed: _createFolder,
            icon: const Icon(Icons.create_new_folder_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'export':
                  await _export();
                case 'import':
                  await _import();
                case 'delete':
                  await _deleteFolder();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'export', child: Text('导出为 JSON')),
              const PopupMenuItem(value: 'import', child: Text('从 JSON 导入')),
              PopupMenuItem(
                value: 'delete',
                enabled: folders.length > 1,
                child: Text('删除「$_folder」'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (folders.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                children: [
                  for (final name in folders) ...[
                    ChoiceChip(
                      label: Text(
                        '$name (${state.favorites[name]?.length ?? 0})',
                      ),
                      selected: name == _folder,
                      onSelected: (_) => setState(() => _folder = name),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '本地共收藏 $total 首',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StateView(
              empty: _songs.isEmpty,
              emptyText: '这个收藏夹还空着',
              emptyIcon: Icons.favorite_border_rounded,
              child: RefreshIndicator(
                onRefresh: () => state.refresh(force: true),
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 90),
                  itemCount: _songs.length,
                  itemBuilder: (context, index) {
                    final song = _songs[index];
                    return SongCard(
                      song: song,
                      isFavorite: true,
                      onFavorite: () => state.toggleFavorite(song.id, folder: _folder),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SongInfoPage(songId: song.id),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建收藏夹'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '收藏夹名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await _state.createFolder(name);
      setState(() => _folder = name);
    }
  }

  Future<void> _deleteFolder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除「$_folder」'),
        content: const Text('仅删除本地收藏记录，不影响落雪账号数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _state.removeFolder(_folder);
      setState(() => _folder = _state.currentFavoritesFolder);
    }
  }

  Future<void> _export() async {
    final text = _state.exportFavorites();
    try {
      final uri = await FilePicker.saveFile(
        dialogTitle: '导出收藏夹',
        fileName: 'maisearchsong_favorites.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: utf8.encode(text),
      );
      if (uri == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已取消导出')));
        return;
      }
      // file_picker v13 在传入 bytes 时会自动写入文件，
      // 返回的 uri 即用户选择的目标位置，无需再手动 writeAsString。
      if (!mounted) return;
      final displayPath =
          uri.isScheme('file') ? uri.toFilePath() : uri.toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已导出到 $displayPath')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出失败：$e')));
    }
  }

  Future<void> _import() async {
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: '导入收藏夹',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (files.isEmpty) return; // 用户取消时返回空列表
      final path = files.first.path;
      if (path == null) return;
      final text = await File(path).readAsString();
      final count = await _state.importFavorites(text);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已导入 $count 条收藏记录')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导入失败：$e')));
    }
  }
}
