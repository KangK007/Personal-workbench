import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 统一面板组件：默认高不透明度，按需启用清新绿色玻璃层。
///
/// 层次手法：底色 + 1px panelBorder 边框 + 微阴影双保险。
/// - [glass] 仅用于导航、页头、重点区和浮层；长列表默认保持实色。
/// - [elevated] 为 `false` 时使用 panelShadow（blur 10 / y+3），
///   为 `true` 时使用 raisedShadow（blur 16 / y+6），用于对话框/菜单等浮层。
/// - [selected] 时左缘绘制 3px 实心 primary 条，边框转 primary@40%。
/// - [accent] 保留 LogSurface 的左侧强调条语义（自定义色）。
class SolidPanel extends StatelessWidget {
  const SolidPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.accent,
    this.radius,
    this.elevated = false,
    this.selected = false,
    this.glass = false,
    this.blur,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// 左侧强调条颜色（优先级低于 [selected]）。
  final Color? accent;

  /// 圆角半径，默认 [AppRadius.card]（6px）。
  final double? radius;

  /// 是否为浮层（对话框/弹层/菜单）——使用更深的投影。
  final bool elevated;

  /// 选中态：左缘 3px 实心 primary 条 + 边框转 primary@40%。
  final bool selected;

  /// 是否启用半透明玻璃表面。关闭 [GlassConfig.blurEnabled] 时自动降级。
  final bool glass;

  /// 可选的局部模糊半径；为空时使用主题令牌。
  final double? blur;

  /// 面板底色，默认 tokens.panel。
  final Color? color;

  /// 边框色，默认 tokens.panelBorder。
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    final r = radius ?? AppRadius.card;
    final selectedBorderColor = scheme.primary.withValues(alpha: 0.4);
    final glassActive = glass && GlassConfig.blurEnabled;
    final effectiveBorder =
        borderColor ??
        (selected
            ? selectedBorderColor
            : glass
            ? tokens.glassBorder
            : tokens.panelBorder);
    final effectiveAccent = selected ? scheme.primary : accent;

    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? (glass ? tokens.glassPanel : tokens.panel),
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: effectiveBorder),
        boxShadow: [
          BoxShadow(
            color: elevated ? tokens.raisedShadow : tokens.panelShadow,
            blurRadius: elevated ? 16 : 10,
            offset: Offset(0, elevated ? 6 : 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: effectiveAccent == null ? 0 : 3,
            ),
            child: Padding(padding: padding, child: child),
          ),
          if (effectiveAccent != null)
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: effectiveAccent,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(r),
                  ),
                ),
              ),
            ),
          if (glass)
            PositionedDirectional(
              start: r,
              end: r,
              top: 0,
              child: Container(height: 1, color: tokens.glassHighlight),
            ),
        ],
      ),
    );

    if (!glassActive) return panel;
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blur ?? tokens.glassBlur,
            sigmaY: blur ?? tokens.glassBlur,
          ),
          child: panel,
        ),
      ),
    );
  }
}

/// 玻璃面板：用于导航、页头、重点区和弹层，支持性能降级。
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.accent,
    this.radius,
    this.blur,
    this.glow = true,
    this.enabled = true,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final double? radius;

  /// 可选的局部模糊半径；为空时使用主题令牌。
  final double? blur;

  /// 保留兼容参数；当前只使用边框和微高光，不添加外发光。
  final bool glow;

  /// 是否启用玻璃表面；关闭时回退为高不透明度面板。
  final bool enabled;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return SolidPanel(
      padding: padding,
      accent: accent,
      radius: radius,
      elevated: elevated,
      glass: enabled,
      blur: blur,
      color: enabled ? null : context.tokens.panel,
      child: child,
    );
  }
}

/// 玻璃降级开关：关闭后保留半透明层级，但移除 BackdropFilter。
abstract final class GlassConfig {
  static bool blurEnabled = true;
}
