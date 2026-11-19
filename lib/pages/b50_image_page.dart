import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/b50_image_renderer.dart';

/// B50 长图的生成进度、预览与导出页。
class B50ImagePage extends StatefulWidget {
  const B50ImagePage({super.key, required this.document});

  final B50ImageDocument document;

  @override
  State<B50ImagePage> createState() => _B50ImagePageState();
}

class _B50ImagePageState extends State<B50ImagePage> {
  Uint8List? _bytes;
  double? _progress;
  String? _error;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _bytes = null;
      _error = null;
      _progress = 0;
    });
    try {
      final bytes = await B50ImageRenderer.generate(
        widget.document,
        onProgress: (done, total) {
          if (mounted && total > 0) setState(() => _progress = done / total);
        },
      );
      if (mounted) setState(() => _bytes = bytes);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<File> _temporaryFile(Uint8List bytes) async {
    final directory = await getTemporaryDirectory();
    final folder = Directory(p.join(directory.path, 'b50_images'));
    await folder.create(recursive: true);
    final file = File(p.join(folder.path, widget.document.fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _share() async {
    final bytes = _bytes;
    if (bytes == null) return;
    final file = await _temporaryFile(bytes);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: '我的 ${widget.document.title} 成绩图',
      ),
    );
  }

  Future<void> _save() async {
    final bytes = _bytes;
    if (bytes == null) return;
    final path = await FilePicker.saveFile(
      dialogTitle: '保存 B50 图片',
      fileName: widget.document.fileName,
      bytes: bytes,
      mimeType: 'image/png',
    );
    if (path != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('图片已保存：$path')));
    }
  }

  Future<void> _export(Future<void> Function() action) async {
    if (_bytes == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.document.title} 图片'),
        actions: [
          if (bytes != null)
            IconButton(
              key: const Key('b50-share-button'),
              tooltip: '分享图片',
              onPressed: _exporting ? null : () => _export(_share),
              icon: const Icon(Icons.share_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: bytes == null
            ? _ProgressView(progress: _progress, error: _error, onRetry: _load)
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      '${widget.document.entryCount} 条成绩 · '
                      '${B50ImageRenderer.canvasWidth.round()} × '
                      '${B50ImageRenderer.heightOf(widget.document).round()} px'
                      ' · 可双指放大预览',
                      key: const Key('b50-generated-preview-label'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4,
                        child: Center(
                          child: Image.memory(bytes, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  ),
                  if (_exporting) const LinearProgressIndicator(minHeight: 2),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('b50-save-button'),
                            onPressed: _exporting ? null : () => _export(_save),
                            icon: const Icon(Icons.save_alt_rounded),
                            label: const Text('保存图片'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _exporting
                                ? null
                                : () => _export(_share),
                            icon: const Icon(Icons.share_rounded),
                            label: const Text('分享图片'),
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

class _ProgressView extends StatelessWidget {
  const _ProgressView({required this.progress, this.error, this.onRetry});

  final double? progress;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重新生成'),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(value: progress),
          const SizedBox(height: 16),
          Text('正在生成图片…（${((progress ?? 0) * 100).round()}%）'),
          const SizedBox(height: 6),
          const Text('正在加载曲绘，加载失败时会使用占位图'),
        ],
      ),
    );
  }
}

