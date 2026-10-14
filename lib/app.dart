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
import 'ui/widgets/jade_botanical_edge.dart';
import 'ui/widgets/solid_panel.dart';

TextScaler workbenchTextScaler(TextScaler scaler) =>
    scaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 2.0);

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

class _PersonalWorkbenchAppState extends State<PersonalWorkbenchApp>
    with WidgetsBindingObserver {
  late final WorkbenchController controller;
  bool _retryingInitialization = false;
  bool _initializationRetryAttempted = false;
  String? _lastInitializationError;
  String? _unhandledInitializationError;

  Future<void> _retryInitialization() async {
    if (_retryingInitialization) return;
    setState(() {
      _lastInitializationError =
          _unhandledInitializationError ?? controller.error;
      _unhandledInitializationError = null;
      _retryingInitialization = true;
      _initializationRetryAttempted = false;
    });
    try {
      await controller.initialize();
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _unhandledInitializationError = '初始化重试失败：$exception';
        _retryingInitialization = false;
        _initializationRetryAttempted = true;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _retryingInitialization = false;
      _initializationRetryAttempted = controller.error != null;
      _lastInitializationError = controller.error;
    });
  }

  Future<void> _initializeOnLaunch() async {
    try {
      await controller.initialize();
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _unhandledInitializationError = '初始化失败：$exception';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = WorkbenchController(
      database: AppDatabase(overridePath: widget.databasePath),
      backupService: BackupService(),
      searchService: SearchService(),
      focusService: FocusService(),
      notificationService: NotificationService(),
      shareCaptureService: ShareCaptureService(),
      syncService: SupabaseSyncService(widget.supabaseClient),
    );
    _initializeOnLaunch();
  }

  @override
  void didChangeAccessibilityFeatures() {
    setState(() {});
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
          themeAnimationDuration: const Duration(milliseconds: 180),
          themeAnimationCurve: Curves.easeOutCubic,
          themeAnimationStyle:
              WidgetsBinding
                  .instance
                  .platformDispatcher
                  .accessibilityFeatures
                  .disableAnimations
              ? AnimationStyle.noAnimation
              : null,
          scrollBehavior: const WorkbenchScrollBehavior(),
          // Android 系统栏与应用导航表面同步，图标亮度跟随主题。
          builder: (context, child) {
            final theme = Theme.of(context);
            final isLight = theme.brightness == Brightness.light;
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              // Preserve the full accessibility range exercised by the UI
              // matrix while keeping a lower bound for legacy platform data.
              data: mediaQuery.copyWith(
                textScaler: workbenchTextScaler(mediaQuery.textScaler),
              ),
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: isLight
                      ? Brightness.dark
                      : Brightness.light,
                  statusBarBrightness: isLight
                      ? Brightness.light
                      : Brightness.dark,
                  systemNavigationBarColor: theme
                      .extension<WorkbenchTokens>()!
                      .navigation,
                  systemNavigationBarIconBrightness: isLight
                      ? Brightness.dark
                      : Brightness.light,
                  systemNavigationBarDividerColor: Colors.transparent,
                ),
                child: child!,
              ),
            );
          },
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: _retryingInitialization
              ? InitializationErrorView(
                  message: _lastInitializationError ?? '工作台数据暂时无法载入。',
                  onRetry: _retryInitialization,
                  retrying: true,
                )
              : _unhandledInitializationError != null
              ? InitializationErrorView(
                  message: _unhandledInitializationError!,
                  onRetry: _retryInitialization,
                  retryAttempted: _initializationRetryAttempted,
                )
              : controller.loading
              ? const _LaunchView()
              : controller.error == null
              ? WorkbenchShell(controller: controller)
              : InitializationErrorView(
                  message: controller.error!,
                  onRetry: _retryInitialization,
                  retryAttempted: _initializationRetryAttempted,
                ),
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      case TargetPlatform.windows:
        return Scrollbar(
          controller: details.controller,
          thumbVisibility: MediaQuery.disableAnimationsOf(context)
              ? false
              : null,
          child: child,
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return child;
    }
  }
}

class InitializationErrorView extends StatelessWidget {
  const InitializationErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.retrying = false,
    this.retryAttempted = false,
  });

  final String message;
  final VoidCallback onRetry;
  final bool retrying;
  final bool retryAttempted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final clay = context.accents.clay;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final reason = message.contains('迁移失败')
        ? '本地数据升级未完成。请重新启动应用后重试；若问题持续，可查看下方错误详情。'
        : '暂时无法载入工作台数据。请确认本地数据目录可访问，然后重试。';
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.pageCompact),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: SolidPanel(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: clay.container,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card,
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      Icons.build_outlined,
                                      size: AppIconSize.lg,
                                      color: clay.color,
                                    ),
                                    Positioned(
                                      right: 3,
                                      bottom: 3,
                                      child: Icon(
                                        Icons.error_outline,
                                        size: AppIconSize.xs,
                                        color: theme.colorScheme.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              const JadeBotanicalEdge(
                                width: 66,
                                height: 42,
                                compact: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            '工作台初始化失败',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            reason,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 15,
                              color: tokens.mutedText,
                            ),
                          ),
                          if (retryAttempted) ...[
                            const SizedBox(height: AppSpacing.md),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                '重试仍未成功。工作台数据未更改，可展开错误详情排查。',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: EdgeInsets.zero,
                            expansionAnimationStyle: AnimationStyle(
                              duration: reducedMotion
                                  ? Duration.zero
                                  : AppMotion.standard,
                              reverseDuration: reducedMotion
                                  ? Duration.zero
                                  : AppMotion.standard,
                            ),
                            title: const Text('查看错误详情'),
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: tokens.subtle,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.control,
                                  ),
                                ),
                                child: SelectableText(
                                  message,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: AppFonts.numeric,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: FilledButton.icon(
                              onPressed: retrying ? null : onRetry,
                              icon: retrying
                                  ? reducedMotion
                                        ? const Icon(Icons.hourglass_top)
                                        : SizedBox.square(
                                            dimension: AppIconSize.sm,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: tokens.mutedText,
                                            ),
                                          )
                                  : const Icon(Icons.refresh),
                              label: Text(retrying ? '正在重试' : '重试载入'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
