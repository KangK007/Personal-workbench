# Android 界面 UI 优化方案（CODEX 可执行）

> 面向对象：CODEX / 自动化优化代理
> 项目：个人工作台 Personal Workbench（Flutter 3.38.9 / Dart 3.10.8）
> 编制日期：2026-09-18
> 配套文档：`AUDIT_PLAN_CODEX.md`（检测方案，定义如何验证本文件每一项）
> 设计规范：`MASTER.md`（项目级设计系统主规范，本文件所有改动必须服从它）

---

## 0. 执行前必读

### 0.1 硬约束（违反即回滚）

1. **不改产品语义**：不改路由枚举语义、不改控制器方法签名、不改数据模型、不改真实文案含义。
2. **不改业务逻辑**：布局与视觉重构不得改变业务流程、状态机或持久化行为。
3. **保留跨端一致性**：Windows 端现有体验不得退化。所有移动端改动必须用 `AppBreakpoints` 或 `defaultTargetPlatform` 收窄，不得全局生效。
4. **保留令牌体系**：颜色、圆角、间距、动效一律取自 `lib/core/theme/app_theme.dart`。新增令牌需先写入该文件，再在页面引用。
5. **不得引入新依赖**：尤其是 UI 组件库、状态管理库、图标库。当前图标统一使用 Material（`Icons.*`）。
6. **不得重引入玻璃拟态**：禁止 `BackdropFilter`、`GlassSurface`、装饰渐变。
7. **每完成一个批次，必须跑 `flutter analyze` 与 `flutter test`，并更新 Golden 基准。**

### 0.2 设计基线（来自 `MASTER.md`，Android 端必须遵守）

| 维度 | Android 端要求 |
| --- | --- |
| 间距标尺 | 仅用 `4 / 8 / 12 / 16 / 24 / 32` |
| 圆角 | 面板 12 / 按钮输入 Chip 8 / 对话框与 Sheet 顶角 16 / 短标签胶囊 |
| 触控目标 | ≥ 48dp |
| 移动列表行高 | ≈ 52dp |
| 移动页名 | 20px；正文字号不得小于 16px |
| 行高 | 正文 1.5，长文阅读列 1.7–1.8 |
| 断点 | `<768` 移动；`768–1199` 紧凑桌面；`≥1200` 完整工作面 |
| 必测尺寸 | `375×812`、`412×915`、`768`、`1024`、`1200`、`1440`、`1536×864`（本方案追加 `360×800` 与横屏 `812×375`） |
| 动效 | 控件反馈 120ms / 状态变化 180ms / 页面切换 220ms；必须响应 `MediaQuery.disableAnimationsOf` |
| 无障碍 | 键盘焦点 2px 环；状态不得仅靠颜色表达；支持系统文本缩放且放大后不遮挡 |

---

## 1. 批次 1 · P0 可用性与布局（必须本轮完成）

### A1 · 移动端补回可见返回控件

**严重度**：P0
**位置**：`lib/ui/workbench_shell.dart:323-326`

**现状**

```dart
// _mobileLayout() 的 AppBar
leading: Padding(
  padding: const EdgeInsets.only(left: 12),
  child: Center(child: SealLogo(size: 30)),
),
```

`leading` 被品牌 Logo 占用，而 `automaticallyImplyLeading` 在显式提供 `leading` 后不再生效。同时该页面维护了 `_mobileHistory` 返回栈（`:125`、`:633-637`、`:309-318`），说明设计意图是支持多级返回，但**屏幕上没有任何可点的返回入口**，用户只能依赖系统返回键或手势。

**目标实现**

`leading` 应根据是否存在返回层级在「返回按钮」与「品牌 Logo」之间切换：

```dart
leading: _mobileHistory.isEmpty
    ? Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Center(child: SealLogo(size: 30)),
      )
    : IconButton(
        onPressed: () {
          final previous = _mobileHistory.removeLast();
          setState(() {
            section = previous;
            _visitedSections.add(previous);
          });
        },
        tooltip: '返回',
        icon: const Icon(Icons.arrow_back),
      ),
```

同时把 `:311-318` 的 `PopScope.onPopInvokedWithResult` 回退逻辑抽成一个私有方法（例如 `_popMobileHistory()`），由 `PopScope` 与 `IconButton` 共用，避免两处逻辑漂移。

**额外要求**

- 当 `_mobileHistory` 非空时，`AppBar.title` 应显示当前页名（保持现状即可），但需确认标题在返回按钮出现后仍有足够宽度，不被 `maxLines: 2` 截断关键信息。
- `_MobileNavigationSheet` 的 `onSelected`/`onParentSelected` 回调（`:658-665`）在跳转前已 `Navigator.pop`，需确认返回按钮行为与之一致（都经由 `_select`，返回栈由 `_select` 统一维护）。

**验收标准**

1. 从「今日」→「更多」→「笔记」，AppBar 左侧出现返回按钮；点击后回到「今日」。
2. 在「今日」时 AppBar 左侧显示品牌 Logo，不显示返回按钮。
3. 屏幕上可见的返回控件与系统返回键行为完全一致。
4. 横屏场景下行为同样正确（见 A3）。

---

### A2 · 修复导航枚举可达性

**严重度**：P0
**位置**：`lib/ui/workbench_shell.dart:469-482`（项目）、`:484-490`（回顾）、`:619`（协议）

**现状**

三个独立缺陷：

```dart
// 缺陷 1：_projectPage 完全忽略 tab 形参
Widget _projectPage(WorkbenchSection value, ProjectDetailTab tab) =>
    ProjectsPage(
      key: ValueKey(value),
      controller: widget.controller,
      initialTab: ProjectDetailTab.overview,   // ← 硬编码，忽略 tab 形参
      showTabs: false,
      ...
    );

// 缺陷 2：_reviewPage 硬编码 diary
Widget _reviewPage(WorkbenchSection value, ReviewTab tab) => ReviewPage(
      key: ValueKey(value),
      controller: widget.controller,
      initialTab: ReviewTab.diary,             // ← 硬编码，忽略 tab 形参
      showHeader: _showPageHeader,
      showPeriodSwitcher: true,
    );

// 缺陷 3：protocols 被规范化到 goals，且导航树无入口
WorkbenchSection.protocols => WorkbenchSection.goals,
```

并且 `lib/ui/pages/projects_page.dart` 中 `initialTab`（`:24`、`:34`）与 `showTabs`（`:25`、`:35`）**只有声明、无任何使用点**（全文件仅 4 处出现，均为声明）。

**目标实现**

分两步，先修参数传递，再修页面消费。

**步骤 1 · 修正 shell 传参**

`_projectPage` 与 `_reviewPage` 使用传入的 `tab`：

```dart
Widget _projectPage(WorkbenchSection value, ProjectDetailTab tab) =>
    ProjectsPage(
      key: ValueKey(value),
      controller: widget.controller,
      initialTab: tab,                    // 改为使用形参
      showHeader: _showPageHeader,
      showTabs: false,
      ...
    );

Widget _reviewPage(WorkbenchSection value, ReviewTab tab) => ReviewPage(
      key: ValueKey(value),
      controller: widget.controller,
      initialTab: tab,                    // 改为使用形参
      showHeader: _showPageHeader,
      showPeriodSwitcher: true,
    );
```

**步骤 2 · 让 `ProjectsPage` 真正消费 `initialTab`**

这是关键。`ProjectsPage` 当前用 `SegmentedButton<ProjectViewMode>`（`:272`、`:332`）做视图切换，`ProjectDetailTab` 枚举（`overview / tasks / groups / milestones / notes`，`:17`）与实际渲染无对应关系。需明确定义两者的映射并在 `initState` 中初始化内部状态。

建议映射（保持既有产品语义）：

| `ProjectDetailTab` | 目标内部状态 |
| --- | --- |
| `overview` | `ProjectViewMode` 的概览视图 |
| `tasks` | `ProjectViewMode` 的任务视图 |
| `groups` | 概览/任务视图内的「任务群」分组区块 |
| `milestones` | 概览视图内的里程碑区块 |
| `notes` | 概览/任务视图内的笔记与回顾区块 |

若 `groups / milestones / notes` 在现有实现中没有独立视图，**三种处理方案任选其一，但必须显式选定并注释说明**：

- **方案 1（推荐，改动最小）**：`ProjectsPage` 接收 `initialTab` 后滚动定位到对应区块（使用 `ScrollController` + `GlobalKey.ensureVisible`），`showTabs: false` 时不分页而做锚点定位。
- **方案 2**：把 `ProjectDetailTab` 与 `ProjectViewMode` 合并为单一枚举，删除冗余枚举。此方案会改到页面公开 API，需同步更新测试。
- **方案 3（最保守）**：删除 `projectsTasks / projectsGroups / projectsMilestones / projectsNotes` 四个枚举值，并在 `_select` 中把它们的 legacy 别名统一指向 `projectsOverview`；同时从 `_navigationParentId`（`:787-790`）移除对应分支。此方案承认现状，消除幽灵枚举。

> **CODEX 注意**：方案 1 与方案 3 都不会改数据模型；方案 2 会改公开 API。若无法确认业务意图，**选方案 3**，因为它消除死代码且不引入新行为。

**步骤 3 · 处理 `ProtocolsPage` 不可达**

`:573-580` 仍保留 `WorkbenchSection.protocols => ProtocolsPage(...)` 分支，但 `_select`（`:619`）把该枚举规范化到 `goals`，导航树也无入口。二选一：

- **A**：删除 `ProtocolsPage` 引用分支与 `ProtocolTab` 相关状态（`:121`、`:632`），并删除 `ui/pages/protocols_page.dart`。
- **B**：将其恢复为可达功能（新增导航入口）。

若产品意图不明确，**选 A**（与 `MASTER.md` 第 10 节「保留全部 `WorkbenchSection` 路由」冲突时以本文件为准，但需在 PR 说明中标注）。无论选哪个，都必须同步处理 `test/ui_audit_screenshot_test.dart:667-675` 中为该页生成的基准。

**验收标准**

1. 从导航依次进入「项目 · 概览 / 任务 / 任务群 / 里程碑 / 笔记」，**产生可区分的画面**（截图两两不同）。
2. 从导航依次进入「回顾 · 日 / 周 / 月」，**产生可区分的画面**。
3. `WorkbenchSection` 中不存在「有枚举值但无入口且无独立渲染」的成员。
4. `flutter analyze` 零 issue（删除死参数后不应留下未使用警告）。

---

### A3 · 修复横屏手机返回栈失效

**严重度**：P0
**位置**：`lib/ui/workbench_shell.dart:186-188` 与 `:626`

**现状**

```dart
// build() 中的判定
final compact =
    size.width < AppBreakpoints.compact ||
    size.height < AppBreakpoints.compactHeight;   // 短边或矮边任一满足即走移动端 UI

// _select() 中的判定 —— 只用了宽度！
final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
```

两处判定条件不一致。在 `915×412`（横屏手机）下：`height(412) < 600` 成立 → 走移动端 UI；但 `width(915) < 768` 不成立 → `_mobileHistory` 永不入栈 → `PopScope.canPop` 恒为 `true` → **按系统返回键直接退出应用**。

**目标实现**

抽出单一判定来源，消除双份逻辑：

```dart
// 在 _WorkbenchShellState 内新增
bool _isCompactLayout(Size size) =>
    size.width < AppBreakpoints.compact ||
    size.height < AppBreakpoints.compactHeight;

bool _shouldTrackMobileHistory(Size size) => _isCompactLayout(size);
```

然后 `:626` 改为：

```dart
final compact = _isCompactLayout(MediaQuery.sizeOf(context));
```

若产品意图是「仅按宽度决定返回栈」（即横屏不记录历史），则必须改为让 `PopScope` 在横屏时也能正确退出到上一级或显式允许退出，并在代码注释中写明理由。**不允许两处判定继续各自为政。**

**验收标准**

1. 横屏 `915×412` 下，从「今日」→「更多」→「笔记」→ 按系统返回键，回到「今日」而非退出应用。
2. 竖屏 `412×915` 下行为不变。
3. 竖屏 ↔ 横屏旋转后返回栈行为仍然自洽（不出现"退不出去"或"跳两级"）。
4. 在 `768×864`（刚好达到 compact 宽度阈值，但高度足够）下行为正确。

---

### A4 · 修复移动端底部导航高亮

**严重度**：P0
**位置**：`lib/ui/workbench_shell.dart:273-277`

**现状**

```dart
final primary = _mobilePrimaryFor(section) ?? _lastMobilePrimary;
final index = _mobilePrimarySections.indexOf(primary);
// Project detail pages are reachable from 更多 but are not bottom
// destinations; keep NavigationBar on a valid neutral index.
final navigationIndex = index < 0 ? 0 : index;
```

注释说明了意图（保持合法索引），但后果是：当用户停在「项目」「笔记」「专注」「目标」「成长」等非底部目的地时，底部导航高亮**错误地落在「今日」**（索引 0）。用户会认为当前在今日页。

**目标实现**

`NavigationBar` 需要表达「当前不在任何底部目的地」的状态。两种做法：

- **推荐**：把 `navigationIndex` 改为可空，当无匹配时不选中任何项。Material 3 的 `NavigationBar.selectedIndex` 要求 `int`，因此需改用 `selectedIndex: -1` 的实现方式——**注意**：Flutter 的 `NavigationBar` 对越界索引会断言失败，需实测确认。若不可行，退到下一方案。
- **备选**：不改变索引，但为「非底部目的地」状态提供显式区分——例如把 `_lastMobilePrimary` 的语义改为「最后停留的底部目的地」，并在 AppBar 标题上明确显示当前页名（已实现），同时**在底部导航条上方增加一条当前页名指示**。

无论采用哪种，必须满足：**用户能一眼判断自己当前不在底部五项中的任何一项**，或至少高亮项不会误导。

**验收标准**

1. 从「更多」抽屉进入「项目」，底部导航不得高亮「今日」（若技术上必须高亮，则需在导航条或 AppBar 上给出非误导性的明确指示）。
2. 在底部五项之间切换时，高亮正确。
3. 从非底部目的地按底部导航返回时，能回到正确的目的地。

---

### A5 · 修复「更多」抽屉展开即跳页

**严重度**：P0
**位置**：`lib/ui/workbench_shell.dart:1277-1305`

**现状**

```dart
ExpansionTile(
  key: ValueKey('navigation-group:${node.id}'),
  initiallyExpanded: controller.navigationGroupExpanded(node.id!),
  leading: Icon(node.icon),
  title: Text(node.label),
  onExpansionChanged: (expanded) {
    controller.setNavigationGroupExpanded(node.id!, expanded);
    final containsSelected = node.children.any(
      (child) => child.section == selected,
    );
    if (!containsSelected) {
      onParentSelected(node.children.first.section!);   // ← 展开即跳页并关闭抽屉
    }
  },
  ...
)
```

用户点击「任务」分组的展开箭头，本意是浏览子项，结果直接跳转到「全部」并关闭了抽屉，**无法展开查看**。

**目标实现**

`onExpansionChanged` 只负责展开状态，不做导航：

```dart
onExpansionChanged: (expanded) {
  controller.setNavigationGroupExpanded(node.id!, expanded);
},
```

如果希望保留「点击分组标题快速进入默认子页」的便利，应把该行为绑定到 `ExpansionTile.title` 的独立点击区（例如 `title: InkWell(onTap: () => onSelected(node.children.first.section!), child: Text(node.label))`），与展开箭头分离。

同时需同步检查桌面端的对应实现 `_node`（`:1068-1137`）——桌面端已有 `containsSelected` 判断后再跳转的逻辑，行为更合理，可作为移动端的参考。

**验收标准**

1. 在「更多」抽屉点击「任务」分组，抽屉**保持打开**且分组展开，可见「全部 / 周视图 / 任务群」三个子项。
2. 点击子项后跳转并关闭抽屉。
3. `controller.navigationGroupExpanded` 状态在抽屉重开后保持。
4. 桌面端侧栏行为不退化。

---

### A6 · 修复任务群列表 trailing 溢出

**严重度**：P0
**位置**：`lib/ui/pages/plan_page.dart:417-468`

**现状**

```dart
trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    if (sequential) ...[
      IconButton(tooltip: '上移', ...),
      IconButton(tooltip: '下移', ...),
    ],
    if (task.status == WorkStatus.failed)
      TextButton(child: const Text('跳过并继续'), ...),
    IconButton(tooltip: '编辑任务', ...),
    IconButton(tooltip: '移出任务群', ...),
  ],
),
```

最坏情况 5 个控件：`48×4 (IconButton) + ≈96 (TextButton)` ≈ **288dp**，还不含 `ListTile` 的 `contentPadding`（16×2）、`leading`、`horizontalTitleGap`（12）。在 360dp 屏上标题可用宽度为负，**必然 `RenderFlex overflow`**。

**目标实现**

按「主操作保留、次操作收进菜单」的 Material 惯例重构。窄屏（`< AppBreakpoints.compact`）时收敛为「一个主操作 + 溢出菜单」：

```dart
final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;

trailing: compact
    ? Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 保留最高频的一个操作
          IconButton(
            tooltip: '编辑任务',
            onPressed: () => showRecordEditor(
              context, widget.controller,
              kind: RecordKind.task, record: task,
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<_MemberAction>(
            tooltip: '更多操作',
            itemBuilder: (context) => [
              if (sequential) ...[
                PopupMenuItem(
                  value: _MemberAction.moveUp,
                  enabled: widget.controller.taskGroupMemberCanMove(task, group, index - 1),
                  child: const Text('上移'),
                ),
                PopupMenuItem(
                  value: _MemberAction.moveDown,
                  enabled: widget.controller.taskGroupMemberCanMove(task, group, index + 1),
                  child: const Text('下移'),
                ),
              ],
              if (task.status == WorkStatus.failed)
                const PopupMenuItem(
                  value: _MemberAction.skipAndContinue,
                  child: Text('跳过并继续'),
                ),
              const PopupMenuItem(
                value: _MemberAction.remove,
                child: Text('移出任务群'),
              ),
            ],
            onSelected: (action) { /* switch 分发到既有回调 */ },
          ),
        ],
      )
    : /* 保持现有完整 Row，但用 SizedBox 限定总宽以避免极窄桌面窗口溢出 */,
```

需要新增私有枚举 `_MemberAction { moveUp, moveDown, skipAndContinue, remove }` 与 `onSelected` 分发，**复用既有的 `_moveMember` / `skipTaskAndContinueChain` / `_removeMember` 回调，不新增业务逻辑**。

同时为桌面分支加保护：给 trailing 包一层 `ConstrainedBox(constraints: BoxConstraints(maxWidth: 200))` 或让标题使用 `Flexible`，确保窗口被拖窄时不溢出。

**验收标准**

1. `360×800` 下渲染任务群列表（含失败状态任务），无 `RenderFlex overflow`。
2. 窄屏下溢出菜单可打开，四个操作均可正常执行且行为与桌面一致。
3. `1536×864` 桌面端布局与交互不退化。
4. `375×812` 且字体缩放 1.5x 时仍无溢出。

---

### A7 · 建立全局系统字体缩放策略

**严重度**：P0
**位置**：`lib/app.dart`（`MaterialApp` 构造处，`:56-104`）

**现状**

全项目 `lib/` 目录下 `textScaler` / `clampedTextScaling` / `textScaleFactor` **零匹配**。同时代码中存在大量固定高度容器（如 `lib/ui/widgets/record_editor_dialog.dart:1040`、`lib/ui/widgets/task_row.dart:74`、`lib/ui/widgets/common.dart:467` 等）。Android 用户在「设置 → 显示 → 字体大小」调到最大时，所有文本无上限放大，**必然导致溢出与截断**。

**目标实现**

在 `MaterialApp.builder` 中对文本缩放施加合理上限。**注意**：不能粗暴限制为 1.0，那会破坏无障碍（`MASTER.md` 第 9 节明确要求支持系统文本缩放）。

推荐做法——保底 + 封顶：

```dart
// lib/app.dart 的 MaterialApp.build 中
builder: (context, child) {
  final theme = Theme.of(context);
  final isLight = theme.brightness == Brightness.light;
  final mediaQuery = MediaQuery.of(context);
  return MediaQuery(
    // 保留下限以支持无障碍放大，同时封顶避免布局崩坏
    data: mediaQuery.copyWith(
      textScaler: mediaQuery.textScaler.clamp(
        minScaleFactor: 1.0,
        maxScaleFactor: 1.3,   // 与 Android 系统最大档位对齐后按实测调整
      ),
    ),
    child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(/* 保持现有配置 */),
      child: child!,
    ),
  );
},
```

**关键要求**

1. `maxScaleFactor` 的取值必须由 `AUDIT_PLAN_CODEX.md` 的 `C-03` 检测项实测确定：在 `360×800` 与 `412×915` 下，分别扫 1.0 / 1.15 / 1.3 / 1.5 / 2.0，取**不产生溢出且仍能满足无障碍诉求的最大值**。
2. 封顶之后，`AUDIT_PLAN_CODEX.md` 的 `C-03` 与 `G-04` 需同步调整判定口径：1.5x / 2.0x 场景验证的是「封顶后布局稳定」，而非「原生 2.0x 布局可用」。
3. 若实测发现封顶至 1.3 仍溢出，**必须逐页修复布局**（优先改用可滚动容器与 `Flexible`），不得继续下调上限。

**验收标准**

1. 系统字体最大档位下，`第 2.1 节` 全矩阵无溢出、无关键文字截断。
2. 系统字体默认档位下视觉与当前完全一致（无回归）。
3. 无障碍诉求被保留：正文可辨识放大（不可封顶为 1.0）。

---

### A8 · 修复通知准确性与点击响应

**严重度**：P0
**位置**：`lib/services/notification_service.dart:62-70`、`:123`、`:157`、`:224`

**现状**

```dart
// 1) 初始化未注册点击回调
const settings = InitializationSettings(
  android: AndroidInitializationSettings('@mipmap/ic_launcher'),
);
_initialized = await _plugin.initialize(settings) ?? false;

// 2) 三处定时调度均为非精确模式
androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
```

后果：

- `inexactAllowWhileIdle` 是**非精确**调度，Doze 模式下可延迟数分钟至数十分钟。**专注计时结束提醒**（`:224`）属于用户强期待准点的场景，延迟即功能失效。
- 未注册 `onDidReceiveNotificationResponse`，payload（`:124`、`:159`、`:225`）从未被消费，**点击通知无任何响应**。

同时 `AndroidInitializationSettings('@mipmap/ic_launcher')` 使用彩色启动图标作为通知小图标，Android 会把非单色图标渲染为白块（详见 `B4-01`）。

**目标实现**

**步骤 1 · 注册点击回调**

在 `initialize` 中传入回调，并新增一个可被上层消费的跳转意图：

```dart
final settings = InitializationSettings(
  android: AndroidInitializationSettings('@drawable/ic_notification'),
);

_initialized = await _plugin.initialize(
  settings,
  onDidReceiveNotificationResponse: (response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    _pendingNavigation = payload;      // 新增字段，形如 'task:<id>' / 'focus:<id>'
    onNavigationRequested?.call(payload);  // 新增回调，由 WorkbenchController 注入
  },
);
```

由 `WorkbenchController` 消费该 payload，跳转到对应记录或专注页面。**若上层暂时无法接入跳转，至少必须把 payload 记录下来并给出可见反馈（如 SnackBar 提示"已打开对应记录"或提示暂不支持），不允许静默丢弃。**

**步骤 2 · 专注计时改用精确调度**

专注计时是短时、前台可见、用户强期待准点的场景：

```dart
// scheduleFocusEnd —— 改为精确模式
androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
```

并在 `android/app/src/main/AndroidManifest.xml` 声明：

```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
```

**注意**：Android 12+ 使用 `exactAllowWhileIdle` 需具备该权限，`SCHEDULE_EXACT_ALARM` 在部分机型上需用户在系统设置中授权。因此需补充权限探测与降级：

- 启动或首次排定专注计时前，调用 `AndroidFlutterLocalNotificationsPlugin.requestExactAlarmsPermission()`。
- 未获授权时，**降级为 `inexactAllowWhileIdle` 并明确告知用户「通知可能延迟」**，不得静默失败。

**步骤 3 · 任务提醒与每日回顾**

`task_reminders`（`:123`）与 `review_overdue`（`:157`）是否也改精确，取决于产品预期。建议：

- `review_overdue` 每日提醒保留 `inexact`（延迟可接受，且能省电）。
- `task_reminders` 若有时间块语义（精确到分钟），应改为 `exact`；否则保留 `inexact` 并在 UI 上说明。

**验收标准**

1. 设定 5 分钟专注计时 → 锁屏等待 → 通知到达误差在 1 分钟内。
2. 点击通知 → 应用打开到对应记录/专注页。
3. 拒绝精确闹钟权限后，功能降级为可用状态且有明确提示，不崩溃。
4. 每日回顾提醒仍能正常触发。

---

### A9 · 修复离线删除记录复活

**严重度**：P0
**位置**：`lib/services/supabase_sync_service.dart`、`lib/data/app_database.dart`

**现状**

离线期间删除的记录，在恢复联网触发同步后被远端数据覆盖，重新出现在列表中（见 `AUDIT_PLAN_CODEX.md` 的 `B-13`）。

**目标实现**

引入删除标记（tombstone）或等效机制：

1. 软删除记录必须携带可同步的删除时间戳（例如复用现有软删除字段 + 新增 `deletedAt` 的上行同步语义）。
2. 同步合并时以「删除时间」与「远端更新时间」比较，删除优先。
3. 若当前 schema 无法承载，需在 `lib/data/app_database.dart` 增加字段并编写迁移（参照现有迁移模式 `lib/data/workspace_migration.dart`）。
4. **冲突策略必须显式定义并注释**，不得依赖"后写入者胜出"的隐式行为。

**验收标准**

1. 飞行模式下删除一条记录 → 恢复联网 → 手动触发同步 → 该记录**不复活**。
2. 两台设备场景（或模拟）：A 删除、B 修改同一记录，合并结果符合显式定义的冲突策略且用户可感知。
3. 现有同步测试全部通过。

---

## 2. 批次 2 · P1 Android 体验优化

### B1 · 窄屏溢出批量修复

以下四处均因固定尺寸或缺失滚动容器导致窄屏溢出，**成因同类，建议一并处理**。

| 编号 | 位置 | 现状 | 目标 |
| --- | --- | --- | --- |
| B1-01 | `lib/ui/widgets/quick_capture_sheet.dart:192-216` | 底部三按钮行（完善信息 / 取消 / 收下）在窄屏 + 放大时溢出 | 窄屏时改为「收下」占满主行、其余降为文字按钮或收进菜单；或改用 `Wrap` |
| B1-02 | `lib/ui/widgets/quick_capture_sheet.dart:91-98` | `Padding` + `Column(mainAxisSize: min)`，无 `SingleChildScrollView`，键盘弹起溢出 | 外层包 `SingleChildScrollView`，保留现有 `MediaQuery.viewInsetsOf(context).bottom` 内边距 |
| B1-03 | `lib/ui/widgets/task_row.dart:86-155` | 固定宽前导层叠加：缩进条(最大 176) + 40 复选框 + 8 + 3 强调条 + 8 + 标记 + 8 + 40 展开钮 | 窄屏下压缩缩进步长（`_hierarchyIndentStep`，`:48`）并把非关键标记移入次级行；确保正文区有最小宽度 |
| B1-04 | `lib/ui/widgets/common.dart:504-509` | `PageHeader` 的 `actions` 用 `...actions.map(...)` 直接展开，无 `Flexible` | 用 `Flexible` 或限定 actions 总宽；超过 2 个 action 时收进溢出菜单 |
| B1-05 | `lib/ui/workbench_shell.dart:1262-1263` | 移动端「更多」Sheet 高度 `clamp(320, 560)`，小屏 + 大字体内容被裁 | 改为按内容自适应 + 上限约束，或使用 `DraggableScrollableSheet` |

**统一验收**：`360×800` 与 `375×812`，字体 1.3x / 1.5x，均无 `RenderFlex overflow`。

---

### B2 · 编辑器与弹层的移动端模式统一

**问题**：移动端弹层策略不一致——`record_editor_dialog.dart:1019-1056` 已实现 `Dialog.fullscreen` 全屏分支（**这是正面范例**），而 `markdown_editor_dialog.dart:74` 仍是居中 `AlertDialog`，`today_page.dart` 的 5 处弹窗（`:1680`、`:1751`、`:1842`、`:1997`、`:2104`）内容不可滚动。

**目标实现**

1. **提取统一的移动端弹层决策**。建议在 `lib/ui/widgets/common.dart` 新增：

```dart
/// 移动端使用全屏对话框，桌面端使用居中对话框。
/// [builder] 接收是否为紧凑布局，便于表单自行调整列数。
Widget adaptiveDialogScaffold({
  required BuildContext context,
  required String title,
  required Widget content,
  required List<Widget> actions,
  VoidCallback? onClose,
}) { /* 复用 record_editor_dialog.dart:1019-1056 的既有结构与样式 */ }
```

2. `markdown_editor_dialog.dart:74` 改用上述统一入口，让笔记编辑在手机上获得全屏编辑体验。
3. `today_page.dart` 的 5 处 `AlertDialog`：
   - 内容包 `SingleChildScrollView`；
   - 若含输入框，改用统一弹层入口；
   - 保留既有 `StatefulBuilder` 的状态更新逻辑不变。

**验收标准**

1. 手机上打开 Markdown 笔记编辑器，为全屏 + AppBar + 底部操作栏形态。
2. 今日页全部弹窗在键盘弹起时可滚动到底部操作按钮。
3. 桌面端形态不变（仍为居中对话框）。

---

### B3 · 数据视图的移动端适配

| 编号 | 位置 | 问题 | 目标方向 |
| --- | --- | --- | --- |
| B3-01 | `lib/ui/pages/habits_page.dart:100-176` | 习惯矩阵已用横向滚动（`:148`、`:172`），但"今天"列需手动滚到才可见，且无滚动提示 | 首次渲染自动滚动至今日列；边缘增加渐隐提示（用 `ShaderMask`，不得用模糊）；`MASTER.md` 写的是「28 日矩阵」，代码用 `daysInMonth`（`:110`），需统一口径 |
| B3-02 | `lib/ui/pages/habits_page.dart:393-394` | `InkWell(onTap: null)` —— 矩阵格不可点击，无法补记历史 | 开放补记：`onTap` 弹出状态选择（完成 / 跳过 / 清除），复用过既有习惯记录写入逻辑，**不新增业务规则** |
| B3-03 | `lib/ui/pages/focus_page.dart` | `SegmentedButton` 四段（快捷 / 自定义 / 白名单 / 黑名单）窄屏拥挤 | 窄屏改为两行 `Wrap`，或改为横向可滚动的分段控件；保持选中态语义不变 |
| B3-04 | `lib/ui/pages/policies_page.dart` | 国策树 `InteractiveViewer` 固定 `960×560`，移动端可视区极小 | 约束改为按可用空间计算（`LayoutBuilder` + 比例），并提供"适应屏幕"按钮 |
| B3-05 | `lib/ui/pages/calendar_page.dart` | 工作周小时轴 58dp + 7 天列，393dp 下横向溢出 | 移动端改为「单日视图」或降低列宽并允许横向滚动；必须保留冲突状态的视觉表达 |

**统一验收**：`360×800` 与 `412×915` 下无溢出；关键信息不需横向滚动即可看到；触控目标 ≥ 48dp。

---

### B4 · Android 原生层修复

| 编号 | 位置 | 现状 | 目标 |
| --- | --- | --- | --- |
| **B4-01** | `lib/services/notification_service.dart:63` | 通知小图标用 `@mipmap/ic_launcher`（彩色），Android 渲染为白色方块 | 新增单色 drawable `android/app/src/main/res/drawable/ic_notification.xml`（纯 alpha 剪影，通常 24dp），改引用为 `@drawable/ic_notification` |
| **B4-02** | `android/app/src/main/res/` | 仅 5 张 PNG，**缺 `mipmap-anydpi-v26/ic_launcher.xml`**，Android 8+ 图标被系统遮罩裁切 | 新增自适应图标：`mipmap-anydpi-v26/ic_launcher.xml` + `ic_launcher_round.xml`，配套 `drawable/ic_launcher_foreground.xml` 与 `values/ic_launcher_background.xml`；Android 13+ 追加 `<monochrome>` 图层以支持主题图标 |
| **B4-03** | `android/app/src/main/res/values/styles.xml`、`values-night/styles.xml` | 启动底色与 Flutter 令牌不一致：`#F6F8F6` vs `lightCanvas #F2F7F3`；`#0E1311` vs `darkCanvas #0F1712`；`navigationBarColor #151C19` vs `darkSurface #16231B`、`#FFFFFF` vs `lightSurface #FBFDFB` | 全部对齐到 `app_theme.dart` 的当前令牌值。**今后任何令牌调整都需同步此两文件**——建议在两文件加注释指向 `app_theme.dart` |
| **B4-04** | `android/app/src/main/AndroidManifest.xml:9-17` | 缺 `android:enableOnBackInvokedCallback`，Android 13+ 预测性返回不生效 | 加入 `android:enableOnBackInvokedCallback="true"`，并**实测应用内返回栈行为与手势一致**（依赖 A1/A3 修好） |
| **B4-05** | `android/app/src/main/AndroidManifest.xml:5-8` | 未声明备份策略，含隐私/科研记录的 SQLite 默认进入云备份 | 显式声明策略。推荐 `android:allowBackup="false"`（应用自带加密备份功能，见 `lib/data/backup_service.dart`）；如确需系统备份，则配置 `android:dataExtractionRules`（API 31+）与 `android:fullBackupContent`（API 30-）排除数据库与附件 |
| **B4-06** | `android/app/build.gradle.kts:48-51`、`:71-77` | SDK 版本全用 `flutter.*` 默认值；release 未开混淆与资源压缩 | 显式锁定 `minSdk` / `targetSdk` / `compileSdk`；release 开启 `isMinifyEnabled = true` + `isShrinkResources = true` 并配置 `proguardFiles`。**开混淆后必须回归全部功能**（重点：`sqflite`、`flutter_local_notifications`、`supabase_flutter` 的反射/序列化） |
| **B4-07** | `android/app/src/main/AndroidManifest.xml:30-34`、`:56-65` | 分享接收 intent-filter 仅声明 `text/plain` | 评估补充 `text/*` 与含标题的链接分享场景（`EXTRA_SUBJECT`），避免部分来源的网页分享漏收 |

**统一验收**：在真实 Android 设备上逐项验证（见 `AUDIT_PLAN_CODEX.md` 的 D 类）。

---

### B5 · 触屏可达性修复

| 编号 | 位置 | 问题 | 目标 |
| --- | --- | --- | --- |
| B5-01 | `lib/ui/widgets/task_row.dart:69-71`、`lib/ui/pages/plan_page.dart:385`、`lib/state/workbench_controller.dart:3974` | 多选依赖长按，且显式入口（复选框）仅在 Windows 显示 | Android 上提供可发现的进入方式：在 AppBar 或工具条加「多选」按钮；长按作为加速入口保留；进入多选后顶部显示批量工具条与退出入口 |
| B5-02 | `lib/ui/pages/habits_page.dart:393-394` | 矩阵格不可点（见 B3-02） | 至少保证可点击区域 ≥ 48dp（当前格 16dp，需外包最小命中区） |

**验收标准**：Android 上不借助长按或右键，也能发现并进入多选模式；所有关键操作有可见入口。

---

### B6 · 主题与令牌纪律

| 编号 | 位置 | 问题 | 目标 |
| --- | --- | --- | --- |
| B6-01 | `lib/ui/pages/habits_page.dart:438`、`lib/ui/widgets/celebration.dart:65,158` | 硬编码 `Colors.white` | 改用 `Theme.of(context).colorScheme.onPrimary` 或 `tokens.raised`，需按语义选择并在深色模式验证 |
| B6-02 | `lib/ui/widgets/common.dart:1059-1077` | `bestContrastingText` 硬编码 `#1A1F1C` / `#F1F5F9` | 参数默认值改为从令牌推导，或新增 `tokens.contrastDark` / `tokens.contrastLight` |
| B6-03 | `lib/ui/workbench_shell.dart:1146` | `_showGroupMenu` 硬编码 `RelativeRect.fromLTRB(72, 180, 0, 0)` | 改用被点击控件的 `RenderBox` 计算锚点（参照 `showMenu` 的标准用法）或改用 `PopupMenuButton` |
| B6-04 | `lib/ui/workbench_shell.dart:374,397` | 同步状态条高 26 + 字号 11 | 提升至 `labelSmall`（12px）以上且满足可读性；或改为仅在异常时出现的提示条，避免常驻占用底部空间 |
| B6-05 | `lib/core/theme/app_theme.dart:440-444` | `bodyMedium` 15px，低于 `MASTER.md` 第 4 节「移动正文不小于 16px」 | 二选一：① 移动端正文字号提升到 16px；② 修订 `MASTER.md` 让规范与实现一致。**推荐 ①**，因 Android 建议正文 16sp |
| B6-06 | `lib/ui/pages/habits_page.dart:376-377`、`lib/ui/pages/growth_page.dart:559,657` 等 | 响应式判断混用 `MediaQuery.sizeOf(context).width` 与 `LayoutBuilder` | 统一策略：**可被容器约束的组件用 `LayoutBuilder`**（如 `growth_page.dart:420`、`restriction_page.dart:1583/1742` 的既有正确写法），页面级断点用 `AppBreakpoints` + `MediaQuery` |

**验收标准**：`AUDIT_PLAN_CODEX.md` 的 F-01 检测项（`ui/` 中零硬编码颜色）通过；深色模式下无不可读元素。

---

## 3. 批次 3 · P2 精修（排期处理）

### C1 · 组件收敛（消除重复实现）

同一 UI 语义在多处各写一遍，导致移动端适配需要重复修。建议按下列清单收敛为单一组件（放置于 `lib/ui/widgets/`）：

| 语义 | 重复位置 | 收敛建议 |
| --- | --- | --- |
| 统计数值块 | `today_page.dart`、`growth_page.dart`、`focus_page.dart`、`habits_page.dart` | 统一为 `StatTile(label, value, unit, accent)` |
| 区块标题 | `common.dart:517` 的 `SectionHeading` vs 各页自建标题 | 强制改用 `SectionHeading` |
| 空态 | `common.dart:778` 的 `EmptyState` vs 各页自建空态文案 | 强制改用 `EmptyState`；同时消除 `EmptyState` 内部的成对重复分支（`:837-903`） |
| 错误/警告条 | 各页自建 `Row(Icon(error) + Text)` | 统一为 `InlineNotice(kind, message)` |
| 底部操作栏 | `record_editor_dialog.dart:1036-1054` vs 各 Sheet 自建底栏 | 统一为 `DialogActionBar(primary, secondary, tertiary)` |
| 三按钮/四按钮行 | `quick_capture_sheet.dart:192-216`、`focus_page.dart`、各弹窗 | 统一为 `AdaptiveActionRow`，内置窄屏折叠逻辑 |

### C2 · 圆角 / 间距 / 字号标尺收口

- 检索 `BorderRadius.circular(` 与 `EdgeInsets.` 的字面量，全部替换为 `AppRadius.*` / `AppSpacing.*`。
- 检索 `fontSize:` 字面量，全部改为从 `textTheme` 取，或先写入 `AppTheme` 再引用。
- 注意 `AppSpacing.xl` 与 `AppSpacing.xxl` **当前值相同（均为 24）**，`lib/core/theme/app_theme.dart:98-99`，属于标尺缺陷，需修正为有区分度的取值（如 `xl=24`、`xxl=32`）并全量替换引用处。

### C3 · 细节与动效

- `lib/app.dart:125` 的 `_LaunchView` 硬编码 `420ms`，改为使用 `AppMotion` 令牌。
- `lib/ui/widgets/common.dart:343-347` 的 `SkeletonBlock` 在 `build` 中惰性创建并 `repeat()` 动画控制器，属于反模式，改为在 `initState` 中创建。
- `lib/ui/widgets/common.dart:674` 的 `LogRail` 使用 `IntrinsicHeight`，长列表下有性能开销（`AUDIT_PLAN_CODEX.md` 的 `C-11`），评估改为固定行高或 `CustomMultiChildLayout`。
- `lib/ui/widgets/common.dart:129,158` 的 `showWorkbenchSheet` 硬编码透明边框 `Color(0x00000000)`，属冗余，移除或改为令牌。

---

## 4. 执行顺序与批次交付

| 批次 | 内容 | 前置条件 | 批次出口条件 |
| --- | --- | --- | --- |
| **批次 0** | 按 `AUDIT_PLAN_CODEX.md` 阶段 2 补齐检测能力（视口矩阵、溢出断言、导航链路测试、Android Golden 矩阵） | 无 | 新增测试能稳定复现 `第 7.1 节` 的 P0 缺陷 |
| **批次 1** | A1–A9（P0 可用性、布局、平台能力、数据完整性） | 批次 0 完成 | `AUDIT_PLAN_CODEX.md` 全部 P0 项通过 |
| **批次 2** | B1–B6（P1 体验、原生层、令牌纪律） | 批次 1 完成 | 判定标准总表全部达标 |
| **批次 3** | C1–C3（P2 收敛与精修） | 批次 2 完成 | 组件重复清单清零；令牌纪律通过 |

**每个批次的固定流程**：

1. 先确认该批次的检测项处于「失败」状态（复现）。
2. 实施改动。
3. `flutter analyze` → `dart format --set-exit-if-changed` → `flutter test`。
4. 更新受影响的 Golden，**逐张确认变化属于预期，而非回归**。
5. 在真机 / 模拟器上跑 `第 2.1 节` 矩阵中该批次涉及的尺寸与场景。
6. 填写 `AUDIT_PLAN_CODEX.md` 的报告模板。

---

## 5. Android 端专项检查点（提交前逐项确认）

- [~] `360×800`、`375×812`、`412×915`、横屏 `812×375` 四档均无溢出（当前自动化证据覆盖 375×812、412×915、915×412；360×800 与 812×375 仍需补充设备矩阵）
- [x] 系统字体 1.0x / 1.3x / 1.5x / 2.0x 四档均无关键文字截断（应用层将系统输入限制在 1.0–1.3，2.0x 回归已通过）
- [x] 每个二级页面都存在**屏幕上可见**的返回控件
- [x] 底部导航高亮不误导；「更多」抽屉可展开浏览分组
- [x] 全部可点元素 ≥ 48×48 dp
- [x] 键盘弹起时表单、Sheet、Dialog 均可滚动到提交按钮
- [x] 深色模式下无白底白字 / 黑底黑字，系统栏图标亮度正确
- [~] 通知：图标为单色、定时准确、点击可跳转（图标、点击和权限路径已验证；锁屏/重启后的准确时序需实体设备复验）
- [x] 桌面图标为自适应图标，未被遮罩裁切
- [x] 冷启动无白屏/黑屏闪烁，启动底色与首帧一致
- [x] `flutter analyze` 零 issue
- [x] `flutter test` 全通过，总数不低于改动前（241/241）
- [x] Android Golden 基准已更新，且每张变化都有说明
- [~] Windows 端在改动后做了回归（自动化和隔离启动已通过；托盘、系统级快捷键等真实副作用需隔离会话）

> 标记说明：`[x]` 表示已有自动化或本机运行证据；`[~]` 表示代码路径已完成且部分验证通过，但仍保留真实设备、系统会话或额外视口的外部复验项。对应阻塞项同步记录在 `AUDIT_PLAN_CODEX.md` 和 `docs/qa/TEST_MATRIX.md`，不视为隐藏待办。

---

## 6. 附：本方案与既有文档的差异说明

| 既有文档 | 本方案的处理 |
| --- | --- |
| `UI_AUDIT_CODEX_OPTIMIZATION.md`（根目录，2026-08-19） | **其 P0 结论已失效**。该文档以「头部翠绿渐变污染」为核心问题，但当前 `lib/ui/widgets/common.dart:437-515` 的 `PageHeader` 已改为 `SolidPanel` + `tokens.panel` 实色，无渐变；文中引用的色值（主色 `#059669`、画布 `#F6F8F6`、divider `#E5E7EB`）与现行令牌（`#2F7D57`、`#F2F7F3`、`#D6E3D8`）不符。该文档可归档 |

| `docs/UI_AUDIT_2026-08-21.md` | 结论需逐条核对当前代码后再决定是否保留 |
| `docs/UI_OPTIMIZATION_GUIDE.md` | 同上 |
| `design-system/default/MASTER.md` | 按 `MASTER.md` 第 11 节，仅为检索基线来源记录，不作规范 |

---

## 7. 设计方向声明（需产品确认，非 CODEX 自动决策）

以下三项涉及设计取向，CODEX 不应自行决定，需人工确认后写入本文件再执行：

1. **移动端底部导航在非底部目的地时的表达方式**（A4）——是高亮回落至"今日"并加显式指示，还是允许无选中项。
2. **`ProjectDetailTab` 的 `groups / milestones / notes` 三个子页的产品意图**（A2）——是做锚点定位、合并枚举，还是删除这组导航入口。
3. **`ProtocolsPage` 的去留**（A2 步骤 3）——是删除，还是恢复为可达功能。

在未确认前，CODEX 应采用本文件标注的「推荐 / 最保守」方案，并在提交说明中显著标注该决策点。

---

## 8. 本轮执行记录（2026-09-18）

本节是对本方案检查点的实际执行记录；前文的检测建议和人工确认项仍保留为方法说明，不视为已获得真实设备或发布凭据。

- 已完成：移动端返回路径与横屏返回栈、项目/回顾子页参数、协议页入口、更多抽屉分组展开、任务群窄屏菜单、习惯历史补记、快速新增键盘适配、PageHeader 换行、国策树高度、应用层文本缩放上限、通知点击/精确闹钟降级/单色图标、自适应图标/启动主题/预测性返回/分享 MIME/备份策略、Supabase tombstone、减少动效下 Skeleton 卸载。
- 已验证：`flutter analyze` 通过；`flutter test --reporter compact` 为 241/241；Golden/UI 审计基准已按实际主题和布局变化更新；Android arm64 Debug 脚本构建成功，构建 APK 与 `dist/apk/` 副本一致。
- 已记录为外部阻塞：Android Release 签名、实体设备休眠/重启通知与后台进程恢复、隔离 Supabase、Windows 原生系统副作用和原生窗口完整交互。对应状态不得改写为 PASS。
- 迁移要求：提交时只纳入源码、Android 资源、测试基准和文档；`build/`、`dist/`、`.dart_tool/`、数据库、备份、`android/key.properties`、keystore 和其他敏感配置均不纳入版本库。
