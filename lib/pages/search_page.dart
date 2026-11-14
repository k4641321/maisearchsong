import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_state.dart';
import '../core/constants.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/song_widgets.dart';
import 'song_info_page.dart';

/// 查歌页：关键词检索 + 多维筛选 + 排序。
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final AppState _state = AppState.instance;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;

  String _keyword = '';
  /// 当前展示条数（分页加载，避免一次渲染上千行）。
  int _visible = 60;

  @override
  void initState() {
    super.initState();
    _state.addListener(_onChanged);
    _scroll.addListener(_onScroll);
    _controller.text = _keyword;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _state.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (_scroll.position.pixels > max - 600) {
      setState(() => _visible += 60);
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      setState(() {
        _keyword = value;
        _visible = 60;
      });
    });
  }

  /// 关键词与筛选条件过滤。
  List<Song> _filtered() {
    final keyword = _keyword.trim();
    final state = _state;

    final result = state.songs.where((song) {
      // 难度筛选
      if (state.levelFilter >= 0) {
        final has = song.allDifficulties.any(
          (d) => d.type != SongType.utage && d.difficulty == state.levelFilter,
        );
        if (!has) return false;
      }
      // 类型筛选
      if (state.typeFilter != null && state.typeFilter != SongType.utage) {
        final has = song.allDifficulties.any((d) => d.type == state.typeFilter);
        if (!has) return false;
      }
      if (state.typeFilter == SongType.utage && !song.isUtage) return false;
      // 版本筛选
      if (state.versionFilter > 0 && song.version != state.versionFilter) {
        return false;
      }
      // 分类筛选
      if (state.genreFilter.isNotEmpty && song.genre != state.genreFilter) {
        return false;
      }
      // 定数区间
      if (state.constantMin != null || state.constantMax != null) {
        final has = song.allDifficulties.any((d) {
          final c = d.levelValue;
          if (c <= 0) return false;
          if (state.constantMin != null && c < state.constantMin!) return false;
          if (state.constantMax != null && c > state.constantMax!) return false;
          return true;
        });
        if (!has) return false;
      }
      // 关键词
      if (keyword.isEmpty) return true;
      if (Utils.fuzzyContains(song.title, keyword)) return true;
      if (Utils.fuzzyContains(song.artist, keyword)) return true;
      if (song.aliases.any((a) => Utils.fuzzyContains(a, keyword))) return true;
      if (song.allDifficulties.any(
        (d) => Utils.fuzzyContains(d.noteDesigner, keyword),
      )) {
        return true;
      }
      if (song.id.toString() == keyword) return true;
      return false;
    }).toList();

    _sort(result);
    return result;
  }

  void _sort(List<Song> list) {
    switch (_state.sort) {
      case SongSort.id:
        list.sort((a, b) => a.id.compareTo(b.id));
      case SongSort.title:
        list.sort((a, b) => a.title.compareTo(b.title));
      case SongSort.version:
        list.sort((a, b) {
          final byVersion = b.version.compareTo(a.version);
          return byVersion != 0 ? byVersion : a.id.compareTo(b.id);
        });
      case SongSort.bpm:
        list.sort((a, b) => b.bpm.compareTo(a.bpm));
      case SongSort.level:
        list.sort((a, b) {
          final av = a.topDifficulty?.levelValue ?? 0;
          final bv = b.topDifficulty?.levelValue ?? 0;
          final byLevel = bv.compareTo(av);
          return byLevel != 0 ? byLevel : a.id.compareTo(b.id);
        });
    }
  }

  bool get _hasFilter =>
      _state.levelFilter >= 0 ||
      _state.typeFilter != null ||
      _state.versionFilter > 0 ||
      _state.genreFilter.isNotEmpty ||
      _state.constantMin != null ||
      _state.constantMax != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = _state;
    final results = state.loaded || state.songs.isNotEmpty
        ? _filtered()
        : const <Song>[];
    final shown = results.take(_visible).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppInfo.appName),
        actions: [
          IconButton(
            tooltip: '排序',
            onPressed: _showSortSheet,
            icon: const Icon(Icons.sort_rounded),
          ),
          IconButton(
            tooltip: '刷新曲库',
            onPressed: state.loading ? null : () => state.refresh(force: true),
            icon: state.loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.search,
                    onChanged: _onQueryChanged,
                    decoration: InputDecoration(
                      hintText: '曲名 / 曲师 / 别名 / 谱师 / ID',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _controller.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _controller.clear();
                                _onQueryChanged('');
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: _hasFilter,
                  child: IconButton.filledTonal(
                    tooltip: '筛选',
                    onPressed: () => _showFilterSheet(context),
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ),
              ],
            ),
          ),
          if (_hasFilter)
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  if (state.levelFilter >= 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text(
                          LevelIndex.fromValue(state.levelFilter).label,
                        ),
                        onDeleted: () => setState(() => state.levelFilter = -1),
                      ),
                    ),
                  if (state.typeFilter != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text(state.typeFilter!.label),
                        onDeleted: () => setState(() => state.typeFilter = null),
                      ),
                    ),
                  if (state.constantMin != null || state.constantMax != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text(
                          '定数 ${state.constantMin?.toStringAsFixed(1) ?? '0'}'
                          ' ~ ${state.constantMax?.toStringAsFixed(1) ?? '∞'}',
                        ),
                        onDeleted: () => setState(() {
                          state.constantMin = null;
                          state.constantMax = null;
                        }),
                      ),
                    ),
                  if (state.versionFilter > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text(
                          state.versions
                                  .where((v) => v.version == state.versionFilter)
                                  .map((v) => v.title)
                                  .firstOrNull ??
                              '${state.versionFilter}',
                        ),
                        onDeleted: () => setState(() => state.versionFilter = 0),
                      ),
                    ),
                  if (state.genreFilter.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text(state.genreFilter),
                        onDeleted: () => setState(() => state.genreFilter = ''),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                Text(
                  '共 ${results.length} 首',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  state.cacheTime == null
                      ? '未缓存'
                      : '更新于 ${DateFormat('MM-dd HH:mm').format(state.cacheTime!)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StateView(
              loading: state.loading && state.songs.isEmpty,
              error: state.songs.isEmpty ? state.error : null,
              onRetry: () => state.refresh(force: true),
              empty: shown.isEmpty,
              emptyText: _keyword.isEmpty ? '没有符合条件的曲目' : '找不到「$_keyword」',
              emptyIcon: Icons.search_off_rounded,
              child: RefreshIndicator(
                onRefresh: () => state.refresh(force: true),
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: shown.length,
                  itemBuilder: (context, index) {
                    final song = shown[index];
                    return SongCard(
                      song: song,
                      subtitle: song.aliases.isEmpty
                          ? null
                          : song.aliases.take(3).join(' / '),
                      isFavorite:
                          (state.favorites[state.currentFavoritesFolder] ??
                                  const [])
                              .contains(song.id),
                      onFavorite: () => state.toggleFavorite(song.id),
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

  void _showSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: RadioGroup<SongSort>(
          groupValue: _state.sort,
          onChanged: (value) {
            setState(() => _state.sort = value ?? SongSort.id);
            Navigator.of(context).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  '排序方式',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              for (final sort in SongSort.values)
                RadioListTile<SongSort>(
                  value: sort,
                  title: Text(sort.label),
                  subtitle: Text(sort.description),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    final state = _state;
    var level = state.levelFilter;
    SongType? type = state.typeFilter;
    var version = state.versionFilter;
    var genre = state.genreFilter;
    var min = state.constantMin;
    var max = state.constantMax;
    final minController = TextEditingController(
      text: min?.toStringAsFixed(1) ?? '',
    );
    final maxController = TextEditingController(
      text: max?.toStringAsFixed(1) ?? '',
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => DraggableScrollableSheet(
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
                      level = -1;
                      type = null;
                      version = 0;
                      genre = '';
                      min = null;
                      max = null;
                      minController.clear();
                      maxController.clear();
                    }),
                    child: const Text('重置'),
                  ),
                ],
              ),
              const Divider(),
              const _SectionLabel('难度'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('不限'),
                    selected: level < 0,
                    onSelected: (_) => setSheetState(() => level = -1),
                  ),
                  for (final item in LevelIndex.values)
                    ChoiceChip(
                      label: Text('${item.label} ${item.colorName}'),
                      selected: level == item.value,
                      onSelected: (_) =>
                          setSheetState(() => level = item.value),
                    ),
                ],
              ),
              const _SectionLabel('谱面类型'),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('不限'),
                    selected: type == null,
                    onSelected: (_) => setSheetState(() => type = null),
                  ),
                  for (final item in SongType.values)
                    ChoiceChip(
                      label: Text(item.label),
                      selected: type == item,
                      onSelected: (_) => setSheetState(() => type = item),
                    ),
                ],
              ),
              const _SectionLabel('定数区间'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: '下限'),
                      onChanged: (v) =>
                          setSheetState(() => min = double.tryParse(v)),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('~'),
                  ),
                  Expanded(
                    child: TextField(
                      controller: maxController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: '上限'),
                      onChanged: (v) =>
                          setSheetState(() => max = double.tryParse(v)),
                    ),
                  ),
                ],
              ),
              const _SectionLabel('版本'),
              DropdownMenu<int>(
                initialSelection: version,
                width: MediaQuery.sizeOf(context).width - 32,
                label: const Text('版本'),
                onSelected: (v) => setSheetState(() => version = v ?? 0),
                dropdownMenuEntries: [
                  const DropdownMenuEntry(value: 0, label: '不限'),
                  for (final v in state.versions.reversed)
                    DropdownMenuEntry(value: v.version, label: v.title),
                ],
              ),
              const _SectionLabel('分类'),
              DropdownMenu<String>(
                initialSelection: genre,
                width: MediaQuery.sizeOf(context).width - 32,
                label: const Text('分类'),
                onSelected: (v) => setSheetState(() => genre = v ?? ''),
                dropdownMenuEntries: [
                  const DropdownMenuEntry(value: '', label: '不限'),
                  for (final g in state.genres)
                    DropdownMenuEntry(value: g.genre, label: g.title),
                ],
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    state.levelFilter = level;
                    state.typeFilter = type;
                    state.versionFilter = version;
                    state.genreFilter = genre;
                    state.constantMin = min;
                    state.constantMax = max;
                    _visible = 60;
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
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
