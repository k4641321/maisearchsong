import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_singbox_client/flutter_singbox_client.dart';
import 'package:logger_rs/logger_rs.dart';

import 'constants.dart';

/// 内置 sing-box 代理管理器。
///
/// 国服查分器在部分网络环境下不可直连，这里复用参考项目的
/// `flutter_singbox_client` 依赖，用一份内置配置起一个本地代理。
/// 未连接时所有网络请求直连，不改变默认行为。
class ProxyManager {
  ProxyManager._();

  static final ProxyManager instance = ProxyManager._();

  final SingboxClient _client = SingboxClient();
  ServiceState _state = ServiceState.stopped;
  String _config = '';
  bool _initialized = false;
  String? _lastError;

  /// `flutter_singbox_client` 只提供 Android 原生实现，其他平台没有引擎。
  ///
  /// 在桌面端直接判定为不支持，避免调用时抛 `MissingPluginException` 污染日志。
  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// 服务状态流。
  Stream<ServiceState> get stateStream => _client.serviceStateStream;

  /// 当前状态。
  ServiceState get state => _state;

  /// 是否已连接。
  bool get isRunning => _state.isRunning;

  /// 最近一次错误。
  String? get lastError => _lastError;

  /// 引擎版本。
  Future<String> coreVersion() async {
    if (!isSupported) return '当前平台不支持';
    return _client.getCoreVersion();
  }

  /// 载入内置配置文本。
  void loadConfig(String json) => _config = json;

  /// 读取随应用打包的默认配置（单例只读一次）。
  Future<void> loadAssetConfig() async {
    if (_config.isNotEmpty) return;
    try {
      _config = await rootBundle.loadString(Assets.proxyConfig);
      Log.i('已载入内置代理配置（${_config.length} 字符）');
    } catch (e) {
      _lastError = '内置配置读取失败：$e';
      Log.e('内置代理配置读取失败', error: e);
    }
  }

  /// 校验配置。
  Future<void> validate() async {
    if (!isSupported) return;
    await _client.checkConfig(_config);
  }

  /// 初始化引擎（非 Android 平台直接跳过）。
  Future<void> init() async {
    if (_initialized) return;
    if (!isSupported) {
      _lastError = '当前平台不支持内置加速线路';
      return;
    }
    try {
      await _client.initialize();
      _client.serviceStateStream.listen((s) {
        _state = s;
        Log.i('代理状态：${s.name}');
      });
      _initialized = true;
    } catch (e) {
      _lastError = '$e';
      Log.e('代理引擎初始化失败', error: e);
    }
  }

  /// 连接代理（会请求 VPN 权限）。
  Future<bool> connect() async {
    _lastError = null;
    if (!isSupported) {
      _lastError = '当前平台不支持内置加速线路';
      return false;
    }
    try {
      await init();
      final granted = await _client.requestVPNPermission();
      if (!granted) {
        _lastError = '未授予 VPN 权限';
        return false;
      }
      await _client.connect(
        SessionOptions(
          config: _config,
          networkMode: NetworkMode.vpn,
          notification: const NotificationConfig(
            title: '乌蒙查歌 · 加速线路',
            showTrafficStats: true,
          ),
        ),
      );
      return true;
    } catch (e) {
      _lastError = '$e';
      Log.e('代理连接失败', error: e);
      return false;
    }
  }

  /// 断开代理。
  Future<void> disconnect() async {
    if (!isSupported) return;
    try {
      await _client.disconnect();
    } catch (e) {
      Log.e('代理断开失败', error: e);
    }
  }
}
