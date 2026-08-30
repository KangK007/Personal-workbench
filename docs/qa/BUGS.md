# 个人工作台发布级缺陷台账

> 基线提交：`052487c`（本轮 QA 修复在该提交后的工作树中）
> 状态流：`OPEN` → `FIXED` → `VERIFIED`；高风险且无法自行决定的事项使用 `BLOCKED`。

## BUG-001

模块：代码质量  
页面：不适用  
严重程度：P3  
类型：Compatibility / Maintainability

复现步骤：

1. 在项目根目录执行 `dart format --output=none --set-exit-if-changed lib test`。
2. 观察退出码和文件列表。

预期：全部 Dart 源码和测试符合仓库统一格式，命令退出码为 0。

实际：8 个文件存在格式漂移，命令退出码为 1。

根本原因：部分后续编辑未运行统一格式化。

修改文件：

- `lib/app.dart`
- `lib/services/restriction_monitor.dart`
- `lib/services/restriction_security_service.dart`
- `lib/services/windows_activity_service.dart`
- `lib/ui/widgets/attachment_panel.dart`
- `test/restriction_monitor_test.dart`
- `test/workbench_controller_test.dart`
- `test/workspace_migration_test.dart`

修复方式：仅使用项目 Dart formatter 做机械格式化，不改变业务逻辑。

验证方式：重新执行格式检查、`flutter analyze` 和完整 `flutter test`。

回归结果：最终格式检查、`flutter analyze` 和 233 项完整测试均通过。

状态：VERIFIED

## BUG-006

模块：今日 / 移动布局  
页面：今日已开始状态  
严重程度：P2  
类型：UI / Accessibility

复现步骤：

1. 使用 `412×915` 紧凑视口打开已有今日承诺的页面。
2. 查看承诺日志右下角的“更换承诺”操作。

预期：操作文字与右下角全局快速新增悬浮按钮均可辨认、可点击。

实际：“更换承诺”右对齐，落在悬浮按钮下方，文字和点击区域被遮挡。

根本原因：紧凑布局仍沿用桌面端右对齐，未为固定右下角操作预留空间。

修改文件：

- `lib/ui/pages/today_page.dart`
- `test/goldens/android_today.png`

修复方式：紧凑布局把“更换承诺”左对齐并保留 8dp 起始间距；桌面布局保持原有右对齐。

验证方式：更新并重新检查 Android Today Golden；运行 Today 相关交互测试与全页面布局矩阵。

回归结果：Golden 中操作与悬浮按钮不再重叠；相关测试通过。

状态：VERIFIED

## BUG-007

模块：任务 / 周视图  
页面：移动周视图  
严重程度：P2  
类型：Accessibility / UI

复现步骤：

1. 使用 `375×812` 视口打开任务“周视图”。
2. 将系统文字缩放设为 200%。

预期：5 个工作日选择卡完整显示星期与日期，无裁剪或溢出。

实际：每个日期卡的纵向 `Column` 底部溢出 9px。

根本原因：日期条固定为 68px，没有随系统文字缩放增长。

修改文件：`lib/ui/pages/calendar_page.dart`

修复方式：日期条高度在 68px 下限基础上按文字比例增长，不改变日期、选择或时间块逻辑。

验证方式：重新运行包含 37 个当前可构建页面表面的 200% 文字缩放全矩阵。

回归结果：`375×812` 及其余全部视口通过，无 RenderFlex overflow。

状态：VERIFIED

## BUG-008

模块：专注  
页面：专注计时全屏页  
严重程度：P2  
类型：Accessibility / UI

复现步骤：

1. 使用 `375×812` 视口进入专注会话页。
2. 将系统文字缩放设为 200%。

预期：模式选择、计时器、进度和操作按钮均可访问，页面可滚动。

实际：固定居中的主 `Column` 底部溢出 95px，底部操作无法完整显示。

根本原因：全屏专注内容仅以固定间距垂直居中，没有在内容高度超过视口时提供滚动退路。

修改文件：`lib/ui/pages/focus_page.dart`

修复方式：使用 `LayoutBuilder + SingleChildScrollView + minHeight`；内容较少时继续居中，内容较高时可以自然滚动。

验证方式：运行专注页 200% 缩放场景、专注结算回归和全页面布局矩阵。

回归结果：全部通过，无溢出，正常字号下原有居中结构保持。

状态：VERIFIED

## BUG-009

模块：共享骨架加载组件  
页面：所有使用 `SkeletonBlock` 的启动/加载表面  
严重程度：P1  
类型：Runtime / Accessibility / Lifecycle

复现步骤：

1. 开启系统“减少动效”。
2. 显示含骨架块的表面后快速切换或卸载。
3. 重复执行。

预期：减少动效时显示静态骨架，卸载无异常。

实际：`dispose()` 首次求值惰性 `_shimmer` getter，在已停用的 Element 上创建带 `vsync` 的 `AnimationController`，抛出 `Looking up a deactivated widget's ancestor is unsafe`。

根本原因：减少动效分支从未在 `build()` 创建控制器，但 `dispose()` 无条件访问了惰性控制器。

修改文件：

- `lib/ui/widgets/common.dart`
- `test/ui_audit_screenshot_test.dart`

修复方式：保存可空控制器，只在动画分支按需创建，销毁时仅释放已创建实例。

验证方式：新增连续三次挂载/卸载的减少动效回归；随后运行所有页面的减少动效矩阵。

回归结果：独立生命周期回归及 39 页面全矩阵均通过。

状态：VERIFIED

## BUG-002

模块：测试基础设施 / Visual QA  
页面：全页面审计截图  
严重程度：P1  
类型：Compatibility / UI Regression

复现步骤：

1. 使用干净工作区执行 `flutter test`。
2. 运行到 `test/ui_audit_screenshot_test.dart`。
3. 观察首个 `matchesGoldenFile` 断言。

预期：默认完整测试在新克隆环境可复现，视觉断言拥有仓库内可携带基线。

实际：测试读取 `docs/images/ui_audit/*.png`，但该目录被 `.gitignore` 排除且基线不存在；首张 `plan_desktop.png` 必然失败。首轮结果为 206 通过、1 失败。

根本原因：截图生成资产与回归 Golden 混用；测试引用了未受版本控制的本地输出目录。

修改文件：

- `test/ui_audit_screenshot_test.dart`
- `test/goldens/ui_audit/*.png`（已生成并纳入回归）

修复方式：保留全部像素断言，将 21 张审计基线迁移到 `test/goldens/ui_audit/`，使默认测试和新克隆环境均可复现。

验证方式：

1. 使用 `--update-goldens` 生成新的受控基线。
2. 不带 `--update-goldens` 单独运行截图测试。
3. 重新运行完整 `flutter test`。

回归结果：21 张 UI 审计基线已迁入 `test/goldens/ui_audit/`；默认完整测试包含 33 张 Golden，233/233 通过。

状态：VERIFIED

## BUG-003

模块：Windows / Android 构建脚本  
页面：不适用  
严重程度：P1  
类型：Compatibility / Build

复现步骤：

1. 在 Codex worktree 的中文路径中运行 `tool/build_windows.ps1 -Configuration debug`。
2. 脚本创建 ASCII junction 并在 junction 内执行 `flutter clean`、`flutter pub get`。
3. 观察 `.dart_tool` 创建失败和退出码 66。

预期：项目提供的中文路径兼容脚本应能在当前 worktree 完成构建。

实际：Windows 目录联接可以读取已存在的 `.dart_tool`，但不能在当前 worktree 目标中经由 junction 新建该隐藏目录；Windows 构建脚本在构建前失败。Android 脚本使用相同流程，存在同类风险。

根本原因：把依赖准备阶段也放进了仅为底层构建工具规避 Unicode 路径而创建的 junction。

修改文件：

- `tool/build_windows.ps1`
- `tool/build_android.ps1`

修复方式：把源码镜像到 `%LOCALAPPDATA%\PersonalWorkbenchBuild\<项目哈希>\source-copy`，排除 `.git`、`.dart_tool`、`build`、`dist` 等生成目录；依赖准备和平台构建都在纯 ASCII 副本中执行，再把产物复制回项目标准输出目录。该方案不修改或覆盖真实源码。

验证方式：分别运行 Windows Debug、Windows Release 和 Android Debug 构建，检查预期产物。

回归结果：Windows Debug、Windows Release 与 Android Debug 均已完成干净构建并生成预期产物。

状态：VERIFIED

## BUG-004

模块：Android 构建脚本  
页面：不适用  
严重程度：P1  
类型：Compatibility / Build

复现步骤：

1. 在当前 Windows Codex 进程中运行 `tool/build_android.ps1 -Configuration debug -Clean`。
2. Gradle 启动单次守护进程。
3. 观察 JDK 21 `WEPollSelectorImpl` 抛出 `Unable to establish loopback connection`，内部错误为 `UnixDomainSockets.connect0` 的 `Invalid argument: connect`。

预期：Gradle 能建立本机进程间通道并继续构建。

实际：当前受控进程的有效临时套接字路径超过 Windows AF_UNIX 路径限制，Gradle 在项目配置前退出。

根本原因：JDK 21 在 Windows 上为 NIO selector 创建 AF_UNIX 唤醒通道，通道路径派生自进程临时目录；受控进程中的有效路径过长。

修改文件：`tool/build_android.ps1`

修复方式：仅在 Gradle 子进程期间把 `TEMP`、`TMP` 指向 `C:\PWBTemp\<项目哈希>`，完成后恢复原进程环境；不改变系统级环境变量。

验证方式：不预设外部 `TEMP/TMP`，重新执行 Android Debug 干净构建。

回归结果：未预设外部 `TEMP/TMP`，Android Debug 干净构建成功并生成可解析 APK。

状态：VERIFIED

## BUG-005

模块：专注 / 完成证据对话框  
页面：专注计时全屏页  
严重程度：P0  
类型：Runtime Crash / UI Lifecycle / Layout Overflow

复现步骤：

1. 在隔离数据库中创建并锁定一项今日承诺。
2. 从“今日”进入专注，选择“正计时”，开始后暂停或继续。
3. 点击“完成本次专注”，不填写可选的“完成内容”和“备注”。
4. 点击“结算本轮”。

预期：普通任务允许空证据，结算完成且对话框正常退场。

实际：对话框退场动画期间出现 `A TextEditingController was used after being disposed`，输入区变为红屏，并报告约 199588 像素的底部溢出。证据截图：`docs/qa/screenshots/runtime_focus_empty_evidence_crash.png`。

根本原因：`showGeneralDialog` 的结果 Future 在 `Navigator.pop` 后、反向动画结束前完成；调用方随即释放 `TextEditingController`，而退场中的 `TextField` 仍会重建并访问控制器。

修改文件：

- `lib/ui/pages/focus_page.dart`
- `test/ui_coverage_regression_test.dart`

修复方式：完成证据对话框不再为两个短输入持有外部 `TextEditingController`，改用 `TextField.onChanged` 写入局部字符串；保留普通任务证据可选、CTDP 完成内容必填的原有语义。

验证方式：

1. 新增 Widget 回归测试，空证据结算普通专注并在 100ms 退场动画窗口检查无异常。
2. 单独运行相关测试。
3. 重建隔离版 Windows Debug，按原步骤真实界面回归。
4. 完整运行静态分析、全部测试与 Golden 回归。

回归结果：新增普通任务空证据与 CTDP 必填证据自动测试均通过；重建隔离 Windows Debug 后按原路径真实界面复验，无红屏、无溢出，记录正确返回今日页。

状态：VERIFIED

## BUG-010

模块：笔记附件 / 原生文件选择器  
页面：笔记详情  
严重程度：P1  
类型：Accessibility / Keyboard / Platform Integration

复现步骤：

1. 在隔离数据库中创建并打开一条笔记。
2. 点击“添加图片”打开 Windows 原生文件选择器。
3. 按 `Escape` 取消选择。
4. 按 `Ctrl+K` 打开全局搜索。

预期：文件选择器关闭后焦点回到“添加图片”按钮，应用快捷键立即可用。

实际：焦点停留在原生窗口根节点，`Ctrl+K` 连续两次无响应；首轮旧构建还曾出现一次主内容黑屏。

根本原因：附件按钮没有稳定 `FocusNode`，`FilePicker` 返回后也没有显式恢复 Flutter 焦点；Windows 原生对话框关闭会把焦点留在顶层窗口。

修改文件：

- `lib/ui/widgets/attachment_panel.dart`
- `test/ui_coverage_regression_test.dart`

修复方式：为“添加图片”按钮持有并释放专用 `FocusNode`；文件选择器启用 `lockParentWindow`，返回后无论取消或选中文件都恢复按钮焦点。

验证方式：

1. Widget 测试模拟原生选择器夺走焦点并返回空结果。
2. 检查按钮重新获得焦点，且无未处理异常。
3. 重建隔离 Windows Debug，按原路径复验 `Ctrl+K`、关闭搜索和再次编辑。

回归结果：自动化回归已通过；真实 Windows 序列因共享桌面出现用户前台活动而停止，未安全完成修复后复验。

状态：FIXED（真实平台复验 BLOCKED）

## BUG-011

模块：Windows 构建脚本  
页面：不适用  
严重程度：P2  
类型：Build / Automation

复现步骤：

1. 在 PowerShell 调用 `tool/build_windows.ps1 -Configuration debug`。
2. 构建和快捷方式更新均成功。
3. 在调用方读取 `$LASTEXITCODE`。

预期：成功构建向调用方报告退出码 `0`。

实际：产物成功生成，但调用方读到 `3`，这是 `robocopy` 的“成功且有额外文件”状态码。

根本原因：脚本正确接受 `robocopy` 的 `0`–`7` 为成功，却没有在所有操作成功后归一化调用方可见的 `$LASTEXITCODE`。

修改文件：`tool/build_windows.ps1`

修复方式：成功结束前把调用方可见的 `$LASTEXITCODE` 明确归零；任何真实失败仍通过已有 `throw` 路径终止。

验证方式：重新执行 Windows Debug 构建并读取调用方 `$LASTEXITCODE`。

回归结果：Windows Debug 与最终 Windows Release 干净构建均成功，调用方退出码为 0，三个快捷方式目标存在且指向最终 Release 产物。

状态：VERIFIED

## BUG-012

模块：应用壳 / Android 响应式导航  
页面：手机横屏今日页  
严重程度：P1  
类型：UI / Responsive / Runtime

复现步骤：

1. 在 Pixel 6 API 35 模拟器中以 1080×2400 竖屏启动应用并创建一项任务。
2. 旋转到 2400×1080 横屏。
3. 检查左侧导航和 Flutter 运行日志。

预期：手机横屏继续使用可访问的移动导航，无布局溢出。

实际：宽度断点把手机横屏误判为桌面布局；受横屏安全区挤压，折叠侧栏出现 `RIGHT OVERFLOWED BY 29 PIXELS`。

根本原因：应用壳只根据宽度选择移动/桌面布局，没有考虑手机横屏的低可用高度。

修改文件：

- `lib/core/theme/app_theme.dart`
- `lib/ui/workbench_shell.dart`
- `test/ui_coverage_regression_test.dart`
- `test/page_smoke_test.dart`

修复方式：增加 600 逻辑像素的紧凑高度阈值；低高度窗口使用移动端导航。保留 1300×620 桌面侧栏滚动回归，并新增 915×412 手机横屏回归。

验证方式：

1. 定向运行手机横屏与桌面最低高度测试。
2. 重建 Android Debug APK。
3. 在同一模拟器重新安装，旋转后采集截图、UIAutomator 语义树和 logcat。
4. 运行最终 233 项完整测试。

回归结果：横屏显示 5 个移动导航语义节点，无红色溢出条；logcat 无 `RenderFlex overflowed`、`E/flutter` 或应用崩溃；完整测试通过。

状态：VERIFIED

## BUG-013

模块：任务群编辑器  
页面：任务群新建与编辑 Dialog  
严重程度：P0  
类型：Runtime / Lifecycle

复现步骤：

1. 打开任务群新建或编辑 Dialog。
2. 保存后等待 Dialog 退出动画；重复打开、取消或连续点击保存。
3. 观察 Flutter 错误输出。

预期：Dialog 平稳关闭，数据只保存一次，不产生生命周期断言。

实际：整体页面红屏并触发 `framework.dart` 的 `_dependents.isEmpty` 断言。

根本原因：旧实现由外部函数创建并提前释放 `TextEditingController`，同时通过 `StatefulBuilder` 驱动仍处于退出动画中的 Dialog，导致依赖树清理时生命周期错序。

修改文件：

- `lib/ui/widgets/task_group_editor_dialog.dart`
- `lib/ui/pages/plan_page.dart`
- `lib/ui/pages/projects_page.dart`
- `lib/ui/pages/calendar_page.dart`
- `test/optimization_regression_test.dart`

修复方式：提取独立 `TaskGroupEditorDialog`，由其 State 创建和释放控制器；保存期间锁定关闭与重复提交，校验和持久化错误显示在表单内，成功保存后才关闭 Dialog。

验证方式：使用内存数据库执行新建、编辑、取消、校验失败、重复提交和退出动画 Widget 回归，并运行完整 Flutter 测试与隔离 Windows 启动。

回归结果：任务群生命周期定向回归通过；最终 233 项完整测试、静态分析和 Windows Debug 隔离启动通过，未再出现 `_dependents.isEmpty`。

状态：VERIFIED

## BUG-014

模块：共享 Dialog 基础设施
页面：全局搜索、快速新增、记录编辑器、任务群编辑器、关联选择器、Markdown 编辑器
严重程度：P2
类型：Accessibility / Interaction / Keyboard

复现步骤：

1. 通过 `showWorkbenchDialog` 打开一个 `barrierDismissible: false` 的共享 Dialog。
2. 将焦点移入输入框并按 `Tab` 多次。
3. 按 `Escape`，并在 375×812、1200×864、1536×864 与 200% 字号下重复。

预期：Dialog 路由取得焦点，Tab 不逃出 Dialog，Escape 在允许关闭时只关闭当前 Dialog；保存中的任务群 Dialog 仍服从 `PopScope` 禁止关闭。

实际：共享 `showGeneralDialog` 没有显式请求路由焦点；不可点遮罩的 Dialog 缺少一致的 Escape 路径。初版修复若使用可遍历的根 `Focus`，还会改变 Tab 顺序并导致焦点陷阱回归。

根本原因：共享 Dialog 封装只配置了动画和遮罩，没有统一承担键盘焦点及 Escape 语义；根 `Focus` 节点若参与遍历，会成为额外 Tab 停靠点。

修改文件：

- `lib/ui/widgets/common.dart`
- `test/ui_audit_screenshot_test.dart`
- `test/theme_accessibility_test.dart`

修复方式：让 `showGeneralDialog` 显式 `requestFocus`；使用 `skipTraversal: true` 的根 `Focus` 捕获 Escape，通过 `Navigator.maybePop` 保留 `PopScope` 业务约束，并在路由已反向/结束动画时避免重复 pop。

验证方式：

1. 定向运行 `Ctrl+K opens global search from the workbench shell`，验证原焦点陷阱和关闭路径。
2. 对 6 个共享 Dialog 执行 4 个尺寸/字号场景，共 24 个 Focus/Tab/Escape/长文本组合。
3. 对 37 个表面在 3 个窗口尺寸触发 Hover、Pressed、Focus、Keyboard，并开关全部实际存在的 Popup/Dropdown。
4. 运行 Golden/UI 子集 28/28、`flutter analyze` 和完整测试 233/233。

回归结果：定向焦点陷阱、24 个 Dialog 场景、222 个页面交互-尺寸场景、28 个 Golden/UI 测试和 233 项完整测试均通过。

状态：VERIFIED

## BUG-015

模块：QA 覆盖统计
页面：`PROJECT_MAP.md`、`TEST_MATRIX.md` 与最终报告
严重程度：P2
类型：Documentation / Test Governance

复现步骤：

1. 从 `test/ui_audit_screenshot_test.dart` 实际展开 `_auditSurfaces`。
2. 逐行解析 `TEST_MATRIX.md` 的 Case ID 与状态。
3. 将结果与文档中的 39 个表面、208 个 Case 比较。

预期：项目地图、矩阵正文和统计表一致，且所有合法 Case ID 都参与计数。

实际：当前可构建表面实际为 37 个；旧 Case 统计正则只接受纯字母前缀，漏计了 7 条 `A11Y-*`，把 215 条既有 Case 写成 208 条。

根本原因：页面枚举调整后统计未从代码重新生成；Case 计数脚本假设 ID 前缀不含数字。

修改文件：

- `docs/qa/PROJECT_MAP.md`
- `docs/qa/TEST_MATRIX.md`
- `docs/qa/FINAL_QA_REPORT.md`
- `docs/qa/UI_UX_AUDIT_FINAL.md`

修复方式：按当前枚举明确列出 37 个表面；Case 解析允许 `[A-Z0-9]+-[0-9]+`，重新统计为 253 条：242 PASS、11 BLOCKED、0 FAIL。

验证方式：机器逐行解析 Case ID、状态与重复项；核对 38 条 `U4D-*`；扫描项目地图和矩阵的未执行标记。

回归结果：253 个唯一 Case，242 PASS、11 BLOCKED；38 条 `U4D-*`；无重复 ID、无未执行项。

状态：VERIFIED

## 已知发布风险（非本轮直接修复）

### RISK-001：依赖已停用

`flutter pub get` 报告 `flutter_markdown 0.7.7+1` 已停用并由 `flutter_markdown_plus` 替代。当前静态分析与既有功能仍可运行；直接迁移会改变依赖与渲染 API，需单独做 Markdown 兼容和视觉回归。本轮先记录风险，不把无证据的大版本依赖迁移混入普通缺陷修复。

### RISK-002：Android 构建工具链兼容警告

Android Debug 干净构建成功，但存在 SDK XML 版本 4/工具理解到版本 3、第三方插件 Manifest `package` 属性被忽略、JDK 21 编译 Java 8 目标已弃用，以及 Gradle 9 不兼容弃用特性的警告。当前不阻断 0.1.0+4 Debug APK；升级 Android Gradle Plugin、插件或 Java 目标时需要单独执行依赖与通知/文件选择器回归。

### RISK-003：Android 模拟器宿主稳定性

Android Emulator 37.1.11 在无窗口 SwiftShader 会话中多次发生 ADB 协议故障或图形缓冲错误并自行离线。应用启动、IME、Back、权限、即时通知、分享、横屏、尺寸变化和持久化均已在稳定窗口内通过，logcat 未见应用 `FATAL EXCEPTION`；休眠/重启后的定时通知仍需物理设备或稳定隔离模拟器验证。
