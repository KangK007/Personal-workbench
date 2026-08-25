import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ─── 色彩体系：个人工作台 · 个人航行日志 ───
// 中性记录纸张承载长期工作，航迹蓝标记路径，信号红标记风险，黄铜色标记证据。

abstract final class AppColors {
  // ═══ 浅色 · 记录纸张 ═══
  static const lightCanvas = Color(0xFFF1F4F2);
  static const lightSurface = Color(0xFFFAFBF9);
  static const lightRaised = Color(0xFFFFFFFF);
  static const lightInk = Color(0xFF1B2521);
  static const lightInkMuted = Color(0xFF687772);
  static const lightDivider = Color(0xFFD5DEDA);
  static const lightPrimary = Color(0xFF256B73); // 航迹蓝绿
  static const lightPrimaryContainer = Color(0xFFDCECEF);
  static const lightSecondary = Color(0xFF5B7C78);
  static const lightSecondaryContainer = Color(0xFFE8EFED);
  static const lightSignal = Color(0xFFC84F45); // 信号红
  static const lightReward = Color(0xFFB8862D); // 黄铜证据
  static const lightRewardContainer = Color(0xFFF4EBD8);
  static const lightInfo = Color(0xFF4A7DA8);
  static const lightDanger = Color(0xFFB53D3A);
  static const lightGold = Color(0xFFB8862D); // 黄铜证据

  // ═══ 深色 · 夜间记录台 ═══
  static const darkCanvas = Color(0xFF101614);
  static const darkSurface = Color(0xFF18211E);
  static const darkRaised = Color(0xFF202B27);
  static const darkInk = Color(0xFFE9EFEB);
  static const darkInkMuted = Color(0xFFA5B4AE);
  static const darkDivider = Color(0xFF34433E);
  static const darkPrimary = Color(0xFF64B3BC);
  static const darkPrimaryContainer = Color(0xFF203F43);
  static const darkSecondary = Color(0xFF9ABBB5);
  static const darkSecondaryContainer = Color(0xFF253431);
  static const darkSignal = Color(0xFFF07A6F);
  static const darkReward = Color(0xFFDDB65B);
  static const darkRewardContainer = Color(0xFF4A3D22);
  static const darkInfo = Color(0xFF7EA9D0);
  static const darkDanger = Color(0xFFF07A6F);
  static const darkGold = Color(0xFFDDB65B);
}

// ─── 响应式断点（强制收敛：仅此两档）───
abstract final class AppBreakpoints {
  static const compact = 768.0; // <768: 移动端
  static const expanded = 1200.0; // ≥1200: 完整展开
}

// ─── 圆角标尺（v2 锐利几何）───
abstract final class AppRadius {
  static const card = 6.0; // 卡片/弹窗/FAB
  static const control = 4.0; // 按钮/输入框/Chip
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
  static const standard = Duration(milliseconds: 180);

  /// 页面切换、庆祝仪式、大面积编排。
  static const emphasized = Duration(milliseconds: 220);

  /// 页面切换过渡（emphasized 的实用档）。
  static const pageTransition = Duration(milliseconds: 220);

  /// 列表项交错入场间隔。
  static const staggerInterval = Duration(milliseconds: 20);
}

// ─── 间距标尺（v2 收紧 15-20%）───
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  // 页面横向边距
  static const pageCompact = 16.0;
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
    required this.route,
    required this.signal,
    required this.marker,
  });

  final Color canvas;
  final Color panel;
  final Color raised;
  final Color subtle;

  /// 面板 1px 描边，保持中性，不参与状态编码。
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
  final Color route;
  final Color signal;
  final Color marker;

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
    Color? route,
    Color? signal,
    Color? marker,
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
      route: route ?? this.route,
      signal: signal ?? this.signal,
      marker: marker ?? this.marker,
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
      route: Color.lerp(route, other.route, t)!,
      signal: Color.lerp(signal, other.signal, t)!,
      marker: Color.lerp(marker, other.marker, t)!,
    );
  }
}

extension WorkbenchThemeContext on BuildContext {
  WorkbenchTokens get tokens => Theme.of(this).extension<WorkbenchTokens>()!;
}

abstract final class AppFonts {
  static const display = 'LXGW WenKai GB';
  static const body = 'IBM Plex Sans SC';
  static const numeric = 'IBM Plex Mono';
}

TextStyle _bodyStyle({
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
    fontFamily: AppFonts.body,
    fontFamilyFallback: const [
      AppFonts.display,
      'GoldenCjk',
      'Noto Sans CJK SC',
      'Microsoft YaHei UI',
      'Microsoft YaHei',
    ],
  );
}

TextStyle _displayStyle({
  required double fontSize,
  required double height,
  Color? color,
}) => TextStyle(
  fontSize: fontSize,
  height: height,
  fontWeight: FontWeight.w500,
  color: color,
  letterSpacing: 0,
  fontFamily: AppFonts.display,
  fontFamilyFallback: const [
    AppFonts.body,
    'GoldenCjk',
    'Noto Sans CJK SC',
    'Microsoft YaHei UI',
  ],
);

// ─── AppTheme ───
abstract final class AppTheme {
  static ThemeData light() => _build(
    brightness: Brightness.light,
    canvas: AppColors.lightCanvas,
    tokens: const WorkbenchTokens(
      canvas: AppColors.lightCanvas,
      panel: AppColors.lightSurface,
      raised: AppColors.lightRaised,
      subtle: Color(0xFFE8EFED),
      panelBorder: Color(0xFFD5DEDA),
      panelShadow: Color(0x0A17211D),
      raisedShadow: Color(0x1A17211D),
      focusRing: Color(0x52256B73),
      mutedText: AppColors.lightInkMuted,
      divider: AppColors.lightDivider,
      reward: AppColors.lightReward,
      rewardContainer: AppColors.lightRewardContainer,
      info: AppColors.lightInfo,
      danger: AppColors.lightDanger,
      route: AppColors.lightPrimary,
      signal: AppColors.lightSignal,
      marker: AppColors.lightGold,
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
      tertiary: AppColors.lightSignal,
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFF8E5E2),
      onTertiaryContainer: Color(0xFF6E241F),
      error: AppColors.lightDanger,
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF450A0A),
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightInk,
      surfaceContainerHighest: Color(0xFFE8EFED),
      onSurfaceVariant: AppColors.lightInkMuted,
      outline: Color(0xFF758781),
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
      subtle: Color(0xFF253431),
      panelBorder: Color(0xFF34433E),
      panelShadow: Color(0x47000000), // rgba(0,0,0,0.28)
      raisedShadow: Color(0x66000000), // rgba(0,0,0,0.40)
      focusRing: Color(0x6664B3BC),
      mutedText: AppColors.darkInkMuted,
      divider: AppColors.darkDivider,
      reward: AppColors.darkReward,
      rewardContainer: AppColors.darkRewardContainer,
      info: AppColors.darkInfo,
      danger: AppColors.darkDanger,
      route: AppColors.darkPrimary,
      signal: AppColors.darkSignal,
      marker: AppColors.darkGold,
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
      tertiary: AppColors.darkSignal,
      onTertiary: Color(0xFF321312),
      tertiaryContainer: Color(0xFF4A2725),
      onTertiaryContainer: Color(0xFFFFDAD5),
      error: AppColors.darkDanger,
      onError: Color(0xFF450A0A),
      errorContainer: Color(0xFF7F1D1D),
      onErrorContainer: Color(0xFFFECACA),
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkInk,
      surfaceContainerHighest: AppColors.darkRaised,
      onSurfaceVariant: AppColors.darkInkMuted,
      outline: Color(0xFF83958F),
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
      displayLarge: _displayStyle(
        fontSize: 28,
        height: 1.3,
        color: scheme.onSurface,
      ),
      headlineMedium: _displayStyle(
        fontSize: 22,
        height: 1.35,
        color: scheme.onSurface,
      ),
      titleLarge: _bodyStyle(
        fontSize: 18,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleMedium: _bodyStyle(
        fontSize: 16,
        height: 1.375,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleSmall: _bodyStyle(
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyLarge: _bodyStyle(fontSize: 15, height: 1.5, color: scheme.onSurface),
      bodyMedium: _bodyStyle(
        fontSize: 15,
        height: 1.5,
        color: scheme.onSurface,
      ),
      bodySmall: _bodyStyle(
        fontSize: 13,
        height: 1.35,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: _bodyStyle(
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      labelMedium: _bodyStyle(
        fontSize: 13,
        height: 1.35,
        color: scheme.onSurface,
      ),
      labelSmall: _bodyStyle(
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

      // ─── AppBar：稳定实色工作面 ───
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: tokens.panel,
        surfaceTintColor: Colors.transparent,
      ),

      // ─── Card：实色工作面 + 中性边框 ───
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: tokens.panel,
        shape: cardShape.copyWith(side: BorderSide(color: tokens.panelBorder)),
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
        color: tokens.raised,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: tokens.panelBorder),
        ),
        labelTextStyle: WidgetStatePropertyAll(textTheme.bodyMedium),
      ),

      // ─── Dialog: 实色 raised 底 + 1px 边框 + 浮层阴影 ───
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: tokens.raised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: tokens.panelBorder),
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
        backgroundColor: WidgetStatePropertyAll(tokens.panel),
        shape: WidgetStatePropertyAll(
          cardShape.copyWith(side: BorderSide(color: tokens.panelBorder)),
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

      // ─── NavigationBar (移动端): 实色 surface + 顶缘分隔 ───
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: tokens.panel,
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
        backgroundColor: tokens.raised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBackgroundColor: tokens.raised,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheetTop),
          ),
        ),
      ),
    );
  }
}
