import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'data/app_database.dart';
import 'data/backup_service.dart';
import 'services/focus_service.dart';
import 'services/notification_service.dart';
import 'services/search_service.dart';
import 'services/share_capture_service.dart';
import 'services/supabase_sync_service.dart';
import 'state/workbench_controller.dart';
import 'ui/workbench_shell.dart';
import 'ui/widgets/common.dart';
import 'ui/widgets/ink_decoration.dart';

class PersonalWorkbenchApp extends StatefulWidget {
  const PersonalWorkbenchApp({
    super.key,
    this.supabaseClient,
    this.databasePath,
  });

  final SupabaseClient? supabaseClient;
  final String? databasePath;

  @override
  State<PersonalWorkbenchApp> createState() => _PersonalWorkbenchAppState();
}

class _PersonalWorkbenchAppState extends State<PersonalWorkbenchApp> {
  late final WorkbenchController controller;

  @override
  void initState() {
    super.initState();
    controller = WorkbenchController(
      database: AppDatabase(overridePath: widget.databasePath),
      backupService: BackupService(),
      searchService: SearchService(),
      focusService: FocusService(),
      notificationService: NotificationService(),
      shareCaptureService: ShareCaptureService(),
      syncService: SupabaseSyncService(widget.supabaseClient),
    );
    controller.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return MaterialApp(
          title: '个人工作台',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: controller.themeMode,
          themeAnimationCurve: Curves.easeInOut,
          scrollBehavior: const WorkbenchScrollBehavior(),
          // Android 系统栏适配：状态栏透明融入 AppBar 渐变，
          // 导航栏与底部 NavigationBar 同色，图标亮度跟随主题。
          builder: (context, child) {
            final theme = Theme.of(context);
            final isLight = theme.brightness == Brightness.light;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: isLight
                    ? Brightness.dark
                    : Brightness.light,
                statusBarBrightness: isLight
                    ? Brightness.light
                    : Brightness.dark,
                systemNavigationBarColor: theme.colorScheme.surface,
                systemNavigationBarIconBrightness: isLight
                    ? Brightness.dark
                    : Brightness.light,
                systemNavigationBarDividerColor: Colors.transparent,
              ),
              child: child!,
            );
          },
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: controller.loading
              ? const _LaunchView()
              : controller.error == null
              ? WorkbenchShell(controller: controller)
              : _InitializationErrorView(
                  message: controller.error!,
                  onRetry: controller.initialize,
                ),
        );
      },
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class _LaunchView extends StatefulWidget {
  const _LaunchView();

  @override
  State<_LaunchView> createState() => _LaunchViewState();
}

class _LaunchViewState extends State<_LaunchView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Semantics(
          label: '正在载入个人工作台',
          child: FadeTransition(
            opacity: reduce ? const AlwaysStoppedAnimation(1) : _curve,
            child: ScaleTransition(
              scale: reduce
                  ? const AlwaysStoppedAnimation(1)
                  : Tween<double>(begin: 0.92, end: 1).animate(_curve),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SealLogo(size: 44),
                  const SizedBox(height: 26),
                  // 工作台骨架占位：标题行 + 三条列表骨架，替代孤立转圈的空白等待
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Semantics(
                      label: '正在载入工作台数据',
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBlock(height: 18, widthFactor: 0.32),
                          SizedBox(height: 20),
                          SkeletonListTile(),
                          SkeletonBlock(height: 1, widthFactor: 1),
                          SkeletonListTile(),
                          SkeletonBlock(height: 1, widthFactor: 1),
                          SkeletonListTile(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 桌面端常显滚动条；触屏端保持系统默认。
class WorkbenchScrollBehavior extends MaterialScrollBehavior {
  const WorkbenchScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (axisDirectionToAxis(details.direction) == Axis.horizontal) {
      return child;
    }
    switch (getPlatform(context)) {
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return Scrollbar(
          controller: PrimaryScrollController.maybeOf(context),
          thumbVisibility: MediaQuery.disableAnimationsOf(context)
                  ? false
                  : null,
          child: child,
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
      case TargetPlatform.windows:
        return child;
    }
  }
}

class _InitializationErrorView extends StatelessWidget {
  const _InitializationErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 40,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  '工作台初始化失败',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                SelectableText(message, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
