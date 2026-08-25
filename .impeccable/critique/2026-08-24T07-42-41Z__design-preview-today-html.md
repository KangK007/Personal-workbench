---
target: design_preview/today.html
total_score: 26
max_score: 40
na_heuristics: ""
p0_count: 0
p1_count: 3
timestamp: 2026-08-24T07-42-41Z
slug: design-preview-today-html
---
## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|---|---:|---|
| 1 | Visibility of System Status | 3/4 | 日期、状态、进度和冲突计数可见，但冲突没有直接处理反馈。 |
| 2 | Match Between System and Real World | 4/4 | 今日承诺、逻辑日、时间线、习惯和日结贴合个人科研工作流。 |
| 3 | User Control and Freedom | 2/4 | 有开始、取消和撤销路径，但冲突和时间线条目缺少就地退出/恢复动作。 |
| 4 | Consistency and Standards | 3/4 | 色板、字体、圆角和状态条统一；静态 div 伪控件与真实 Flutter 行为不一致。 |
| 5 | Error Prevention | 2/4 | 承诺锁定规则清晰，但排程冲突只有提示，没有预防或修复入口。 |
| 6 | Recognition Rather Than Recall | 3/4 | 当前页、日期、状态和时间清楚；习惯点阵缺少日期顺序和图例。 |
| 7 | Flexibility and Efficiency | 2/4 | 有 Ctrl+K 提示，但静态预览不可触发；批量重排和快捷修复不明显。 |
| 8 | Aesthetic and Minimalist Design | 3/4 | 日志色彩和实色表面成熟，但指标、承诺、时间线、习惯和日结竞争注意力。 |
| 9 | Error Recovery | 2/4 | 能发现“1 冲突”，不能在当前上下文中查看、调整或替换。 |
| 10 | Help and Documentation | 2/4 | 有锁定规则和搜索提示，但缺少逻辑日、冲突、点阵和下一步的上下文解释。 |
| **Total** |  | **26/40** | **Acceptable（65%）；基础可用，高影响恢复和移动连续性仍需处理。** |

## Design Specificity Verdict

这是明显为“个人航行日志”和单人科研/学习工作台定制的 Operate 界面：真实中文任务、逻辑日、今日承诺、航迹节点、route/signal/marker 状态色、文楷标题和等宽数字都具有产品依据，不是可直接套给任意待办应用的模板。

但 `design_preview/today.html` 仍有通用 dashboard 的类别化痕迹：顶部指标、承诺卡、时间线卡、习惯卡和日结卡并列，且 `.panel.timeline` 内嵌 `.tl-card.panel`，与 `MASTER.md` 禁止嵌套卡片墙的约束冲突。最大的机会是让冲突、当前任务、下一步和执行证据成为一条真正可操作的工作路径，而不是给每个区块各画一张卡。

### Deterministic scan

- `today.html` 单页 detector：exit code 0，JSON `[]`，0 条发现。
- `design_preview/` 目录 detector：实际 exit code 1，共 12 条 warning（脚本与参考文档约定的 findings exit code 2 不一致）。
- `side-tab` 7 条：主要位于 `tokens.css` 与 `glass_today.html`；其中任务状态条、选中条、冲突节点均绑定真实状态，属于低置信度误报。
- `flat-type-hierarchy` 4 条：位于 `components.html`、`glass_today.html`、`mobile.html`、`tasks.html`，部分是展示型页面的多角色字号聚合，需人工判断。
- `bounce-easing` 1 条：`focus.html:44`，是庆祝徽章的 bounce cubic-bezier 语法命中，建议改为更克制的 ease-out。
- 浏览器可视化未产生可靠证据：新标签页的可变注入失败，原因是 Playwright evaluate 只读，设置 `document.title` 报 `TypeError: Cannot set property title ... getter`；因此没有 [Human] overlay 或 impeccable console findings。

## Overall Impression

这套系统已经建立了稳定、克制且有科研记录气质的视觉世界。颜色、字体和状态结构值得保留；但今日页目前同时展示太多“证据”，反而弱化了“现在该做什么”。单一最大机会是把冲突处理和移动端连续操作从说明性信息提升为当前上下文中的明确动作。

## What's Working

1. “整理衍射实验数据与误差记录”“逻辑日 04:00 起算”“+12 XP”等真实文案让品牌语言与科研用户的工作场景绑定。
2. 左缘状态条、时间线节点、mono 时间和进度条共同编码顺序与证据，亮暗主题也保持一致。
3. 中性画布、实色面板和细分隔线适合长时间阅读，已经摆脱玻璃拟态、装饰渐变和模板化卡片墙的主要问题。

## Priority Issues

### [P1] 移动断点隐藏了全局入口

**问题**：`tokens.css` 在 `<768px` 隐藏侧栏并预留底部空间，但 `today.html` 没有对应的五项底部导航或 FAB。

**影响**：Android 用户在今日页无法直接切换任务、回顾、行为和设置，也无法快速捕获事项；跨端核心任务流被截断。

**修复**：复用 Flutter 的五项移动入口和单一快速捕获 FAB；为安全区和底部内容留出明确 padding。建议 `$impeccable adapt`。

### [P1] 冲突只被宣布，没有恢复动作

**问题**：`today.html` 的“1 冲突”和时间块重叠描述没有 signal 节点、明确状态文本或“查看冲突/调整安排”入口。

**影响**：用户能发现风险，却不能在当前上下文恢复，必须凭记忆跳到任务或日历页；Nielsen 5 和 9 均受损。

**修复**：在冲突行加入结构性 signal 节点、可见“时间冲突”文本和低摩擦调整入口，保持任务标题和当前时间上下文。建议 `$impeccable harden` + `$impeccable clarify`。

### [P1] 习惯点阵是无标签的颜色状态

**问题**：`.habit-dots .d` 只通过 `hit/miss/空` class 和位置表达状态，没有日期、周几、图例、文本或 aria 语义。

**影响**：屏幕阅读器、低视力和色觉差用户无法判断哪天完成、漏记或未记录，也无法确认点阵方向。

**修复**：增加日期/周几标签和完成、漏记、未记录图例；色点叠加勾/短线等结构符号，Flutter 对应补 Semantics。建议 `$impeccable audit`。

### [P2] 嵌套面板与首屏指标稀释“下一步”

**问题**：时间线外层 panel 内嵌多个 panel；顶部统计、承诺、习惯和日结都具有近似边界权重。

**影响**：用户先读数字和容器，而不是找到当前承诺、下一时间块或冲突修复；违反“今天只回答今天该做什么”的产品原则。

**修复**：时间线改为单一 rail + divider rows，移除内层边框；把统计降为页头元数据或证据侧轨，让当前承诺/下一步成为唯一主锚点。建议 `$impeccable distill` + `$impeccable layout`。

### [P2] 预览壳层包含不可操作的伪控件

**问题**：侧栏 `.nav-item`、折叠箭头、搜索提示和 `.checkbox` 多为 `div`，视觉上像可导航、可勾选或可触发控件，却没有键盘、语义或路由行为。

**影响**：Alex 看到的是虚假快捷路径；Sam 无法 Tab/Enter/Space 操作；静态预览和真实 Flutter 行为产生错误预期。

**修复**：若预览需要交互，改用 `<a>/<button>` 并添加 `aria-current`、`aria-label`、`aria-pressed` 和焦点顺序；若只是 specimen，明确标为展示状态。建议 `$impeccable audit` + `$impeccable polish`。

## Persona Red Flags

### Alex（Impatient Power User）

- `Ctrl+K 全局搜索` 在静态今日页只是提示，不能通过快捷键打开。
- 3 个承诺和 5 条时间线没有批量选择、重排或冲突快捷修复。
- 侧栏 `.nav-item` 是 div，没有可直接激活的路由或键盘路径。

### Sam（Accessibility-Dependent User）

- 习惯点阵没有日期、图例或语义名称，状态依赖颜色和位置。
- 中等断点隐藏导航文字，仅保留图标；静态预览没有 Tooltip/aria 标签。
- 折叠箭头、导航项和 checkbox 样式都不是可聚焦控件。

### Casey（Distracted Mobile User）

- `<768px` 没有底部五项入口或 FAB，离开今日页后回到任务/回顾成本高。
- “开始今天”位于顶部，长页面中不在拇指区。
- 移动样式仍有 44px 习惯行和 12px 状态点，容易误触或难以识别。

## Minor Observations

- `transition: all` 可收窄为颜色、背景和边框，避免无关属性动画。
- `.sidebar .nav-group` 的 `text-transform: uppercase` 对中文无效，像英文模板残留。
- 时间线节点约 10px、习惯点约 12px；若未来承担交互，必须扩展到触控目标或把点击区域外扩。
- `color-mix()` 建议提供纯色 fallback，兼容旧版 Android WebView。
- 静态预览日期为 2026-08-21，而部分 Flutter Golden 为 8 月 7 日；验收时应标明“示例数据”或统一夹具日期。
- 12–13px 辅助文本在系统字号放大时会先产生折行压力。

## Questions to Consider

- 如果今日页只回答“现在该做什么”，顶部“今日专注/完成计划”是否应移入证据侧轨或次级折叠？
- “1 冲突”出现时，用户下一步是查看详情、调整时间还是替换承诺？为什么这个决定没有在当前页出现？
- 移动端最常用的是开始专注、勾选任务还是快速捕获？唯一主动作是否应固定在拇指区？
- 日结在 21:30 前不可用时，能否同时展示原因和当前可执行的准备动作，而不是只让用户等待？
