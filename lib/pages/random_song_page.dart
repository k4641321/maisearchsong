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

  @override
  Widget build(BuildContext context) {
    final pool = _pool;

    return Scaffold(
      appBar: AppBar(title: const Text('随机歌曲')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('全部分类'),
                      selected: _genreKey.isEmpty,
                      onSelected: (_) => setState(() => _genreKey = ''),
                    ),
                    for (final genre in _state.genres)
                      ChoiceChip(
                        label: Text(genre.title),
                        selected: _genreKey == genre.genre,
                        onSelected: (_) =>
                            setState(() => _genreKey = genre.genre),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('全部版本'),
                      selected: _version == 0,
                      onSelected: (_) => setState(() => _version = 0),
                    ),
                    for (final version in _state.versions.reversed)
                      ChoiceChip(
                        label: Text(version.title),
                        selected: _version == version.version,
                        onSelected: (_) =>
                            setState(() => _version = version.version),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('全部难度'),
                      selected: _level < 0,
                      onSelected: (_) => setState(() => _level = -1),
                    ),
                    for (final level in LevelIndex.values)
                      ChoiceChip(
                        label: Text(level.label),
                        selected: _level == level.value,
                        onSelected: (_) => setState(() => _level = level.value),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
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
          const Divider(height: 12),
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
