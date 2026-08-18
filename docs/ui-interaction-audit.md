# UI 交互与动画优化审查报告

> 审查日期：2026-08-16 · 范围：`lib/ui` + `lib/app.dart` + 主题层
> **实施状态**：P0+P1 已于同日全部实施（#1-#7），P2 项（#8-#12）待定
> 现状：翠绿主题已上线，静态视觉已达标；**动态体验是当前最大短板**——全项目仅 4 处显式动画。

## 一、动画现状盘点

| 位置 | 已有动画 | 时长 |
|------|---------|------|
| 侧栏宽度折叠（workbench_shell.dart:150） | AnimatedContainer | 300ms easeOut |
| 任务行完成态高度变化（task_row.dart:35） | AnimatedSize | 220ms easeOutCubic |
| 加载指示器（ink_decoration.dart:280） | InkRippleLoader | 1200ms |
| 今日页展开/收起（today_page.dart:894） | AnimatedCrossFade | 160ms |

除此以外，几乎所有状态变化都是**瞬时跳变**。

## 二、发现的问题（按优先级）

### P0 · 高收益快赢

**1. 页面切换无过渡动画**
- 位置：`workbench_shell.dart:299` `_pageStack()` 使用 `IndexedStack`，桌面侧栏点击 / 移动端底部导航点击时页面**瞬跳**，是"廉价感"的最主要来源。
- 建议：外层包 `AnimatedSwitcher`（fade-through：150ms 淡出 + 12px 上移，easeOutCubic），需给每个页面加 `Key`；移动端可用横向滑动暗示层级。注意保持 IndexedStack 保活语义（或用 `FadeThroughSwitcher` + AutomaticKeepAlive 评估）。

**2. 勾选完成任务的瞬间反馈不足**
- 位置：`task_row.dart:92` Checkbox 自带涟漪，但完成时刻缺少"成就感"：无划线动画、无 XP 飘字。
- 建议：完成时标题文字加 `AnimatedDefaultTextStyle` 划线+变灰过渡（180ms）；若有 XP 奖励，加一个 `TweenAnimationBuilder` +240xp 飘字（上浮渐隐 800ms）。这是打卡类应用（如"21天早睡打卡"）的核心爽点。

**3. 数字指标跳变生硬**
- 涉及：今日进度百分比、成长页 XP/等级、专注页倒计时以外的统计数字。
- 建议：数值变化用 `TweenAnimationBuilder<int>` 做 300ms 计数滚动（等宽数字字体已有 NumericText，正好匹配）。

### P1 · 体验一致性

**4. 移动端二级页切换无方向感**
- 位置：`workbench_shell.dart:208` 移动端切换 section 直接 `setState`，前进/后退都是瞬跳，且 Android 返回键只是历史回退、无动画。
- 建议：前进 slide-in from right（220ms），返回 slide-out；底部导航主 tab 仍用 fade。

**5. 对话框/弹层样式不统一**
- 位置：全项目 100+ 处 `showDialog` / `showModalBottomSheet` 全用默认参数（默认白底 barrier、默认圆角）。
- 建议：封装 `showWorkbenchDialog()`：统一 `barrierColor: tokens.ink @ 40%`、`insetPadding`、fade + 4px scale-up 入场（180ms）；bottom sheet 统一顶部圆角 16px + 拖拽把手。已有 `showWorkbenchSnackBar` 封装先例，风格一致。

**6. 桌面端长列表无滚动条**
- 位置：仅侧栏 `workbench_shell.dart:595` 有 Scrollbar；各页面主内容区（任务、笔记、政策等长列表）桌面端不显示滚动条。
- 建议：在 `MaterialApp.scrollBehavior` 定制（`MaterialScrollBehavior` + 桌面平台加 `Scrollbar`），一处改动全局生效，同时可开启鼠标滚轮平滑滚动。

**7. 启动页过于简陋**
- 位置：`app.dart:86 _LaunchView` 只有一个转圈。
- 建议：加 Logo（已有 SealLogo 组件）淡入 + 加载文案，300ms，与翠绿品牌呼应。

### P2 · 打磨细节

**8. 按钮无按压反馈（桌面）**
- 桌面端无触摸涟漪感知，FilledButton 按下无缩放。建议主题层给按钮加 `ScaleEffect` 式按压 0.97 缩放（可用 `AnimatedScale` 包裹或直接调 `ElevatedButton.styleFrom` + 自定义）。

**9. 自定义可点击行缺鼠标手型**
- `task_row.dart:44`、`habits_page.dart:192` 等 InkWell 未设 `mouseCursor: SystemMouseCursors.click`，桌面端悬停仍是箭头。一处封装即可。

**10. 列表无骨架屏**
- 数据加载中只有 InkRippleLoader 居中转圈；长列表页可加 3-4 行灰色骨架块（shimmer 或静态 subtle 色），感知性能更好。

**11. 专注页计时器可加强**
- 倒计时数字切换可用固定宽度 + 轻微 fade；结束时点可加全屏脉冲/环形进度动画强化仪式感。

**12. 主题切换动画可调**
- MaterialApp 默认 `themeAnimationDuration: 200ms` 可保留，但建议补 `themeAnimationCurve: Curves.easeInOut`，深浅切换更顺滑。

## 三、建议实施顺序

| 批次 | 内容 | 预计改动面 |
|------|------|-----------|
| 第一批（快赢） | #1 页面切换过渡 + #3 数字滚动 + #9 鼠标手型 | 3 个文件，纯增量 |
| 第二批 | #2 完成反馈 + #5 对话框封装 + #6 scrollBehavior | 4-5 个文件 |
| 第三批（打磨） | #4 移动端方向动画 + #7 启动页 + #8/#10/#11/#12 | 按需 |

所有改动均为 UI 层增量，不触碰数据/逻辑层，与既有"只做界面优化"原则一致。
