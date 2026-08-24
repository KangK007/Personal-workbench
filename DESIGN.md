# Design System

> 本文档记录当前实现（**清新绿色玻璃拟态工作台**，2026-08-23 起）。本文是主题、布局和交互组件的实现依据；产品功能、数据语义和平台约束仍以 `PRODUCT.md` 为准。

## Direction Contract

**THESIS:** 把每日工作呈现为一张可操作的现代工作台面，而不是由等大卡片拼成的通用仪表盘。
**OWN-WORLD:** 清透绿色玻璃 × 工程秩序：薄荷画布、半透明导航与重点面板、1px 翠绿边框和轻阴影。长列表使用高不透明度内容面板，避免模糊噪声和滚动开销；暖橙用于状态与成就点缀，琥珀金用于进度与亮点。
**STORY:** 用户先看见今日三项重点与时间线，再收集、安排、执行，最后进入日记和回顾。任务完成即进度推进；专注即沉浸模式。
**FIRST VIEWPORT:** 桌面为 80px 折叠/236px 展开玻璃侧栏、中央今日时间线与右侧重点清单；移动端纵向排列今日重点、下一时间块和任务。快速新增始终可达。
**FORM:** Operate 模式的自适应工作台；宽屏（≥1200dp）使用导航栏与多栏布局，窄屏（<768dp）使用 Material 3 底部导航、顶部栏和单一主操作。
**视觉边界:** 玻璃只用于导航、页头、今日重点、快速新增、弹窗和专注仪式层；禁止离散渐变球、持续漂浮背景、复杂纹理、霓虹外发光和无意义装饰动画。

## Visual World

界面采用清新玻璃拟态工作台：关键面板使用半透明填充、`BackdropFilter` 模糊、1px 翠绿边框、顶部微高光和轻阴影；任务列表、时间线和密集表格使用高不透明度面板。结构依靠列、行、刻度、标签和状态标记；页面标题旁使用 3px 实心翠绿竖条，分区标题使用 3px primary@60% 竖条；装饰仅服务于导航、分组和空态识别，不承载业务信息。

### Color Roles

语义色采用薄荷画布与深墨绿双主题，玻璃层由 `WorkbenchTokens` 统一提供：

- 浅色：`canvas #EAF5EF`、`surface #F9FDFA`、`raised #FFFFFF`、`subtle #F0F8F3`、`ink #17352A`、`muted #698077`、`divider #CEE2D7`、`primary #159765`、`primaryContainer #D8F1E2`、`reward #F97316`、`gold #F59E0B`。
- 深色：`canvas #071B14`、`surface #123529`、`raised #1A3E30`、`subtle #173B2D`、`ink #E5F3EA`、`muted #9AB7AA`、`divider #2D5A47`、`primary #5EE0A8`、`primaryContainer #1E523D`、`reward #FB923C`、`gold #FBBF24`。
- 玻璃令牌：`glassPanel`、`glassRaised`、`glassBorder`、`glassHighlight`、`glassBlur=18`；`GlassConfig.blurEnabled=false` 时保留半透明层级并移除 `BackdropFilter`。
- 面板令牌：`panelBorder`、`panelShadow`、`raisedShadow`、`focusRing` 继续用于高不透明度列表和浮层。

色彩纪律：强调色仅用于主操作、选中态、关键数据与品牌标识，大面积区域永远中性。正文对比度 ≥ 12:1，次级文字 ≥ 4.5:1，边框相对 surface ≥ 1.15:1（日历网格、习惯矩阵空格、里程碑印章等空单元格不得使用 divider 作描边，用 `mutedText@0.35-0.45`）。深色主题使用相同语义角色，不直接反相。

### Typography

系统字体链（Noto Sans CJK SC → Microsoft YaHei UI → Microsoft YaHei），无自定义字体。H1: 28px Bold（ls -0.5）、H2: 22px w600（ls -0.3）、H3: 18px w600、H4: 16px w600、正文: 15px、辅助: 13px。标题负字间距仅用于 ≥18px；小标签（≤12px）禁用负间距。时间、日期、等级、计时器等数字使用 `NumericText`（w600 + tabularFigures 等宽特性）。

### Shape And Depth

- 圆角标尺（`AppRadius`）：卡片/弹窗/FAB 6px，按钮/输入框/Chip 5px，底部弹层顶部 8px，NavigationBar indicator 6px，Snackbar 6px，Tooltip 4px。
- 层次体系（`SolidPanel` / `GlassSurface`，见 `lib/ui/widgets/solid_panel.dart`）：
  - 层级 0 canvas：纯色，无边框无阴影
  - 层级 1 内容面板：高不透明度 surface + panelBorder 1px + panelShadow
  - 层级 1 玻璃面板：glassPanel + BackdropFilter + glassBorder + 顶部高光
  - 层级 2 raised 浮层：glassRaised + raisedShadow（`elevated: true`）
  - 选中态：左缘 3px 实心 primary 条 + 边框转 primary@40%（`selected: true`）
- 禁止：装饰性背景模糊、外发光、渐变边框、大面积阴影；模糊只服务于玻璃导航、页头、重点区和浮层。阴影浅色模式极轻，深色模式加深以保证可见性。
- 任务行左侧强调条统一状态色：doing=primary、todo=muted@40%、done=primary@30%、cancelled=divider。
- 空态徽章：56px 圆，1.5px primary@40% 描边 + primary@8% 填充 + 26px Outlined 图标，320ms 缩放淡入。

## Layout

- `< 768 dp`（`AppBreakpoints.compact`）：Android/窄屏布局，底部导航保持"今日、任务、回顾、国策、设置"五项。
- `768-1199 dp`：导航栏或紧凑侧栏，内容保持单主列加辅助抽屉。
- `>= 1200 dp`（`AppBreakpoints.expanded`）：宽屏完整侧栏，今日页为中央时间线和右侧重点区域。
- **断点纪律**：页面局部布局切换只允许使用 compact=768 / expanded=1200 两个断点，禁止新硬编码阈值。
- 密度标尺：列表行 44px、行内边距 14px、分区间距 20px、页面边距 24（wide）/14（compact）、卡片内边距 14px；间距标尺 4/8/12/14/20/24/32（`AppSpacing`）。
- 固定格式控件使用稳定高度与约束，加载、计时和状态变化不得推动周围布局。窄屏触控区域不小于 48dp。

## Interaction

- 快速新增先收标题，再以可选字段补充日期、项目、优先级和类型。
- 创建任务和习惯在窄屏使用全屏编辑器。标题、CTDP 触发标志和 RSIP 最小动作在字段内校验；高级协议字段按组逐步呈现，不用 Snackbar 替代输入错误说明。
- 临时成功或撤销使用 Snackbar；永久删除和恢复备份使用确认对话框。
- 专注模式只保留当前任务、计时器、暂停/完成和退出。
- 窄屏所有触控目标至少 48 dp，并遵循系统返回、键盘和安全区。
- 完成承诺使用约 `220ms` 线性折叠，XP（成长）进入右侧刻度尺。
- 动效标尺（`AppMotion`）：micro 120ms easeOut（按压/悬停/焦点环）、standard 200ms easeOutCubic（淡入/尺寸/Snackbar/弹层入场）、emphasized 320ms emphasizedDecelerate（页面切换/庆祝编排）、页面切换 240ms 淡入+8px 上移、列表入场 20ms 交错（`StaggeredEntrance`，最多前 8 项）。
- **无障碍**：所有动效必须检查 `MediaQuery.disableAnimations`，禁用时退化为静态终态；彩纸/涟漪类装饰动效不播放。不使用连续闪烁或声音。

## Visual QA

`test/visual_golden_test.dart` 固定宽屏 1536×864、窄屏 412×915 和 2026-08-07 示例日，使用独立内存数据库和系统中文字体生成 Golden；`test/solid_panel_test.dart` 覆盖实色列表面板、玻璃面板降级、elevated/selected 状态与对话框浮层。更新命令：

```powershell
flutter test test/visual_golden_test.dart test/ui_audit_screenshot_test.dart --update-goldens
```

## States

每个主要页面必须覆盖首次空状态、加载、离线、同步中、同步失败和内容溢出。被拒绝的通知权限显示应用内解释，不阻塞任务与日记功能。删除进入回收站；永久删除明确说明不可恢复。空态统一使用 EmptyState 徽章组件（Inbox/Goals/Focus/Growth 等全部页面）。

## Content Rules

使用具体动作作为按钮文案，例如"安排到今天""开始专注""移入回收站"。不展示未经验证的效率结论、科研结果或虚构数据。示例内容使用明显的通用个人任务，并可一键清空。
