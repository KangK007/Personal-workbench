# 个人工作台设计系统

> 本文档记录当前“个人航行日志”界面实现（2026-08-24 起）。产品功能、数据语义和平台边界仍以 `PRODUCT.md` 为准。

> 项目级设计令牌、页面族、响应式规则和可访问性验收以根目录 `MASTER.md` 为准；本文保留实现说明与迁移记录。

## 用户、任务与内容

- 目标用户：在 Windows 进行完整规划与回顾、在 Android 快速记录和执行的单人科研学习用户。
- 核心任务：收集事项、组织项目、确定今日重点、安排时间、进入专注、沉淀笔记、回顾执行证据。
- 内容特点：中文信息密集、时间与顺序明确、状态变化频繁，并可能包含私密研究和个人记录。
- 设计目标：适合长时间阅读和重复操作；所有状态具有文字、图标或结构提示，不只依赖颜色。

## 视觉方向

视觉概念为“个人航行日志”。界面借用日志页、航迹、时刻和航标的组织逻辑，但不添加船舶、海浪、虚构坐标或装饰编号。

标志性元素“日志航迹线”只允许承载真实时间、任务顺序、里程碑、周期或执行证据。当前节点使用航迹色，完成节点使用黄铜标记色，冲突节点使用信号色；设置等无序内容不绘制航迹。

应用标记由“日志页 + 路径节点”组成，保留“个人工作台”名称与原有导航行为。

## 颜色令牌

| 角色 | 浅色 | 深色 | 用途 |
| --- | --- | --- | --- |
| `canvas` | `#F1F4F2` | `#101614` | 页面背景 |
| `surface` | `#FAFBF9` | `#18211E` | 稳定阅读面 |
| `ink` | `#1B2521` | `#E9EFEB` | 主文字 |
| `route` | `#256B73` | `#64B3BC` | 当前路径、主操作与焦点 |
| `signal` | `#C84F45` | `#F07A6F` | 冲突、失败与危险操作 |
| `marker` | `#B8862D` | `#DDB65B` | 完成证据、XP 与里程碑 |

`WorkbenchTokens` 同时提供 `panel`、`raised`、`subtle`、`panelBorder`、`divider`、`focusRing` 等结构令牌。所有工作面均为实色，不使用 `BackdropFilter` 或背景模糊。

## 字体

- 页名与少量章节标题：`LXGW WenKai GB Medium`，体现私人日志感。
- 正文、表单和控件：`IBM Plex Sans SC`，保持高密度中文界面的稳定可读性。
- 时间、XP、序号与参数：`IBM Plex Mono Medium`，使用等宽数字和 `tabularFigures`。
- 字体文件位于 `assets/fonts/`，由 Flutter 与 `design_preview/` 离线加载；许可证分别保存为 `OFL-LXGW-WenKai-GB.txt` 和 `OFL-IBM-Plex.txt`。
- 字间距统一为 `0`，不随视口缩放字号。

## 形状、密度与层级

- 面板圆角 `6px`，控件 `4px`，对话框和底部弹层 `8px`。
- 桌面内容行最小高度 `44px`，移动端内容行最小高度 `52px`，交互触控区域至少 `48dp`。
- 间距使用 `4 / 8 / 12 / 16 / 24 / 32`。
- 页面分区保持无框；卡片只用于重复记录、弹窗和确有边界的工具，不在卡片内嵌套卡片。
- 面板使用中性 `1px` 分隔线与克制阴影建立层次。状态强调使用左缘标记、航迹节点或图标，不制造装饰性表面。

## 页面布局

- `<768dp`：移动单列，保留今日、任务、回顾、行为、设置五个底部主入口、FAB 和 Android 系统返回。
- `768-1199dp`：折叠索引导航，主工作面与必要侧轨并存。
- `>=1200dp`：236px 索引导航；今日、任务、项目与工作周采用“主工作区 + 证据侧轨”。
- 笔记和回顾采用稳定阅读列；专注页为不嵌卡片的沉浸式计时工作面；自律页保持高密度规则编辑。
- 所有 `WorkbenchSection` 路由、控制器调用、键盘操作、数据模型和真实文案保持不变。

## 动效与无障碍

- 控件反馈 `120ms`，状态变化 `180ms`，页面切换 `220ms`。
- 任务完成时只推进对应真实航迹节点；开始专注时工作面收束到计时器；不使用持续环境动画。
- `MediaQuery.disableAnimationsOf(context)` 和 `prefers-reduced-motion` 直接显示静态终态。
- 键盘焦点使用明确 `2px` 外环；正文对比度目标至少 `4.5:1`；状态同时提供非颜色提示。

## 静态预览

`design_preview/` 保留原有 `index.html`、`today.html`、`tasks.html`、`focus.html`、`review.html`、`mobile.html`、`components.html` 和 `glass_today.html`，并新增：

- `projects.html`
- `notes.html`
- `behavior.html`
- `growth.html`
- `restriction.html`
- `settings.html`

`glass_today.html` 仅保留历史路径名，内容是新方向的亮暗主题验收页。`generate_glass_today.py` 使用项目离线字体生成 `glass_today_light.png` 与 `glass_today_dark.png`。

## 验证

```powershell
dart format lib test
flutter analyze
flutter test
flutter test --update-goldens test/visual_golden_test.dart
python design_preview/generate_glass_today.py
```

Golden 固定覆盖 1536×864 和 412×915 等关键工作面；静态预览还需检查 390px 横向溢出、亮暗主题、减少动效、长文案与链接有效性。
