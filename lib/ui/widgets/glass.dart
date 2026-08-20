import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 全局玻璃效果配置。
///
/// [blurEnabled] 为全局降级开关：为 `false` 时所有玻璃面板回退为
/// 「半透明实色 + 边框」（保持层次与可读性），用于低端机、无障碍场景
/// 或后续「减少透明效果」设置项。
abstract final class GlassConfig {
  static bool blurEnabled = true;
}

/// 绿色系玻璃拟态面板。
///
/// 结构（正常模式）：
/// `RepaintBoundary → ClipRRect(radius) → BackdropFilter(blur) →
/// DecoratedBox(glassPanel 填充 + glassBorder 微光边框 +
/// glassHighlight 顶部高光 + glassGlow 外发光) → Padding`。
///
/// - [enabled] 为 `false` 或 [GlassConfig.blurEnabled] 为 `false` 时，
///   回退为实色面板（`tokens.panel` 96% 不透明 + 常规阴影），视觉层次不丢失。
/// - [accent] 保留 `LogSurface` 的左侧强调条语义。
/// - 圆角默认 12（宽屏）/ 10（窄屏），模糊半径默认取 `tokens.glassBlur`。
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
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// 左侧强调条（沿用 LogSurface.accent 语义）。
  final Color? accent;

  /// 圆角半径，默认 12（宽屏）/ 10（窄屏）。
  final double? radius;

  /// 背景模糊半径 sigma，默认取 `tokens.glassBlur`。
  final double? blur;

  /// 翠绿微光边框 / 外发光。
  final bool glow;

  /// 是否启用玻璃效果（false 时回退实色面板）。
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;
    final r = radius ?? (wide ? 12.0 : 10.0);
    final useBlur = GlassConfig.blurEnabled && enabled;
    final isLight = theme.brightness == Brightness.light;

    final fillColor = useBlur ? tokens.glassPanel : tokens.panel.withValues(alpha: 0.96);
    final borderColor = useBlur ? tokens.glassBorder : tokens.divider;

    final decoration = BoxDecoration(
      color: fillColor,
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: borderColor),
      boxShadow: [
        if (glow && useBlur)
          BoxShadow(
            color: tokens.glassGlow,
            blurRadius: 14,
            offset: const Offset(0, 4),
          )
        else
          BoxShadow(
            color: isLight ? const Color(0x0A000000) : const Color(0x14000000),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
      ],
    );

    Widget panel = DecoratedBox(
      decoration: decoration,
      child: Stack(
        children: [
          // 顶部微高光（玻璃高光渐变，向下淡出）
          if (useBlur)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(r)),
                  gradient: LinearGradient(
                    colors: [
                      tokens.glassHighlight,
                      tokens.glassHighlight.withValues(alpha: 0.15),
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
                    left: Radius.circular(r),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (useBlur) {
      panel = ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blur ?? tokens.glassBlur,
            sigmaY: blur ?? tokens.glassBlur,
          ),
          child: panel,
        ),
      );
    }

    return RepaintBoundary(child: panel);
  }
}
