# Design System

> 本文档记录当前实现（**v2 翠绿·锐意工作台 / Emerald Precision**，2026-08-21 起），完整设计决策见 `docs/DESIGN_V2_EMERALD_PRECISION.md`。本文仅记录实现背景，不构成后续 UI 开发的强制规范。保留的约束仅限于可读性、无障碍、触控可用性、错误反馈和不遮挡核心内容等产品质量要求。

## Direction Contract

**THESIS:** 把每日工作呈现为一张可操作的现代工作台面，而不是由等大卡片拼成的通用仪表盘。
**OWN-WORLD:** 实色锐利面板 × 翠绿气质：约 90% Linear 式工程秩序，10% 翠绿鲜活仪式感。亮色清爽灰白底 + 翠绿主色，暗色深墨绿石墨底 + 亮翠绿；翠绿负责主操作与选中态，暖橙用于状态与成就点缀，琥珀金用于进度与亮点。
**STORY:** 用户先看见今日三项重点与时间线，再收集、安排、执行，最后进入日记和回顾。任务完成即进度推进；专注即沉浸模式。
**FIRST VIEWPORT:** 桌面为 80px 折叠/220px 展开侧栏、中央今日时间线与右侧重点清单；移动端纵向排列今日重点、下一时间块和任务。快速新增始终可达。
**FORM:** Operate 模式的自适应工作台；宽屏（≥1200dp）使用导航栏与多栏布局，窄屏（<768dp）使用 Material 3 底部导航、顶部栏和单一主操作。
**v2 移除项:** 全部玻璃拟态（BackdropFilter）、三色背景光晕、丝纹/网格纹理、全部渐变装饰与渐变强调条。背景 = 纯色 canvas。

## Visual World

界面采用 Linear 式锐利工程风格：干净的实色面板、1px 边框 + 微阴影双保险层次、6px 锐利圆角、收紧的密度。层次不靠透明和模糊，靠边框、阴影与留白。结构依靠列、行、刻度、标签和状态标记；页面标题旁使用 3px 实心翠绿竖条，分区标题使用 3px primary@60% 竖条；装饰仅服务于导航、分组和空态识别，不承载业务信息。

### Color Roles

语义色沿用 v1 色值（无迁移成本），面板层次令牌全面替换 glass* 四件套：

- 浅色：`canvas #EDF5EF`、`panel #FFFFFF`、`raised #FFFFFF`、`subtle #F0F4F2`、`ink #1A1F1C`、`muted #6B7280`、`divider #E5E7EB`、`primary #059669`（翠绿主色）、`primaryContainer #D1FAE5`、`secondary #10B981`、`reward #F97316`（暖橙）、`gold #F59E0B`。
- 深色：`canvas #071612`（深墨绿）、`panel #151C19`、`raised #1C2420`、`subtle #1C2420`、`ink #F1F5F9`、`muted #94A3B8`、`divider #28322D`、`primary #34D399`（亮翠绿）、`primaryContainer #064E3B`、`secondary #6EE7B7`、`reward #FB923C`（亮暖橙）、`gold #FBBF24`（亮琥珀）。
- 面板令牌（`WorkbenchTokens`）：`panelBorder #E2E8E5 / #2A342F`（面板 1px 描边，同色系灰绿）、`panelShadow 4-6% / 28%`（blur 10, y+3）、`raisedShadow 8-12% / 40%`（blur 16, y+6）、`focusRing primary@32% / 40%`（键盘焦点 2px 外环）。
- **已删除**：glassPanel / glassBorder / glassHighlight / glassGlow / glassBlur 全部令牌及 GlassSurface 组件（`lib/ui/widgets/glass.dart` 仅剩兼容 re-export shim）。

色彩纪律：强调色仅用于主操作、选中态、关键数据与品牌标识，大面积区域永远中性。正文对比度 ≥ 12:1，次级文字 ≥ 4.5:1，边框相对 surface ≥ 1.15:1（日历网格、习惯矩阵空格、里程碑印章等空单元格不得使用 divider 作描边，用 `mutedText@0.35-0.45`）。深色主题使用相同语义角色，不直接反相。

### Typography

系统字体链（Noto Sans CJK SC → Microsoft YaHei UI → Microsoft YaHei），无自定义字体。H1: 28px Bold（ls -0.5）、H2: 22px w600（ls -0.3）、H3: 18px w600、H4: 16px w600、正文: 15px、辅助: 13px。标题负字间距仅用于 ≥18px；小标签（≤12px）禁用负间距。时间、日期、等级、计时器等数字使用 `NumericText`（w600 + tabularFigures 等宽特性）。

### Shape And Depth

- 圆角标尺（`AppRadius`）：卡片/弹窗/FAB 6px，按钮/输入框/Chip 5px，底部弹层顶部 8px，NavigationBar indicator 6px，Snackbar 6px，Tooltip 4px。
- 层次体系（`SolidPanel`，见 `lib/ui/widgets/solid_panel.dart`）：
  - 层级 0 canvas：纯色，无边框无阴影
  - 层级 1 surface 面板：panelBorder 1px + panelShadow
  - 层级 2 raised 浮层：panelBorder 1px + raisedShadow（`elevated: true`）
  - 选中态：左缘 3px 实心 primary 条 + 边框转 primary@40%（`selected: true`）
- 禁止：背景模糊、外发光、渐变边框、大面积阴影。阴影浅色模式极轻（4-6%），深色模式加深以保证可见性。
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

`test/visual_golden_test.dart` 固定宽屏 1536×864、窄屏 412×915 和 2026-08-07 示例日，使用独立内存数据库和系统中文字体生成 Golden；`test/solid_panel_test.dart` 覆盖实色面板无 BackdropFilter、elevated/selected 状态与对话框实色浮层。更新命令：

```powershell
flutter test test/visual_golden_test.dart test/ui_audit_screenshot_test.dart --update-goldens
```

## States

每个主要页面必须覆盖首次空状态、加载、离线、同步中、同步失败和内容溢出。被拒绝的通知权限显示应用内解释，不阻塞任务与日记功能。删除进入回收站；永久删除明确说明不可恢复。空态统一使用 EmptyState 徽章组件（Inbox/Goals/Focus/Growth 等全部页面）。

## Content Rules

使用具体动作作为按钮文案，例如"安排到今天""开始专注""移入回收站"。不展示未经验证的效率结论、科研结果或虚构数据。示例内容使用明显的通用个人任务，并可一键清空。
