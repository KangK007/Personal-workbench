import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ─── 色彩体系：翠绿·暖橙·清爽灰白 ───
// 灵感：自然治愈系工作台，清新绿意、层次分明
// 浅色：清爽灰白底 + 翠绿主色 + 暖橙点缀
// 深色：深墨绿石墨底 + 亮翠绿 + 暖橙点缀

abstract final class AppColors {
  // ═══ 浅色 · 清新绿意工作台 ═══
  static const lightCanvas = Color(0xFFF6F8F6); // 清爽灰白页面底色（微绿调）
  static const lightSurface = Color(0xFFFFFFFF); // 面板背景
  static const lightRaised = Color(0xFFFFFFFF); // 浮层背景
  static const lightInk = Color(0xFF1A1F1C); // 主文字
  static const lightInkMuted = Color(0xFF6B7280); // 次级文字
  static const lightDivider = Color(0xFFE5E7EB); // 分隔线
  static const lightPrimary = Color(0xFF059669); // 翠绿主色
  static const lightPrimaryContainer = Color(0xFFD1FAE5); // 翠绿容器
  static const lightSecondary = Color(0xFF10B981); // 次级翠绿
  static const lightSecondaryContainer = Color(0xFFECFDF5); // 次级背景
  static const lightReward = Color(0xFFF97316); // 暖橙状态
  static const lightRewardContainer = Color(0xFFFFF7ED); // 暖橙容器
  static const lightInfo = Color(0xFF0EA5E9); // 信息状态
  static const lightDanger = Color(0xFFEF4444); // 危险状态
  static const lightGold = Color(0xFFF59E0B); // 琥珀金

  // ═══ 深色 · 深墨绿夜色 ═══
  static const darkCanvas = Color(0xFF0E1311); // 深墨绿石墨底色
  static const darkSurface = Color(0xFF151C19); // 墨绿面板
  static const darkRaised = Color(0xFF1C2420); // 墨绿浮层
  static const darkInk = Color(0xFFF1F5F9); // 亮白文字
  static const darkInkMuted = Color(0xFF94A3B8); // 灰绿辅助
  static const darkDivider = Color(0xFF28322D); // 暗墨绿线
  static const darkPrimary = Color(0xFF34D399); // 亮翠绿
  static const darkPrimaryContainer = Color(0xFF064E3B); // 暗翠绿容器
  static const darkSecondary = Color(0xFF6EE7B7); // 亮翠绿辅助
  static const darkSecondaryContainer = Color(0xFF022C22); // 暗翠绿容器
  static const darkReward = Color(0xFFFB923C); // 亮暖橙
  static const darkRewardContainer = Color(0xFF431407); // 暗暖橙容器
  static const darkInfo = Color(0xFF38BDF8); // 亮天蓝
  static const darkDanger = Color(0xFFF87171); // 亮红色(警示)
  static const darkGold = Color(0xFFFBBF24); // 亮琥珀
}

// ─── 响应式断点 ───
abstract final class AppBreakpoints {
  static const compact = 768.0; // <768: 移动端
  static const expanded = 1200.0; // ≥1200: 完整展开
}

// ─── 间距标尺 ───
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 40.0;
  // 页面横向边距
  static const pageCompact = 16.0;
  static const pageMedium = 24.0;
  static const pageWide = 28.0;
}

// ─── 自定义主题令牌 ───
@immutable
class WorkbenchTokens extends ThemeExtension<WorkbenchTokens> {
  const WorkbenchTokens({
    required this.canvas,
    required this.panel,
    required this.raised,
    required this.subtle,
    required this.mutedText,
    required this.divider,
    required this.reward,
    required this.rewardContainer,
    required this.info,
    required this.danger,
    required this.sealColor,
    required this.washColor,
    required this.gold,
  });

  final Color canvas;
  final Color panel;
  final Color raised;
  final Color subtle;
  final Color mutedText;
  final Color divider;
  final Color reward;
  final Color rewardContainer;
  final Color info;
  final Color danger;
  final Color sealColor; // 主品牌强调色
  final Color washColor; // 背景晕染色
  final Color gold; // 点缀金色

  @override
  WorkbenchTokens copyWith({
    Color? canvas,
    Color? panel,
    Color? raised,
    Color? subtle,
    Color? mutedText,
    Color? divider,
    Color? reward,
    Color? rewardContainer,
    Color? info,
    Color? danger,
    Color? sealColor,
    Color? washColor,
    Color? gold,
  }) {
    return WorkbenchTokens(
      canvas: canvas ?? this.canvas,
      panel: panel ?? this.panel,
      raised: raised ?? this.raised,
      subtle: subtle ?? this.subtle,
      mutedText: mutedText ?? this.mutedText,
      divider: divider ?? this.divider,
      reward: reward ?? this.reward,
      rewardContainer: rewardContainer ?? this.rewardContainer,
      info: info ?? this.info,
      danger: danger ?? this.danger,
      sealColor: sealColor ?? this.sealColor,
      washColor: washColor ?? this.washColor,
      gold: gold ?? this.gold,
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
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      reward: Color.lerp(reward, other.reward, t)!,
      rewardContainer: Color.lerp(rewardContainer, other.rewardContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      sealColor: Color.lerp(sealColor, other.sealColor, t)!,
      washColor: Color.lerp(washColor, other.washColor, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
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
  return TextStyle(
    fontSize: fontSize,
    height: height,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing ?? 0,
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
      subtle: Color(0xFFF0F4F2),
      mutedText: AppColors.lightInkMuted,
      divider: AppColors.lightDivider,
      reward: AppColors.lightReward,
      rewardContainer: AppColors.lightRewardContainer,
      info: AppColors.lightInfo,
      danger: AppColors.lightDanger,
      sealColor: Color(0xFF059669), // 翠绿品牌色
      washColor: Color(0x08059669), // 翠绿晕染 3%
      gold: AppColors.lightGold,
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
      surfaceContainerHighest: Color(0xFFF0F4F2),
      onSurfaceVariant: AppColors.lightInkMuted,
      outline: Color(0xFF9CA3AF),
      outlineVariant: AppColors.lightDivider,
      shadow: Color(0x14000000),
      scrim: Color(0x66000000),
      inverseSurface: AppColors.lightInk,
      onInverseSurface: AppColors.lightCanvas,
      inversePrimary: Color(0xFF34D399),
    ),
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    canvas: AppColors.darkCanvas,
    tokens: const WorkbenchTokens(
      canvas: AppColors.darkCanvas,
      panel: AppColors.darkSurface,
      raised: AppColors.darkRaised,
      subtle: Color(0xFF1C2420),
      mutedText: AppColors.darkInkMuted,
      divider: AppColors.darkDivider,
      reward: AppColors.darkReward,
      rewardContainer: AppColors.darkRewardContainer,
      info: AppColors.darkInfo,
      danger: AppColors.darkDanger,
      sealColor: Color(0xFF34D399), // 亮翠绿品牌色
      washColor: Color(0x0A34D399), // 亮翠绿晕染 4%
      gold: AppColors.darkGold,
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
      outline: Color(0xFF64748B),
      outlineVariant: AppColors.darkDivider,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFFF1F5F9),
      onInverseSurface: Color(0xFF0E1311),
      inversePrimary: Color(0xFF059669),
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
    // H1: 28px Bold；H2: 22px SemiBold；H3: 18px Medium
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
      borderRadius: BorderRadius.circular(8),
    );
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    return base.copyWith(
      extensions: [tokens],
      textTheme: textTheme,
      focusColor: scheme.primary.withValues(alpha: 0.1),
      hoverColor: scheme.primary.withValues(alpha: 0.06),
      highlightColor: scheme.primary.withValues(alpha: 0.08),

      // ─── AppBar ───
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
      ),

      // ─── Card: 现代卡片 + 微阴影 ───
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: tokens.panel,
        shape: cardShape.copyWith(side: BorderSide(color: tokens.divider)),
        shadowColor: Colors.transparent,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: tokens.subtle,
        side: BorderSide(color: tokens.divider),
        shape: shape,
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: tokens.raised,
        elevation: 4,
        shape: cardShape.copyWith(side: BorderSide(color: tokens.divider)),
        labelTextStyle: WidgetStatePropertyAll(textTheme.bodyMedium),
      ),

      // ─── Dialog ───
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: tokens.raised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: tokens.divider),
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
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: tokens.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: tokens.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
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
          cardShape.copyWith(side: BorderSide(color: tokens.divider)),
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
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, controlHeight),
          shape: shape,
          side: BorderSide(color: scheme.primary),
          foregroundColor: scheme.primary,
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
          shape: shape,
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        focusElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // ─── Checkbox ───
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: scheme.outline, width: 1.5),
      ),

      // ─── ListTile ───
      listTileTheme: ListTileThemeData(
        minTileHeight: isAndroid ? 48 : 40,
        shape: shape,
        selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.5),
        selectedColor: scheme.primary,
        iconColor: scheme.onSurfaceVariant,
      ),

      // ─── NavigationBar (移动端) ───
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: tokens.panel.withValues(alpha: 0.95),
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
      ),

      // ─── TabBar: 统一分页 ───
      tabBarTheme: TabBarThemeData(
        dividerColor: tokens.divider,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),

      // ─── Tooltip ───
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(color: scheme.onInverseSurface),
      ),
    );
  }
}
