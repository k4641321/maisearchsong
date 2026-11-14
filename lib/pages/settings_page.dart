import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_state.dart';
import '../core/constants.dart';
import '../core/palette.dart';
import '../core/proxy.dart';

/// 设置页。
class SettingsTabPage extends StatefulWidget {
  const SettingsTabPage({super.key});

  @override
  State<SettingsTabPage> createState() => _SettingsTabPageState();
}

class _SettingsTabPageState extends State<SettingsTabPage> {
  final AppState _state = AppState.instance;
  final TextEditingController _token = TextEditingController();
  String _version = '';
  String _coreVersion = '';

  @override
  void initState() {
    super.initState();
    _state.addListener(_onChanged);
    _token.text = _state.settings.userToken;
    _loadInfo();
  }

  @override
  void dispose() {
    _state.removeListener(_onChanged);
    _token.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = '${info.version}+${info.buildNumber}');
      }
    } catch (_) {
      // 忽略
    }
    try {
      await ProxyManager.instance.init();
      final core = await ProxyManager.instance.coreVersion();
      if (mounted) setState(() => _coreVersion = core);
    } catch (_) {
      // 平台不支持时忽略
    }  }

  @override
  Widget build(BuildContext context) {
    final settings = _state.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 90),
        children: [
          const _Header('外观'),
          ListTile(
            leading: const Icon(Icons.brightness_6_rounded),
            title: const Text('主题模式'),
            subtitle: Text(switch (settings.themeMode) {
              ThemeMode.system => '跟随系统',
              ThemeMode.light => '浅色',
              ThemeMode.dark => '深色',
            }),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.auto_mode_rounded)),
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded)),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded)),
              ],
              selected: {settings.themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (value) => _state.updateSettings(
                settings.copyWith(themeMode: value.first),
              ),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.palette_rounded),
            title: const Text('使用系统取色'),
            subtitle: const Text('Material You，Android 12+ 生效'),
            value: settings.useDynamicColor,
            onChanged: (value) => _state.updateSettings(
              settings.copyWith(useDynamicColor: value),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.colorize_rounded),
            title: const Text('品牌主色'),
            subtitle: const Text('关闭系统取色后生效'),
            trailing: Container(
              width: 40,
              height: 26,
              decoration: BoxDecoration(
                color: settings.seedColor,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onTap: _pickColor,
          ),
          ListTile(
            leading: const Icon(Icons.format_size_rounded),
            title: const Text('字号缩放'),
            subtitle: Slider(
              value: settings.fontScale,
              min: 0.85,
              max: 1.3,
              divisions: 9,
              label: settings.fontScale.toStringAsFixed(2),
              onChanged: (value) => _state.updateSettings(
                settings.copyWith(fontScale: value),
              ),
            ),
            trailing: Text('${(settings.fontScale * 100).round()}%'),
          ),

          const _Header('数据源'),
          ListTile(
            leading: const Icon(Icons.cloud_rounded),
            title: const Text('落雪咖啡屋'),
            subtitle: const Text(AppInfo.lxnsWeb),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => launchUrl(
              Uri.parse(AppInfo.lxnsWeb),
              mode: LaunchMode.externalApplication,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.numbers_rounded),
            title: const Text('曲库版本号'),
            subtitle: const Text('对应落雪 API 的 version 参数'),
            trailing: DropdownButton<int>(
              value: _state.versions.any((v) => v.version == settings.version)
                  ? settings.version
                  : AppInfo.defaultVersion,
              underline: const SizedBox.shrink(),
              items: [
                if (!_state.versions.any((v) => v.version == settings.version))
                  DropdownMenuItem(
                    value: settings.version,
                    child: Text('${settings.version}'),
                  ),
                for (final v in _state.versions.reversed)
                  DropdownMenuItem(value: v.version, child: Text('${v.version}')),
              ],
              onChanged: (value) async {
                if (value == null) return;
                await _state.updateSettings(settings.copyWith(version: value));
                await _state.refresh(force: true);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.key_rounded),
            title: const Text('开发者 Token'),
            subtitle: Text(
              settings.userToken.isEmpty ? '未设置（仅影响需鉴权的接口）' : '已设置',
            ),
            trailing: const Icon(Icons.edit_rounded, size: 18),
            onTap: _editToken,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vpn_lock_rounded),
            title: const Text('内置加速线路'),
            subtitle: Text(
              !ProxyManager.isSupported
                  ? '仅 Android 端可用，当前平台直连'
                  : (ProxyManager.instance.isRunning ? '已连接' : '未连接（默认直连）'),
            ),
            value: settings.proxyEnabled && ProxyManager.isSupported,
            onChanged: !ProxyManager.isSupported
                ? null
                : (value) async {
                    final messenger = ScaffoldMessenger.of(context);
                    await _state.updateSettings(
                      settings.copyWith(proxyEnabled: value),
                    );
                    if (value) {
                      await ProxyManager.instance.loadAssetConfig();
                      final ok = await ProxyManager.instance.connect();
                      if (!ok) {
                        final reason =
                            ProxyManager.instance.lastError ?? '未知原因';
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(content: Text('连接失败：$reason')),
                        );
                      }
                    } else {
                      await ProxyManager.instance.disconnect();
                    }
                    if (mounted) setState(() {});
                  },
          ),

          const _Header('本地数据'),
          ListTile(
            leading: const Icon(Icons.storage_rounded),
            title: const Text('本地缓存'),
            subtitle: Text(
              '${_state.songs.length} 首曲目'
              '${_state.cacheTime == null ? '' : '　更新于 ${_state.cacheTime}'}',
            ),
            trailing: TextButton(
              onPressed: () => _state.refresh(force: true),
              child: const Text('立即刷新'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_rounded),
            title: const Text('清除本地数据'),
            subtitle: const Text('曲库缓存与收藏夹都会被删除'),
            onTap: _clearData,
          ),

          const _Header('关于'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(AppInfo.appName),
            subtitle: Text('版本 ${_version.isEmpty ? '—' : _version}'),
          ),
          ListTile(
            leading: const Icon(Icons.memory_rounded),
            title: const Text('代理内核版本'),
            subtitle: Text(_coreVersion.isEmpty ? '不可用' : _coreVersion),
          ),
          ListTile(
            leading: const Icon(Icons.code_rounded),
            title: const Text('参考项目'),
            subtitle: const Text(AppInfo.repoUrl),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => launchUrl(
              Uri.parse(AppInfo.repoUrl),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Text(
              '曲目、谱面、收藏品与成绩数据均来自落雪咖啡屋（maimai.lxns.net），'
              '本应用仅作查询展示，与世嘉、华立无隶属关系。',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickColor() async {
    var picked = _state.settings.seedColor;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择品牌主色'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: picked,
            onColorChanged: (c) => picked = c,
            enableAlpha: false,
            labelTypes: const [],
            portraitOnly: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _state.updateSettings(
        _state.settings.copyWith(
          seedColorValue: picked.toARGB32(),
          useDynamicColor: false,
        ),
      );
    }
  }

  Future<void> _editToken() async {
    final controller = TextEditingController(text: _state.settings.userToken);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('开发者 Token'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '在落雪开发者页面申请的 API Token',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (value != null) {
      await _state.updateSettings(_state.settings.copyWith(userToken: value));
      setState(() => _token.text = value);
    }
  }

  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除本地数据'),
        content: const Text('曲库缓存与所有收藏夹都会被删除，且不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _state.clearLocalData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('本地数据已清除')));
    }
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AppPalette.seed,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
