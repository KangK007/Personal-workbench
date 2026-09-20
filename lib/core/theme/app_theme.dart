import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ─── 色彩体系：个人工作台 · 新芽晨光 / 夜露 ───
// 2026-09-19 换代（方案 C）：绿色主调。浅色「新芽晨光」= 晨露绿画布 + 纯白工作面；
// 深色「夜露」= 同源暗绿姊妹版，取代原暖褐「夜间炭壤」。
// 语义色（砖红 signal / 陶土 clay / 靛蓝 info）与 8 类节点色相**保持不变**，
// 以便沿用既有的 ΔE00 与对比度结论；仅主色族与中性层换轨。

abstract final class AppColors {
  // 命名约定：规范用语义名描述色板（新芽绿 sprout / 陶土 clay / 砖红 signal），
  // 实现层沿用既有字段名以免大规模重命名。二者是同一令牌，对照见
  // ORGANIC_UI_SPEC.md 第 4 节。全部色值经 tool/verify_colors.py 实算达标。

  // ═══ 浅色 · 新芽晨光 ═══
  static const lightCanvas = Color(0xFFF5FAF0); // 晨露绿画布
  static const lightSurface = Color(0xFFFFFFFF); // 纯白工作面
  static const lightRaised = Color(0xFFFFFFFF); // 对话框 / 菜单 / 浮层
  static const lightSubtle = Color(0xFFEFF8F0); // 输入框 / 次级填充
  static const lightInk = Color(0xFF17301B); // 正文 14.24:1
  static const lightInkMuted = Color(0xFF5D7961); // 辅助 4.80:1
  static const lightInkFaint = Color(0xFF849A88); // 装饰级 3.02:1，禁止承载信息
  static const lightDivider = Color(0xFFDFEBE1); // 柔化分组线
  static const lightBorderStrong = Color(0xFFC4D8C9); // 控件边界

  // 新芽绿 · 唯一行动色 4.84:1
  //
  // 取值说明：方案 C 原稿的 sprout-600 `#3F8F4F` 在白底仅 3.99:1、绿底 3.92:1，
  // 不足以承载按钮标签与链接文本（需 ≥4.5:1）。故沿同一色相主轴压深至
  // `#3E7F4B`（4.84:1 / 4.56:1）——这是**仍能达标的最亮值**，最大限度保留明快感。
  static const lightPrimary = Color(0xFF3E7F4B);
  static const lightPrimaryContainer = Color(0xFFE2F3E5);
  static const lightPrimaryOnContainer = Color(0xFF1D4A27); // 8.82:1

  // 分类色层：8 类节点专用。色相**未随换代调整**——它们在纯白工作面下
  // 两两最小 ΔE00 仍为 14.7（属「可用」区间），无需重调。
  static const lightTeal = Color(0xFF0F6668); // 习惯
  static const lightOlive = Color(0xFF8F931A); // 目标
  // 嫩黄绿容器对（方案 C 的「今日必达」pill）。浅色取方案 C 原稿的
  // #F1F6DA / #5F6C15，实测 5.20:1；容器底与 primaryContainer 的 ΔE00 = 6.4，
  // 落在「分类偏弱」区间，故 pill 一律带文字标签，不以底色单独承载语义。
  static const lightOliveContainer = Color(0xFFF1F6DA);
  static const lightOliveOnContainer = Color(0xFF5F6C15);
  static const lightViolet = Color(0xFF6B4A8C); // 触发器
  // 奖励节点专用琥珀。不复用 lightReward：后者是语义成果色（陶土），
  // 二者在同类色相上互相挤到 ΔE00 12.4，故分家。
  static const lightAmber = Color(0xFFBB811B);

  // 砖红 · 系统唯一红 6.76:1
  static const lightSignal = Color(0xFF9E3A32);
  static const lightSignalContainer = Color(0xFFF7DEDA);
  static const lightSignalOnContainer = Color(0xFF5A1F19); // 9.98:1

  // 陶土 · 成果与证据 5.79:1
  static const lightReward = Color(0xFF9B5227);
  static const lightRewardContainer = Color(0xFFF5E3D6);
  static const lightRewardOnContainer = Color(0xFF4A2410); // 10.86:1

  // 靛蓝 · 中性提示 5.98:1
  static const lightInfo = Color(0xFF3E6883);
  static const lightInfoContainer = Color(0xFFDCE8F0);
  static const lightInfoOnContainer = Color(0xFF1C3947); // 9.76:1

  // 提醒节点中性 accent。由原暖灰 `#918783` 换为绿灰，与绿色基座同温；
  // 压纯白 3.32:1，略高于 8 类节点色地板的 3.30:1（goal），不改变底线。
  static const lightOutline = Color(0xFF7E9284);

  // ═══ 深色 · 夜露 ═══
  static const darkCanvas = Color(0xFF0F1A13);
  static const darkSurface = Color(0xFF16231A);
  static const darkRaised = Color(0xFF1E2C21);
  static const darkSubtle = Color(0xFF243528);
  static const darkInk = Color(0xFFE4EFE6);
  static const darkInkMuted = Color(0xFFA2B5A6);
  static const darkInkFaint = Color(0xFF73867A);
  static const darkDivider = Color(0xFF2A3A2F);
  static const darkBorderStrong = Color(0xFF3D5044);

  static const darkPrimary = Color(0xFF7FCB8E); // 8.40:1
  static const darkPrimaryContainer = Color(0xFF1D3A26);
  static const darkPrimaryOnContainer = Color(0xFFC9EBD0); // 9.66:1

  static const darkTeal = Color(0xFF5FC0BD);
  static const darkOlive = Color(0xFFD4D864);
  static const darkOliveContainer = Color(0xFF2B3312);
  static const darkOliveOnContainer = Color(0xFFD4D864); // 8.71:1
  static const darkViolet = Color(0xFFC2A6E4);
  static const darkAmber = Color(0xFFDBA657);

  static const darkSignal = Color(0xFFE88C7E);
  static const darkSignalContainer = Color(0xFF4C2A26);
  static const darkSignalOnContainer = Color(0xFFF9D9D3);

  static const darkReward = Color(0xFFE2A176);
  static const darkRewardContainer = Color(0xFF4A3629);
  static const darkRewardOnContainer = Color(0xFFF7DCC6);

  static const darkInfo = Color(0xFF93B7CF);
  static const darkInfoContainer = Color(0xFF27333D);
  static const darkInfoOnContainer = Color(0xFFC7DCE8);

  static const darkOutline = Color(0xFF8A968C); // 压面板底 5.29:1
}

// ─── 响应式断点（强制收敛：仅此两档）───
abstract final class AppBreakpoints {
  static const compact = 768.0; // <768: 移动端
  static const compactHeight = 600.0; // 低高度横屏保持移动端导航
  static const expanded = 1200.0; // ≥1200: 完整展开
}

// ─── 圆角标尺（圆润有机）：外层工作面柔和，内层控件保持同心层级 ───
// 同心圆角规则（硬约束）：内边距 P < 外层圆角 R 时，内层必须用 r = R − P。
abstract final class AppRadius {
  static const xs = 8.0; // 小标签 / 复选框 / 色块
  static const control = 12.0; // 按钮 / 输入框 / Chip / 列表选中底
  static const card = 16.0; // 卡片 / FAB / 菜单
  static const panel = 20.0; // 主要工作面 / 证据块
  static const dialog = 24.0; // 对话框
  static const sheetTop = 28.0; // 底部弹层顶部角
  static const indicator = 12.0; // NavigationBar indicator / Snackbar
  static const tooltip = 8.0; // Tooltip
  static const pill = 999.0; // 短状态标签

  /// 小方点：任务复选框（20×20）、习惯打卡点（17×17）、分段进度块。
  ///
  /// 单列一档而非并入 [xs]（8）——17px 方块上 8px 已接近胶囊，会丢掉
  /// 「方块」的辨识；方案 C 用 6/17 明确保持方感。
  static const dot = 6.0;

  /// 主浮动操作按钮 52×52。
  ///
  /// 比 [card]（16）更圆是刻意的：方案 C 让 FAB 在整页的 16px 卡海中
  /// 单独圆一档，作为「唯一主操作」的形态线索。
  static const fab = 19.0;
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

  /// 元素退场，短于入场以减少等待感。
  static const exit = Duration(milliseconds: 150);

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
  static const xxl = 32.0;
  // P6：原与 xxl 同为 32，导致标尺实际只有 6 档，无法表达页面级分区。
  static const xxxl = 56.0;
  // 页面横向边距
  static const pageCompact = 20.0;
  static const pageMedium = 28.0;
  static const pageWide = 36.0;

  /// 移动端底部导航净空。
  ///
  /// 由 `workbench_shell.dart` 底部导航 Column 的实际构成推导：
  /// MobileBottomBar 58 + 同步状态条 26 + 次级页面横幅约 29 ≈ 113，取 116 作余量。
  /// 页面底部内边距使用它，避免内容被底部导航遮挡。
  /// 此前该数值在 15 个文件里硬编码 24 次，任一处漏改都会造成遮挡错位。
  ///
  /// 2026-09-19：底栏由 NavigationBar（80）换为 MobileBottomBar（58），
  /// 净空随之从 132 收紧到 116。
  static const bottomNavClearance = 116.0;

  /// 桌面卡片 / 表单列的宽度上限。
  ///
  /// 规范 §8 给「阅读列」定的 620 是按中文 25–40 字/行推出来的，约束的是
  /// **长文**；卡片列表的行长由标题长度决定，620 会过窄。实测 1536 视口下
  /// 主工作区约 847px，而任务卡的可见内容只需约 300px——不限宽时 65% 的
  /// 卡面是空白，扫读视线要横穿整行。720 让卡片保持「标题 + 标签行」的
  /// 自然宽度，同时仍是居中单列，不引入栅格。
  static const contentMax = 720.0;
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
    required this.borderStrong,
    required this.panelShadow,
    required this.raisedShadow,
    required this.focusRing,
    required this.mutedText,
    required this.inkFaint,
    required this.divider,
    required this.reward,
    required this.rewardContainer,
    required this.rewardOnContainer,
    required this.info,
    required this.infoContainer,
    required this.infoOnContainer,
    required this.teal,
    required this.olive,
    required this.oliveContainer,
    required this.oliveOnContainer,
    required this.violet,
    required this.amber,
    required this.route,
    required this.signal,
    required this.signalContainer,
    required this.signalOnContainer,
  });

  final Color canvas;
  final Color panel;
  final Color raised;
  final Color subtle;

  /// 面板 1px 描边，保持中性，不参与状态编码。
  final Color panelBorder;

  /// 交互控件边界（输入框 / 复选框）。与 [subtle] 填充共同构成边界，
  /// 不依赖单一线条承载可辨识性。
  final Color borderStrong;

  /// 保留给悬停等短暂抬升反馈；普通面板默认不使用投影。
  final Color panelShadow;

  /// 浮层投影色（配合 blur 16 / offset(0,6)）。
  final Color raisedShadow;

  /// 键盘焦点 2px 外环。
  ///
  /// 必须是**实色**：半透明会与底层混合导致对比度塌陷（原 primary@32%
  /// 实测仅 1.54:1 / 2.45:1，不满足 WCAG 1.4.11 的 3:1）。
  /// 现为实色 moss：5.70:1（浅）/ 8.17:1（深）。
  final Color focusRing;

  /// 辅助说明、次要元数据。
  final Color mutedText;

  /// 禁用文字与纯装饰。装饰级对比度（3.2–3.9:1），**禁止承载任何必须被读到的信息**。
  final Color inkFaint;

  /// 柔化分组线。对比度仅 1.3–1.4:1 是刻意的柔化取向：
  /// 分组职责由留白承担（组间 ≥ 组内 2 倍），线条只做次要提示。
  final Color divider;

  /// 成果色（陶土）：完成证据、里程碑、XP。**绝不用于错误或警告。**
  final Color reward;
  final Color rewardContainer;

  /// 容器底上的文字——**永远**用这个，不要直接叠 [reward]。
  final Color rewardOnContainer;

  /// 中性提示、同步状态。
  final Color info;
  final Color infoContainer;
  final Color infoOnContainer;

  /// 8 类节点独立色相之青碧（习惯 habit）。
  final Color teal;

  /// 8 类节点独立色相之橄榄（目标 goal）。
  final Color olive;

  /// 嫩黄绿容器对（方案 C 的「今日必达」pill 等强调标签）。
  final Color oliveContainer;
  final Color oliveOnContainer;

  /// 8 类节点独立色相之紫（触发器 trigger）；同时是 ColorScheme.tertiary 的值。
  final Color violet;

  /// 分类色层之琥珀（奖励 reward 节点）。
  ///
  /// 不复用 [reward]：后者是语义成果色（陶土）。在新暖色基座上二者
  /// 互相挤到 ΔE00 12.4，低于分类色可用区间上沿，故分开。
  final Color amber;

  final Color route;

  /// 系统唯一红：冲突 / 危险 / 停止。原 `danger` 字段已并入此处。
  final Color signal;
  final Color signalContainer;
  final Color signalOnContainer;

  @override
  WorkbenchTokens copyWith({
    Color? canvas,
    Color? panel,
    Color? raised,
    Color? subtle,
    Color? panelBorder,
    Color? borderStrong,
    Color? panelShadow,
    Color? raisedShadow,
    Color? focusRing,
    Color? mutedText,
    Color? inkFaint,
    Color? divider,
    Color? reward,
    Color? rewardContainer,
    Color? rewardOnContainer,
    Color? info,
    Color? infoContainer,
    Color? infoOnContainer,
    Color? teal,
    Color? olive,
    Color? oliveContainer,
    Color? oliveOnContainer,
    Color? violet,
    Color? amber,
    Color? route,
    Color? signal,
    Color? signalContainer,
    Color? signalOnContainer,
  }) {
    return WorkbenchTokens(
      canvas: canvas ?? this.canvas,
      panel: panel ?? this.panel,
      raised: raised ?? this.raised,
      subtle: subtle ?? this.subtle,
      panelBorder: panelBorder ?? this.panelBorder,
      borderStrong: borderStrong ?? this.borderStrong,
      panelShadow: panelShadow ?? this.panelShadow,
      raisedShadow: raisedShadow ?? this.raisedShadow,
      focusRing: focusRing ?? this.focusRing,
      mutedText: mutedText ?? this.mutedText,
      inkFaint: inkFaint ?? this.inkFaint,
      divider: divider ?? this.divider,
      reward: reward ?? this.reward,
      rewardContainer: rewardContainer ?? this.rewardContainer,
      rewardOnContainer: rewardOnContainer ?? this.rewardOnContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      infoOnContainer: infoOnContainer ?? this.infoOnContainer,
      teal: teal ?? this.teal,
      olive: olive ?? this.olive,
      oliveContainer: oliveContainer ?? this.oliveContainer,
      oliveOnContainer: oliveOnContainer ?? this.oliveOnContainer,
      violet: violet ?? this.violet,
      amber: amber ?? this.amber,
      route: route ?? this.route,
      signal: signal ?? this.signal,
      signalContainer: signalContainer ?? this.signalContainer,
      signalOnContainer: signalOnContainer ?? this.signalOnContainer,
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
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      panelShadow: Color.lerp(panelShadow, other.panelShadow, t)!,
      raisedShadow: Color.lerp(raisedShadow, other.raisedShadow, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      reward: Color.lerp(reward, other.reward, t)!,
      rewardContainer: Color.lerp(rewardContainer, other.rewardContainer, t)!,
      rewardOnContainer: Color.lerp(
        rewardOnContainer,
        other.rewardOnContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      infoOnContainer: Color.lerp(infoOnContainer, other.infoOnContainer, t)!,
      teal: Color.lerp(teal, other.teal, t)!,
      olive: Color.lerp(olive, other.olive, t)!,
      oliveContainer: Color.lerp(oliveContainer, other.oliveContainer, t)!,
      oliveOnContainer: Color.lerp(
        oliveOnContainer,
        other.oliveOnContainer,
        t,
      )!,
      violet: Color.lerp(violet, other.violet, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      route: Color.lerp(route, other.route, t)!,
      signal: Color.lerp(signal, other.signal, t)!,
      signalContainer: Color.lerp(signalContainer, other.signalContainer, t)!,
      signalOnContainer: Color.lerp(
        signalOnContainer,
        other.signalOnContainer,
        t,
      )!,
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
      subtle: AppColors.lightSubtle,
      panelBorder: AppColors.lightDivider,
      borderStrong: AppColors.lightBorderStrong,
      panelShadow: Color(0x0A14251A),
      raisedShadow: Color(0x1F14251A),
      focusRing: AppColors.lightPrimary,
      mutedText: AppColors.lightInkMuted,
      inkFaint: AppColors.lightInkFaint,
      divider: AppColors.lightDivider,
      reward: AppColors.lightReward,
      rewardContainer: AppColors.lightRewardContainer,
      rewardOnContainer: AppColors.lightRewardOnContainer,
      info: AppColors.lightInfo,
      infoContainer: AppColors.lightInfoContainer,
      infoOnContainer: AppColors.lightInfoOnContainer,
      teal: AppColors.lightTeal,
      olive: AppColors.lightOlive,
      oliveContainer: AppColors.lightOliveContainer,
      oliveOnContainer: AppColors.lightOliveOnContainer,
      violet: AppColors.lightViolet,
      amber: AppColors.lightAmber,
      route: AppColors.lightPrimary,
      signal: AppColors.lightSignal,
      signalContainer: AppColors.lightSignalContainer,
      signalOnContainer: AppColors.lightSignalOnContainer,
    ),
    scheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.lightPrimary,
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: AppColors.lightPrimaryContainer,
      onPrimaryContainer: AppColors.lightPrimaryOnContainer,
      // secondary 不参与本产品视觉：原 lightSecondary 与 primary 是同义冗余，
      // 已删除。Material 要求该槽位非空，故指向 primary 族（无调用点依赖）。
      secondary: AppColors.lightPrimary,
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: AppColors.lightPrimaryContainer,
      onSecondaryContainer: AppColors.lightPrimaryOnContainer,
      // tertiary 原 = signal(红)，与 error 语义错位（凡当第三强调色用处都渲染成危险红）。
      // 现独立为紫：vs signal ΔE 31.0，on/onContainer 对比度 7.04:1 / 10.47:1。
      tertiary: AppColors.lightViolet,
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFEDE4F6),
      onTertiaryContainer: Color(0xFF3E2755),
      error: AppColors.lightSignal,
      onError: Color(0xFFFFFFFF),
      errorContainer: AppColors.lightSignalContainer,
      onErrorContainer: AppColors.lightSignalOnContainer,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightInk,
      surfaceContainerHighest: AppColors.lightSubtle,
      onSurfaceVariant: AppColors.lightInkMuted,
      outline: AppColors.lightOutline,
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
      subtle: AppColors.darkSubtle,
      panelBorder: AppColors.darkDivider,
      borderStrong: AppColors.darkBorderStrong,
      panelShadow: Color(0x47000000),
      raisedShadow: Color(0x66000000),
      focusRing: AppColors.darkPrimary,
      mutedText: AppColors.darkInkMuted,
      inkFaint: AppColors.darkInkFaint,
      divider: AppColors.darkDivider,
      reward: AppColors.darkReward,
      rewardContainer: AppColors.darkRewardContainer,
      rewardOnContainer: AppColors.darkRewardOnContainer,
      info: AppColors.darkInfo,
      infoContainer: AppColors.darkInfoContainer,
      infoOnContainer: AppColors.darkInfoOnContainer,
      teal: AppColors.darkTeal,
      olive: AppColors.darkOlive,
      oliveContainer: AppColors.darkOliveContainer,
      oliveOnContainer: AppColors.darkOliveOnContainer,
      violet: AppColors.darkViolet,
      amber: AppColors.darkAmber,
      route: AppColors.darkPrimary,
      signal: AppColors.darkSignal,
      signalContainer: AppColors.darkSignalContainer,
      signalOnContainer: AppColors.darkSignalOnContainer,
    ),
    scheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.darkPrimary,
      onPrimary: Color(0xFF0F1A13),
      primaryContainer: AppColors.darkPrimaryContainer,
      onPrimaryContainer: AppColors.darkPrimaryOnContainer,
      secondary: AppColors.darkPrimary,
      onSecondary: Color(0xFF0F1A13),
      secondaryContainer: AppColors.darkPrimaryContainer,
      onSecondaryContainer: AppColors.darkPrimaryOnContainer,
      tertiary: AppColors.darkViolet,
      onTertiary: Color(0xFF2C1A40),
      tertiaryContainer: Color(0xFF3B2A4F),
      onTertiaryContainer: Color(0xFFE9DCF8),
      error: AppColors.darkSignal,
      onError: Color(0xFF3A1512),
      errorContainer: AppColors.darkSignalContainer,
      onErrorContainer: AppColors.darkSignalOnContainer,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkInk,
      surfaceContainerHighest: AppColors.darkRaised,
      onSurfaceVariant: AppColors.darkInkMuted,
      outline: AppColors.darkOutline,
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
        fontSize: 30,
        height: 1.32,
        color: scheme.onSurface,
      ),
      headlineMedium: _displayStyle(
        fontSize: 22,
        height: 1.4,
        color: scheme.onSurface,
      ),
      titleLarge: _bodyStyle(
        fontSize: 18,
        height: 1.5,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleMedium: _bodyStyle(
        fontSize: 16,
        height: 1.45,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleSmall: _bodyStyle(
        fontSize: 14,
        height: 1.5,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      // P3：bodyLarge 与 bodyMedium 原为同一档（16 / 1.5），语义重叠、易误用。
      // 现分家——bodyLarge 专供长文阅读列（行高放宽），bodyMedium 为界面正文
      // （桌面 15px；Android 保留 16px 正文下限）。
      bodyLarge: _bodyStyle(
        fontSize: 16,
        height: 1.65,
        color: scheme.onSurface,
      ),
      bodyMedium: _bodyStyle(
        fontSize: isAndroid ? 16 : 15,
        height: 1.6,
        color: scheme.onSurface,
      ),
      bodySmall: _bodyStyle(
        fontSize: 13,
        height: 1.5,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: _bodyStyle(
        fontSize: 15,
        height: 1.45,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      labelMedium: _bodyStyle(
        fontSize: 13,
        height: 1.45,
        color: scheme.onSurface,
      ),
      labelSmall: _bodyStyle(
        fontSize: 12,
        height: 1.4,
        color: scheme.onSurface,
      ),
    );

    // 密度（规范 6.4）：桌面 40 / 移动 52。触控目标 ≥48dp 由命中区矩形保证。
    final controlHeight = isAndroid ? 52.0 : 40.0;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
    );
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
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

      // ─── Dialog: 实色 raised 底 + 单一柔和阴影 ───
      dialogTheme: DialogThemeData(
        elevation: 2,
        shadowColor: tokens.raisedShadow,
        backgroundColor: tokens.raised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
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
        // 交互控件不依赖单一线条：subtle 填充 + borderStrong 描边 + 文字标签。
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: tokens.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: tokens.borderStrong),
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
        style:
            FilledButton.styleFrom(
              minimumSize: Size(0, controlHeight),
              shape: shape,
              elevation: 0,
              alignment: Alignment.center,
            ).copyWith(
              animationDuration: AppMotion.micro,
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return scheme.onPrimary.withValues(alpha: 0.16);
                }
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)) {
                  return scheme.onPrimary.withValues(alpha: 0.08);
                }
                return null;
              }),
            ),
      ),

      // ─── OutlinedButton: 翠绿边框次按钮 ───
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              minimumSize: Size(0, controlHeight),
              shape: shape,
              foregroundColor: scheme.primary,
              alignment: Alignment.center,
            ).copyWith(
              animationDuration: AppMotion.micro,
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
                if (states.contains(WidgetState.pressed)) {
                  return scheme.primary.withValues(alpha: 0.12);
                }
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
        style:
            TextButton.styleFrom(
              minimumSize: Size(0, controlHeight),
              shape: shape,
              foregroundColor: scheme.primary,
              alignment: Alignment.center,
            ).copyWith(
              animationDuration: AppMotion.micro,
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return scheme.primary.withValues(alpha: 0.14);
                }
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)) {
                  return scheme.primary.withValues(alpha: 0.08);
                }
                return null;
              }),
            ),
      ),

      // ─── IconButton ───
      iconButtonTheme: IconButtonThemeData(
        style:
            IconButton.styleFrom(
              minimumSize: Size.square(isAndroid ? 48 : 40),
              iconSize: AppIconSize.md,
              shape: shape,
              alignment: Alignment.center,
            ).copyWith(
              animationDuration: AppMotion.micro,
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return scheme.primary.withValues(alpha: 0.16);
                }
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)) {
                  return scheme.primary.withValues(alpha: 0.08);
                }
                return null;
              }),
            ),
      ),

      // ─── FAB（方案 C 规格）：52×52 + 圆角 19 ───
      // 尺寸经 sizeConstraints 下发，故调用点用常规 FloatingActionButton
      // 即可命中 52，不必用 .small（40）再靠外层 SizedBox 纠正。
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 3,
        focusElevation: 5,
        hoverElevation: 5,
        sizeConstraints: const BoxConstraints.tightFor(width: 52, height: 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.fab),
        ),
      ),

      // ─── Checkbox ───
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: tokens.borderStrong, width: 1.5),
      ),

      // ─── ListTile：桌面 44px、Android 48px，保证文字和图标有稳定节奏 ───
      listTileTheme: ListTileThemeData(
        minTileHeight: isAndroid ? 60 : 48,
        shape: shape,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        minLeadingWidth: 36,
        horizontalTitleGap: AppSpacing.md,
        selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.5),
        selectedColor: scheme.primary,
        iconColor: scheme.onSurfaceVariant,
      ),

      // ─── NavigationBar (移动端)：已由 MobileBottomBar 取代 ───
      // 方案 C 的选中态是「主色文字 + 标签下方 16×2.5 短条」，而
      // NavigationBar 的选中态只能是图标背后的胶囊 indicator，且指示条
      // 无法落在文字下方。故底栏改为自制组件（见 ui/widgets/mobile_bottom_bar.dart）。
      //
      // 此处保留主题项并把 indicator 置空：万一别处仍构造 NavigationBar，
      // 也不会把胶囊底带回来（胶囊与方案 C 的选中语言相冲突）。
      navigationBarTheme: NavigationBarThemeData(
        height: 58,
        elevation: 0,
        backgroundColor: tokens.panel,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
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

      // ─── BottomSheet: 实色 raised + 顶部 16px 圆角 ───
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
