import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/constants.dart';
import '../core/palette.dart';
import '../models/models.dart';
import '../widgets/common.dart';

/// 收藏品种类。
enum CollectionType {
  trophy('trophy', '称号', 'trophies'),
  icon('icon', '头像', 'icons'),
  plate('plate', '姓名框', 'plates'),
  frame('frame', '背景框', 'frames');

  const CollectionType(this.value, this.label, this.responseKey);

  /// 接口路径段。
  final String value;

  /// 中文名。
  final String label;

  /// 列表响应里的字段名。
  final String responseKey;
}

/// 收藏品查询页：称号 / 头像 / 姓名框 / 背景框。
class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key, required this.type});

  /// 初始种类。
  final CollectionType type;

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage>
    with SingleTickerProviderStateMixin {
  final AppState _state = AppState.instance;
  late final TabController _tabs = TabController(
    length: CollectionType.values.length,
    initialIndex: CollectionType.values.indexOf(widget.type),
    vsync: this,
  );

  final TextEditingController _keyword = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _state.addListener(_onChanged);
    _tabs.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _state.removeListener(_onChanged);
    _tabs.removeListener(_onChanged);
    _tabs.dispose();
    _keyword.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  CollectionType get _current => CollectionType.values[_tabs.index];

  Future<void> _load() async {
    try {
      await _state.loadCollections(_current.value);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('收藏品获取失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _state.collections[_current.value] ?? const <Collection>[];
    final filtered = _query.isEmpty
        ? list
        : list.where((c) {
            return c.name.contains(_query) ||
                c.description.contains(_query) ||
                '${c.id}' == _query.trim();
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('收藏品查询'),
        bottom: TabBar(
          controller: _tabs,
          onTap: (_) => _load(),
          tabs: [
            for (final type in CollectionType.values) Tab(text: type.label),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: _keyword,
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: InputDecoration(
                hintText: '搜索${_current.label}名称、描述或 ID',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _keyword.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: StateView(
              loading: _state.loading && list.isEmpty,
              error: _state.error != null && list.isEmpty ? _state.error : null,
              empty: filtered.isEmpty,
              emptyIcon: Icons.workspace_premium_outlined,
              emptyText: list.isEmpty ? '正在等待收藏品数据' : '没有匹配的收藏品',
              onRetry: _load,
              child: GridView.builder(
                padding: const EdgeInsets.only(left: 10, right: 10, bottom: 90),
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 170,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.82,
                    ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return _CollectionTile(
                    type: _current,
                    collection: item,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CollectionDetailPage(
                          type: _current,
                          collection: item,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.type,
    required this.collection,
    required this.onTap,
  });

  final CollectionType type;
  final Collection collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = type == CollectionType.trophy
        ? TrophyPalette.of(collection.color)
        : theme.colorScheme.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Image.network(
                  Utils.collectionUrl(type.value, collection.id),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '#${collection.id}　${collection.genre}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 收藏品详情：说明与达成条件。
class CollectionDetailPage extends StatefulWidget {
  const CollectionDetailPage({
    super.key,
    required this.type,
    required this.collection,
  });

  final CollectionType type;
  final Collection collection;

  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<CollectionDetailPage> {
  final AppState _state = AppState.instance;
  Collection? _detail;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _state.api.fetchCollection(
        widget.type.value,
        widget.collection.id,
        version: _state.settings.version,
      );
      if (mounted) setState(() => _detail = Collection.fromJson(data));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('详情获取失败：$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Collection get _item => _detail ?? widget.collection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = _item;
    final color = widget.type == CollectionType.trophy
        ? TrophyPalette.of(item.color)
        : theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: Text(item.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Center(
            child: Image.network(
              Utils.collectionUrl(widget.type.value, item.id),
              height: 160,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                Icons.image_not_supported_outlined,
                size: 64,
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              RateBadge(label: widget.type.label, color: color),
              RateBadge(label: '#${item.id}', color: theme.colorScheme.primary),
              if (item.genre.isNotEmpty)
                RateBadge(
                  label: item.genre,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              if (item.color != null)
                RateBadge(
                  label: TrophyColor.labelOf(item.color),
                  color: TrophyPalette.of(item.color),
                ),
            ],
          ),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(item.description, style: theme.textTheme.bodyMedium),
          ],
          if (_loading) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
          if (item.required.isEmpty && !_loading) ...[
            const SizedBox(height: 20),
            const Text('该收藏品没有公开的达成条件列表。'),
          ],
          for (var i = 0; i < item.required.length; i++)
            _RequiredCard(
              index: i + 1,
              required: item.required[i],
              songs: _state.songs,
            ),
        ],
      ),
    );
  }
}

class _RequiredCard extends StatelessWidget {
  const _RequiredCard({
    required this.index,
    required this.required,
    required this.songs,
  });

  final int index;
  final CollectionRequired required;
  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final difficulties = required.difficulties
        .map((d) => LevelIndex.fromValue(d).label)
        .join(' / ');

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '条件 $index',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (required.completed == true)
                  const RateBadge(
                    label: '已完成',
                    color: Color(0xFF66BB6A),
                  ),
              ],
            ),
            if (difficulties.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('难度：$difficulties'),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (required.rate != null)
                  RateBadge(
                    label: RateType.labelOf(required.rate),
                    color: RatePalette.of(required.rate),
                  ),
                if (required.fc != null)
                  RateBadge(
                    label: FcType.fromValue(required.fc)?.label ?? required.fc!,
                    color: MarkPalette.fc(required.fc),
                  ),
                if (required.fs != null)
                  RateBadge(
                    label: FsType.fromValue(required.fs)?.label ?? required.fs!,
                    color: MarkPalette.fs(required.fs),
                  ),
              ],
            ),
            if (required.songs.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '指定曲目（${required.songs.where((s) => s.completed == true).length}'
                '/${required.songs.length}）',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final song in required.songs)
                    Chip(
                      avatar: CircleAvatar(
                        backgroundColor: song.completed == true
                            ? const Color(0xFF66BB6A)
                            : theme.colorScheme.outlineVariant,
                        radius: 7,
                        child: Icon(
                          song.completed == true
                              ? Icons.check_rounded
                              : Icons.music_note_rounded,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                      label: Text(
                        song.title.isEmpty
                            ? '${song.type.label} #${song.id}'
                            : song.title,
                        style: const TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
