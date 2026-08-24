# DESIGN V2 · 清新绿色玻璃拟态工作台

> 版本：v2.1（2026-08-23）
> 前版：v2.0 翠绿·锐意实色工作台（2026-08-21）
> 定位：以清新绿色玻璃承载导航、页头、重点和浮层，密集任务内容保持高不透明度以保证可读性与性能
> 配套：`design_preview/` 示例稿与 `lib/core/theme/app_theme.dart` 主题令牌

> 说明：本文早期章节仍保留部分 v2.0 的历史对照表。当前实现以 `DESIGN.md`、`app_theme.dart` 和 `solid_panel.dart` 为准；当两者描述冲突时，当前实现优先。

---

## 0. Direction Contract（方向契约）

| 维度 | 决策 |
|---|---|
| 一句话 | 清新绿色玻璃 × 高对比工作台 × 丰富仪式感动效 |
| 保留 | 翠绿主色、墨绿暗底、暖橙/琥珀点缀、系统字体+等宽数字、Material Outlined 图标 |
| 移除 | 装饰性渐变球、持续漂浮背景、复杂纹理、霓虹外发光和无意义装饰动画 |
| 引入 | 关键层玻璃面板、1px 翠绿边框、顶部微高光、6px 锐利圆角、收紧密度标尺、三级动效标尺 |
| 双主题 | 亮/暗等价投入，跟随系统 |

---

## 1. Color Roles（色彩令牌）

### 1.1 语义色（保留 v1 色值，不迁移成本）

| 角色 | 浅色 | 深色 | 用途 |
|---|---|---|---|
| canvas | `#EAF5EF` | `#071B14` | 页面底色 |
| surface | `#F9FDFA` | `#123529` | 高不透明度内容面板 |
| raised | `#FFFFFF` | `#1A3E30` | 浮层底（对话框/弹层/菜单） |
| subtle | `#F0F4F2` | `#1C2420` | 输入框/Chip/骨架填充 |
| ink | `#17352A` | `#E5F3EA` | 主文字 |
| inkMuted | `#698077` | `#9AB7AA` | 次级文字 |
| divider | `#CEE2D7` | `#2D5A47` | 分隔线 |
| primary | `#159765` | `#5EE0A8` | 翠绿主色 |
| primaryContainer | `#D8F1E2` | `#1E523D` | 主色容器 |
| secondary | `#38B989` | `#8DE8C2` | 次级翠绿 |
| secondaryContainer | `#E6F6ED` | `#113827` | 次级容器 |
| reward | `#F97316` | `#FB923C` | 暖橙（tertiary） |
| rewardContainer | `#FFF7ED` | `#431407` | 暖橙容器 |
| info | `#0EA5E9` | `#38BDF8` | 信息状态 |
| danger | `#EF4444` | `#F87171` | 危险状态 |
| gold | `#F59E0B` | `#FBBF24` | 琥珀点缀 |

### 1.2 面板与玻璃令牌

| 令牌 | 浅色 | 深色 | 说明 |
|---|---|---|---|
| panelBorder | `#E2E8E5` | `#2A342F` | 面板 1px 描边（同色系灰绿，非中性灰） |
| panelShadow | `rgba(10,20,15,0.04)` | `rgba(0,0,0,0.28)` | 面板投影：blur 10、offset (0,3) |
| raisedShadow | `rgba(10,20,15,0.08)` | `rgba(0,0,0,0.40)` | 浮层投影：blur 16、offset (0,6) |
| focusRing | `#059669 @ 32%` | `#34D399 @ 40%` | 键盘焦点 2px 外环（新增强可访问性） |

**当前实现**：`glassPanel`、`glassRaised`、`glassBorder`、`glassHighlight`、`glassBlur` 和 `GlassSurface` 由主题统一提供；`GlassConfig.blurEnabled=false` 时回退为高不透明度面板。

### 1.3 色彩使用纪律

- 强调色仅用于：主操作、选中态、关键数据、品牌标识。大面积区域永远中性
- 亮色模式正文对比度 ≥ 12:1（#1A1F1C on #EDF5EF ≈ 15:1 ✓）
- 次级文字对比度 ≥ 4.5:1（#6B7280 on #FFFFFF ≈ 4.8:1 ✓）
- 边框对比度 ≥ 1.15:1（相对 surface，修正 P0#2 对比度问题的基准）

---

## 2. Shape & Depth（形状与深度）

### 2.1 圆角标尺（v1 → v2）

| 元素 | v1 | v2 |
|---|---|---|
| 卡片/弹窗/FAB | 12px | **6px** |
| 按钮/输入框/Chip | 8px | **5px** |
| 底部弹层顶部角 | 16px | **8px** |
| NavigationBar indicator | 10px | **6px** |
| Snackbar | 10px | **6px** |
| Tooltip | 6px | **4px** |
| 骨架块 | 跟随容器 | 跟随容器（6/5px） |

### 2.2 层次手法（边框+微阴影双保险）

```
层级 0  canvas      纯色，无边框无阴影
层级 1  surface 面板  panelBorder 1px + panelShadow(blur 10, y+3, 4-6%)
层级 2  raised 浮层  panelBorder 1px + raisedShadow(blur 16, y+6, 8-12%)
选中态  surface 面板  左缘 3px 实心 primary 条 + 边框转 primary@40%
```

- 禁止：背景模糊、外发光（glow）、渐变边框、大面积阴影
- 阴影只在浅色模式极轻（4-6%），深色模式加深（28%）以保证可见性

### 2.3 强调元素（全部纯色实心）

| 元素 | v1（渐变） | v2（实心） |
|---|---|---|
| PageHeader 竖条 | 5px primary→secondary 渐变+圆点 | **3px 实心 primary，全高** |
| SectionHeading 竖条 | 4px 渐变 | **3px 实心 primary@60%**（与页头区分层级） |
| 空态徽章 | 双层渐变圆+玻璃圆 | **56px 圆，1.5px primary@40% 描边，内部 primary@8% 填充，26px Outlined 图标** |
| 选中态侧栏项 | 渐变条 | **3px 实心 primary 左缘条** |
| 任务卡强调条 | 规则不一 | **统一：3px 实心，doing=primary、todo=inkMuted@40%、done=success@30%、cancelled=divider** |

---

## 3. Typography（排版）

维持 v1 体系不变：系统字体链（Noto Sans CJK SC → Microsoft YaHei UI → Microsoft YaHei），无自定义字体。

| 语义 | 槽位 | 字号/行高 | 字重 |
|---|---|---|---|
| H1 | displayLarge | 28/1.3 | Bold, ls -0.5 |
| H2 | headlineMedium | 22/1.35 | w600, ls -0.3 |
| H3 | titleLarge | 18/1.4 | w600 |
| H4 | titleMedium | 16/1.375 | w600 |
| 正文 | bodyLarge/Medium | 15/1.5 | normal |
| 辅助 | bodySmall | 13/1.35 | normal |
| 数字 | NumericText | 跟随槽位 | w600 + tabularFigures |

新增纪律：标题负字间距仅用于 ≥18px；小标签（≤12px）禁用负间距。

---

## 4. Spacing & Density（间距与密度）

### 4.1 密度收紧（v1 → v2，整体 -15~20%）

| 项 | v1 | v2 |
|---|---|---|
| 列表行高 | 48px | **44px** |
| 列表行水平内边距 | 16px | **14px** |
| 分区间距 | 24px | **20px** |
| 页面边距（wide） | 28px | **24px** |
| 页面边距（compact） | 16px | **14px** |
| 卡片内边距 | 16px | **14px** |
| 间距标尺 | 4/8/12/16/24/32/40 | **4/8/12/14/20/24/32** |
| 桌面视觉密度 | (-1,-1) | (-1,-1) 不变 |

### 4.2 响应式断点（强制收敛）

```
compact  = 768   （移动布局）
expanded = 1200  （完整桌面布局）
```

**纪律**：页面局部布局切换只允许使用这两个断点（或其派生的 compact-200 阅读栏宽度等规范值），禁止新硬编码阈值。现存 8 种碎片化阈值在实施阶段全部收敛。

---

## 5. Motion（动效规范）★ 新增章节

### 5.1 三级时长标尺

| 级别 | 时长 | 曲线 | 用途 |
|---|---|---|---|
| micro | 120ms | easeOut | 按压反馈、悬停、开关、焦点环 |
| standard | 200ms | easeOutCubic | 淡入淡出、尺寸变化、Snackbar、弹层入场 |
| emphasized | 320ms | emphasizedDecelerate | 页面切换、庆祝仪式、大面积编排 |

### 5.2 必备动效清单（修复 P1#4）

| 场景 | 规格 |
|---|---|
| 页面切换 | 240ms 淡入 + 8px 上移（替换 IndexedStack 瞬跳；移动端二级页 280ms 水平推入） |
| 列表入场 | 每项 20ms 交错 stagger，standard 淡入+12px 位移，最多前 8 项参与 |
| 计数滚动 | AnimatedNumber 350ms easeOutCubic（扩展到回顾快照/成长等级等全部数据位） |
| 任务完成 | 勾选 120ms 缩放弹跳 + 行内删除线划过 |
| 专注庆祝 | FocusCelebration 保留并精修（1800ms，彩纸四色改实心纯色） |
| 骨架屏 | shimmer 1300ms 循环保留 |
| 侧栏折叠 | 保留现有实现 |
| 空态入场 | 图标徽章 320ms 缩放淡入 + 文案 200ms 延迟 80ms 跟入 |

### 5.3 无障碍

所有动效必须检查 `MediaQuery.disableAnimations`：禁用时全部退化为瞬时状态（静态显示终态）。彩纸/涟漪类装饰动效直接不播放。

---

## 6. Components（组件规范）

### 6.1 变更总表

| 组件 | 变更 |
|---|---|
| GlassSurface | **废弃** → 新建 `SolidPanel`（radius 默认 6，border+shadow，`elevated` 参数切换浮层阴影） |
| LogSurface | 别名保留，内部改委托 SolidPanel |
| PageHeader | 玻璃底条→实色 surface 底条+底 1px divider；渐变竖条→3px 实心；密度收紧 |
| SectionHeading | 渐变窄条→3px 实心 primary@60%；标题 20→18px |
| EmptyState | 双渐变环→单色描边圆；强制推广到 Inbox/Goals/Focus/Growth（修 P0#3） |
| TaskRow | 行高 44px；左侧强调条按 2.3 节状态色规范统一（修 P1#7） |
| StatusPill / BambooChip | BambooChip 改名 `Tag`（清理水墨残留命名）；高度 24→22px |
| 骨架屏 | 圆角跟随新标尺，shimmer 保留 |
| Dialog | 实色 raised 底 + 1px 边框 + raisedShadow；圆角 6px；入场 200ms 淡入+8px 缩放 |
| BottomSheet | 实色 raised + 顶部 8px 圆角 + 把手；滑入 280ms |
| FAB | 实色 primary，圆角 6px，阴影 raisedShadow |
| 侧栏 | 实色 surface + 右缘 1px divider；选中项 3px 实心左缘条 + primary@8% 底 |
| NavigationBar | 实色 surface + 顶缘 1px divider；indicator 圆角 6px |
| 背景组件 | WorkbenchBackdrop/SilkTexture/LandscapePattern/BambooSprig/OrientalMark **全部删除**，背景=纯 canvas |
| 对比度工具 | `_bestContrastingText` 合并为一份实现，硬编码色改引用 ink 令牌 |

### 6.2 新组件：SolidPanel

```dart
// lib/ui/widgets/solid_panel.dart（实施阶段创建）
SolidPanel({
  double radius = 6,
  bool elevated = false,     // false: panelShadow, true: raisedShadow
  bool selected = false,     // 左缘 3px 实心 primary 条 + 边框转 primary@40%
  EdgeInsetsGeometry padding = EdgeInsets.all(14),
  Widget? child,
})
```

---

## 7. Visual QA（验收基准）

1. 亮暗双主题逐页截图对比，无玻璃残影、无渐变残影
2. 对比度抽查：日历网格线、习惯矩阵空格、里程碑印章（修 P0#2 三个案例全部达标）
3. 断点扫描：`grep -rn "width >\|width <" lib/ui/pages/` 无 768/1200 之外阈值
4. 动效：disableAnimations 下全页面走查无中间态残留
5. 金图全部重基准（新风格视觉变化大，旧基准全部作废）
6. `flutter analyze` 零问题、189 测试全绿（金图重基准后）

---

## 8. 实施路线（用户确认预览稿后启动，另行立项）

```
Phase 1  令牌层：app_theme.dart 新令牌 + 删除 glass* + 组件主题圆角/密度更新
Phase 2  组件层：SolidPanel 新建 → common.dart/ink_decoration.dart 迁移 → 装饰组件删除
Phase 3  壳层：workbench_shell.dart 侧栏/导航/AppBar 实色化 + 页面切换动效
Phase 4  页面层：18 页逐一迁移（今日/任务/专注先行）+ 断点收敛 + 空态补齐
Phase 5  收尾：金图重基准、DESIGN.md 重写、命名清理、孤儿资源删除
```
