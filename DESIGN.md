# Design System

## Direction Contract

**THESIS:** 把每日工作呈现为一张可操作的现代工作台面，而不是由等大卡片拼成的通用仪表盘。  
**OWN-WORLD:** 现代专业工作台风格：约 90% 现代软件秩序，10% 暖色点缀细节。亮色使用清爽灰白与翠绿主色，暗色使用深墨绿石墨底色与亮翠绿；翠绿负责主操作，暖橙用于状态与成就点缀，琥珀金用于进度与亮点。
**STORY:** 用户先看见今日三项重点与时间线，再收集、安排、执行，最后进入日记和回顾。任务完成即进度推进；专注即沉浸模式。  
**FIRST VIEWPORT:** 桌面为 80px 折叠/220px 展开侧栏、中央今日时间线与右侧重点清单；移动端纵向排列今日重点、下一时间块和任务。快速新增始终可达。  
**FORM:** Operate 模式的自适应工作台；宽屏（平板/大屏）使用导航栏与多栏布局，窄屏使用 Material 3 底部导航、顶部栏和单一主操作。

## Visual World

界面采用现代专业工作台风格：干净的灰白底色、翠绿主色调、暖橙状态点缀。主要面板采用绿色系玻璃拟态——半透明翠绿微光面板叠加背景模糊，顶部 1px 高光与翠绿外发光，仅在低端机或「减少透明效果」降级开关开启时回退为实色面板。装饰元素以几何图形和微妙的渐变光晕为主，不使用传统纹样。页面标题旁使用翠绿竖条标记，分区标题使用主色竖条 + 标签胶囊，画布背景使用极淡的网格纹理和右上角光晕，页面底部铺设淡淡的渐变。装饰仅服务于导航、分组和留白识别，不承载业务信息；亮色透明度控制在 1%-3%，不进入正文、表单和密集列表区域。

界面取材于现代 SaaS 工作台、专业效率工具和 Material 3 设计语言。干净的卡片、圆角、微阴影和留白构成主要视觉层次。结构依靠现代列、行、刻度、标签和状态标记，不使用大面积纹样或装饰性渐变。

### Color Roles

翠绿作为主操作色和选中态，暖橙作为状态与成就色，琥珀金作为进度与亮点色，灰色系作为正文与背景层。标题、正文、按钮、菜单和数据均使用平台系统字体，现代感由配色、字重、留白和微阴影表达。

- 浅色：`canvas #EDF5EF`（微绿灰白）、`panel #FFFFFF`、`raised #FFFFFF`、`subtle #F0F4F2`、`ink #1A1F1C`、`muted #6B7280`、`divider #E5E7EB`、`primary #059669`（翠绿主色）、`primaryContainer #D1FAE5`、`secondary #10B981`、`reward #F97316`（暖橙）、`gold #F59E0B`。
- 深色：`canvas #071612`（深墨绿）、`panel #151C19`、`raised #1C2420`、`subtle #1C2420`、`ink #F1F5F9`、`muted #94A3B8`、`divider #28322D`、`primary #34D399`（亮翠绿）、`primaryContainer #064E3B`、`secondary #6EE7B7`、`reward #FB923C`（亮暖橙）、`gold #FBBF24`（亮琥珀）。
- 玻璃令牌（`WorkbenchTokens.glass*`，供 `GlassSurface` 使用）：亮色 `glassPanel #8CFFFFFF`（白 55%）、`glassBorder #26059669`（翠绿 15%）、`glassHighlight #B3FFFFFF`（白 70%）、`glassGlow #1A059669`（翠绿 10%）、`glassBlur 10.0`；暗色 `glassPanel #14FFFFFF`（白 8%）、`glassBorder #2E34D399`（翠绿 18%）、`glassHighlight #33FFFFFF`（白 20%）、`glassGlow #3334D399`（翠绿 20%）、`glassBlur 12.0`。

深色主题使用相同语义角色，不直接反相。状态同时使用颜色、刻度线、符号或文本；正文与背景对比度目标至少 4.5:1。暖橙控制在 3%-5% 的细节范围内，不作为大面积底色。

### Typography

标题和正文均使用平台系统无衬线字体，避免联网下载。H1: 28px Bold（letterSpacing -0.5）、H2: 22px SemiBold（letterSpacing -0.3）、H3: 18px Medium、正文: 15px Regular、辅助: 13px Regular。间距基准为 4px，主要间距为 8/12/16/24px（见 `AppSpacing`）。时间、日期、等级、修为和计时器启用等宽数字特性。

### Shape And Depth

- 普通卡片统一 12px 圆角，按钮、输入框和标签统一 8px 圆角；弹窗和浮层使用 12px 圆角。
- 页面分区优先使用留白和 1dp 分隔线；重复条目可使用卡片。
- 卡片使用极淡阴影（浅色模式下 `0x08000000`，暗色模式无阴影）+ 1dp 边框；浮层阴影由 Material 组件按需提供。
- 玻璃面板（`GlassSurface`）结构：`RepaintBoundary → ClipRRect(radius) → BackdropFilter(ImageFilter.blur) → DecoratedBox(glassPanel 填充 + glassBorder 微光边框 + 顶部 1px glassHighlight 高光 + glassGlow 外发光)`；圆角默认 12（宽屏）/ 10（窄屏），模糊半径默认 `tokens.glassBlur`。`GlassConfig.blurEnabled == false` 或 `enabled == false` 时回退为 `tokens.panel` 96% 实色 + 常规阴影，层次与可读性不丢失。全屏区域（侧栏、AppBar、底部栏）使用 `radius: 0` + `glow: false` 的玻璃层。
- 背景装饰（网格纹理、光晕）仅用于画布边缘和空状态，透明度控制在 0.2%-0.3%。

## Layout

- `< 768 dp`: Android/窄屏布局，底部导航保持"今日、任务、回顾、国策、设置"五项，项目、专注、笔记等入口保留在顶部操作区或页面内导航。
- `720-1199 dp`: 导航栏或紧凑侧栏，内容保持单主列加辅助抽屉。
- `>= 1200 dp`: 宽屏完整侧栏，今日页为中央时间线和右侧重点区域。
- 固定格式控件使用稳定高度与约束，加载、计时和状态变化不得推动周围布局。
- 宽屏侧栏使用 `radius: 0` 的玻璃面板（GlassSurface），与主画布以 1px 玻璃边框区分，用分组编号、细分隔线、主色选中胶囊和图标着色区分层级；设置页图标使用统一 34×34 圆角翠绿容器 + 18px 描边图标，图标与标题垂直居中对齐，开关行与列表行保持 16px 统一水平内边距。窄屏触控区域不小于 `48dp`。

## Interaction

- 快速新增先收标题，再以可选字段补充日期、项目、优先级和类型。
- 创建任务和习惯在窄屏使用全屏编辑器。标题、CTDP 触发标志和 RSIP 最小动作在字段内校验；高级协议字段按组逐步呈现，不用 Snackbar 替代输入错误说明。
- 临时成功或撤销使用 Snackbar；永久删除和恢复备份使用确认对话框。
- 专注模式只保留当前任务、计时器、暂停/完成和退出。
- 窄屏所有触控目标至少 48 dp，并遵循系统返回、键盘和安全区。
- 完成承诺使用约 `220ms` 线性折叠，XP（成长）进入右侧刻度尺；尊重减少动效设置，不使用粒子、烟花、连续闪烁或声音。

## Visual QA

`test/visual_golden_test.dart` 固定宽屏 1536×864、窄屏 412×915 和 2026-08-07 示例日，使用独立内存数据库和系统中文字体生成 Golden。更新命令：

```powershell
flutter test test/visual_golden_test.dart --update-goldens
```

## States

每个主要页面必须覆盖首次空状态、加载、离线、同步中、同步失败和内容溢出。被拒绝的通知权限显示应用内解释，不阻塞任务与日记功能。删除进入回收站；永久删除明确说明不可恢复。

## Content Rules

使用具体动作作为按钮文案，例如"安排到今天""开始专注""移入回收站"。不展示未经验证的效率结论、科研结果或虚构数据。示例内容使用明显的通用个人任务，并可一键清空。

## Stitch 母版

本轮使用独立的私有 Stitch 项目 `Personal Workbench · 翠绿工作台 UI v4`，不修改已有 Stitch 项目。母版尺寸与视觉测试保持一致：宽屏 `1536 × 864`、窄屏 `412 × 915`。已生成宽屏 Today、窄屏 Today、宽屏 Tasks 的浅色母版，以及宽屏 Today、窄屏 Today 的深墨绿夜色变体；Stitch 仅用于视觉验证，生产实现仍使用现有 Flutter 组件和路由。
