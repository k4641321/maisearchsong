import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:logger_rs/logger_rs.dart';

import 'core/app_state.dart';
import 'core/constants.dart';
import 'core/palette.dart';
import 'pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Log.init();
  Log.i('${AppInfo.appName} 启动');
  runApp(const WumengApp());
}

/// 舞萌查歌应用根组件。
class WumengApp extends StatefulWidget {
  const WumengApp({super.key});

  @override
  State<WumengApp> createState() => _WumengAppState();
}

class _WumengAppState extends State<WumengApp> {
  final AppState _state = AppState.instance;

  @override
  void initState() {
    super.initState();
    _state.addListener(_onStateChanged);
    _state.bootstrap();
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final settings = _state.settings;
        final lightScheme = settings.useDynamicColor && lightDynamic != null
            ? lightDynamic.harmonized()
            : ColorScheme.fromSeed(seedColor: settings.seedColor);
        final darkScheme = settings.useDynamicColor && darkDynamic != null
            ? darkDynamic.harmonized()
            : ColorScheme.fromSeed(
                seedColor: settings.seedColor,
                brightness: Brightness.dark,
              );

        return MaterialApp(
          title: AppInfo.appName,
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: _buildTheme(lightScheme),
          darkTheme: _buildTheme(darkScheme),
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            minScaleFactor: settings.fontScale,
            maxScaleFactor: settings.fontScale,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const HomePage(),
        );
      },
    );
  }

  ThemeData _buildTheme(ColorScheme scheme) {
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
    );
    return base.copyWith(
      cardTheme: base.cardTheme.copyWith(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppPalette.cardRadius),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      listTileTheme: const ListTileThemeData(
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
