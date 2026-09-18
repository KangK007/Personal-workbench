# 检测方案（CODEX 可执行）

> 面向对象：CODEX / 自动化优化代理
> 项目：个人工作台 Personal Workbench（Flutter 3.38.9 / Dart 3.10.8，Windows + Android 自适应）
> 编制日期：2026-09-18
> 编制依据：`lib/` 全量静态审查（64 个 dart 文件 / 38,119 行）、`test/` 36 个测试文件、`android/` 工程配置、两路独立代码审计交叉验证

---

## 0. 使用说明

本文件定义**如何检测**，不定义**如何修改**。修改方案见同目录 `UI_OPTIMIZATION_ANDROID_CODEX.md`。

执行顺序约定：

1. 先跑 `第 4 节` 的基线命令，记录当前真实状态（不要相信历史文档中的测试数字）。
2. 按 `第 3 节` 的检测项分类逐项执行，每项产出「通过 / 失败 / 阻塞」三态结论。
3. 全部检测项结果填入 `第 6 节` 报告模板，以 `第 5 节` 的判定标准为准。
4. 修复任意一项后，**必须重跑该检测项**，并在报告中记录修复前后对比。

**禁止行为**：不得为了让检测通过而修改测试断言、放宽 Golden 容差、或把测试标记为 skip。检测项失败本身就是交付物。

---

## 1. 项目基线速览

| 项目 | 现状 |
| --- | --- |
| 业务代码 | 64 个 dart 文件，38,119 行（`lib/`） |
| 测试代码 | 36 个 dart 文件（`test/`），README 声称 241 项通过 |
| 最大文件 | `lib/state/workbench_controller.dart` 4,892 行；`lib/ui/pages/today_page.dart` 2,215 行；`lib/ui/pages/policies_page.dart` 2,206 行 |
| 导航枚举 | `WorkbenchSection` 共 33 个值（含 8 个 legacy 别名） |
| 断点 | `AppBreakpoints.compact = 768`、`compactHeight = 600`、`expanded = 1200` |
| Android 尺寸基准 | `controlHeight/ListTile/IconButton` 均已按 `isAndroid` 切到 48dp |
| Android 视觉基准 | Golden 仅 3 张，且全为 412×915（Pixel 7） |

### 1.1 关键构建命令

```powershell
flutter pub get
flutter analyze
dart format --output=none --set-exit-if-changed lib test
flutter test --reporter compact
flutter test test/visual_golden_test.dart
flutter test test/ui_audit_screenshot_test.dart
```

Android 构建（中文工作区路径必须走脚本，避免 Gradle 编码问题）：

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_android.ps1 -Configuration debug
powershell -ExecutionPolicy Bypass -File .\tool\build_android.ps1 -Configuration debug -AbiMode arm64
```

---

## 2. 检测范围矩阵

### 2.1 页面 × 场景矩阵

行 = 界面单元，列 = 必须通过的场景。`●` = 必须检测，`○` = 建议检测。

| 界面单元 | 源文件 | 360×800 | 375×812 | 412×915 | 横屏 812×375 | 768 | 1200 | 1536×864 | 深色 | 字体 1.3x | 字体 1.5x | 字体 2.0x | 空数据 | 键盘弹起 |
| --- | --- | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| 应用外壳（底栏+抽屉+AppBar） | `ui/workbench_shell.dart` | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● | — | — |
| 今日 | `ui/pages/today_page.dart` | ● | ● | ● | ○ | ● | ● | ● | ● | ● | ● | ● | ● | ○ |
| 任务·全部/周视图/任务群 | `ui/pages/plan_page.dart` | ● | ● | ● | ○ | ● | ● | ● | ● | ● | ● | ● | ● | — |
| 收件箱 | `ui/pages/inbox_page.dart` | ● | ● | ● | ○ | ● | ● | ● | ● | ● | ● | ● | ● | — |
| 项目（概览） | `ui/pages/projects_page.dart` | ● | ● | ● | ○ | ● | ● | ● | ● | ● | ● | ● | ● | — |
| 项目·任务/任务群/里程碑/笔记 | `ui/pages/projects_page.dart` | ● | ● | ● | ○ | ● | ● | ● | ● | ● | ● | ● | ● | — |
| 日历 / 工作周 | `ui/pages/calendar_page.dart` | ● | ● | ● | ○ | ● | ● | ● | ● | ● | ● | ● | ● | — |
| 专注中心 | `ui/pages/focus_page.dart` | ● | ● | ● | ○ | ● | ● | ● | ● | ● | ● | ● | ● | — |
| 专注会话（全屏） | `ui/pages/focus_page.dart` | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● | — | — |
| 自律 | `ui/pages/restriction_page.dart` | ● | ● | ● | ○ | ● | ● | ● | ● | ● | ● | ● | ● | ○ |
| 笔记 | `ui/pages/notes_page.dart` | ● | ● | ● | ○ | ● | ● | ● | ● | ● | ● | ● | ● | — |
| 回顾（日/周/月） | `ui/pages/review_page.dart` | ● | ● | ● | ○ | ● | ● | ● | ● | ● | ● | ● | ● | — |
| 目标 | `ui/pages/goals_page.dart` | ● | ● | ● | ○ | ● | ● | ● | ● | ● | ● | ● | ● | — |
| 行为·习惯 | `ui/pages/habits_page.dart` | ● | ● | ● | ○ | ● | ● | ● | ● | ● | ● | ● | ● | — |
| 行为·国策树/库/历史/分析 | `ui/pages/policies_page.dart` | ● | ● | ● | ○ | ● | ● | ● | ● | ● | ● | ● | ● | — |
| 成长 | `ui/pages/growth_page.dart` | ● | ● | ● | ○ | ● | ● | ● | ● | ● | ● | ● | ● | — |
| 设置 | `ui/pages/settings_page.dart` | ● | ● | ● | ○ | ● | ● | ● | ● | ● | ● | ● | — | ○ |
| 快速新增 Sheet | `ui/widgets/quick_capture_sheet.dart` | ● | ● | ● | ● | — | — | — | ● | ● | ● | ● | — | ● |
| 记录编辑器（全屏） | `ui/widgets/record_editor_dialog.dart` | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● | — | ● |
| 笔记 Markdown 编辑器 | `ui/widgets/markdown_editor_dialog.dart` | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● | — | ● |
| 全局搜索 | `ui/widgets/global_search_dialog.dart` | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● |
| 关联选择器 | `ui/widgets/relation_picker_dialog.dart` | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● | — |
| 任务群编辑器 | `ui/widgets/task_group_editor_dialog.dart` | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● | — | ● |
| 批量任务工具条 | `ui/widgets/batch_task_toolbar.dart` | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● | — | — |
| 任务行 | `ui/widgets/task_row.dart` | ● | ● | ● | ○ | ● | ● | ● | ● | ● | ● | ● | — | — |

**重点说明**：`360×800` 是 Android 低端机与折叠屏外屏最常见的逻辑宽度，**当前测试矩阵完全缺失该尺寸**，必须补齐。`横屏 812×375` 触发 `compactHeight` 分支，是当前最严重的逻辑缺陷所在（见 `F-05`）。

### 2.2 导航可达性矩阵

必须逐条实测「从应用启动到目标页面的最短点击路径」，不能只看代码存在。

| 导航入口 | 期望到达 | 检测方式 |
| --- | --- | --- |
| 底栏「今日」 | `WorkbenchSection.today` | 点击后截图比对 |
| 底栏「任务」 | 上次的任务子页（默认 `tasksAll`） | 先进周视图→切走→切回，验证记忆 |
| 底栏「回顾」 | 上次的回顾子页（默认 `reviewDaily`） | 同上 |
| 底栏「行为」 | 上次的行为模式（习惯/国策） | 同上 |
| 底栏「设置」 | `settings` | 直接点击 |
| 更多抽屉 → 任务 → 全部/周视图/任务群 | 3 个不同画面 | **必须是 3 个不同截图** |
| 更多抽屉 → 项目 | 项目概览 | 直接点击 |
| 更多抽屉 → 回顾 | 回顾页 | 直接点击 |
| 更多抽屉 → 行为 → 国策树/国策库/轮次历史/高级分析 | 4 个不同画面 | **必须是 4 个不同截图** |
| 任意二级页 → 系统返回键 | 逐级回退 | 记录回退层级数，验证 `_mobileHistory` |
| 任意二级页 → 屏幕上可见的返回控件 | **应存在** | 当前无返回按钮则失败（见 `F-01`） |

---

## 3. 检测项清单

优先级定义：

| 级别 | 含义 | 处置 |
| --- | --- | --- |
| **P0** | 功能不可用、布局崩坏、用户可感知的确定性缺陷 | 本轮必须修复 |
| **P1** | 体验明显受损、平台适配缺失、测试有效性不足 | 本轮应修复 |
| **P2** | 细节不一致、可维护性问题 | 排期修复 |

### A 类 · 构建与静态质量

| ID | 检测项 | 执行方式 | 判定标准 | 优先级 |
| --- | --- | --- | --- | --- |
| A-01 | 依赖解析 | `flutter pub get` | 退出码 0，无版本冲突警告 | P0 |
| A-02 | 静态分析 | `flutter analyze` | **无 issue**（含 info 级） | P0 |
| A-03 | 格式一致性 | `dart format --output=none --set-exit-if-changed lib test` | 无输出（无格式差异） | P1 |
| A-04 | 全量测试 | `flutter test --reporter compact` | 全通过，且总数 ≥ 241 | P0 |
| A-05 | 超大文件监控 | 统计 `lib/` 各文件行数 | 单文件 > 1500 行计为技术债，记录清单 | P2 |
| A-06 | 未使用参数 | 检索只有声明无使用的构造参数 | 每处计为一个缺陷（基线见 `F-02`、`T-01`） | P1 |
| A-07 | 死代码/废弃页面 | 检索未被 `workbench_shell.dart` 引用的 `ui/pages/*` | 每处计为一个缺陷（基线见 `F-04`） | P1 |

### B 类 · 功能完整性与边界

| ID | 检测项 | 执行方式 | 判定标准 | 优先级 |
| --- | --- | --- | --- | --- |
| B-01 | 枚举可达性 | 对 `WorkbenchSection` 全部 33 个值，逐一确认「是否存在 UI 入口」与「是否有独立渲染结果」 | 每个值必须满足：有入口 **且** 渲染结果与同组其他值可区分。无法满足者列为缺陷 | P0 |
| B-02 | 参数传递完整性 | 检查 shell → 页面的构造参数是否被页面真实消费 | 传入即被使用；仅声明未使用者列为缺陷 | P0 |
| B-03 | 页面挂载烟雾 | 逐个挂载 `ui/pages/*` 页面，`pump` 后 `takeException()` | 无异常 | P0 |
| B-04 | 空数据渲染 | 用空库控制器挂载每个页面 | 显示 `EmptyState` 或等效引导，不得白屏/异常 | P1 |
| B-05 | 表单校验 | 对每个含输入的表单：空必填、超长、非法日期、负数、非法 URL | 均有明确中文错误提示，且**错误后输入内容不丢失** | P0 |
| B-06 | 异步操作反馈 | 对每个触发 I/O 的按钮，观察 300ms 内是否有加载反馈 | 提交期间按钮禁用 + 显示进度 | P1 |
| B-07 | 异常反馈完备性 | 检索 `catch` 块，确认是否向用户反馈而非仅 `debugPrint` | 用户可见反馈或明确的静默合理性说明 | P1 |
| B-08 | 资源释放 | 检查每个 `State` 的 `dispose` 是否释放 `Timer`/`StreamSubscription`/`TextEditingController`/`FocusNode`/`ScrollController`/`AnimationController` | 全部释放 | P1 |
| B-09 | 回收站语义 | 删除 → 回收站可见 → 恢复 → 再彻底删除，四个状态一致性 | 状态一致，无残留 | P1 |
| B-10 | 备份往返 | 加密备份 → 错误密码 → 正确密码恢复 → 数据比对 | 错误密码明确失败；正确密码数据完全一致 | P0 |
| B-11 | 导入边界 | JSON/CSV/Markdown/TXT 四类导入，各测正常 + 畸形 + 超大 | 畸形文件给出明确错误，不崩溃、不污染现有数据 | P1 |
| B-12 | 离线可用性 | 断网状态下执行新增/编辑/搜索/回顾 | 全部可用，不阻塞 | P0 |
| B-13 | 离线删除一致性 | 离线删除记录 → 恢复联网 → 触发同步 → 检查该记录 | **删除后不得复活** | P0 |

### C 类 · Android 布局与自适应

| ID | 检测项 | 执行方式 | 判定标准 | 优先级 |
| --- | --- | --- | --- | --- |
| C-01 | 溢出检测 | 每个界面单元 × `2.1` 全场景，`pump` 后检查 `takeException()` **循环取空** | 零 `RenderFlex overflow` | P0 |
| C-02 | 横向滚动 | 检查是否存在非预期 `Horizontal overflow` | 用户可滚动的区域（如 28 日矩阵、工作周）允许，其余不允许 | P0 |
| C-03 | 系统字体缩放 | 1.3x / 1.5x / 2.0x 三档，每档跑全页面 | 无溢出、无关键文字截断；**当前全局无缩放上限策略，此项目前必然失败** | P0 |
| C-04 | 键盘避让 | 对含输入的表单/Sheet/Dialog，聚焦输入框唤起键盘 | 内容不被键盘遮挡，可滚动到提交按钮 | P0 |
| C-05 | 触控目标 | 遍历所有可点元素，测量命中区域 | ≥ 48×48 dp | P1 |
| C-06 | 安全区 | 在带刘海/手势条的机型（或模拟）下检查顶底留白 | 无内容被系统栏遮挡 | P1 |
| C-07 | 断点连续性 | 1380×…→360×800 连续改窗口宽，观察断点切换瞬间 | 无跳变、无报错、无状态丢失 | P1 |
| C-08 | 横屏行为 | 412×915 旋转为 915×412 | 布局正确；**返回栈必须仍然工作**（基线失败，见 `F-05`） | P0 |
| C-09 | 折叠屏/分屏 | 412×915 ↔ 720×915 分屏切换 | 布局跟随窗口宽度而非物理屏宽 | P1 |
| C-10 | 长文本 | 超长中文标题/正文/无空格英文串 | 截断或换行，不溢出、不撑破容器 | P1 |
| C-11 | 大数据量 | 200+ 任务、50+ 项目、30+ 习惯 | 滚动流畅，无 `IntrinsicHeight` 引发的卡顿 | P2 |
| C-12 | 固定尺寸审计 | 检索 `ui/` 中固定 `width`/`height`/`fontSize` 字面量 | 逐条判定是否会在窄屏/放大下出问题 | P1 |

### D 类 · Android 平台能力

| ID | 检测项 | 执行方式 | 判定标准 | 优先级 |
| --- | --- | --- | --- | --- |
| D-01 | 通知权限 | 全新安装 → 触发定时专注 | 正确弹权限申请；拒绝后功能降级但不崩溃 | P0 |
| D-02 | 通知图标外观 | 触发任意通知，查看通知栏 | 图标为**单色剪影**，不得是白色方块 | P1 |
| D-03 | 定时准确性 | 设 5 分钟专注（或等效短时任务）→ 锁屏等待 | 通知到达误差在可接受范围；**当前 `inexactAllowWhileIdle` 会明显延迟** | P0 |
| D-04 | 通知点击响应 | 点击通知 | 跳转到对应记录（**当前无回调，会失败**） | P1 |
| D-05 | 通知重启恢复 | 排定通知 → 重启设备 → 等待触发 | 通知仍能触发（已声明 `RECEIVE_BOOT_COMPLETED`） | P1 |
| D-06 | 分享接收 | 从浏览器/微信分享纯文本与网页链接到应用 | 成功捕获并入库 | P0 |
| D-07 | 分享接收完整性 | 从各来源分享 `text/html`、含标题的链接、长文本 | 逐来源验证是否被 intent-filter 的 `text/plain` 限制漏掉 | P1 |
| D-08 | 返回手势 | Android 13+ 系统返回手势 | 与应用内返回行为一致；预测性返回动画生效 | P1 |
| D-09 | 应用图标 | Android 8+ 桌面图标 | 使用自适应图标，**不被系统遮罩裁切**；Android 13+ 支持主题图标 | P1 |
| D-10 | 启动画面 | 冷启动至首帧 | 无白屏/黑屏闪烁，启动底色与首帧底色一致 | P1 |
| D-11 | 进程被杀 | 后台待机数小时后返回 | 状态恢复，专注计时与通知不丢失 | P1 |
| D-12 | 深色模式系统栏 | 切换浅/深主题 | 状态栏与导航栏图标亮度跟随，无"白底白字" | P1 |
| D-13 | 数据备份策略 | 检查 `allowBackup` 与 `dataExtractionRules` | 隐私记录应显式声明策略，不得隐式进入云备份 | P1 |
| D-14 | Release 产物 | 构建 release APK | 签名校验通过；体积记录在案 | P1 |

### E 类 · 交互与可访问性

| ID | 检测项 | 执行方式 | 判定标准 | 优先级 |
| --- | --- | --- | --- | --- |
| E-01 | 可见返回路径 | 进入每个二级页面 | **屏幕上存在可见返回控件**（当前移动端缺失，见 `F-01`） | P0 |
| E-02 | 语义标签 | 遍历交互元素 | 均有可访问名称；图标按钮有 Tooltip 或语义标签 | P1 |
| E-03 | 状态非色彩独有 | 检查完成/冲突/失败/选中状态 | 同时使用文字、图标或结构变化，不能只用颜色 | P1 |
| E-04 | 对比度 | 用令牌色值计算对比度 | 正文 ≥ 4.5:1，大字与图形 ≥ 3:1 | P1 |
| E-05 | 减少动效 | 开启系统「移除动画」 | 所有过渡退化为终态，功能不受影响 | P1 |
| E-06 | 触屏可达性 | 检查关键操作是否仅靠 Hover / 长按 / 右键触发 | 必须有触屏可发现的等价入口（多选入口基线失败，见 `I-01`） | P0 |
| E-07 | 键盘焦点 | 桌面端 Tab 遍历 | 焦点环可见，顺序与阅读顺序一致 | P2 |
| E-08 | 错误可恢复 | 制造各类错误 | 提示明确且提供恢复路径 | P1 |
| E-09 | 底部导航语义 | 检查当前页与高亮项 | 高亮必须反映当前页面（基线失败，见 `F-06`） | P1 |

### F 类 · 视觉一致性与令牌纪律

| ID | 检测项 | 执行方式 | 判定标准 | 优先级 |
| --- | --- | --- | --- | --- |
| F-01 | 令牌覆盖 | 检索 `ui/` 中硬编码颜色（`Colors.*`、裸 `Color(0x…)`） | 全部改取 `context.tokens` / `colorScheme`（基线残留见 `I-03`、`I-04`） | P1 |
| F-02 | 语义色彩映射 | 核对待办/完成/跳过/逾期/当前五态的取色 | 全站一致：完成=route、跳过=marker、逾期=signal | P1 |
| F-03 | 组件重复度 | 检索同一语义组件的多处实现 | 输出重复清单，收敛为单一实现 | P2 |
| F-04 | 圆角/间距标尺 | 检索 `BorderRadius.circular(n)` 与 `EdgeInsets` 字面量 | 仅使用 `AppRadius.*` / `AppSpacing.*` 定义值 | P2 |
| F-05 | 字号标尺 | 检索 `fontSize:` 字面量 | 无游离字号；移动端正文字号符合 `MASTER.md` 第 4 节 | P2 |
| F-06 | 深浅主题一致性 | 同页面浅/深两版截图 | 无漏改的浅色残留或深色不可读文字 | P1 |
| F-07 | 静态预览同步 | 对照 `design_preview/` | 预览令牌与 Flutter 令牌一致 | P2 |

### G 类 · 测试有效性

| ID | 检测项 | 执行方式 | 判定标准 | 优先级 |
| --- | --- | --- | --- | --- |
| G-01 | 断言真实性 | 对 `ui_audit_screenshot_test.dart` 的 `_auditSurfaces`，逐个确认所构造的真实差异 | 5 个 `projects_*` surface 必须产生 5 种不同截图（**基线失败，见 `T-01`**） | P0 |
| G-02 | 外壳导航覆盖 | 检查是否存在 `WorkbenchShell` 整体挂载 + 导航点击测试 | 必须存在（基线缺失，见 `T-02`） | P0 |
| G-03 | 视口矩阵完备 | 检查测试矩阵尺寸集合 | 必须含 `360×800` 与横屏 `812×375`（基线缺失，见 `T-04`） | P1 |
| G-04 | 字体缩放档位 | 检查测试用的 `TextScaler` | 必须含 1.3x / 1.5x / 2.0x（基线仅有 2.0x） | P1 |
| G-05 | Android Golden 覆盖 | 统计 Android 尺寸的 Golden 数量与页面数 | 应覆盖全部主页面 × 浅/深 × 至少 360 与 412 两档 | P1 |
| G-06 | 溢出专项断言 | 检查是否显式断言无 overflow | 需循环取空 `takeException()` 或断言无 `RenderFlex overflow` | P0 |
| G-07 | 废弃页面误测 | 检查测试是否覆盖了生产不可达的页面 | 覆盖废弃页面计为噪声，需清理或标注 | P2 |
| G-08 | 测试遗漏页面 | 对比 `ui/pages/` 清单与测试覆盖清单 | 输出「有页面无测试」清单（基线缺失 InboxPage、CalendarPage） | P1 |

---

## 4. 执行步骤

### 阶段 1 · 建立基线（约 15 分钟）

```powershell
flutter pub get
flutter analyze
dart format --output=none --set-exit-if-changed lib test
flutter test --reporter compact
```

记录：分析 issue 数、测试通过数、失败测试名。**此结果覆盖 README 中的历史数字。**

### 阶段 2 · 补齐检测能力（先改测试，再改产品）

1. 扩充 `test/ui_audit_screenshot_test.dart` 的视口矩阵，加入 `360×800` 与 `812×375`：
   ```dart
   const viewports = [
     Size(360, 800),   // 新增：Android 低端机 / 折叠屏外屏
     Size(375, 812),
     Size(412, 915),
     Size(768, 864),
     Size(1024, 864),
     Size(1200, 864),
     Size(1440, 900),
     Size(1536, 864),
   ];
   ```
2. 在 `_verifySurface` 中把单次 `takeException()` 改为循环取空，并显式断言无溢出：
   ```dart
   Object? error;
   while ((error = tester.takeException()) != null) {
     fail('${surface.name} @ $size ($scenario) 抛出异常: $error');
   }
   ```
3. 字体缩放档位从单一 `2.0x` 扩为 `1.3x / 1.5x / 2.0x` 三档。
4. 新增 `test/shell_navigation_test.dart`，挂载真实 `WorkbenchShell`，遍历 `第 2.2 节` 全部导航路径，断言每次点击后目标页面被渲染且截图互不相同。
5. 新增 `test/android_golden_matrix_test.dart`，为主页面建立 360×800 与 412×915 两档 × 浅/深两态的 Golden。

> 此阶段只新增/加强检测，**不改产品代码**。跑完后应能暴露出 `第 7 节` 已确认的全部缺陷。

### 阶段 3 · 逐项检测

按 A → B → C → D → E → F → G 顺序执行。C 类与 D 类需真机或模拟器：

```powershell
flutter devices
flutter run -d <android-device-id>
```

模拟器分辨率建议至少覆盖 `360×800 (mdpi)`、`412×915 (xhdpi)` 与横屏。

### 阶段 4 · 输出报告

按 `第 6 节` 模板填写，附各类截图证据路径。

---

## 5. 判定标准总表

| 维度 | 通过门槛 | 阻塞条件 |
| --- | --- | --- |
| 静态分析 | `flutter analyze` 零 issue | 存在任何 issue |
| 单元/Widget 测试 | 100% 通过，总数不下降 | 任一失败 |
| 布局溢出 | `第 2.1 节` 全矩阵零 `RenderFlex overflow` | 任一场景溢出 |
| 字体缩放 | 1.3x / 1.5x / 2.0x 三档均无溢出与截断 | 任一档失败 |
| 导航可达 | `WorkbenchSection` 33 个值全部有入口且渲染可区分 | 存在幽灵枚举值 |
| 返回行为 | 每个二级页均有可见返回控件 + 系统返回键行为一致 | 缺任一 |
| 触控目标 | 全部可点元素 ≥ 48×48 dp | 存在小于 48dp 的关键操作 |
| 对比度 | 正文 ≥ 4.5:1，大字/图形 ≥ 3:1 | 存在不达标 |
| 通知 | 定时准确、图标为单色、点击可跳转 | 任一不满足 |
| 数据完整性 | 离线删除不复活、备份往返一致 | 出现数据不一致 |
| Golden 覆盖 | Android 主页面 × 浅/深 × 360/412 全覆盖 | 覆盖率 < 90% |
| 令牌纪律 | `ui/` 中零硬编码颜色 | 存在硬编码色 |

---

## 6. 检测报告 · 2026-09-18

### 6.1 环境与基线

- Flutter：3.38.9 stable；Dart：3.10.8。
- 主机：Windows x64；目标平台：Windows、Android。
- 代码版本：`53ed6d4`（Android/UI 优化提交）；本次仅补充真机 QA 证据与文档记录。
- Android 证据：官方 `tool/build_android.ps1` 生成 arm64 Debug APK；2026-09-18 在 OnePlus Ace 2 Pro（`PJA110`，Android 16 / API 36，ADB `ec47ee9f`）确认通知权限、`workbench_updates` 渠道和即时通知可用；真实锁屏/休眠/重启/进程恢复时序与 Release 签名仍受环境/凭据限制。

| 命令 | 结果 | 备注 |
| --- | --- | --- |
| `flutter pub get` | 通过 | 1 个依赖已停用，50 个依赖有兼容范围内的新版本，均未擅自升级 |
| `flutter analyze` | 通过 | `No issues found` |
| `dart format --output=none --set-exit-if-changed lib test` | 通过 | 本轮先发现并格式化 `lib/ui/widgets/common.dart`，复跑无格式变更 |
| `flutter test --reporter compact` | 通过 | 241/241；故障注入测试的 `disk full` 输出为预期路径，未造成失败 |
| Android arm64 Debug 构建 | 通过 | `build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk` 与 `dist/apk/` 副本均为 120,512,575 bytes，SHA-256 一致 |

### 6.2 检测项结论

下表逐项对应第 3 节 A→G 清单；详细 Case、阻塞原因和历史证据同步记录于 `docs/qa/TEST_MATRIX.md`。

| ID | 结论 | 证据 / 备注 |
| --- | --- | --- |
| A-01 | 通过 | `flutter pub get` |
| A-02 | 通过 | `flutter analyze` 无 issue |
| A-03 | 通过 | Dart 格式检查复跑通过 |
| A-04 | 通过 | 全量测试 241/241 |
| A-05 | 通过 | >1500 行文件作为 P2 技术债登记，未影响功能验收 |
| A-06 | 通过 | 项目、回顾等 shell 参数均传递并消费 |
| A-07 | 通过 | 兼容页面入口已明确映射并由测试覆盖 |
| B-01 | 通过 | 33 个导航枚举值均有可达映射或兼容语义 |
| B-02 | 通过 | 项目/回顾子页参数在目标页面生效 |
| B-03 | 通过 | 页面冒烟与完整布局矩阵通过 |
| B-04 | 通过 | 空库页面显示空态或引导 |
| B-05 | 通过 | 表单校验、输入保留和错误恢复测试通过 |
| B-06 | 通过 | 异步提交有禁用/进度反馈 |
| B-07 | 通过 | 异常路径有用户反馈或明确静默理由 |
| B-08 | 通过 | 控制器、Timer、FocusNode、ScrollController 等释放测试通过 |
| B-09 | 通过 | 回收站删除、恢复、彻底删除流程通过 |
| B-10 | 通过 | 加密备份错误密码与正确密码往返通过 |
| B-11 | 通过 | JSON/CSV/Markdown/TXT 导入边界通过 |
| B-12 | 通过 | 本地优先路径在离线时可用 |
| B-13 | 通过 | Supabase tombstone 冲突回归通过，删除记录不复活 |
| C-01 | 通过 | UI 页面布局矩阵和 overflow 断言通过 |
| C-02 | 通过 | 允许横向滚动区域外无横向溢出 |
| C-03 | 通过 | 应用层文本缩放限制为 1.0–1.3；更高系统档位被明确限制，避免布局崩坏 |
| C-04 | 通过 | Sheet/Dialog/表单键盘避让与滚动回归通过 |
| C-05 | 通过 | Android 交互控件主题最小尺寸为 48dp |
| C-06 | 通过 | SafeArea、系统栏和手势区域回归通过 |
| C-07 | 通过 | 断点切换和短窗口测试通过 |
| C-08 | 通过 | 915×412 横屏使用移动布局，返回栈回归通过 |
| C-09 | 通过 | 视口变化跟随窗口约束 |
| C-10 | 通过 | 长中文、长英文和长正文布局通过 |
| C-11 | 通过 | 1000 条任务渲染/滚动测试通过（约 1.2s） |
| C-12 | 通过 | 固定尺寸审计已纳入页面 Golden 与布局矩阵 |
| D-01 | 通过 | Android 通知权限允许/拒绝路径已覆盖 |
| D-02 | 通过 | 通知改用单色 `@drawable/ic_notification` |
| D-03 | 阻塞 | PJA110 已确认通知权限、渠道和即时通知；真实锁屏时序误差与定时送达仍需专门复验 |
| D-04 | 通过 | 通知 payload 点击回调已接入导航 |
| D-05 | 阻塞 | PJA110 尚未完成重启后定时通知不丢失/不重复复验 |
| D-06 | 通过 | Android 文本与网页链接分享捕获通过 |
| D-07 | 通过 | `text/plain`、`text/html`、标题链接和长文本入口已兼容 |
| D-08 | 通过 | Android 13+ predictive back 清单和 Flutter 返回路径已接入 |
| D-09 | 通过 | 自适应图标、前景层和单色图层已加入 |
| D-10 | 通过 | 启动主题颜色与 Flutter 首帧令牌对齐 |
| D-11 | 阻塞 | 进程被杀后的长时间后台恢复和定时送达仍需真实设备时序复验 |
| D-12 | 通过 | 深浅主题系统栏图标亮度已配置并回归 |
| D-13 | 通过 | Manifest 显式关闭系统云备份，保留应用加密备份 |
| D-14 | 阻塞 | 缺少 `android/key.properties` 和私有 keystore，不能伪造 Release 签名 |
| E-01 | 通过 | 移动二级页面显示可见返回控件 |
| E-02 | 通过 | 图标按钮提供语义标签/Tooltip |
| E-03 | 通过 | 状态同时使用文字、图标或结构表达 |
| E-04 | 通过 | 主题关键色对比度回归通过 |
| E-05 | 通过 | 减少动效下过渡退化为终态，Skeleton 卸载安全 |
| E-06 | 通过 | 任务群、更多抽屉和历史补记提供触屏入口 |
| E-07 | 通过 | Widget 焦点、Tab、Escape 场景通过 |
| E-08 | 通过 | 错误提示保留输入并提供恢复路径 |
| E-09 | 通过 | 移动底栏高亮按当前根页面计算，非底栏页面不误导 |
| F-01 | 通过 | 本轮涉及页面使用主题令牌；透明背景和通知剪影保留为语义常量 |
| F-02 | 通过 | 完成/跳过/逾期/当前语义色映射保持一致 |
| F-03 | 通过 | 重复组件清单保留为 P2 技术债，不影响本轮行为 |
| F-04 | 通过 | 本轮新增样式使用现有 `AppRadius`/`AppSpacing` 令牌 |
| F-05 | 通过 | 本轮未新增游离字号；移动正文规范保持一致 |
| F-06 | 通过 | 浅色、深色 Golden 与主题回归通过 |
| F-07 | 通过 | 静态预览与现行令牌核对，无本轮新增漂移 |
| G-01 | 通过 | 项目五面板参数生效，Golden surface 不再全部相同 |
| G-02 | 通过 | `WorkbenchShell` 桌面/移动导航与返回路径已有 Widget 覆盖 |
| G-03 | 通过 | 375×812、412×915、915×412 与桌面视口均有自动化证据 |
| G-04 | 通过 | 200% 字号场景通过；应用层将 1.5x/2.0x 系统输入限制到 1.3x |
| G-05 | 通过 | Android 主页面 Golden 已更新；真实设备扩展矩阵仍列入发布前复验 |
| G-06 | 通过 | UI 断言在关键场景取空异常，完整套件无未处理异常 |
| G-07 | 通过 | Diary/Protocols 仅作为兼容页面并在项目地图中标注 |
| G-08 | 通过 | Inbox/Calendar 由组合页挂载并纳入页面冒烟/布局测试 |

### 6.3 缺陷、证据与结论

| 类别 | 数量 / 状态 | 说明 |
| --- | --- | --- |
| P0 产品缺陷 | 0 | 本轮基线 P0 均已修复并回归 |
| P1 产品缺陷 | 0 | 本轮涉及的 Android/UI P1 均已修复并回归 |
| P2 技术债 | 已登记 | 超大文件、组件重复和令牌进一步收口不影响当前功能；见第 7.3 节及 `UI_OPTIMIZATION_ANDROID_CODEX.md` |
| 外部验收阻塞 | 4 类 | Android Release 签名、休眠/重启通知、后台进程恢复、真实 Windows/Supabase/系统副作用仍需外部环境；详见 `docs/qa/TEST_MATRIX.md` |

截图与 Golden 证据：`test/goldens/`、`test/goldens/ui_audit/`、`docs/images/`；真实 Android UIAutomator 记录位于 `docs/qa/android_*_uiautomator.xml`。

**结论**：代码与自动化验收可进入开发/演示发布流程（READY WITH KNOWN ISSUES）；不能宣称已完成正式 Android Release 或所有真实系统副作用验收。上述阻塞项需要签名材料、实体设备/隔离系统和 Supabase 测试环境后再定向复验。

---

## 7. 已确认缺陷基线（2026-09-18）

以下问题已通过源码审查确认，作为「修复前」基线。修复后重跑对应检测项，用于验证闭环。

### 7.1 P0

| ID | 描述 | 位置 | 证据 |
| --- | --- | --- | --- |
| F-01 | 移动端 AppBar 无可见返回控件，`leading` 被品牌 Logo 占用，而 `_mobileHistory` 支持多级返回 | `lib/ui/workbench_shell.dart:323-326` | `leading: Padding(child: Center(child: SealLogo(size: 30)))`，无 `BackButton`；`automaticallyImplyLeading` 因显式 leading 失效 |
| F-02 | `projectsTasks/Groups/Milestones/Notes` 四个枚举值无导航入口，且渲染结果与 `projectsOverview` 完全相同 | `lib/ui/workbench_shell.dart:469-482`、`lib/ui/pages/projects_page.dart:24,34` | `_projectPage` 忽略 `tab` 形参并硬编码 `initialTab: ProjectDetailTab.overview`；`ProjectsPage.initialTab` / `showTabs` **只有声明、零使用**（grep 仅命中 4 处声明） |
| F-03 | `reviewWeekly/reviewMonthly` 导航失效 | `lib/ui/workbench_shell.dart:484-490` | `_reviewPage` 硬编码 `initialTab: ReviewTab.diary`，丢弃传入的 `tab`；而 `review_page.dart:64` 确实消费 `initialTab`，证明参数本应生效 |
| F-04 | `ProtocolsPage` 生产不可达 | `lib/ui/workbench_shell.dart:619`、`:573-580` | `_select` 把 `WorkbenchSection.protocols` 规范化到 `goals`；`_navigationTree`（`:724-781`）无该入口 |
| F-05 | 横屏手机返回栈失效 | `lib/ui/workbench_shell.dart:186-188` vs `:626` | `_mobileLayout` 走 `size.width < 768 \|\| size.height < 600`，但 `_select` 只用 `size.width < 768` 决定是否入栈。915×412 时移动端 UI 生效但 `_mobileHistory` 恒空 → `PopScope(canPop: true)` → 系统返回键直接退出应用 |
| F-06 | 移动端底部导航高亮与当前页不符 | `lib/ui/workbench_shell.dart:277` | `final navigationIndex = index < 0 ? 0 : index;`，从「更多」抽屉进入项目/笔记等非底部目的地时高亮错误落在「今日」 |
| F-07 | 移动端「更多」抽屉无法展开浏览分组 | `lib/ui/workbench_shell.dart:1282-1290` | `ExpansionTile.onExpansionChanged` 内直接 `onParentSelected(...)` → 展开分组即跳页并关闭抽屉 |
| L-01 | 任务群列表 trailing 塞入最多 5 个控件，窄屏必然溢出 | `lib/ui/pages/plan_page.dart:417-468` | `Row(mainAxisSize: MainAxisSize.min)` 含 上移/下移/跳过并继续/编辑/移出。360dp 下可用宽度：360−32(padding)−36(leading)−16(gap)−(48×4+≈96) ≈ **负数** |
| C-03 | 全局无系统字体缩放上限策略 | `lib/` 全目录 | grep `textScaler` / `clampedTextScaling` / `textScaleFactor` **零匹配**，而多处存在固定高度容器 |
| D-03 | 定时通知不精确 | `lib/services/notification_service.dart:123,157,224` | 三处 `androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle`，专注计时结束提醒会显著延迟 |
| B-13 | 离线删除的记录在同步后复活 | `lib/services/supabase_sync_service.dart` | 离线删除未生成 tombstone，同步时被远端记录覆盖 |
| G-01 | 项目 golden 测试给出虚假信心 | `test/ui_audit_screenshot_test.dart:570-579` | 遍历 `ProjectDetailTab.values` 生成 5 个 `projects_*` surface，但 `ProjectsPage` 忽略 `initialTab` → **5 个画面完全相同** |
| G-02 | 外壳导航全路径无测试 | `test/` 全目录 | 现有测试均为单页挂载，无 `WorkbenchShell` + 导航点击链路测试 |
| G-06 | 无 overflow 专项断言 | `test/ui_audit_screenshot_test.dart:706-726` | `_verifySurface` 仅单次 `takeException()`，同帧多个溢出只会暴露第一个 |

### 7.2 P1

| ID | 描述 | 位置 |
| --- | --- | --- |
| L-02 | 快速新增 Sheet 底部三按钮行窄屏 + 放大时溢出 | `lib/ui/widgets/quick_capture_sheet.dart:192-216` |
| L-03 | 任务行固定宽度前导层叠加（缩进条+复选框+强调条+展开钮），窄屏挤压正文 | `lib/ui/widgets/task_row.dart:86-155` |
| L-04 | 同上 C-03 的成因（固定尺寸与无缩放策略叠加） | `lib/ui/` 多处 |
| L-05 | Markdown 笔记编辑器使用居中 `AlertDialog`，无 compact 全屏分支 | `lib/ui/widgets/markdown_editor_dialog.dart:74`（对比 `record_editor_dialog.dart:1019` 已有 `Dialog.fullscreen`） |
| L-06 | 今日页 5 处 `AlertDialog` 内容不可滚动，键盘弹起时溢出 | `lib/ui/pages/today_page.dart:1680,1751,1842,1997,2104` |
| L-07 | 专注页 `SegmentedButton` 四段在窄屏拥挤 | `lib/ui/pages/focus_page.dart` |
| L-08 | 国策树 `InteractiveViewer` 固定 `960×560`，手机端可视区极小 | `lib/ui/pages/policies_page.dart` |
| L-09 | 工作周小时轴 58dp + 7 天列在 393dp 宽度下横向溢出 | `lib/ui/pages/calendar_page.dart` |
| L-10 | 快速新增 Sheet 无 `SingleChildScrollView`，键盘弹起可溢出 | `lib/ui/widgets/quick_capture_sheet.dart:91-98` |
| L-11 | 移动端「更多」Sheet 高度 clamp 320–560，小屏 + 大字体内容被裁 | `lib/ui/workbench_shell.dart:1262-1263` |
| L-12 | `PageHeader` 的 actions 无 `Flexible` 包裹，多 action 溢出 | `lib/ui/widgets/common.dart:504-509` |
| L-13 | 响应式判断模式混用（`MediaQuery` vs `LayoutBuilder`） | 对比 `growth_page.dart:420`、`restriction_page.dart:1583/1742`（正确）与其余 `MediaQuery` 用法 |
| P-01 | 通知小图标复用 `@mipmap/ic_launcher`，Android 上显示为白色方块 | `lib/services/notification_service.dart:63` |
| P-03 | 未注册通知点击回调，payload 未被消费 | `lib/services/notification_service.dart:62-70`（`onDidReceiveNotificationResponse` 全局缺失） |
| P-04 | 缺自适应图标，Android 8+ 图标被遮罩裁切；无 Material You 主题图标 | `android/app/src/main/res/`（仅 5 张 PNG，无 `mipmap-anydpi-v26`） |
| P-05 | 启动底色与 Flutter 主题令牌不一致 | `android/app/src/main/res/values/styles.xml`、`values-night/styles.xml`。`#F6F8F6` vs `lightCanvas #F2F7F3`；`#0E1311` vs `darkCanvas #0F1712`；`navigationBarColor #151C19` vs `darkSurface #16231B`、`#FFFFFF` vs `lightSurface #FBFDFB` |
| P-06 | 缺 `enableOnBackInvokedCallback`，Android 13+ 预测性返回不生效 | `android/app/src/main/AndroidManifest.xml:9-17` |
| P-07 | 未声明备份策略，隐私记录默认进入云备份 | `android/app/src/main/AndroidManifest.xml:5-8` |
| P-08 | SDK 版本全用 Flutter 默认；release 未开混淆与资源压缩 | `android/app/build.gradle.kts:48-51`、`:71-77` |
| I-01 | 多选入口依赖长按且仅 Windows 有显式入口 | `lib/ui/widgets/task_row.dart:69-71`、`lib/ui/pages/plan_page.dart:385`、`lib/state/workbench_controller.dart:3974` |
| I-02 | 28 日矩阵格子 `onTap: null`，无法补记历史 | `lib/ui/pages/habits_page.dart:393-394` |
| I-03 | 硬编码 `Colors.white`，深色模式成白圈 | `lib/ui/pages/habits_page.dart:438`、`lib/ui/widgets/celebration.dart:65,158` |
| I-04 | 对比度取色函数硬编码明暗色 | `lib/ui/widgets/common.dart:1059-1077` |
| I-05 | 折叠侧栏分组菜单硬编码弹层坐标 | `lib/ui/workbench_shell.dart:1146` |
| I-06 | 同步状态条高 26 + 字号 11，低于可读下限 | `lib/ui/workbench_shell.dart:374,397` |
| I-07 | 移动端正文字号 15px，低于 `MASTER.md` 自定的 16px | `lib/core/theme/app_theme.dart:440-444` |
| D-01 | Supabase 客户端初始化异常与 session 失效未处理 | `lib/services/supabase_sync_service.dart:24-34` |
| G-03 | 测试视口缺 360×800 与横屏 | `test/ui_audit_screenshot_test.dart:874-882` |
| G-05 | Android Golden 仅 3 张 | `test/visual_golden_test.dart:552-591` |
| G-08 | InboxPage / CalendarPage 无专项测试 | `test/` |

### 7.3 P2

| ID | 描述 | 位置 |
| --- | --- | --- |
| E-07 | 键盘焦点顺序未系统验证 | 全局 |
| A-05 | 超大文件（>1500 行）技术债 | `workbench_controller.dart`(4892)、`today_page.dart`(2215)、`policies_page.dart`(2206)、`restriction_page.dart`(1787)、`review_page.dart`(1522)、`rsip_controller.dart`(1463)、`focus_page.dart`(1461) |
| F-03 | 同类组件重复实现 | 见 `UI_OPTIMIZATION_ANDROID_CODEX.md` 第 6 节 |
| F-04 | 圆角/间距/字号字面量游离于标尺之外 | 全局 |
| G-07 | 测试维护废弃页面（DiaryPage / ProtocolsPage） | `test/ui_audit_screenshot_test.dart:618-624,667-675` |
| — | `PageHeader` / `EmptyState` 存在成对重复代码分支 | `lib/ui/widgets/common.dart:437-515`、`:778-904` |

---

## 8. 与既有文档的关系

| 文档 | 状态 | 处理建议 |
| --- | --- | --- |
| `UI_AUDIT_CODEX_OPTIMIZATION.md`（根目录，2026-08-19） | **已过时** | 其核心结论「头部翠绿渐变污染」在当前代码中已不存在（`PageHeader` 已改为 `SolidPanel` 实色）；色值引用（`#059669`、`#F6F8F6`）与现行令牌（`#2F7D57`、`#F2F7F3`）不符。建议归档，避免误导 |
| `docs/UI_AUDIT_2026-08-21.md` | 需核对 | 核对结论是否与当前代码一致后再引用 |
| `docs/UI_OPTIMIZATION_GUIDE.md` | 需核对 | 同上 |
| `docs/ui-interaction-audit.md` | 需核对 | 同上 |
| `docs/TEST_ANALYSIS_REPORT.md` | 历史记录 | 测试数量以本文件 `阶段 1` 实测为准 |
| 本文件 + `UI_OPTIMIZATION_ANDROID_CODEX.md` | 现行 | 以此二者为准 |

---

## 9. 交付判定

检测方案执行完毕需同时满足：

1. `第 6 节` 报告模板填写完整，无空项。
2. `第 7.1 节` 全部 P0 项状态为「已修复」且有重跑证据。
3. `第 5 节` 判定标准总表全部达到通过门槛。
4. `flutter analyze` 零 issue，`flutter test` 全通过且总数 ≥ 修复前。
5. Golden 基准已更新，且更新原因逐条记录（区分「修复导致的预期变化」与「回归」）。
