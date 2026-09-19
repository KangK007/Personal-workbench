import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import 'solid_panel.dart';

void showWorkbenchSnackBar(BuildContext context, SnackBar snackBar) {
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  messenger.showSnackBar(snackBar);
}

/// 列表行统一图标底：为描边图标提供稳定尺寸、留白和主题色状态。
class SurfaceIcon extends StatelessWidget {
  const SurfaceIcon(this.icon, {super.key, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Icon(icon, size: 18, color: tint),
    );
  }
}

/// 输入控件的外置顶部标签：标签不参与输入框边框绘制，避免浮动标签
/// 与边框重叠，并通过 Semantics 保留控件的可访问名称。
class ExternalField extends StatelessWidget {
  const ExternalField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: context.tokens.mutedText,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 可见标签保留视觉层级，读屏名称由实际控件统一提供，避免重复朗读。
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 2),
          child: ExcludeSemantics(child: Text(label, style: labelStyle)),
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(label: label, container: true, child: child),
      ],
    );
  }
}

/// 统一对话框入口：品牌遮罩色 + 淡入缩放入场，替代散落各处的默认 showDialog。
Future<T?> showWorkbenchDialog<T extends Object?>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
}) {
  return showGeneralDialog<T>(
    context: context,
    pageBuilder: (context, animation, secondaryAnimation) => CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          final route = ModalRoute.of(context);
          final isBeingPopped =
              route?.animation?.status == AnimationStatus.reverse ||
              route?.animation?.status == AnimationStatus.dismissed;
          if (route?.isCurrent == true && !isBeingPopped) {
            Navigator.of(context, rootNavigator: true).maybePop();
          }
        },
      },
      child: Focus(
        autofocus: true,
        canRequestFocus: true,
        skipTraversal: true,
        child: builder(context),
      ),
    ),
    barrierDismissible: barrierDismissible,
    barrierColor:
        barrierColor ??
        Theme.of(context).colorScheme.scrim.withValues(alpha: 0.4),
    barrierLabel:
        barrierLabel ??
        MaterialLocalizations.of(context).modalBarrierDismissLabel,
    requestFocus: true,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
    transitionDuration: AppMotion.standard,
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// 统一底部弹层入口：实色 raised 底 + 顶部 8px 圆角 + 拖拽把手。
Future<T?> showWorkbenchSheet<T extends Object?>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  double? elevation,
  ShapeBorder? shape,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  AnimationController? transitionAnimationController,
  Offset? anchorPoint,
}) {
  final tokens = context.tokens;
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    backgroundColor: backgroundColor ?? tokens.raised,
    elevation: elevation ?? 0,
    shape:
        shape ??
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheetTop),
          ),
          side: BorderSide.none,
        ),
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle ?? true,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    transitionAnimationController: transitionAnimationController,
    anchorPoint: anchorPoint,
  );
}

/// 数字滚动动画：进度百分比、XP、统计数值变化时平滑计数。
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.decimals = 0,
    this.duration = const Duration(milliseconds: 350),
    this.formatter,
  });

  final num value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final int decimals;
  final Duration duration;
  final String Function(num value)? formatter;

  String _format(num v) =>
      formatter?.call(v) ?? '$prefix${v.toStringAsFixed(decimals)}$suffix';

  @override
  Widget build(BuildContext context) {
    final numberStyle = (style ?? const TextStyle()).copyWith(
      fontFamily: AppFonts.numeric,
      fontFeatures: const [FontFeature.tabularFigures()],
      fontWeight: style?.fontWeight ?? FontWeight.w500,
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(_format(value), style: numberStyle);
    }
    return TweenAnimationBuilder<num>(
      tween: Tween(end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, current, child) =>
          Text(_format(current), style: numberStyle),
      child: null,
    );
  }
}

/// 按压缩放反馈：包裹任意可点按钮/卡片，按下时轻微缩放。
/// 使用 Listener 不参与手势竞技场，不干扰内部按钮的点击逻辑。
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.pressedScale = 0.98});

  final Widget child;
  final double pressedScale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: AppMotion.micro,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// 列表交错入场：前 8 项每项 20ms 交错，淡入 + 12px 上移。
/// 尊重系统「减少动画」设置；仅首次挂载播放。
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.maxAnimated = 8,
  });

  final Widget child;
  final int index;
  final int maxAnimated;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.emphasized,
  );

  @override
  void initState() {
    super.initState();
    final participates = widget.index < widget.maxAnimated;
    if (participates) {
      final delay = Duration(
        milliseconds: widget.index * AppMotion.staggerInterval.inMilliseconds,
      );
      Future.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04), // 约 12px 位移
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}

/// 骨架块：微光扫过（shimmer）的灰色占位，尊重系统"减少动画"设置。
class SkeletonBlock extends StatefulWidget {
  const SkeletonBlock({
    super.key,
    this.width,
    this.height = 12,
    this.widthFactor,
    this.borderRadius = AppRadius.xs,
  });

  final double? width;
  final double? widthFactor;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock>
    with SingleTickerProviderStateMixin {
  AnimationController? _shimmerController;

  AnimationController get _shimmer =>
      _shimmerController ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1300),
      )..repeat();

  @override
  void dispose() {
    _shimmerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    Widget block = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: tokens.subtle,
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
    );
    if (widget.widthFactor != null) {
      block = FractionallySizedBox(
        widthFactor: widget.widthFactor,
        alignment: Alignment.centerLeft,
        child: block,
      );
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      return ExcludeSemantics(child: block);
    }
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _shimmer,
          builder: (context, _) {
            final sweep = _shimmer.value * 2 - 1;
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                gradient: LinearGradient(
                  begin: Alignment(sweep - 0.7, 0),
                  end: Alignment(sweep + 0.7, 0),
                  colors: [
                    tokens.subtle,
                    tokens.divider.withValues(alpha: 0.9),
                    tokens.subtle,
                  ],
                ),
              ),
              child: block,
            );
          },
        ),
      ),
    );
  }
}

/// 列表行骨架：圆形头像占位 + 两行长短文本占位，形似真实列表项。
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key, this.rows = 2});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SkeletonBlock(
            width: 34,
            height: 34,
            borderRadius: AppRadius.xs,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBlock(height: 13, widthFactor: 0.72),
                if (rows > 1) ...[
                  const SizedBox(height: 8),
                  const SkeletonBlock(height: 10, widthFactor: 0.42),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < AppBreakpoints.compact;
    final wide = width >= AppBreakpoints.expanded;
    return SolidPanel(
      radius: 0,
      padding: EdgeInsets.zero,
      color: tokens.panel,
      // 移除下边框：页头与内容的分离改由 24px 下留白承担（规范 9）。
      borderColor: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? AppSpacing.pageCompact : AppSpacing.pageWide,
          wide ? 18 : 14,
          compact ? 10 : AppSpacing.pageWide,
          AppSpacing.xl,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 3,
              height: wide ? 38 : 30,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: compact ? 24 : 30,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tokens.mutedText,
                        fontFeatures: _numericFeaturesIfUseful(subtitle!),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                ],
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final action in actions)
                        PressScale(key: ValueKey(action), child: action),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.scale,
    this.trailing,
  });

  final String title;
  final String? scale;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < AppBreakpoints.compact;
    return Padding(
      // 移除装饰航迹条后，层级由 24px 上留白确立（规范 6.3 / 9）。
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (scale != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.subtle,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      border: Border.all(color: tokens.panelBorder),
                    ),
                    child: Text(
                      scale!,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: tokens.mutedText,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

enum VineRailState { pending, current, completed, warning }

@immutable
class VineRailEntry {
  const VineRailEntry({
    required this.label,
    this.detail,
    this.state = VineRailState.pending,
    this.trailing,
  });

  final String label;
  final String? detail;
  final VineRailState state;
  final Widget? trailing;
}

/// 藤线航迹：只用于真实时间、顺序或证据；调用方负责提供已有数据。
///
/// 状态以**形状**表达，不依赖颜色（规范 3.2）：
/// - 未开始 = 空心芽点（行动色 30% 描边）
/// - 进行中 = 实心芽点 + 外环
/// - 已结果 = 实心芽点（陶土成果色）
/// - 断口   = 连线断开 6px + 缺口弧（砖红）
class VineRail extends StatelessWidget {
  const VineRail({super.key, required this.entries});

  final List<VineRailEntry> entries;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      children: [
        for (var index = 0; index < entries.length; index++)
          _VineRailRow(
            entry: entries[index],
            first: index == 0,
            last: index == entries.length - 1,
            tokens: tokens,
          ),
      ],
    );
  }
}

/// 藤线连线：1.5px 圆头，柔化分组色。
class _VineLine extends StatelessWidget {
  const _VineLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 1.5,
        height: double.infinity,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

/// 芽点：四态各有一种轮廓，形状本身即可区分。
class _VineBud extends StatelessWidget {
  const _VineBud({super.key, required this.state, required this.tokens});

  final VineRailState state;
  final WorkbenchTokens tokens;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case VineRailState.pending:
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: tokens.focusRing.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
        );
      case VineRailState.current:
        return Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: tokens.focusRing, width: 1.5),
          ),
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tokens.focusRing,
              ),
            ),
          ),
        );
      case VineRailState.completed:
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tokens.reward,
          ),
        );
      case VineRailState.warning:
        return SizedBox(
          width: 14,
          height: 14,
          child: CustomPaint(painter: _GapArcPainter(color: tokens.signal)),
        );
    }
  }
}

/// 缺口弧：生长被打断的形态，比红点更易扫读，且不依赖颜色。
class _GapArcPainter extends CustomPainter {
  const _GapArcPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      -math.pi / 2,
      math.pi * 1.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GapArcPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _VineRailRow extends StatelessWidget {
  const _VineRailRow({
    required this.entry,
    required this.first,
    required this.last,
    required this.tokens,
  });

  final VineRailEntry entry;
  final bool first;
  final bool last;
  final WorkbenchTokens tokens;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final stateLabel = switch (entry.state) {
      VineRailState.pending => '待进行',
      VineRailState.current => '进行中',
      VineRailState.completed => '已完成',
      VineRailState.warning => '需要注意',
    };
    final broken = entry.state == VineRailState.warning;
    return IntrinsicHeight(
      child: Semantics(
        label: '${entry.label}，$stateLabel',
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: compact ? 60 : 48),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    SizedBox(
                      height: 12,
                      child: first ? null : _VineLine(color: tokens.divider),
                    ),
                    SizedBox(
                      height: 20,
                      child: Center(
                        // 键按状态区分，使回归测试能直接断言「四态各有独立结构」，
                        // 而不必依赖颜色或图标。
                        child: _VineBud(
                          key: ValueKey('vine-bud:${entry.state.name}'),
                          state: entry.state,
                          tokens: tokens,
                        ),
                      ),
                    ),
                    // 断口：连线在此断开 6px。
                    if (broken) const SizedBox(height: 6),
                    if (last)
                      const Spacer()
                    else
                      Expanded(child: _VineLine(color: tokens.divider)),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 0, 12),
                  child: compact && entry.trailing != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.label),
                            if (entry.detail != null)
                              Text(
                                entry.detail!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            const SizedBox(height: AppSpacing.sm),
                            entry.trailing!,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entry.label),
                                  if (entry.detail != null)
                                    Text(
                                      entry.detail!,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                            ?entry.trailing,
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LogSurface extends StatelessWidget {
  const LogSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.accent,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    // 统一日志表面；长列表与正文始终保持实色和稳定对比度。
    return SolidPanel(padding: padding, accent: accent, child: child);
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final badge = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primaryContainer,
      ),
      child: Icon(icon, size: 26, color: scheme.onPrimaryContainer),
    );

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        const SizedBox(height: 14),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: context.tokens.mutedText,
          ),
          textAlign: TextAlign.center,
        ),
        if (action != null) ...[
          const SizedBox(height: 18),
          PressScale(child: action!),
        ],
      ],
    );

    if (MediaQuery.disableAnimationsOf(context)) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: 56,
            ),
            child: content,
          ),
        ),
      );
    }

    // 入场编排：徽章 320ms 缩放淡入；文案延迟 80ms 淡入跟随。
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: 56,
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: AppMotion.emphasized,
            curve: Curves.easeOutCubic,
            builder: (context, t, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.8 + 0.2 * t.clamp(0.0, 1.0),
                      child: badge,
                    ),
                  ),
                  Opacity(
                    opacity: ((t - 0.25) / 0.75).clamp(0.0, 1.0),
                    child: child,
                  ),
                ],
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 14),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.tokens.mutedText,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (action != null) ...[
                  const SizedBox(height: 18),
                  PressScale(child: action!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = color ?? scheme.primaryContainer;
    // 未指定颜色时使用成对的容器/容器上文字令牌；指定颜色时才做自动取色兜底。
    final foreground = color == null
        ? scheme.onPrimaryContainer
        : bestContrastingText(background);
    return Semantics(
      label: '标签：$label',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: foreground),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NumericText extends StatelessWidget {
  const NumericText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      data,
      key: ValueKey(data),
      style:
          style?.copyWith(
            fontWeight: FontWeight.w500,
            fontFamily: AppFonts.numeric,
            fontFeatures: const [FontFeature.tabularFigures()],
          ) ??
          const TextStyle(
            fontWeight: FontWeight.w500,
            fontFamily: AppFonts.numeric,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
    if (MediaQuery.disableAnimationsOf(context)) return text;
    return AnimatedSwitcher(
      duration: AppMotion.standard,
      reverseDuration: AppMotion.exit,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: text,
    );
  }
}

class TickDivider extends StatelessWidget {
  const TickDivider({
    super.key,
    this.height = 6,
    this.dashed = false,
    this.inset = AppSpacing.pageCompact,
  });

  final double height;
  final bool dashed;

  /// 左右内缩，形成呼吸断点而非贯穿满宽（规范 9）。
  final double inset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _TickDividerPainter(
          color: context.tokens.divider,
          dashed: dashed,
          inset: inset,
        ),
      ),
    );
  }
}

class _TickDividerPainter extends CustomPainter {
  const _TickDividerPainter({
    required this.color,
    required this.dashed,
    required this.inset,
  });

  final Color color;
  final bool dashed;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final left = inset;
    final right = size.width - inset;
    if (right <= left) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    if (dashed) {
      for (var x = left; x < right; x += 8) {
        canvas.drawLine(
          Offset(x, size.height / 2),
          Offset(math.min(x + 4, right), size.height / 2),
          paint,
        );
      }
      return;
    }
    canvas.drawLine(Offset(left, 0), Offset(right, 0), paint);
    for (var index = 0; ; index++) {
      final x = left + index * 16.0;
      if (x > right) break;
      final tick = index % 4 == 0 ? size.height : size.height * 0.55;
      canvas.drawLine(Offset(x, 0), Offset(x, tick), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TickDividerPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.dashed != dashed ||
      oldDelegate.inset != inset;
}

List<FontFeature>? _numericFeaturesIfUseful(String value) =>
    RegExp(r'\d').hasMatch(value) ? const [FontFeature.tabularFigures()] : null;

/// 唯一的对比度取色实现：基于 ink 令牌返回在 [background] 上
/// 对比度更高的前景色（深 ink 或近白）。
Color bestContrastingText(
  Color background, {
  Color dark = const Color(0xFF232A22),
  Color light = const Color(0xFFFFFDF9),
}) {
  double contrast(Color foreground) {
    final lighter = math.max(
      foreground.computeLuminance(),
      background.computeLuminance(),
    );
    final darker = math.min(
      foreground.computeLuminance(),
      background.computeLuminance(),
    );
    return (lighter + 0.05) / (darker + 0.05);
  }

  return contrast(dark) >= contrast(light) ? dark : light;
}

IconData iconForKind(RecordKind kind) => switch (kind) {
  RecordKind.task => Icons.check_box_outlined,
  RecordKind.project => Icons.folder_outlined,
  RecordKind.note => Icons.note_alt_outlined,
  RecordKind.diary => Icons.menu_book_outlined,
  RecordKind.link => Icons.link_outlined,
  RecordKind.goal => Icons.flag_outlined,
  RecordKind.milestone => Icons.signpost_outlined,
  RecordKind.habit => Icons.repeat_outlined,
  RecordKind.habitLog => Icons.fact_check_outlined,
  RecordKind.focusSession => Icons.timer_outlined,
  RecordKind.timeBlock => Icons.schedule_outlined,
  RecordKind.template => Icons.copy_all_outlined,
  RecordKind.savedView => Icons.filter_alt_outlined,
  RecordKind.relation => Icons.account_tree_outlined,
  RecordKind.dailyPlan => Icons.today_outlined,
  RecordKind.growthEvent => Icons.stacked_line_chart_outlined,
  RecordKind.profile => Icons.person_outline,
  RecordKind.exceptionRule => Icons.gavel_outlined,
  RecordKind.protocolEvent => Icons.timeline_outlined,
};

String statusLabel(String status) => switch (status) {
  WorkStatus.inbox => '收集箱',
  WorkStatus.todo => '待办',
  WorkStatus.doing => '进行中',
  WorkStatus.done => '已完成',
  WorkStatus.cancelled => '已取消',
  WorkStatus.skipped => '已跳过',
  WorkStatus.failed => '失败',
  WorkStatus.rescheduled => '已改期',
  _ => status,
};
