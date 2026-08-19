import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/workspace_record.dart';
import '../../core/theme/app_theme.dart';
import 'ink_decoration.dart';

void showWorkbenchSnackBar(BuildContext context, SnackBar snackBar) {
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  messenger.showSnackBar(snackBar);
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
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    barrierDismissible: barrierDismissible,
    barrierColor:
        barrierColor ??
        Theme.of(context).colorScheme.scrim.withValues(alpha: 0.4),
    barrierLabel:
        barrierLabel ??
        MaterialLocalizations.of(context).modalBarrierDismissLabel,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
    transitionDuration: const Duration(milliseconds: 200),
  );
}

/// 统一底部弹层入口：品牌面板色 + 顶部 16px 圆角 + 拖拽把手。
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
    backgroundColor: backgroundColor ?? tokens.panel,
    elevation: elevation,
    shape:
        shape ??
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(_format(value), style: style);
    }
    return TweenAnimationBuilder<num>(
      tween: Tween(end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, current, child) =>
          Text(_format(current), style: style),
      child: null,
    );
  }
}

/// 按压缩放反馈：包裹任意可点按钮/卡片，按下时缩至 0.97。
/// 使用 Listener 不参与手势竞技场，不干扰内部按钮的点击逻辑。
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.pressedScale = 0.97});

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
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
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
    this.borderRadius = 6,
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
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _shimmer.dispose();
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SkeletonBlock(width: 38, height: 38, borderRadius: 19),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBlock(height: 13, widthFactor: 0.72),
                if (rows > 1) ...[
                  const SizedBox(height: 10),
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
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < AppBreakpoints.compact;
    final wide = width >= AppBreakpoints.expanded;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.tokens.canvas,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
          ),
          bottom: BorderSide(color: context.tokens.divider),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact
              ? 16
              : wide
              ? 28
              : 24,
          wide ? 20 : 16,
          compact
              ? 10
              : wide
              ? 28
              : 20,
          wide ? 16 : 14,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _GradientAccentBar(height: wide ? 40 : 32),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: wide ? 26 : null,
                      height: wide ? 1.2 : null,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.tokens.mutedText,
                        fontFeatures: _numericFeaturesIfUseful(subtitle!),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(width: 8),
              ...actions.map(
                (action) => PressScale(key: ValueKey(action), child: action),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GradientAccentBar extends StatelessWidget {
  const _GradientAccentBar({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 5,
      height: height,
      child: Column(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: scheme.secondary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Container(
              width: 5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [scheme.primary, scheme.secondary],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TraditionalDivider extends StatelessWidget {
  const TraditionalDivider({super.key, this.height = 9});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height, child: InkBrushDivider());
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
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: wide ? 28 : 22, bottom: wide ? 10 : 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 4,
                  height: 18,
                  child: Column(
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Expanded(
                        child: Container(
                          width: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.secondary,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: wide ? 20 : null,
                      height: wide ? 1.25 : null,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (scale != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: context.tokens.subtle,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      scale!,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: context.tokens.mutedText,
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
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;
    final radius = wide ? 12.0 : 10.0;
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: tokens.divider),
        boxShadow: [
          BoxShadow(
            color: isLight ? const Color(0x0A000000) : const Color(0x14000000),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 顶部微高光
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(radius),
                ),
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.12),
                    theme.colorScheme.primary.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.only(start: accent == null ? 0 : 3),
            child: Padding(padding: padding, child: child),
          ),
          if (accent != null)
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(radius),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class BambooSprig extends StatelessWidget {
  const BambooSprig({super.key, this.width = 150, this.height = 130});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(width, height),
        painter: _ModernSprigPainter(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          accent: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
    );
  }
}

class _ModernSprigPainter extends CustomPainter {
  const _ModernSprigPainter({required this.color, required this.accent});

  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    // 现代几何装饰：交错的圆角矩形和圆形
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.fill;

    // 三个递增的圆形
    for (var i = 0; i < 3; i++) {
      final cx = size.width * (0.3 + i * 0.2);
      final cy = size.height * (0.7 - i * 0.15);
      final r = size.width * (0.06 + i * 0.02);
      canvas.drawCircle(Offset(cx, cy), r, fillPaint);
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }

    // 连接线
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.7),
      Offset(size.width * 0.7, size.height * 0.4),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ModernSprigPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.accent != accent;
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.12),
                      Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.06),
                    ],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: context.tokens.panel,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.tokens.divider),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      size: 26,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.tokens.mutedText,
                ),
                textAlign: TextAlign.center,
              ),
              if (action != null) ...[
                const SizedBox(height: 20),
                PressScale(child: action!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SparseContentTail extends StatelessWidget {
  const SparseContentTail({super.key, this.height = 72});

  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Opacity(opacity: 0.5, child: InkHorizon(height: height)),
      ),
    );
  }
}

class OrientalMark extends StatelessWidget {
  const OrientalMark({super.key, required this.color, this.size = 16});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class WorkbenchBackdrop extends StatelessWidget {
  const WorkbenchBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 极淡背景纹理
        const Positioned.fill(child: SilkTexture()),
        // 淡淡的渐变晕染
        ExcludeSemantics(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _BackdropPainter(
                wash: scheme.primary.withValues(alpha: 0.02),
                accent: scheme.secondary.withValues(alpha: 0.012),
                gold: context.tokens.gold.withValues(alpha: 0.008),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter({
    required this.wash,
    required this.accent,
    required this.gold,
  });

  final Color wash;
  final Color accent;
  final Color gold;

  @override
  void paint(Canvas canvas, Size size) {
    // 右上角主光晕
    final topRight = Paint()
      ..shader = RadialGradient(
        center: Alignment.topRight,
        radius: 0.35,
        colors: [wash.withValues(alpha: 0.025), wash.withValues(alpha: 0)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, topRight);

    // 左下角次光晕
    final bottomLeft = Paint()
      ..shader = RadialGradient(
        center: Alignment.bottomLeft,
        radius: 0.30,
        colors: [accent.withValues(alpha: 0.02), accent.withValues(alpha: 0)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bottomLeft);

    // 右下角金色点缀光晕（更克制）
    final bottomRight = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.85, 0.95),
        radius: 0.20,
        colors: [gold.withValues(alpha: 0.018), gold.withValues(alpha: 0)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bottomRight);
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) =>
      oldDelegate.wash != wash ||
      oldDelegate.accent != accent ||
      oldDelegate.gold != gold;
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final background =
        color ?? Theme.of(context).colorScheme.secondaryContainer;
    final foreground = _bestContrastingText(background);
    return Semantics(
      label: '标签：$label',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(6),
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
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: foreground),
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
    return Text(
      data,
      style:
          style?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ) ??
          const TextStyle(
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
      textAlign: textAlign,
      maxLines: maxLines,
    );
  }
}

class TickDivider extends StatelessWidget {
  const TickDivider({super.key, this.height = 6, this.dashed = false});

  final double height;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _TickDividerPainter(
          color: context.tokens.divider,
          dashed: dashed,
        ),
      ),
    );
  }
}

class _TickDividerPainter extends CustomPainter {
  const _TickDividerPainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    if (dashed) {
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(
          Offset(x, size.height / 2),
          Offset(math.min(x + 4, size.width), size.height / 2),
          paint,
        );
      }
      return;
    }
    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
    for (var index = 0; index * 16 <= size.width; index++) {
      final x = index * 16.0;
      final tick = index % 4 == 0 ? size.height : size.height * 0.55;
      canvas.drawLine(Offset(x, 0), Offset(x, tick), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TickDividerPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashed != dashed;
}

List<FontFeature>? _numericFeaturesIfUseful(String value) =>
    RegExp(r'\d').hasMatch(value) ? const [FontFeature.tabularFigures()] : null;

Color _bestContrastingText(Color background) {
  const dark = Color(0xFF1A1D29);
  const light = Color(0xFFF8FAFC);
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
  _ => status,
};
