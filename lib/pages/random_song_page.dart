import 'dart:math';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/constants.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/song_widgets.dart';
import 'song_info_page.dart';

/// 随机歌曲 / 出勤转盘。
class RandomSongPage extends StatefulWidget {
  const RandomSongPage({super.key});

  @override
  State<RandomSongPage> createState() => _RandomSongPageState();
}

class _RandomSongPageState extends State<RandomSongPage> {
  final AppState _state = AppState.instance;
  final Random _random = Random();
  final List<Song> _history = [];

  String _genreKey = '';
  int _version = 0;
  int _level = -1;

  @override
  void initState() {
    super.initState();
    _state.addListener(_onChanged);
  }

  @override
  void dispose() {
    _state.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  List<Song> get _pool => _state.songs.where((song) {
    if (_genreKey.isNotEmpty && song.genre != _genreKey) return false;
    if (_version != 0 && song.version != _version) return false;
    if (_level >= 0 &&
        !song.allDifficulties.any((d) => d.difficulty == _level)) {
      return false;
    }
    return true;
  }).toList();

  void _roll() {
    final pool = _pool;
    if (pool.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前条件下没有曲目')));
      return;
    }
    final song = pool[_random.nextInt(pool.length)];
    setState(() {
      _history.insert(0, song);
      if (_history.length > 30) _history.removeLast();
    });
  }

  bool get _hasFilter => _genreKey.isNotEmpty || _version != 0 || _level >= 0;

  String get _genreTitle {
    for (final genre in _state.genres) {
      if (genre.genre == _genreKey) return genre.title;
    }
    return _genreKey;
  }

  String get _versionTitle {
    for (final version in _state.versions) {
      if (version.version == _version) return version.title;
    }
    return '$_version';
  }

  void _showFilterSheet() {
    var genreKey = _genreKey;
    var version = _version;
    var level = _level;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          top: false,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            maxChildSize: 0.94,
            builder: (context, scrollController) => ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Row(
                  children: [
                    Text(
                      '筛选条件',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setSheetState(() {
                        genreKey = '';
                        version = 0;
                        level = -1;
                      }),
                      child: const Text('重置'),
                    ),
                  ],
                ),
                const Divider(),
                const _FilterSectionLabel('分类'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('全部分类'),
                      selected: genreKey.isEmpty,
                      onSelected: (_) => setSheetState(() => genreKey = ''),
                    ),
                    for (final genre in _state.genres)
                      ChoiceChip(
                        label: Text(genre.title),
                        selected: genreKey == genre.genre,
                        onSelected: (_) =>
                            setSheetState(() => genreKey = genre.genre),
                      ),
                  ],
                ),
                const _FilterSectionLabel('版本'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('全部版本'),
                      selected: version == 0,
                      onSelected: (_) => setSheetState(() => version = 0),
                    ),
                    for (final item in _state.versions.reversed)
                      ChoiceChip(
                        label: Text(item.title),
                        selected: version == item.version,
                        onSelected: (_) =>
                            setSheetState(() => version = item.version),
                      ),
                  ],
                ),
                const _FilterSectionLabel('难度'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('全部难度'),
                      selected: level < 0,
                      onSelected: (_) => setSheetState(() => level = -1),
                    ),
                    for (final item in LevelIndex.values)
                      ChoiceChip(
                        label: Text(item.label),
                        selected: level == item.value,
                        onSelected: (_) =>
                            setSheetState(() => level = item.value),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _genreKey = genreKey;
                      _version = version;
                      _level = level;
                    });
                    Navigator.of(sheetContext).pop();
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('应用筛选'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pool = _pool;

    return Scaffold(
      appBar: AppBar(
        title: const Text('随机歌曲'),
        actions: [
          Badge(
            isLabelVisible: _hasFilter,
            child: IconButton.filledTonal(
              tooltip: '筛选',
              onPressed: _showFilterSheet,
              icon: const Icon(Icons.tune_rounded),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Text('候选 ${pool.length} 首'),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _roll,
                  icon: const Icon(Icons.casino_rounded, size: 18),
                  label: const Text('抽一首'),
                ),
              ],
            ),
          ),
          if (_hasFilter)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  if (_genreKey.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text('分类：$_genreTitle'),
                        onDeleted: () => setState(() => _genreKey = ''),
                      ),
                    ),
                  if (_version != 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text('版本：$_versionTitle'),
                        onDeleted: () => setState(() => _version = 0),
                      ),
                    ),
                  if (_level >= 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text('难度：${LevelIndex.fromValue(_level).label}'),
                        onDeleted: () => setState(() => _level = -1),
                      ),
                    ),
                ],
              ),
            ),
          const Divider(height: 8),
          Expanded(
            child: _history.isEmpty
                ? const StateView(
                    empty: true,
                    emptyIcon: Icons.casino_rounded,
                    emptyText: '设置条件后点击「抽一首」',
                    child: SizedBox.shrink(),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final song = _history[index];
                      return SongCard(
                        song: song,
                        isFavorite: _state.isFavorite(song.id),
                        onFavorite: () => _state.toggleFavorite(song.id),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SongInfoPage(songId: song.id),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterSectionLabel extends StatelessWidget {
  const _FilterSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}
