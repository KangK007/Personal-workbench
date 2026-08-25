import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 统一实色面板组件。
///
/// 层次手法：底色 + 1px 中性边框 + 克制阴影。
/// - [elevated] 为 `false` 时使用 panelShadow（blur 10 / y+3），
///   为 `true` 时使用 raisedShadow（blur 16 / y+6），用于对话框/菜单等浮层。
/// - [selected] 时左缘绘制 3px 航迹色，边框转 route@40%。
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
    final effectiveBorder =
        borderColor ?? (selected ? selectedBorderColor : tokens.panelBorder);
    final effectiveAccent = selected ? scheme.primary : accent;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? tokens.panel,
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
        ],
      ),
    );
  }
}
