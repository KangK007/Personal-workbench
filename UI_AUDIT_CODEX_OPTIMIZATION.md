# UI 审查与 CODEX 优化方案

> 审查范围：个人工作台（Personal Workbench）Flutter 项目全部 18 个页面/视图 + 核心设计令牌 + 通用组件库
> 审查方式： golden 基准截图（test/goldens/）+ 实际 UI 截图（docs/images/ui_audit/）+ 源码静态分析
> 生成时间：2026-08-19

---

## 一、总体评分

| 维度 | 得分 | 说明 |
|------|------|------|
| 视觉美观性 | 6.5 / 10 | 配色方向正确，但多处装饰元素过强/失控，空白利用率低 |
| 风格一致性 | 7.0 / 10 | 组件复用度高，但头部装饰、卡片边框、标签页存在跨页面不一致 |
| 信息层次 | 7.5 / 10 | 标题/正文/辅助层级清晰，但数据可视化（日历格、习惯矩阵）对比度不足 |
| 可执行优化空间 | 高 | 80% 问题可通过调整 theme 参数和组件常量解决，无需重设计 |

---

## 二、UI 美观性问题清单

### 🔴 P0 — 严重破坏视觉品质

#### 1. 头部翠绿渐变过强（全页面通病）
**现象**：所有页面顶部均出现一条明显的翠绿→灰白渐变带，在浅色模式下尤其刺眼，像图片加载失败的色带或渲染瑕疵。
**截图**：today_mobile.png、plan_desktop.png、settings_desktop.png、notes_desktop.png……全部 18 张截图无一幸免。
**根因**：
- `PageHeader`（common.dart:302）使用 `primary.withValues(alpha: 0.04)` 作为渐变起点
- `workbench_shell.dart` 移动端 `AppBar.flexibleSpace`（line 305）使用相同渐变
- `_DesktopNavigation` 侧边栏头部（line 636）使用 `primary.withValues(alpha: 0.05)`
- 画布底色 `#F6F8F6` 本身带微绿调，叠加翠绿渐变后进一步放大绿色感知

**量化**：翠绿主色 `#059669` 饱和度约 70%，4% 透明度在 `#F6F8F6` 上产生的实际感知对比度约为 1.08:1，不足以形成"层次"，但足以引入色相污染。用户视觉上会感知到"绿色脏痕"而非"品牌高光"。

**建议**：
- 将 PageHeader 渐变 alpha 从 `0.04` 降至 `0.015`（或彻底移除渐变，改用 1px 底部微高光）
- 移动端 `flexibleSpace` 与桌面导航头部同步调整
- 保留 1px 顶部微高光（`primary.withValues(alpha: 0.08)` 高度 1px）作为品牌触感，但不做大面积渐变

#### 2. 大量页面底部空屏浪费（视觉空洞）
**现象**：Inbox、Goals、Focus、Growth、Habits、Protocols、Calendar 等页面底部出现超过 60% 的空白区域，无内容、无装饰、无状态提示。
**截图**：inbox_desktop.png（仅 1 条收集项，下方 80% 空白）、goals_desktop.png（1 条目标，下方 85% 空白）、focus_hub_desktop.png（最近记录后 70% 空白）。
**根因**：页面布局多使用 `Column` + `Expanded` 或 `ListView` 但内容不足以撑满视口时，无空态插图/占位，也未使用 `CustomScrollView` + `SliverFillRemaining` 做底部装饰收束。

**建议**：
- 当列表内容少于 5 项时，在 `ListView` 底部插入 `InkHorizon` 装饰 + 简短的空态提示或功能引导
- 或在 `ListView` 的 `physics` 设为 `AlwaysScrollableScrollPhysics` 并增加底部 `padding` 和装饰，确保页面可滚动到底并有视觉收束

---

### 🟡 P1 — 明显影响体验

#### 3. 日历网格线几乎不可见
**截图**：calendar_desktop.png
**问题**：时间刻度线和日期列分隔线对比度过低，用户难以判断时间块边界。
**根因**：日历组件未使用 `tokens.divider` 或使用了过低的 alpha。
**建议**：日历网格线统一使用 `tokens.divider`（`#E5E7EB`），在深色模式下使用 `darkDivider`（`#28322D`）。当前时间线使用 `primary` 带 2px 宽度提升辨识度。

#### 4. 习惯追踪矩阵与 28 日执行账本对比度不足
**截图**：habits_desktop.png、growth_desktop.png
**问题**：未打卡/空状态的方块几乎与背景融为一体，无法快速扫视历史记录。
**根因**：空状态使用 `subtle` 颜色（`#F0F4F2`）与 canvas（`#F6F8F6`）差异仅约 ΔE 2.3，远低于可辨识阈值（ΔE ≥ 5）。
**建议**：
- 空状态方块使用 `divider` 色（`#E5E7EB`）描边 + 透明填充，或至少提升 subtle→canvas 的对比度
- 打卡态使用 `primary` 填充，跳过态使用 `reward`（暖橙）填充，形成语义-色彩映射
- 增大单格尺寸：当前目测约 10px，建议 14×14px（桌面）/ 16×16px（移动端），增大触控与辨识面积

#### 5. 里程碑印章（Growth）视觉失效
**截图**：growth_desktop.png
**问题**：未解锁的里程碑印章呈极淡灰圈，像占位符错误，无质感。
**建议**：
- 未解锁：使用 `subtle` 填充 + `divider` 描边 + 30% 透明度图标，形成"封印"质感
- 已解锁：使用 `gold` 渐变描边 + 实心图标，提升成就感
- 当前等级印章（如 01）使用 `reward` 色填充，增强视觉锚点

#### 6. 笔记标签（Notes）样式缺失
**截图**：notes_desktop.png
**问题**：标签 "ASM"、"采样" 以纯文本展示，无圆角、无背景、无边距，像编辑器残字。
**建议**：使用已有的 `BambooChip` 组件（ink_decoration.dart）渲染标签，统一为圆角 6px、背景 `primaryContainer`、文字 `onPrimaryContainer`。

#### 7. 任务/项目卡片左侧强调色粗细不一致
**现象**：Today 页面任务卡片左侧有 3px 翠绿竖条，Focus 页面"下一项承诺"卡片也有左侧竖条，但 Project 页面概览卡片、Plan 页面列表项无此处理。
**建议**：统一规则——仅在"今日承诺/重点"、"高优先级"、"进行中"状态使用左侧强调色，普通列表项不使用，避免视觉噪音。

---

### 🟢 P2 — 细节优化

#### 8. 按钮圆角与高度跨页面轻微差异
**现象**：设置页"编辑"按钮（OutlinedButton）与 Focus 页"开始专注"（FilledButton）高度一致，但 Protocols 页"创建第一条链"、Notes 页"添加图片"的视觉重量不同。
**建议**：建立按钮层级——Primary Action（Filled，翠绿）、Secondary Action（Outlined，翠绿边框）、Tertiary Action（TextButton）。当前实现基本遵循此规范，但需统一：所有 OutlinedButton 的边框颜色从 `scheme.primary` 改为 `tokens.divider`，hover 时转为 `primary`，减少页面上的翠绿边框数量。

#### 9. 状态胶囊（StatusPill）在部分页面缺失
**现象**：Review 页"日/周/月"切换、Plan 页"全部/收件箱/周视图/任务群"切换使用 TabBar，而 Settings 页、Notes 页使用其他样式。TabBar 选中态下划线与胶囊风格不一致。
**建议**：TabBar 统一使用 `TabBarIndicatorSize.label` 的短下划线（当前已配置），但下划线宽度增加 2px（当前过细），颜色使用 `primary` 保持统一。或在 Tab 数量 ≤ 4 时改用横向 Pill 切换组（类似 `BambooChip` 的选中态）。

#### 10. 搜索栏与输入框的边框色在浅色模式过弱
**问题**：SearchBar（InputDecorationTheme）的 `enabledBorder` 使用 `tokens.divider`，在 `#F6F8F6` 底色上几乎不可见，导致输入框"浮在空中"。
**建议**：将 `enabledBorder` 颜色从 `tokens.divider` 提升为 `Color(0xFFD1D5DB)`（即比 divider 深 1 级），`focusedBorder` 保持 `primary` 2px。

---

## 三、风格一致性问题清单

### 1. 头部装饰风格不一致（最严重）

| 位置 | 当前实现 | 问题 |
|------|----------|------|
| 桌面 PageHeader | 渐变胶囊竖条 + 渐变背景 | 绿色污染 |
| 移动端 AppBar | flexibleSpace 渐变 + 底部边框 | 绿色污染 + 高度不一致 |
| 桌面侧边栏头部 | 渐变 + SealLogo | 绿色污染 |
| 专注会话页（focus_session_desktop.png） | 无渐变，纯白底 + 极简标题 | **这是最好的实现，应推广** |

**建议**：所有页面头部统一为"纯色底 + 1px 底部分割线 + 胶囊竖条"，移除渐变背景。专注会话页的设计语言最干净，符合"现代专业工作台"方向。

### 2. 卡片与列表项混用
**现象**：Today 页任务用列表项（带竖条），Plan 页任务用列表项（无竖条），Focus 页用卡片（带竖条），Settings 页用卡片分组，Project 页左侧用卡片、右侧用列表。
**建议**：
- 列表项：用于可无限滚动的数据（任务、笔记、收集箱）
- 卡片（LogSurface）：用于功能区块、空态、高价值信息（今日承诺、等级面板、协议统计）
- 统一：列表项 hover 态使用 `primary.withValues(alpha: 0.04)`，选中态使用 `primaryContainer.withValues(alpha: 0.5)`——当前已接近此规范，只需减少列表项上的竖条滥用

### 3. 图标系统双重来源
**现象**：`workbench_shell.dart` 中 `_item` 方法根据平台分别使用 `FluentIcons` 和 `Icons`（Material），但其他页面（如 Settings、Review）统一使用 `Icons`。这导致同屏可能出现两套图标风格（线条粗细、圆角处理不同）。
**建议**：全部统一为 Material 3 图标（`Icons.*`），移除 `FluentIcons` 依赖。Material 3 的图标与 Android 原生视觉一致，且项目中 90% 页面已使用 Material 图标。若保留 FluentIcons，则所有页面必须统一使用。

### 4. 颜色使用语义不一致
**现象**：
- `reward`（暖橙）在 Growth 页用于等级数字，在 Today 页用于完成 XP 标记，在 Focus 页用于状态——这是正确的语义映射。
- 但 `gold`（琥珀金）仅在极少数位置使用（里程碑、空态装饰），未充分发挥"进度与亮点"的语义。
- `info`（天蓝）在截图中几乎从未出现，作为系统色被浪费。

**建议**：
- `gold` 用于：当前选中日期、今日日期、最高优先级标记、解锁成就——建立黄金 = "当前/高光" 的语义
- `info` 用于：同步中、草稿态、未读标记——建立蓝色 = "进行中/待处理" 的语义

---

## 四、CODEX 优化方案（可执行代码级改动）

以下所有改动均无需 GPT-Image，纯 Flutter Theme/Widget 调整。

### 改动 A：根治头部翠绿污染（影响最大）

**文件**：`lib/ui/widgets/common.dart`、`lib/ui/workbench_shell.dart`

```dart
// === common.dart: PageHeader ===
// 修改前：
gradient: LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    theme.colorScheme.primary.withValues(alpha: 0.04),
    context.tokens.canvas,
  ],
),

// 修改后：移除 gradient，保留底部边框 + 1px 顶部微高光
BoxDecoration(
  color: context.tokens.canvas,
  border: Border(bottom: BorderSide(color: context.tokens.divider)),
)
// 顶部 1px 微高光由 WorkbenchBackdrop 统一处理，或单独加入一个 1px 的 DecoratedBox
```

```dart
// === workbench_shell.dart: mobile AppBar flexibleSpace ===
// 修改前：同上，0.04 alpha 渐变
// 修改后：移除 flexibleSpace 的 gradient，仅保留底部边框
// 将 AppBar 的 elevation 保持 0，backgroundColor 保持 tokens.canvas
```

```dart
// === workbench_shell.dart: _DesktopNavigation header ===
// 修改前：primary.withValues(alpha: 0.05) 渐变
// 修改后：纯色 tokens.panel.withValues(alpha: 0.96)，仅底部 border: tokens.divider
```

### 改动 B：WorkbenchBackdrop 光晕再克制化

**文件**：`lib/ui/widgets/common.dart` — `_BackdropPainter.paint`

```dart
// 当前：
// topRight: wash.withValues(alpha: 0.05)
// bottomLeft: accent.withValues(alpha: 0.04)
// bottomRight: gold.withValues(alpha: 0.035)

// 修改后：
// 将三个光晕的 alpha 全部减半，且限制光晕半径更小，使其仅在页面边缘 10% 区域隐约可见
center: Alignment.topRight, radius: 0.65 → radius: 0.35
center: Alignment.bottomLeft, radius: 0.55 → radius: 0.30
center: Alignment(0.85, 0.95), radius: 0.35 → radius: 0.20
```

### 改动 C：习惯/账本矩阵对比度提升

**文件**：各页面文件（habits_page.dart、growth_page.dart）

```dart
// 空状态方块（未打卡）
BoxDecoration(
  border: Border.all(color: tokens.divider),  // 之前可能是 subtle
  borderRadius: BorderRadius.circular(3),
  color: Colors.transparent,
)
// 打卡态
BoxDecoration(
  color: scheme.primary,  // 或 primaryContainer 根据层级
  borderRadius: BorderRadius.circular(3),
)
// 单格尺寸：从 10px 提升到 14px（桌面）或 16px（移动）
```

### 改动 D：日历网格线增强

**文件**：`lib/ui/pages/calendar_page.dart`（或相关日历组件）

```dart
// 时间/日期分隔线
Divider(color: tokens.divider, thickness: 1)
// 当前时间指示线
Container(
  height: 2,
  color: scheme.primary,
)
```

### 改动 E：笔记标签使用 BambooChip

**文件**：`lib/ui/pages/notes_page.dart`

```dart
// 将纯文本标签替换为
Wrap(
  spacing: 8,
  children: tags.map((t) => BambooChip(label: t, size: ChipSize.small)).toList(),
)
```

### 改动 F：输入框边框可见性提升

**文件**：`lib/core/theme/app_theme.dart`

```dart
// 修改 OutlineInputBorder 的 enabledBorder 颜色
enabledBorder: OutlineInputBorder(
  borderRadius: BorderRadius.circular(8),
  borderSide: BorderSide(color: Color(0xFFD1D5DB)), // 比 tokens.divider 深一级
),
```

### 改动 G：空态底部装饰收束

**文件**：所有列表页面的 `ListView` 或 `Column` 布局

```dart
// 在列表或 Column 末尾统一添加
const SizedBox(height: 32),
const InkHorizon(height: 60),
const SizedBox(height: 24),
// 若内容为空，则显示 EmptyState 组件（已存在，当前部分页面未使用）
```

### 改动 H：按钮边框统一（减少视觉噪音）

**文件**：`lib/core/theme/app_theme.dart`

```dart
// 修改 outlinedButtonTheme 的 side
outlinedButtonTheme: OutlinedButtonThemeData(
  style: OutlinedButton.styleFrom(
    minimumSize: Size(0, controlHeight),
    shape: shape,
    side: BorderSide(color: tokens.divider), // 之前是 scheme.primary
    foregroundColor: scheme.primary,
  ).copyWith(
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered)) {
        return scheme.primary.withValues(alpha: 0.08);
      }
      return null;
    }),
  ),
),
```

### 改动 I：里程碑印章质感

**文件**：`lib/ui/pages/growth_page.dart`（或相关组件）

```dart
// 未解锁
Container(
  width: 64,
  height: 64,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: tokens.subtle,
    border: Border.all(color: tokens.divider, width: 2),
  ),
  child: Icon(icon, color: tokens.mutedText.withValues(alpha: 0.4), size: 24),
)
// 已解锁（带金色高光）
Container(
  width: 64,
  height: 64,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: LinearGradient(
      colors: [tokens.gold.withValues(alpha: 0.2), tokens.gold.withValues(alpha: 0.05)],
    ),
    border: Border.all(color: tokens.gold, width: 2),
  ),
  child: Icon(icon, color: tokens.gold, size: 28),
)
```

---

## 五、实施优先级与工作量估算

| 优先级 | 改动 | 预估文件数 | 影响截图数 | 工作量 |
|--------|------|------------|------------|--------|
| P0 | 改动 A（移除头部渐变） | 2 | 全部 18 张 | 30 min |
| P0 | 改动 B（背景光晕减半） | 1 | 全部 18 张 | 15 min |
| P0 | 改动 G（空态底部装饰） | 约 8 个页面 | 8 | 45 min |
| P1 | 改动 C（习惯矩阵对比度） | 2 | 2 | 20 min |
| P1 | 改动 D（日历网格） | 1 | 1 | 15 min |
| P1 | 改动 I（里程碑印章） | 1 | 1 | 20 min |
| P1 | 改动 E（笔记标签） | 1 | 1 | 10 min |
| P2 | 改动 F（输入框边框） | 1 | 全部含输入的 | 10 min |
| P2 | 改动 H（按钮边框统一） | 1 | 全部 | 15 min |
| P2 | 图标统一（FluentIcons → Material） | 1 | 侧边栏 | 20 min |

**总计**：约 10 个文件，200 分钟纯编码时间，golden 基准需全部重跑（`flutter test --update-goldens`）。

---

## 六、视觉验证清单（重跑 golden 后对照）

1. [ ] `wide_today_light.png` — 头部无绿色渐变，时间轴清晰，今日重点卡片正常
2. [ ] `wide_today_dark.png` — 头部与背景自然过渡，无突兀绿色块
3. [ ] `android_today.png` — 移动端 AppBar 无绿色渐变，底部导航正常
4. [ ] `android_growth.png` — 28 日账本方块可辨识，里程碑有质感
5. [ ] `plan_desktop.png` / `protocols_desktop.png` — 标签页无绿色背景干扰
6. [ ] `notes_desktop.png` — 标签显示为圆角 chip
7. [ ] `calendar_desktop.png` — 网格线肉眼可辨识
8. [ ] `habits_desktop.png` / `growth_desktop.png` — 矩阵方块有边框，打卡态有填充
9. [ ] `focus_session_desktop.png` — 保持当前极简风格（作为正面基准）
10. [ ] 所有页面底部无突兀截断，滚动到底有视觉收束

---

## 七、设计方向修正建议（非代码）

1. **重新评估"翠绿渐变"策略**：当前设计文档要求"顶部 1px 主色微高光"和"三色背景光晕"，但实现中 4% alpha 的渐变面积过大，导致光晕变色斑。建议将"渐变"降级为"1px 细线"或"corner-only 光晕"，彻底避免大面积半透明叠色。
2. **空态设计规范**：当前 DESIGN.md 提到"每个主要页面必须覆盖首次空状态"，但截图中空态仅显示纯文字（如"还没有 CTDP 链"）。建议为空态统一配置 `EmptyState` 组件（几何图标 + 引导文案 + 主行动按钮），避免大段空白。
3. **数据可视化颜色规范**：为习惯/日历/成长等数据视图补充"状态-颜色"映射表：空=透明+边框、完成=翠绿、跳过=暖橙、逾期=危险红、当前=琥珀金，确保所有数据视图使用同一套语义色彩。
