import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ─── 色彩体系：个人工作台 · 清新绿色玻璃拟态 ───
// 关键层使用半透明玻璃，长列表保留高不透明度面板以控制性能和对比度。
// 浅色：薄荷画布 + 清透面板 + 翠绿主色；深色：深墨绿画布 + 亮翠绿。

abstract final class AppColors {
  // ═══ 浅色 · 清新绿意工作台 ═══
  static const lightCanvas = Color(0xFFEAF5EF); // 薄荷画布
  static const lightSurface = Color(0xFFF9FDFA); // 高不透明度内容面板
  static const lightRaised = Color(0xFFFFFFFF); // 浮层背景
  static const lightInk = Color(0xFF17352A); // 主文字
  static const lightInkMuted = Color(0xFF698077); // 次级文字
  static const lightDivider = Color(0xFFCEE2D7); // 分隔线
  static const lightPrimary = Color(0xFF159765); // 翠绿主色
  static const lightPrimaryContainer = Color(0xFFD8F1E2); // 翠绿容器
  static const lightSecondary = Color(0xFF38B989); // 次级翠绿
  static const lightSecondaryContainer = Color(0xFFE6F6ED); // 次级背景
  static const lightReward = Color(0xFFF97316); // 暖橙状态
  static const lightRewardContainer = Color(0xFFFFF7ED); // 暖橙容器
  static const lightInfo = Color(0xFF0EA5E9); // 信息状态
  static const lightDanger = Color(0xFFEF4444); // 危险状态
  static const lightGold = Color(0xFFF59E0B); // 琥珀金

  // ═══ 深色 · 深墨绿夜色 ═══
  static const darkCanvas = Color(0xFF071B14); // 深墨绿画布
  static const darkSurface = Color(0xFF123529); // 墨绿内容面板
  static const darkRaised = Color(0xFF1A3E30); // 墨绿浮层
  static const darkInk = Color(0xFFE5F3EA); // 亮绿白文字
  static const darkInkMuted = Color(0xFF9AB7AA); // 灰绿辅助
  static const darkDivider = Color(0xFF2D5A47); // 暗墨绿线
  static const darkPrimary = Color(0xFF5EE0A8); // 亮翠绿
  static const darkPrimaryContainer = Color(0xFF1E523D); // 暗翠绿容器
  static const darkSecondary = Color(0xFF8DE8C2); // 亮翠绿辅助
  static const darkSecondaryContainer = Color(0xFF113827); // 暗翠绿容器
  static const darkReward = Color(0xFFFB923C); // 亮暖橙
  static const darkRewardContainer = Color(0xFF431407); // 暗暖橙容器
  static const darkInfo = Color(0xFF38BDF8); // 亮天蓝
  static const darkDanger = Color(0xFFF87171); // 亮红色(警示)
  static const darkGold = Color(0xFFFBBF24); // 亮琥珀
}

// ─── 响应式断点（强制收敛：仅此两档）───
abstract final class AppBreakpoints {
  static const compact = 768.0; // <768: 移动端
  static const expanded = 1200.0; // ≥1200: 完整展开
}

// ─── 圆角标尺（v2 锐利几何）───
abstract final class AppRadius {
  static const card = 6.0; // 卡片/弹窗/FAB
  static const control = 5.0; // 按钮/输入框/Chip
  static const sheetTop = 8.0; // 底部弹层顶部角
  static const indicator = 6.0; // NavigationBar indicator / Snackbar
  static const tooltip = 4.0; // Tooltip
}

/// 图标尺寸标尺：功能图标保持同一视觉重量，触控区域由主题控件保证。
abstract final class AppIconSize {
  static const xs = 16.0;
  static const sm = 20.0;
  static const md = 24.0;
  static const lg = 32.0;
}

// ─── 动效标尺（三级时长）───
abstract final class AppMotion {
  /// 按压反馈、悬停、开关、焦点环。
  static const micro = Duration(milliseconds: 120);

  /// 淡入淡出、尺寸变化、Snackbar、弹层入场。
  static const standard = Duration(milliseconds: 200);

  /// 页面切换、庆祝仪式、大面积编排。
  static const emphasized = Duration(milliseconds: 320);

  /// 页面切换过渡（emphasized 的实用档）。
  static const pageTransition = Duration(milliseconds: 240);

  /// 列表项交错入场间隔。
  static const staggerInterval = Duration(milliseconds: 20);
}

// ─── 间距标尺（v2 收紧 15-20%）───
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 14.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  // 页面横向边距
  static const pageCompact = 14.0;
  static const pageMedium = 20.0;
  static const pageWide = 24.0;
}

// ─── 自定义主题令牌 ───
@immutable
class WorkbenchTokens extends ThemeExtension<WorkbenchTokens> {
  const WorkbenchTokens({
    required this.canvas,
    required this.panel,
    required this.raised,
    required this.subtle,
    required this.panelBorder,
    required this.panelShadow,
    required this.raisedShadow,
    required this.focusRing,
    required this.mutedText,
    required this.divider,
    required this.reward,
    required this.rewardContainer,
    required this.info,
    required this.danger,
    required this.sealColor,
    required this.gold,
    required this.glassPanel,
    required this.glassRaised,
    required this.glassBorder,
    required this.glassHighlight,
    required this.glassBlur,
  });

  final Color canvas;
  final Color panel;
  final Color raised;
  final Color subtle;

  /// 面板 1px 描边（同色系灰绿，非中性灰）。
  final Color panelBorder;

  /// 面板投影色（配合 blur 10 / offset(0,3)）。
  final Color panelShadow;

  /// 浮层投影色（配合 blur 16 / offset(0,6)）。
  final Color raisedShadow;

  /// 键盘焦点 2px 外环。
  final Color focusRing;
  final Color mutedText;
  final Color divider;
  final Color reward;
  final Color rewardContainer;
  final Color info;
  final Color danger;
  final Color sealColor; // 主品牌强调色
  final Color gold; // 点缀金色

  /// 关键导航、页头和重点区使用的半透明面板。
  final Color glassPanel;

  /// 弹窗、底部弹层和 raised 玻璃浮层。
  final Color glassRaised;

  /// 玻璃边框，使用主色低透明度而不是中性灰。
  final Color glassBorder;

  /// 顶部微高光，用于建立玻璃边缘层次。
  final Color glassHighlight;

  /// BackdropFilter 的模糊半径；关闭 GlassConfig 后自动回退。
  final double glassBlur;

  @override
  WorkbenchTokens copyWith({
    Color? canvas,
    Color? panel,
    Color? raised,
    Color? subtle,
    Color? panelBorder,
    Color? panelShadow,
    Color? raisedShadow,
    Color? focusRing,
    Color? mutedText,
    Color? divider,
    Color? reward,
    Color? rewardContainer,
    Color? info,
    Color? danger,
    Color? sealColor,
    Color? gold,
    Color? glassPanel,
    Color? glassRaised,
    Color? glassBorder,
    Color? glassHighlight,
    double? glassBlur,
  }) {
    return WorkbenchTokens(
      canvas: canvas ?? this.canvas,
      panel: panel ?? this.panel,
      raised: raised ?? this.raised,
      subtle: subtle ?? this.subtle,
      panelBorder: panelBorder ?? this.panelBorder,
      panelShadow: panelShadow ?? this.panelShadow,
      raisedShadow: raisedShadow ?? this.raisedShadow,
      focusRing: focusRing ?? this.focusRing,
      mutedText: mutedText ?? this.mutedText,
      divider: divider ?? this.divider,
      reward: reward ?? this.reward,
      rewardContainer: rewardContainer ?? this.rewardContainer,
      info: info ?? this.info,
      danger: danger ?? this.danger,
      sealColor: sealColor ?? this.sealColor,
      gold: gold ?? this.gold,
      glassPanel: glassPanel ?? this.glassPanel,
      glassRaised: glassRaised ?? this.glassRaised,
      glassBorder: glassBorder ?? this.glassBorder,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      glassBlur: glassBlur ?? this.glassBlur,
    );
  }

  @override
  WorkbenchTokens lerp(WorkbenchTokens? other, double t) {
    if (other == null) return this;
    return WorkbenchTokens(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      panelBorder: Color.lerp(panelBorder, other.panelBorder, t)!,
      panelShadow: Color.lerp(panelShadow, other.panelShadow, t)!,
      raisedShadow: Color.lerp(raisedShadow, other.raisedShadow, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      reward: Color.lerp(reward, other.reward, t)!,
      rewardContainer: Color.lerp(rewardContainer, other.rewardContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      sealColor: Color.lerp(sealColor, other.sealColor, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      glassPanel: Color.lerp(glassPanel, other.glassPanel, t)!,
      glassRaised: Color.lerp(glassRaised, other.glassRaised, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassHighlight: Color.lerp(glassHighlight, other.glassHighlight, t)!,
      glassBlur: glassBlur + (other.glassBlur - glassBlur) * t,
    );
  }
}

extension WorkbenchThemeContext on BuildContext {
  WorkbenchTokens get tokens => Theme.of(this).extension<WorkbenchTokens>()!;
}

// ─── 字体：平台系统字体 ───
// 不指定字体家族，避免首次启动或 Golden 测试触发网络请求。
TextStyle _sansStyle({
  required double fontSize,
  required double height,
  FontWeight fontWeight = FontWeight.normal,
  Color? color,
  double? letterSpacing,
}) {
  // 纪律：负字间距仅用于 ≥18px 标题；小字号禁用。
  final effectiveSpacing = (letterSpacing ?? 0) < 0 && fontSize < 18
      ? 0.0
      : (letterSpacing ?? 0);
  return TextStyle(
    fontSize: fontSize,
    height: height,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: effectiveSpacing,
    fontFamilyFallback: const [
      'Noto Sans CJK SC',
      'Microsoft YaHei UI',
      'Microsoft YaHei',
    ],
  );
}

// ─── AppTheme ───
abstract final class AppTheme {
  static ThemeData light() => _build(
    brightness: Brightness.light,
    canvas: AppColors.lightCanvas,
    tokens: const WorkbenchTokens(
      canvas: AppColors.lightCanvas,
      panel: AppColors.lightSurface,
      raised: AppColors.lightRaised,
      subtle: Color(0xFFF0F8F3),
      panelBorder: Color(0xFFD8EAE0),
      panelShadow: Color(0x0A0A0F0F), // rgba(10,20,15,0.04)
      raisedShadow: Color(0x140A0F0F), // rgba(10,20,15,0.08)
      focusRing: Color(0x52159765), // #159765 @ 32%
      mutedText: AppColors.lightInkMuted,
      divider: AppColors.lightDivider,
      reward: AppColors.lightReward,
      rewardContainer: AppColors.lightRewardContainer,
      info: AppColors.lightInfo,
      danger: AppColors.lightDanger,
      sealColor: AppColors.lightPrimary, // 翠绿品牌色
      gold: AppColors.lightGold,
      glassPanel: Color(0xC2FFFFFF),
      glassRaised: Color(0xE8FFFFFF),
      glassBorder: Color(0x4D159765),
      glassHighlight: Color(0x99FFFFFF),
      glassBlur: 18,
    ),
    scheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.lightPrimary,
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: AppColors.lightPrimaryContainer,
      onPrimaryContainer: Color(0xFF064E3B),
      secondary: AppColors.lightSecondary,
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: AppColors.lightSecondaryContainer,
      onSecondaryContainer: Color(0xFF064E3B),
      tertiary: AppColors.lightReward,
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: AppColors.lightRewardContainer,
      onTertiaryContainer: Color(0xFF431407),
      error: AppColors.lightDanger,
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF450A0A),
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightInk,
      surfaceContainerHighest: Color(0xFFF0F8F3),
      onSurfaceVariant: AppColors.lightInkMuted,
      outline: Color(0xFF7A9C8B),
      outlineVariant: AppColors.lightDivider,
      shadow: Color(0x14000000),
      scrim: Color(0x66000000),
      inverseSurface: AppColors.lightInk,
      onInverseSurface: AppColors.lightCanvas,
      inversePrimary: AppColors.darkPrimary,
    ),
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    canvas: AppColors.darkCanvas,
    tokens: const WorkbenchTokens(
      canvas: AppColors.darkCanvas,
      panel: AppColors.darkSurface,
      raised: AppColors.darkRaised,
      subtle: Color(0xFF173B2D),
      panelBorder: Color(0xFF2D5A47),
      panelShadow: Color(0x47000000), // rgba(0,0,0,0.28)
      raisedShadow: Color(0x66000000), // rgba(0,0,0,0.40)
      focusRing: Color(0x665EE0A8), // #5EE0A8 @ 40%
      mutedText: AppColors.darkInkMuted,
      divider: AppColors.darkDivider,
      reward: AppColors.darkReward,
      rewardContainer: AppColors.darkRewardContainer,
      info: AppColors.darkInfo,
      danger: AppColors.darkDanger,
      sealColor: AppColors.darkPrimary, // 亮翠绿品牌色
      gold: AppColors.darkGold,
      glassPanel: Color(0xE0123A2C),
      glassRaised: Color(0xF21A4535),
      glassBorder: Color(0x665EE0A8),
      glassHighlight: Color(0x335EE0A8),
      glassBlur: 18,
    ),
    scheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.darkPrimary,
      onPrimary: Color(0xFF022C22),
      primaryContainer: AppColors.darkPrimaryContainer,
      onPrimaryContainer: Color(0xFFD1FAE5),
      secondary: AppColors.darkSecondary,
      onSecondary: Color(0xFF022C22),
      secondaryContainer: AppColors.darkSecondaryContainer,
      onSecondaryContainer: Color(0xFFD1FAE5),
      tertiary: AppColors.darkReward,
      onTertiary: Color(0xFF431407),
      tertiaryContainer: AppColors.darkRewardContainer,
      onTertiaryContainer: Color(0xFFFFEDD5),
      error: AppColors.darkDanger,
      onError: Color(0xFF450A0A),
      errorContainer: Color(0xFF7F1D1D),
      onErrorContainer: Color(0xFFFECACA),
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkInk,
      surfaceContainerHighest: AppColors.darkRaised,
      onSurfaceVariant: AppColors.darkInkMuted,
      outline: Color(0xFF6F9D87),
      outlineVariant: AppColors.darkDivider,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: AppColors.lightSurface,
      onInverseSurface: AppColors.darkCanvas,
      inversePrimary: AppColors.lightPrimary,
    ),
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color canvas,
    required ColorScheme scheme,
    required WorkbenchTokens tokens,
  }) {
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      visualDensity: isAndroid
          ? VisualDensity.standard
          : const VisualDensity(horizontal: -1, vertical: -1),
    );

    // ─── 字体排版层 ───
    // H1: 28px Bold；H2: 22px SemiBold；H3: 18px SemiBold
    // 正文: 15px；辅助: 13px，均交给平台系统字体渲染
    final textTheme = base.textTheme.copyWith(
      displayLarge: _sansStyle(
        fontSize: 28,
        height: 1.3,
        fontWeight: FontWeight.bold,
        color: scheme.onSurface,
        letterSpacing: -0.5,
      ),
      headlineMedium: _sansStyle(
        fontSize: 22,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
        letterSpacing: -0.3,
      ),
      titleLarge: _sansStyle(
        fontSize: 18,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleMedium: _sansStyle(
        fontSize: 16,
        height: 1.375,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleSmall: _sansStyle(
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyLarge: _sansStyle(fontSize: 15, height: 1.5, color: scheme.onSurface),
      bodyMedium: _sansStyle(
        fontSize: 15,
        height: 1.5,
        color: scheme.onSurface,
      ),
      bodySmall: _sansStyle(
        fontSize: 13,
        height: 1.35,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: _sansStyle(
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      labelMedium: _sansStyle(
        fontSize: 13,
        height: 1.35,
        color: scheme.onSurface,
      ),
      labelSmall: _sansStyle(
        fontSize: 12,
        height: 1.3,
        color: scheme.onSurface,
      ),
    );

    final controlHeight = isAndroid ? 48.0 : 36.0;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
    );
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
    );
    final inputBorderColor = Color.alphaBlend(
      scheme.onSurface.withValues(
        alpha: brightness == Brightness.light ? 0.14 : 0.18,
      ),
      tokens.subtle,
    );

    return base.copyWith(
      extensions: [tokens],
      textTheme: textTheme,
      iconTheme: IconThemeData(
        size: AppIconSize.md,
        color: scheme.onSurfaceVariant,
      ),
      primaryIconTheme: IconThemeData(
        size: AppIconSize.md,
        color: scheme.onPrimary,
      ),
      focusColor: scheme.primary.withValues(alpha: 0.1),
      hoverColor: scheme.primary.withValues(alpha: 0.06),
      highlightColor: scheme.primary.withValues(alpha: 0.08),

      // ─── AppBar：透明玻璃层，具体模糊由壳层/页面组件提供 ───
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: tokens.glassPanel,
        surfaceTintColor: Colors.transparent,
      ),

      // ─── Card：高不透明度玻璃色阶 + 1px 主色边框 ───
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: tokens.glassPanel,
        shape: cardShape.copyWith(side: BorderSide(color: tokens.glassBorder)),
        shadowColor: Colors.transparent,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: tokens.subtle,
        side: BorderSide(color: tokens.panelBorder),
        shape: shape,
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: tokens.glassRaised,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: tokens.glassBorder),
        ),
        labelTextStyle: WidgetStatePropertyAll(textTheme.bodyMedium),
      ),

      // ─── Dialog: 实色 raised 底 + 1px 边框 + 浮层阴影 ───
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: tokens.glassRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: tokens.glassBorder),
        ),
      ),

      // ─── Input: 干净背景 + 翠绿聚焦边框 ───
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.subtle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: tokens.panelBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: inputBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),

      // ─── SearchBar ───
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(tokens.glassPanel),
        shape: WidgetStatePropertyAll(
          cardShape.copyWith(side: BorderSide(color: tokens.glassBorder)),
        ),
      ),

      // ─── FilledButton: 翠绿主按钮 ───
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(0, controlHeight),
          shape: shape,
          elevation: 0,
        ),
      ),

      // ─── OutlinedButton: 翠绿边框次按钮 ───
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              minimumSize: Size(0, controlHeight),
              shape: shape,
              foregroundColor: scheme.primary,
            ).copyWith(
              side: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return BorderSide(
                    color: tokens.divider.withValues(alpha: 0.55),
                  );
                }
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)) {
                  return BorderSide(color: scheme.primary);
                }
                return BorderSide(color: tokens.panelBorder);
              }),
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)) {
                  return scheme.primary.withValues(alpha: 0.08);
                }
                return null;
              }),
            ),
      ),

      // ─── TextButton ───
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: Size(0, controlHeight),
          shape: shape,
          foregroundColor: scheme.primary,
        ),
      ),

      // ─── IconButton ───
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: Size.square(isAndroid ? 48 : 40),
          iconSize: AppIconSize.md,
          shape: shape,
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        focusElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),

      // ─── Checkbox ───
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: scheme.outline, width: 1.5),
      ),

      // ─── ListTile：桌面 44px、Android 48px，保证文字和图标有稳定节奏 ───
      listTileTheme: ListTileThemeData(
        minTileHeight: isAndroid ? 48 : 44,
        shape: shape,
        selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.5),
        selectedColor: scheme.primary,
        iconColor: scheme.onSurfaceVariant,
      ),

      // ─── NavigationBar (移动端): 半透明 surface + 顶缘分隔 ───
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: tokens.glassPanel,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.indicator),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
      ),

      // ─── TabBar: 统一分页 ───
      tabBarTheme: TabBarThemeData(
        dividerColor: tokens.divider,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelMedium,
      ),

      // ─── Divider ───
      dividerTheme: DividerThemeData(
        color: tokens.divider,
        thickness: 1,
        space: 1,
      ),

      // ─── SnackBar ───
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
        closeIconColor: scheme.onInverseSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.indicator),
        ),
      ),

      // ─── Tooltip ───
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppRadius.tooltip),
        ),
        textStyle: TextStyle(color: scheme.onInverseSurface),
      ),

      // ─── BottomSheet: 实色 raised + 顶部 8px 圆角 ───
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.glassRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBackgroundColor: tokens.glassRaised,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheetTop),
          ),
        ),
      ),
    );
  }
}
