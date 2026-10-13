# 青玉柔光改版验证记录

更新至：2026-10-13（Windows，Asia/Shanghai）。本文件只记录已经执行的检查；逐页完成状态见 `REQUIREMENT_MATRIX.md`，截图对应关系见 `SCREENSHOT_MANIFEST.md`。

## 代码与构建

| 检查 | 结果 | 证据 / 范围 |
|---|---|---|
| CTDP 原子结算与重试后 `flutter test --no-pub`、`flutter analyze --no-pub`、`flutter build windows --release --no-pub` | 通过，454 tests；0 issue；Release 构建 86.6 秒 | 专注会话、任务计数、协议事件、父组结算和提前完成判例使用次数通过 `AppDatabase.saveRecords` 的同一 SQLite 事务保存；页面会话 ID 防止后续失败重试重复计数。隔离数据库测试在批量写入中途注入故障，验证回滚、重试和再次调用均只结算一次；全量跨尺寸矩阵仍通过。日志 `build/full-test-ctdp-atomic-final.log`、`build/windows-release-ctdp-atomic-final.log`（本地）；130 文件格式检查 0 改动，`git diff --check` 通过。真实 SQLite 故障恢复与 Windows 高 DPI 尚待验证。 |
| 普通专注写入失败可重试后 `flutter test --no-pub -r expanded`、`flutter analyze --no-pub`、`flutter build windows --release --no-pub` | 通过，452 tests；0 issue；Release 构建 51.8 秒 | 隔离数据库首次写入故障下，退出入口恢复、计时保留，证据再次打开时预填；重试成功仅生成一条会话记录。专注完成的 360ms 圆环、减少动效和多尺寸截图回归仍通过。日志 `build/full-test-focus-retry-final.log`、`build/windows-release-focus-retry-final.log`（本地）；130 文件格式检查 0 改动，`git diff --check` 通过。CTDP 多步骤部分写入与真实数据库故障恢复未由该测试覆盖。 |
| 专注会话完成态对齐后 `flutter test --no-pub -r expanded`、`flutter analyze --no-pub`、`flutter build windows --release --no-pub` | 通过，451 tests；0 issue；Release 构建 54.0 秒 | PDF 第 6、28 页的轻量完成反馈已用 360ms 圆环、可关闭面板和返回动作实现；新增 320×568/200% 与 1200×900 双主题完成截图，任务胶囊和静态叶影后的 35 项矩阵已更新。定向测试验证 400ms 内收束、减少动效终态、2 秒后仍保留操作，以及有/无任务在短窗的按钮可见性。日志 `build/full-test-focus-session-design-final.log`、`build/windows-release-focus-session-design-final.log`（本地）；130 文件格式检查 0 改动，`git diff --check` 通过。 |
| 短窗与极窄大字布局最终 `flutter test --no-pub -r expanded`、`flutter analyze --no-pub`、`flutter build windows --release --no-pub` | 通过，449 tests；0 issue；Release 构建 53.2 秒 | 35 项双主题尺寸矩阵、800×450/200% 今日主按钮、320×568/200% 日回顾事实卡与今日概览卡几何回归均通过；受影响浅/深色原图逐张目检。日志 `build/full-test-responsive-final-20261013.log`、`build/windows-release-responsive-final-20261013.log`（本地）。130 文件格式检查 0 改动，`git diff --check` 通过。 |
| 今日短窗主操作修正后 `flutter test --no-pub -r expanded`、`flutter analyze --no-pub`、`flutter build windows --release --no-pub` | 通过，447 tests；0 issue；Release 构建 52.9 秒 | 1440×900 五任务双栏首屏与 1440×450 右栏固定入口，以及 800×450、200% 文字下完整主按钮均有几何回归；35 项双主题尺寸矩阵通过，浅/深色短窗原图已目检。日志 `build/full-test-today-short-window-final.log`、`build/windows-release-today-short-window-final.log`（本地）；130 文件格式检查 0 改动，`git diff --check` 通过。 |
| 今日任务 160ms 收拢 `flutter test --no-pub -r expanded`、`flutter analyze --no-pub`、`flutter build windows --release --no-pub` | 通过，445 tests；0 issue；Release 构建 52.2 秒 | 完成后的行位移、退场中撤销回弹、最后一项带动分区收拢、减少动效立即收拢及 40 项长列表离屏行清理通过专项回归；35 审计目标的尺寸矩阵、共享弹窗和静态截图仍通过。日志 `build/full-test-task-reflow-final.log` 与 `build/windows-release-task-reflow-final.log`（本地）；本轮未重测实际 Windows 高 DPI 帧耗。 |
| 今日进度环 `flutter test --no-pub -r expanded`、`flutter analyze --no-pub`、`flutter build windows --release --no-pub` | 通过，442 tests；0 issue；Release 构建 51.7 秒 | 真实任务完成率驱动进度环和中心数字共同过渡 240ms；完成与撤销检查中间帧，减少动效立即更新，语义读取最终值。宽/窄窗今日页截图基线保持一致；日志 `build/full-test-progress-ring.log`（本地） |
| 最终 `flutter test --no-pub -r expanded`、`flutter analyze --no-pub`、`flutter build windows --release --no-pub` | 通过，441 tests；0 issue；Release 构建 52.1 秒 | 35 项双主题九档矩阵含 320×568 与 800×450 的 200% 文字；今日时间标尺密度和周视图日期格按宽度调整，导航壳五张受影响基线已更新。完整测试日志 `build/full-test-responsive-final.log`（本地），截图索引见 `SCREENSHOT_MANIFEST.md` |
| `flutter test --no-pub -r compact`、`flutter analyze --no-pub`、`flutter build windows --release --no-pub` | 通过，440 tests；0 issue；Release 构建 52.8 秒 | 新增 320×568、200% 文字的 35 项双主题截图 70 张及两张总览；周视图日期格按实际宽度收紧星期标签，保留完整语义。浅色周视图原图和两主题总览已目检；`git diff --check` 通过 |
| `flutter analyze --no-pub` | 通过，0 issue | 改版代码与测试静态检查 |
| 本轮最终 `flutter test --no-pub -r expanded`、`flutter analyze --no-pub` | 通过，418 tests；0 issue | 增加真实当天计划和 120 任务长列表回归，验证窗口缩放与末尾滚动；修复纯控制器测试无 Flutter 绑定时的帧索引访问。日志 `build/full-test-final.log`（本地） |
| 矢量插画与按日筛选后 `flutter test --no-pub -r expanded`、`flutter analyze --no-pub` | 通过，419 tests；0 issue | 35 项双主题断点截图及共享浮层、04:00 逻辑日、长列表、矢量插画均通过；日志 `build/full-test-vector-art-final.log`（本地）。`dart format` 检查 129 文件、`git diff --check` 通过 |
| `flutter test --no-pub test/ui_audit_screenshot_test.dart --name "all mapped surfaces reflow\|shared dialogs survive" -r expanded` | 通过，2 tests，43 秒 | 页面子树持续挂载，35 页 × 双主题 × 两档文字 × 七种连续尺寸；六类浮层在 42 种打开场景下继续缩放。`resize-live-layout.log`，范围见 `WINDOW_LAYOUT_AUDIT.md` |
| `flutter test --no-pub test/workbench_feedback_test.dart test/page_smoke_test.dart test/optimization_regression_test.dart test/task_group_transfer_test.dart -r expanded` | 通过，48 tests | 收件箱新记录/整理/撤销、保存失败、正常与减少动效；反馈随窗口与文字大小实时重排，双主题撤销可达。`responsive-feedback-regression.log` |
| `flutter test --no-pub test/ui_audit_screenshot_test.dart --plain-name "captures project group move selection and result" --update-goldens` | 通过，1 test | 反馈动作移入实时自适应内容布局，更新两张宽窗结果截图；浅色 320×568/1200×900 与深色 1200×900 原图已目检。`feedback-golden-update.log` |
| `flutter test --no-pub test/protocol_ui_flow_test.dart -r expanded` | 通过，18 tests | CTDP 预约前后、RSIP 跨日旧记录/当天完成/冻结、零成员任务组与编辑弹窗 180ms、减少动效两种模式；既有保存失败、规则与分析交互回归。`protocol-stage-regression.log` |
| `flutter test --no-pub test/protocol_ui_flow_test.dart -r expanded` | 通过，19 tests | CTDP 96 个子项的可见行构建与末项滚动、预约及任务组阶段、RSIP 当天结算/冻结、编辑弹窗和规则/分析交互。`protocol-tree-full-regression.log` |
| `flutter test --no-pub test/visual_golden_test.dart test/ui_audit_screenshot_test.dart --name "Wide protocols light\|captures grouped protocol\|captures linked execution\|captures the structured rule editor in compact and wide windows" -r expanded` | 通过，4 tests | CTDP 列表按需构建后，宽屏协议、关联历史、分组协议及规则编辑弹窗截图保持一致。`protocol-tree-goldens.log` |
| `flutter test --no-pub test/ui_audit_screenshot_test.dart --update-goldens --name "captures grouped protocol\|captures linked execution\|captures all 35\|captures the remaining UI audit" -r expanded` | 通过，6 tests，约 1 分 50 秒 | 协议册页图标和阶段带影响的 35 项双主题尺寸矩阵、分组入口及关联时间线已重新生成；浅色 390×844、深色 1200×900 的 CTDP/RSIP 四张原图已目检。`protocol-stage-golden-update.log` |
| `flutter test --no-pub test/visual_golden_test.dart --update-goldens --name "Wide protocols light" -r expanded` | 通过，1 test | 宽屏执行协议阶段带截图已更新并目检。`protocol-wide-golden-update.log` |
| `flutter test --no-pub test/ui_audit_screenshot_test.dart --update-goldens --name "captures the structured rule editor in compact and wide windows" -r expanded` | 通过，1 test | 更新规则编辑器背景中受协议册页图标影响的深色窄窗截图，并目检弹窗内容与背景标签。`protocol-rule-golden-update.log` |
| `flutter test --no-pub -r compact` | 通过，418 tests，约 4 分 58 秒 | 全项目测试，包括 35 页双主题尺寸矩阵、保持挂载的连续缩放、导航壳与共享浮层、打开后弹窗缩放、200% 文字、长列表、键盘、失败重试、撤销、全局搜索历史及账号清理、四类关系选择与笔记/回顾保存、深树钻取/新增焦点、跨组拖放/原顺序撤销及 SQLite 保存、反馈动作对比度与实时重排、收件箱整理收束及撤销、执行协议阶段与减少动效、96 个子项的 CTDP 树；详细覆盖见下文，日志 `flutter-test.log` |
| `dart format --output=none --set-exit-if-changed tool lib test` | 通过，126 个文件，0 个格式变化 | 包含新 Windows Profile 测量脚本；`flutter analyze --no-pub` 同时通过，0 issue |
| `flutter test --no-pub --update-goldens test/visual_golden_test.dart` | 通过，25 tests | 更新 `test/goldens/`、14 张导航壳断点截图及 `docs/images/` 中受新视觉影响的基线；含窄窗国策标签调整 |
| `flutter test --no-pub --update-goldens test/ui_audit_screenshot_test.dart` | 通过，37 tests，约 4 分 32 秒 | 更新 490 张 35 页双主题尺寸基线、8 张分组协议入口、4 张关联执行时间线、4 张笔记阅读、4 张计划任务群展开态、4 张项目看板、4 张项目任务群展开态、4 张项目里程碑、4 张项目笔记与回顾、2 张习惯整月展开及 6 张初始化错误/重试状态截图；判例页基线含生效和归档记录 |
| `flutter test --no-pub test/ui_audit_screenshot_test.dart --plain-name "captures relation picker across compact wide and large text" --update-goldens` | 通过，1 test | 四类关系浮层 320×568（200% 文字）、390×844、1200×900 双主题任务/笔记状态截图共 12 张 |
| `flutter test --no-pub --update-goldens test/ui_audit_screenshot_test.dart --plain-name "captures deep group drill paths in plan and project views"` | 通过，1 test | 计划/项目任务群 390×844、1200×900 双主题深层钻取截图共 8 张；共享路径导航与当前根已目检 |
| `flutter test --no-pub --update-goldens test/ui_audit_screenshot_test.dart --plain-name "captures project group move selection and result"` | 通过，1 test | 跨组选择/完成结果 320×568（200% 文字）、1200×900 双主题截图共 8 张；目标高亮、完整反馈及成员未被遮挡 |
| `flutter test --no-pub test/task_group_transfer_test.dart` | 通过，5 tests | 原位置撤销、保留其他编辑、移动/撤销写入失败、过时撤销保护及实际隔离 SQLite 保存 |
| `flutter test --no-pub test/ui_audit_screenshot_test.dart --plain-name "captures markdown editing and preview in both themes" --update-goldens -r expanded` | 通过，1 test | 新增 Markdown 编辑弹窗双主题截图 8 张，覆盖标题校验、窄窗编辑/预览和宽窗双栏；已目检代表画面 |
| `flutter test --no-pub test/ui_audit_screenshot_test.dart --plain-name "captures global search results across window sizes" --update-goldens -r expanded` | 通过，1 test | 新增全局搜索 320×568（200% 文字）、390×844、1200×900 双主题截图 6 张；已目检代表画面 |
| `flutter test --no-pub --update-goldens test/ui_audit_screenshot_test.dart --plain-name "captures recent search history in compact and wide windows"` | 通过，1 test | 最近搜索 320×568（200% 文字）、390×844、1200×900 双主题截图 6 张；桌面两条历史的面板高度小于 450dp |
| `flutter test --no-pub test/ui_audit_screenshot_test.dart --plain-name "captures the quick project picker in both themes" --update-goldens -r expanded` | 通过，1 test | 新增快速新增和项目选择器 320×568（200% 文字）、390×844、1200×900 双主题截图 12 张；已目检代表画面 |
| `flutter test --no-pub test/ui_audit_screenshot_test.dart --plain-name "quick capture focuses the first error in a short window" --update-goldens -r expanded` | 通过，1 test | 新增 320×568、200% 文字下空标题校验截图，并确认焦点回到输入框 |
| `flutter test --no-pub test/ui_audit_screenshot_test.dart --plain-name "captures the restriction editor and schedule preview" --update-goldens -r expanded` | 通过，1 test | 新增编辑器顶部、逐日预览和时段子弹窗双主题截图 18 张，覆盖 320×568（200% 文字）、390×844、1200×900；抽查并修复窄窗大字号星期标签折行 |
| `flutter test --no-pub test/ui_audit_screenshot_test.dart --plain-name "captures the configured account form across window sizes" --update-goldens -r expanded` | 通过，1 test | 新增配置态账号表单双主题截图 12 张及浅色校验态 1 张，覆盖 320×568（200% 文字）、390×844、1200×900；抽查并修复逻辑日设置行窄窗逐字折行 |
| `flutter test --no-pub test/ui_audit_screenshot_test.dart --plain-name "captures sync conflict comparison in compact and wide windows" --update-goldens -r expanded` | 通过，1 test | 新增同步冲突对照与选择双主题截图 8 张，覆盖 320×568（200% 文字）和 1200×900；抽查并收紧桌面少量差异时的弹窗高度 |
| `flutter test --no-pub test/ui_audit_screenshot_test.dart --plain-name "captures the remaining UI audit surfaces" --update-goldens -r expanded` | 通过，1 test | 更新既有自律规则编辑器桌面与移动截图、设置桌面截图基线 |
| `flutter test --no-pub test/ui_audit_screenshot_test.dart --plain-name "captures all 35 audit targets" --update-goldens -r expanded` | 通过，3 tests | 重新生成 35 项双主题尺寸矩阵，覆盖国策标签、习惯长列表与短窗专注布局；已目检窄窗国策及专注代表画面 |
| `flutter test --no-pub --update-goldens test/ui_audit_screenshot_test.dart --name "captures all 35 audit targets\|captures the remaining UI audit surfaces"` | 通过，4 tests | 周视图工作日选中修复后刷新 35 页双主题尺寸矩阵与桌面独立页截图；390×568、800×450、1200×900 浅色总览图重建并目检 |
| `flutter test --no-pub test/settings_cloud_layout_test.dart test/workbench_controller_test.dart -r expanded` | 通过，44 tests | 模拟 320×568、200% 文字、200dp 软键盘下的认证失败保留输入与操作可达；已登录同步错误状态换行和本次启动最近同步时间。随后单跑 `settings_cloud_layout_test.dart` 的 4 项测试，覆盖冲突云端/本地两种决策与数据库写入失败重试 |
| `flutter test --no-pub --update-goldens test/ui_audit_screenshot_test.dart --plain-name "captures the structured rule editor in compact and wide windows"` | 通过，1 test | `rule-editor-golden.log`；新增 390×844、1200×900 双主题结构化判例编辑截图共 4 张 |
| `flutter build windows --release --no-pub` | 通过，85.0 秒 | `build/windows/x64/runner/Release/personal_workbench.exe`；协议阶段带、册页图标、CTDP 父子索引与按需列表及既有响应式修改均已纳入构建，AOT `data/app.so` 更新至 2026-10-12 20:29 |
| 本轮最终 `flutter build windows --release --no-pub` | 通过，57.2 秒 | 包含今日长列表和构建帧索引修正；`build/windows-build-final.log`（本地）。仅验证 Release 可构建，正式安装包待全部设计目标完成后更新 |
| 矢量插画与按日筛选后 `flutter build windows --release --no-pub` | 通过，57.6 秒 | `build/windows-build-vector-art.log`（本地）；新 `data/app.so` 已更新，Release 的 `AssetManifest.bin` 无旧插画路径、打包目录中旧 WebP 数为 0。尚未生成正式安装包 |
| `flutter run -d windows --profile --trace-startup --no-pub` | 通过，首帧约 1.68 秒 | 独立空 SQLite 路径；`build/start_up_info.json` 记录 `timeToFirstFrameMicros=1681221`、首帧栅格化约 1.70 秒。仅一次冷启动样本，非稳定启动时间承诺 |
| `dart tool/profile_window_probe.dart` | 通过，42 个缩放帧 | 实际 Windows Profile 窗口从 1200×900 依次改至 390×844、320×568、800×450、1440×900；所有外窗尺寸达到请求值、窗口 DPI 均为 96。UI 帧 p95 5.734ms、栅格帧 p95 15.918ms，各 42 帧均不超过 16.67ms；报告 `WINDOWS_PROFILE_2026-10-12.json` |
| `dart tool/profile_window_probe.dart`，600 任务隔离数据库 | 已测，按日筛选调整前仍有慢帧 | 同样五档 96 DPI 窗口；600 个任务实例、600 个定义、12 个项目、当天 120 个任务。调整前 32 个 UI 帧 p95 48.146ms、15 帧超过 16.67ms；栅格帧 p95 18.185ms、4 帧超限。报告 `WINDOWS_PROFILE_HEAVY_2026-10-12.json`。 |
| `dart tool/profile_window_probe.dart`，按日筛选调整后 | 两次 96 DPI 复测通过 UI 帧预算 | 同一数据库及五档外窗，每次 42 个 UI 帧：p95 5.040/6.363ms，最大 9.490/8.197ms，均无 UI 超限。栅格 p95 18.879/19.237ms，各 4 帧超 16.67ms。报告 `WINDOWS_PROFILE_HEAVY_DAY_FILTER_2026-10-12.json` 和 `WINDOWS_PROFILE_HEAVY_DAY_FILTER_REPEAT_2026-10-12.json`；只覆盖今日页窗口变化。 |
| `flutter test --no-pub test/today_task_frame_index_test.dart` | 通过，1 test | 构建帧内按日索引在 04:00 逻辑日边界归类正确，记录新增后下一帧更新；35 页断点截图与今日 120 项长列表定向回归另通过 3 tests |
| `flutter test --no-pub test/illustration_vector_test.dart` | 通过，1 test | 七类装饰图在双主题下按指定尺寸绘制，无 `Image` widget；旧 WebP 已从 `pubspec.yaml` 资源声明移除 |
| `flutter test --no-pub --update-goldens test/ui_audit_screenshot_test.dart --name "captures all 35 audit targets"` | 通过，3 tests | 重新生成 35 项双主题断点矩阵；另更新收件箱桌面和笔记阅读两项专项截图，六张总览由 `tool/build_audit_contact_sheets.py` 重新生成。成长、笔记、日回顾双主题窄窗及收件箱桌面、深色宽窗笔记阅读原图已目检 |
| `flutter test --no-pub --update-goldens test/visual_golden_test.dart` | 通过，25 tests | 同步文档页和移动页插画变化，日志 `build/vector-art-visual-golden-update.log`（本地） |
| `flutter test --no-pub test/ui_audit_screenshot_test.dart --name "project overview animates selection\|project board uses actual detail width\|project detail lists build rows\|captures all 35 audit targets"` | 通过，6 tests | 项目详情 180ms 切换淡入、240ms 进度变化及减少动效；项目看板、长列表和 35 页双主题断点基线保持一致。日志 `build/project-overview-golden-regression.log`（本地） |
| `flutter test --no-pub`，项目图标与截图更新后 | 通过，421 tests | 35 项双主题断点、项目清单/看板/任务群/里程碑/知识页截图及文档项目图已同步；日志 `build/project-icon-final-test.log`（本地）。随后新增的长标题测试单独通过，完整测试总数变为 422 |
| 项目图标与长标题定向测试 | 通过，2 tests | 320×568、200% 文字下 8 图标选择及持久化；长标题在 320×568、800×450、1440×900 双主题布局无异常 |
| `flutter build windows --release --no-pub`，项目图标接入后 | 通过，52.9 秒 | `build/project-icon-windows-build.log`（本地），生成 Windows Release 可执行文件；正式安装包按目标完成后的用户指示更新 |
| `flutter test --no-pub`，项目下一步与里程碑摘要接入后 | 通过，423 tests | 覆盖真实下一步、待办/取消/已达成里程碑、22dp 长标题、双主题断点和完整窗口/弹窗矩阵；日志 `build/project-overview-summary-final-test.log`（本地） |
| `flutter build windows --release --no-pub`，项目概览摘要接入后 | 通过，50.4 秒 | `build/project-overview-summary-windows-build.log`（本地）；生成 Windows Release 可执行文件，正式安装包尚未更新 |
| 项目索引惰性构建定向测试 | 通过，2 tests | 120 个附加项目的末项初始不构建，滚动后可访问并选中；项目详情 120 条任务的清单和看板仍按可见范围构建 |
| 项目看板长标题与里程碑局部动效测试 | 通过 | 三种任务状态及长标题覆盖 390×844 单列、1440×900 三列、320×568 的 200% 文字双主题；里程碑 240ms 完成过渡、180ms 新增淡入和减少动效均验证中间及最终状态 |
| `flutter test --no-pub`，项目索引、看板和里程碑动效调整后 | 通过，425 tests | 完整页面、断点、物理窗口缩放、交互状态和弹窗矩阵通过；日志 `build/project-milestone-motion-final-test.log`（本地） |
| `flutter build windows --release --no-pub`，项目索引、看板和里程碑动效调整后 | 通过，51.6 秒 | `build/project-milestone-motion-windows-build.log`（本地）；生成 Windows Release 可执行文件，正式安装包尚未更新 |
| 专注中心预设布局与动效专项测试 | 通过，1 test | 1200×900 双列、320×568 且 200% 文字单列、390×844 减少动效；预设时长、选中渐变和真实七日柱补间均有断言 |
| 专注中心到时确认、真实统计更新与单卡留白专项测试 | 通过，3 tests | 320×568 且 200% 文字下待确认操作不越出卡片，跳过能清除待确认状态；新会话的七日柱 240ms 从零补间，减少动效立即完成；单张预设在桌面扩为 600dp 并居中，标题左缘与卡片对齐 |
| `flutter test --no-pub test/page_smoke_test.dart test/restriction_page_test.dart test/focus_preset_editor_validation_test.dart` | 通过，21 tests | 专注启动、弹窗编辑器、窄窗大字号和相关页面行为未回归 |
| `flutter test --no-pub --update-goldens test/ui_audit_screenshot_test.dart --name "captures all 35" -r expanded` | 通过，3 tests，约 1 分 33 秒 | 更新 35 项双主题七档尺寸矩阵；专注中心额外加入倒计时及正计时两种真实预设。独立桌面/移动截图及六张总览同步更新，目检专注中心浅色桌面、浅/深色手机与深色 800×450 |
| `flutter test --no-pub --update-goldens test/visual_golden_test.dart --plain-name "documentation focus page"` | 通过，1 test | 文档专注页单预设卡扩展、居中及标题对齐后刷新 `docs/images/guide_focus.png`，原图已目检 |
| 自律概览与跨午夜时段专项测试 | 通过，2 tests | 1200/800/390dp 指标列数及 320dp、200% 文字单列；跨午夜日程在规则更新后刷新次日文字摘要，无布局异常 |
| `flutter test --no-pub --update-goldens test/ui_audit_screenshot_test.dart --name "captures all 35\|captures the remaining UI audit surfaces\|captures the restriction editor and schedule preview" -r expanded` | 通过，5 tests，约 1 分 42 秒 | 自律页指标自适应后刷新双主题七档矩阵、独立桌面/移动视图和规则编辑器背景；六张总览随后重建。目检浅色 1200×900 与 390×568、深色 800×450 |
| `flutter test --no-pub --update-goldens test/visual_golden_test.dart --plain-name "documentation focus restriction tab"` | 通过，1 test | 文档自律页 `docs/images/guide_focus_restriction.png` 更新并目检 |
| 专注叶环图标与 13dp 统计单位截图更新 | 通过，5 audit tests + 1 文档图 test | 35 项双主题断点矩阵、独立专注桌面/手机、到时确认状态与 `docs/images/guide_focus.png` 已刷新；浅色桌面、深色手机及文档原图目检无溢出，六张总览同步重建 |
| `flutter test --no-pub -r compact`，专注与自律布局更新后 | 通过，431 tests，约 5 分 01 秒 | 全项目回归含 35 页双主题断点、持续窗口缩放、悬停/按压/键盘焦点、弹窗、窄窗大字号、到时专注确认与跨午夜周时段更新；日志 `build/focus-restriction-verified-test.log`（本地） |
| 回顾页真实完成数据与持续缩放专项测试 | 通过，3 tests | 周图只计入本周六 2 项、周日 1 项；月历按 8 月 2/8/9/10 日分别显示 1/2/1/0 项；320×568、200% 文字下切换周期，再缩放至 800×450 与 1440×900 仍保留月份。12 张浅/深色 390×844、1200×900 截图生成并完成代表原图目检 |
| `flutter test --no-pub test/page_smoke_test.dart test/review_behavior_merge_test.dart -r expanded` | 通过，11 tests | 窄窗记录页、周期控件、核心页面和行为中心回归 |
| `flutter test --no-pub -r compact`，回顾页完成日期索引与真实数据截图后 | 通过，434 tests，约 5 分 00 秒 | 全项目回归含 35 页双主题七档矩阵、持续窗口缩放、弹窗、回顾页真实完成记录；日志 `build/review-period-full-test.log`（本地） |
| `flutter analyze --no-pub`、`dart format --output=none --set-exit-if-changed lib test tool`、`git diff --check` | 通过，0 issue、130 个文件无格式变化、无空白错误 | 回顾页代码、测试和工作区静态检查 |
| `flutter build windows --release --no-pub`，回顾页日期索引与截图更新后 | 通过，52.6 秒 | `build/windows/x64/runner/Release/personal_workbench.exe` 已重建；日志 `build/review-period-windows-build.log`（本地）。正式安装包按整个目标完成后的用户指示统一更新 |
| 目标页宽度与长列表专项测试 | 通过，2 tests | 390/800dp 窗口内容按宽度扩展，1200/1440dp 限制 960dp 阅读区；320×568、200% 文字下 120 个目标的末项仍可滚动到达 |
| `flutter test --no-pub --update-goldens test/ui_audit_screenshot_test.dart --name "captures all 35 audit targets"` | 通过，3 tests，约 1 分 27 秒 | 更新 35 页双主题七档矩阵，目标页宽度变化见浅色 1200×900 与深色 800×450；六张总览拼图随后重建，日志 `build/goals-width-golden-update.log`（本地） |
| `flutter test --no-pub --update-goldens test/ui_audit_screenshot_test.dart --plain-name "captures the remaining UI audit surfaces"` | 通过，1 test | `goals_desktop.png` 及该组独立页面截图刷新 |
| `flutter test --no-pub -r compact`，目标页宽度调整与截图刷新后 | 通过，435 tests，约 5 分 03 秒 | 35 页双主题尺寸矩阵、真实完成记录、连续缩放、弹窗和目标树长列表；日志 `build/goals-width-full-test.log`（本地） |
| `flutter analyze --no-pub`、`dart format --output=none --set-exit-if-changed lib test tool`、`git diff --check` | 通过，0 issue、130 个文件无格式变化、无空白错误 | 目标页和回顾页当前代码及测试静态检查 |
| `flutter build windows --release --no-pub`，目标页宽度调整后 | 通过，52.2 秒 | `build/windows/x64/runner/Release/personal_workbench.exe` 已重建；日志 `build/goals-width-windows-build.log`（本地）。正式安装包按整个目标完成后的用户指示统一更新 |
| 成长页整月账本自适应宽度专项测试 | 通过，1 test | 1200/800/1440dp 日期格按内容宽度伸展且末日落在可用区；390dp 保持折叠与展开，320×568 且 200% 文字仍能展开整月，布局无异常 |
| 成长页整月日期、紧凑展开与 Android 截图回归 | 通过，3 tests | 28/29/30/31 日边界、窄窗折叠与展开、现有 Android 成长截图比对均通过 |
| `flutter test --no-pub --update-goldens test/ui_audit_screenshot_test.dart --name "captures all 35 audit targets|captures the remaining UI audit surfaces"` | 通过，4 tests，约 1 分 42 秒 | 更新 35 页双主题七档矩阵和独立成长桌面图；浅色 1200×900、深色 800×450/1440×900 原图目检通过，六张总览拼图已重建；日志 `build/growth-ledger-golden-update.log`（本地） |
| `flutter test --no-pub -r compact`，成长账本宽度与截图更新后 | 通过，436 tests，约 5 分 08 秒 | 全项目回归含 35 页双主题断点、模拟 Windows 缩放、持续缩放、共享浮层及月账本真实日期；日志 `build/growth-ledger-full-test.log`（本地） |
| `flutter analyze --no-pub`、`dart format --output=none --set-exit-if-changed lib test tool`、`git diff --check` | 通过，0 issue、130 个文件无格式变化、无空白错误 | 当前成长账本代码、测试及工作区静态检查 |
| `flutter build windows --release --no-pub`，成长账本宽度调整后 | 通过，52.6 秒 | `build/windows/x64/runner/Release/personal_workbench.exe` 已重建；日志 `build/growth-ledger-windows-build.log`（本地）。正式安装包将在整个目标完成后统一更新 |
| 主题过渡与系统减少动效专项测试 | 通过，1 test | 应用主题插值配置为 180ms；系统关闭动效时使用无动画主题，偏好恢复后重新启用短过渡。测试使用隔离的不可打开数据库路径，仅验证应用主题配置与监听，不宣称实际 Windows 主题切换画面已目检 |
| 设置页主题、别名、备份、回收站及云端布局定向回归 | 通过，5 tests | 设置页主题与别名等操作、320×568 且 200% 文字及软键盘下的账号表单、已登录同步状态和冲突决策未回归 |
| `flutter test --no-pub -r compact`，主题过渡与减少动效接入后 | 通过，437 tests，约 5 分 02 秒 | 全项目回归含 35 页双主题断点、连续窗口缩放、弹窗及应用主题动画配置；日志 `build/theme-motion-full-test.log`（本地） |
| `flutter analyze --no-pub`、`dart format --output=none --set-exit-if-changed lib test tool` | 通过，0 issue、130 个文件无格式变化 | 应用入口、设置和测试静态检查 |
| `flutter build windows --release --no-pub`，主题动画配置更新后 | 通过，52.5 秒 | `build/windows/x64/runner/Release/personal_workbench.exe` 已重建；日志 `build/theme-motion-windows-build.log`（本地）。真实 Windows 主题切换画面仍待目检，正式安装包将在整个目标完成后统一更新 |
| `flutter test --no-pub test/review_behavior_merge_test.dart -r expanded` | 通过，2 tests | 行为中心普通习惯/RSIP 分离及偏好保存；模式切换 180ms 中间帧、减少动效立即完成，隐藏页计时器停用；含 320×568、200% 文字场景 |
| `flutter test --no-pub -r compact`，行为模式切换与隐藏页计时器调整后 | 通过，438 tests，约 5 分 13 秒 | 全项目回归含原有 35 页双主题截图矩阵、模拟 Windows 缩放、持续缩放、浮层与行为页切换；日志 `build/behavior-mode-full-test.log`（本地） |
| `flutter analyze --no-pub`、`dart format --output=none --set-exit-if-changed lib test tool`、`git diff --check` | 通过，0 issue、130 个文件无格式变化、无空白错误 | 当前行为中心代码、测试与工作区静态检查 |
| `flutter build windows --release --no-pub`，行为模式切换更新后 | 通过，68.1 秒 | `build/windows/x64/runner/Release/personal_workbench.exe` 已重建；日志 `build/behavior-mode-windows-build.log`（本地）。正式安装包将在整个目标完成后统一更新 |
| 国策 14 日图真实结算与自适应宽度专项测试 | 通过，2 tests | 真实结算与无记录空态保持正确；1200/1440dp 图表列宽自动扩展，390dp 与 320dp、200% 文字保留标签宽度和横向滚动 |
| `flutter test --no-pub --update-goldens test/ui_audit_screenshot_test.dart --name "captures all 35 audit targets"` | 通过，3 tests，约 1 分 33 秒 | 更新 35 页双主题七档矩阵中的独立/行为国策分析图，并重建六张总览；浅色 1200×900 和深色 390×844 原图已目检。日志 `build/policies-chart-golden-update.log`（本地） |
| `flutter test --no-pub --update-goldens test/visual_golden_test.dart --plain-name "documentation policies analytics"` | 通过，1 test | 文档国策分析图空态基线已复核，原图目检无布局异常 |
| `flutter test --no-pub -r compact`，国策 14 日图响应式列宽调整后 | 通过，439 tests，约 5 分 03 秒 | 全项目回归含 35 页双主题七档矩阵、连续缩放、共享弹窗与国策图表真实结算；日志 `build/policies-chart-full-test.log`（本地） |
| `flutter analyze --no-pub`、`dart format --output=none --set-exit-if-changed lib test tool`、`git diff --check` | 通过，0 issue、130 个文件无格式变化、无空白错误 | 当前国策图表代码、测试与工作区静态检查 |
| `flutter build windows --release --no-pub`，国策 14 日图更新后 | 通过，53.1 秒 | `build/windows/x64/runner/Release/personal_workbench.exe` 已重建；日志 `build/policies-chart-windows-build.log`（本地）。正式安装包将在整个目标完成后统一更新 |
| `flutter analyze --no-pub`、`dart format --output=none --set-exit-if-changed lib test tool`、`git diff --check` | 通过，0 issue、130 个文件无格式变化、无空白错误 | 本轮 Flutter 代码与测试静态检查 |
| `flutter build windows --release --no-pub`，专注与自律布局更新后 | 通过，65.2 秒 | `build/windows/x64/runner/Release/personal_workbench.exe` 已重建；日志 `build/focus-restriction-windows-build.log`（本地）。正式安装包按目标全部完成后统一更新 |
| `git diff --check` | 通过 | 仅有工作区 CRLF→LF 提示，无空白错误 |
| `flutter test --no-pub --update-goldens test/ui_audit_screenshot_test.dart --name "captures all 35 audit targets"`，月回顾日期格调整后 | 通过，5 tests，约 2 分 01 秒 | 刷新 35 页双主题矩阵；月回顾极窄窗浅/深色原图已目检，十张总览已重建；日志 `build/final-matrix-goldens.log`（本地） |
| `flutter test --no-pub -r compact`，全页面目检与日期格调整后 | 通过，454 tests，约 5 分 37 秒 | 全项目回归含 35 页双主题断点、连续缩放、滚动区域和共享浮层；日志 `build/final-full-test.log`（本地） |
| `flutter analyze --no-pub`、`dart format --output=none --set-exit-if-changed lib test tool`、`git diff --check` | 通过，0 issue、130 个文件无格式变化、无空白错误 | 最终 Flutter 代码与工作区静态检查 |
| `flutter build windows --release --no-pub`，版本升至 0.2.2+8 后 | 通过，94.4 秒 | Windows Release 可执行文件已重建；日志 `build/final-windows-build.log`（本地） |
| `tool/build_android.ps1 -Configuration debug -AbiMode split -Online`，版本 0.2.2+8 | 通过，arm64-v8a、armeabi-v7a、x86_64 三个 APK | 首次离线构建因缺 Kotlin DSL 5.2.0 插件失败；在线重试三档均构建成功，分发副本位于 `dist/apk/`；日志 `build/final-android-split-online.log`（本地） |
| `tool/build_android.ps1 -Configuration debug -AbiMode universal -Online`，版本 0.2.2+8 | 通过，通用 APK | `dist/apk/PersonalWorkbench_0.2.2_8_debug.apk` 已生成；四个 Debug APK 用 `aapt` 核对 `versionCode=8`、`versionName=0.2.2`，用 `apksigner verify` 核对 v2 签名；分架构包各只带对应的 `libflutter.so`，其他插件仍带多 ABI 库 |
| `tool/package_windows_release.ps1 -Configuration release -SkipBuild`，版本 0.2.2+8 | 通过，Windows ZIP 与分离式 CMS 签名 | `dist/PersonalWorkbench_0.2.2+8_windows.zip` 已生成；本机自签证书的指纹及唯一未受信任根链错误经过校验，不修改受信任根库；`test/windows_release_signing.Tests.ps1` 4 项通过，篡改副本的 `HashMismatch` 被拒绝 |

响应式复核包含 35 项审计目标的 390×568、390×844、767×900、768×900、800×450、1200×900、1440×900 双主题截图，另有 320×568、700×420、1024×600、1876×979、1920×1080、2560×1440 等实际内容区布局断言，以及 320×568、390×568、800×450 等窗口的 200% 文字场景。项目详情在短窗口的大字号下出现 0.4px 底部溢出，现将标题与内容放进同一滚动页；新增测试确认滚动到底部后“回顾”区块可操作。旧项目交互测试同步改为先滚动到可见区域再点击。完整导航壳目检又发现 390×568 浮动新增按钮遮挡列表入口，以及 320×568 页头动作挤掉日期；短窗口现将新增放入页头，320 宽将记录与设置收进更多菜单。两处截图已更新，调整后的全量结果见上表。

任务群原审计夹具只有空态。本轮加入固定的并行群、父子任务和已完成成员，以真实计数生成进度轨道，并补充 390×844、1200×900 双主题展开态截图。丰富夹具使 320×568 的嵌套任务行暴露出 11px 元信息溢出；窄屏现在限制缩进、收纳次要操作，极窄元信息保留可展开入口。任务群分支折叠测试覆盖 200% 文字和减少动效。初始化错误页补充 390×568 与 1200×900 双主题截图、390×568 减少动效重试截图，以及实际数据库路径无法打开时的首次失败/再次失败测试；异常恢复步骤抛错时仍显示可操作错误页。

计划与项目并行任务群新增限定深度的当前层钻取：窄窗两层、宽窗四层缩进后显示“进入子层”，重设当前根后不创建该视图之外的深层节点。共用 `task_hierarchy_navigation.dart` 的面包屑、返回上一层和全部层级入口；窄窗、大字号或长路径显示上级菜单与完整当前名称。七层树的 320×568、200% 文字测试在两种动效模式下覆盖两个入口的钻取与返回；面包屑关闭独立滚动位置持久化，避免与任务群展开状态共用 PageStorage 键。计划新增成员的局部淡入与焦点定位测试另外覆盖 390×568、200% 文字、80 条候选及正常/减少动效；初版定位早于展开布局提交，等待最终布局帧后新成员完整可见并获得键盘焦点。候选选择列表按需构建。新增两个入口的 390×844/1200×900 双主题深层截图共八张，已目检浅色计划窄窗、深色项目窄窗与深色项目宽窗。真实 Windows 深树 Profile 仍待验收。

项目任务群跨组移动使用桌面独立拖动柄与目标卡描边/落点图标，窄窗任务菜单打开按需目标选择列表。成功后展开目标组并将移动成员滚到反馈条上方，短暂高亮，撤销恢复原组位置。关系、源组和目标组的顺序经 `AppDatabase.saveRecords` 批量事务一起保存；任务内容、项目和父子关系不修改。控制器测试覆盖源链中间成员移动、原顺序恢复、保留其他编辑/新成员、移动及撤销失败重试、过时撤销拒绝覆盖后续移动，并在实际隔离 SQLite 内核对保存字段。390×568、200% 文字在正常/减少动效下覆盖菜单、移动失败、撤销失败与重试；1440×900 覆盖拖放目标高亮及撤销。初版拖动柄的长按提示抢走手势，改为悬停提示后通过；初版长提示在大字号下挤成单列，改为窄窗提示/动作上下排及辅助文字样式，仍遵守 200% 实际缩放。320×568 截图断言成员行未被反馈条遮挡，目标名称与撤销完整可见。共享 SnackBar 动作改用主题主色，浅/深色动作与背景对比度均通过 4.5:1 断言。此轮相关回归 43 项通过，选择/结果双主题截图共八张已生成并目检；项目展开与深树基线同步更新。真实 Windows 跨组拖动手感与大数据 Profile 仍待实测。

项目任务看板现在按项目详情实际内容宽度切换单列/三列：390 与 1200 窗口的详情区显示单列状态选择，1440 宽窗口显示三列；320×568、200% 文字场景无布局异常。独立拖动柄避开卡片内部长按提示的手势竞争，测试确认拖到另一列后保存状态并可撤销。项目任务群复用层级关系和分枝图标，显示真实完成进度、父子连接线与折叠；320×568、200% 文字及减少动效测试通过。新增双主题看板与任务群展开态截图各 4 张。历史任务群的“根据成员推断”和执行关系提示已保留；相关旧回归测试通过。

项目里程碑加入真实日期轨道、已完成/待到达节点、关联任务摘要与完成撤销；选中节点在窄窗内联、宽窗侧区显示。编辑器现可选当前项目任务，保存关系并保留未保存退出保护。审计夹具增加一项已完成和一项待到达的项目里程碑，并以任务 ID 建立关联；390×844、1200×900 双主题截图共 4 张已抽查，320×568、200% 文字测试通过。项目笔记与回顾合并呈现，回顾不再误入 Markdown 笔记编辑器；390×844、1200×900 双主题截图共 4 张，320×568 和 800×450 的 200% 文字、类型筛选及点击入口测试通过。截图和 Widget 测试不替代真实 Windows 高 DPI 验证。

项目任务清单、看板列、里程碑轨道及笔记/回顾卡片改为依窗口高度决定上限的独立滚动区，列表由 `ListView.builder` 创建可见行，少量内容仍按实际高度收缩。测试为同一项目加入各 120 条任务、笔记和里程碑，确认初始不构建末尾条目、滚动后可访问；看板拖放与撤销、窄窗及宽窗截图回归通过。今日时间标尺只显示分钟，刷新改为对齐下一分钟；测试确认分钟内静止、跨分钟与跨午夜更新。此测试说明 Widget 构建范围和可达性，不是实际 Windows 大数据帧耗测量。

今日任务分区另按实际内容区高度限制滚动范围并按需构建。390×844 与 320×568（200% 文字）窄窗中加入 120 条当天任务，确认末尾条目首屏未创建、滚动后可访问且无布局异常；35 页 1200dp 双主题和 390/767/768 等断点截图比对通过。

国策文库按实际内容宽度切换三/二/一列，260dp 最小卡宽与文字缩放共同决定列数；测试覆盖 1200、767、320dp 及 200% 文字。75 条国策记录的测试确认末尾卡片按滚动创建并可访问。轮次历史使用按需列表且仅在展开轮次时生成详情；75 轮测试确认最旧轮次可经滚动访问。宽窗国策截图首版显示长说明末行被裁切，移除固有高度布局后重新生成 35 项双主题断点基线，复核 1440 浅色、767 深色及 390 浅色；此前的历史证据展开测试与截图比对保持通过。

习惯月度矩阵与目标树改为有界按需列表。习惯在 390×844 和 320×568（200% 文字）分别使用 120 项数据，目标在 320×568（200% 文字）使用 120 项数据，均确认末尾内容初始未创建、滚动后可访问。目标列表首次改造暴露 `PageStorage` 滚动位置和 `ExpansionTile` 展开状态共用键的类型冲突；给每个目标展开项独立键后通过复测。

窄窗国策标签原先随所选项自动横滑，390×568 的分析页把前一个标签截在左侧。现在依据标签栏实际宽度压缩四个标签，200% 文字时保留图标和完整提示，三项操作收进菜单；320×568 和 390×568、正常与 200% 文字下检查四个标签边界都在栏内并可切换分析页。短窗专注页改为正常字号下将计时环与操作横排，大字号下先显示操作再显示环；320×568、390×568、800×450 的正常与 200% 文字测试确认开始和结束按钮都位于首屏且无布局异常。390×568 浅色、800×450 深色专注截图及 390×568 浅色、390×844 深色国策截图已目检。

成长页在窄内容区把整月活动格移入可展开面板，首屏保留连续天数、日结次数和最近证据；展开后说明横向滑动，并仅在展开时构建月度格。390×568 的交互测试确认初始无日期格，展开后可见；活动状态在一次图表构建中分别汇总计划日和分类 XP，避免每格遍历全部记录。390×568、390×844 与 767/768dp 的浅/深色代表截图已目检。收集箱任务层级为记录和可见行建立索引，消除逐项线性查找；页面及交互回归测试通过。两处优化尚未作真实 Windows 大数据 Profile 测量。

收件箱补上置顶任务输入槽。320×568、200% 文字与 200dp 软键盘的测试模拟首次数据库保存失败，确认输入、错误提示和焦点保留；再次提交后任务进入真实控制器收件箱，输入清空。`page_smoke_test.dart` 与 `ui_coverage_regression_test.dart` 的 30 项测试通过；35 页双主题矩阵及桌面独立页截图已更新，目检 390×568、800×450、1440×900 代表画面。任务行仍沿用按需列表，长期真实数据耗时待 Profile 测量。

收件箱本轮增加新记录的局部 180ms 淡入，以及非任务记录“整理完成”后的 160ms 收束与撤销。短暂展示副本不接收指针或语义焦点，业务计数立即使用保存结果；减少动效时直接更新。320×568、200% 文字分别核对保存失败保持原行、重试成功、收束中间帧、撤销重新进入和正文保留。与项目跨组移动共用的反馈现在按实时内容宽度和文字缩放重排，修复宽窗显示后缩至窄窗/大字号导致提示高达 293dp 的问题；双主题缩放往返测试确认反馈小于 200dp、撤销按钮可点击且正确关闭反馈。

连续缩放夹具改用生产侧栏宽度令牌，并用稳定全局键保持页面子树，断言缩放前后为同一 Element。35 页、双主题、100%/200% 文字依次跨过 1440×900、767×900、800×450、320×568、768×568、1200×500、1920×1080，共 980 次尺寸检查；六类浮层 42 个初始场景再进行 168 次打开后的尺寸变化，保持 Tab 焦点及 Escape 关闭。两项定向测试通过，无 Flutter 布局异常。报告见 `WINDOW_LAYOUT_AUDIT.md`；仍不替代真实 Windows 系统缩放与全数据组合验收。

计划页筛选后只让当前可见结果在 120ms 内淡入，批量工具栏用 180ms 呈现；减少动效模式直接显示筛选内容，避免零时长 `AnimatedSize` 布局断言。周视图宽窗拖拽现在有五分钟吸附落点预览，提交后提供撤销；移动与撤销均同步关联任务日期。周切换以 180ms 淡入，减少动效时即时切换。定向交互和控制器回归共 30 项通过；35 页双主题断点截图比对 3 项通过。真实 Windows 拖拽手感与高 DPI 仍待实测。

周视图截图复核发现固定测试日期为周日时，五个工作日标签停在周一至周五，移动端内容却显示周日；前后切周也没有更新所选日期。现在周末默认选中本周周五，切周保留星期，返回本周重新定位。定向测试覆盖周一、周二跨周及周日进入；35 项 390×568、800×450、1200×900 的浅色总览图已随基线重建并目检，周视图 390×568 与 1440×900 原图也已检查。周末时间块仍保留在记录中，工作周页面不显示周末日列。

按 `better-layout` 的分组、对齐、主操作及内容增长检查项，逐张目检浅色与深色 390×568、800×450、1200×900 六张 35 页总览图；每张总览包含 35 个审计目标。结合 14 种内容视口、200% 文字、导航壳缩放往返和滚动位置的 Widget 断言，未发现仍会阻断主要内容或操作的布局异常。总览缩图不足以验证每项小字和真实 Windows 系统 DPI，详见下方尚待验收。
再补 320×568、200% 文字的 35 页双主题原图矩阵与两张总览。逐组查看总览后，周视图五日日期栏是最明显的拥挤处：双字星期改为按内容宽度切换单字，完整星期保留在语义标签。浅色周视图原图已复核，五个日期格与选中态分明；测试同时断言单字文字和完整语义。极窄窗的项目详情需要滚动到首屏以下，已有页面中段/底部滚动测试覆盖可达性，但并未逐张人工验收新增 70 张原图。全量 440 项测试、静态检查及 Windows Release 构建通过。
又补 800×450、200% 文字的 35 页双主题原图矩阵和两张总览。今日页原图暴露 24 个小时数字被缩小并首尾相接；现在根据每小时格宽及文字倍率显示间隔数字，隐藏的数字仍以完整时间写入语义，24 个小时刻度保持。已目检浅色短横向修复前后、浅色 1200×900 导航壳和 1536×864 今日页原图，深色短横向总览也已复核；原有时间按分钟更新、午夜归零和密集横窗测试通过。五张受影响的导航壳基线已更新，差异图只涉及标尺数字位置。

兼容协议的“目标”和“习惯”审计入口原先分别落到执行协议或 RSIP 内容。显式旧入口现在复用正式目标/习惯页及同一控制器记录，普通协议标签仍保留原有 RSIP 配置；测试验证高级功能开关变化和返回普通协议页后的标签、内容。习惯记录带在实际内容宽度低于 640dp 时默认构建最近 14 天，可展开整月；跨月日期使用完整年月日组件键。320dp 与 390dp 交互、320dp 200% 文字、28/29/30/31 天月历均有回归测试，390×844 双主题整月展开截图另行记录。

执行协议新增按 CTDP 任务 ID 关联的最近六轮专注记录时间线，空态提示从执行协议启动。320×568、200% 文字下发现任务卡标题、徽章与菜单同排溢出 99px；现于窄窗及大字号将徽章换行。关联/无关会话筛选和时长显示已通过定向测试。35 页在 320×568、200% 文字及 1200×900 下滚动到中段和底部均无 Flutter 布局异常；另外补测了 800×450、200% 文字的实际内容区。390×568 与 1200×900 浅色总览拼图已整体目检，关联时间线的 390×844、1200×900 双主题专项截图中抽查浅色窄窗和深色宽窗。Widget 截图与布局断言不代表已完成 Windows 125%—200% 系统缩放实测。

兼容协议的“判例”页现在按暂停、提前完成与允许中断分类，卡片标示具体 CTDP 作用任务、生效/归档状态和使用次数，并可展开长条件。新建与编辑弹窗在保存成功后关闭；模拟数据库写入失败时保留输入并可重试，取消或 Escape 已修改内容时提供继续编辑/放弃选择。归档失败显示可重试提示且保留原状态。320×568、200% 文字测试发现作用范围下拉框溢出 122px，现改为可扩展的下拉布局并通过复测。含生效和归档判例的 35 页截图矩阵已更新；浅色 1200×900、深色 390×844 规则页，以及浅色 390×844、深色 1200×900 编辑弹窗已目检。

本轮补查全部 35 个页面目标在 320×568、390×568、767×900、768×864、800×450、1200×500、1440×900 等 14 种内容视口的双主题布局，并在 320×568 与 800×450 增加 200% 文字检查。800×450、200% 文字暴露“全部任务”顶部概览和筛选挤出任务列表的问题；现在顶部区随实际可用高度限制并独立滚动，短横向窗口折叠筛选入口始终可操作。另在带导航占位的窗口中保持页面挂载，连续从 1440×900 缩到 320×568 再放大到 1920×1080，35 页均无 Flutter 布局异常。800×450 的 35 页浅色拼图与任务页原图已目检；内容稀疏页自然保留空白，不强行拉高卡片。该检查不能证明所有滚动位置、长文本和真实 DPI 情形都无视觉问题。

兼容协议分析页改为以 CTDP 实际完成/失败和 RSIP 节点执行/违反计算成功率，预约、创建及跳过记录显示信息态。无结算样本和真实 0% 分别显示；7/30 日切换、5 日分桶、图例和结算柱形来自同一次记录遍历。视觉检查发现原柱形在数据存在时被压为零宽，现为色块指定横向约束，并在测试中断言实际着色区域宽高。浅色 1200×900 与深色 390×844 截图已目检，35 页双主题断点基线已更新。

笔记页现在只把可编辑笔记放进知识索引，日/周/月回顾和只读导入归档仍保留在各自的正式入口；这避免 Markdown 编辑器把回顾的记录类型覆盖。阅读区按标题 20、正文 16/1.65、引用与代码 14 排版，引用有暖陶底色；关联项目数量和标签覆盖旧 `projectId` 与关系选择器的 `relatedProjectIds`。320×568、200% 文字下钻取、返回与缩放往返测试通过。390×844、1200×900 双主题阅读截图共 4 张，已目检浅色窄窗及深色宽窗；附件缩略图改为按 48dp 显示尺寸解码。此项尚未对大量附件的实际滚动耗时或内存占用做 Profile 测量。

执行协议入口在 Android 320×568、200% 文字下可横滑类型页签并打开末项“分析”；宽窗内容扩展至 960dp 后居中。CTDP 根记录按任务组/执行链分区，RSIP 根记录按现有国策组分区；父记录缺失时仍显示孤立记录。卡片内边距统一为 16dp，标题/说明/标签分别为 16/14/13。重新生成 35 页双主题断点矩阵，另增加分组协议 390×844 与 1200×900 双主题截图 8 张，已目检浅色窄窗与深色宽窗。以固定 1600×900 物理窗口模拟 100%、125%、150%、200% 像素密度，35 个审计目标在双主题、包含导航占位的布局中无 Flutter 异常；此为 Widget 模拟，真实 Windows 系统缩放仍未实测。

执行协议的 CTDP/RSIP 卡现以三段细线和文字显示当前阶段。CTDP 预约、任务组开始及完成成员数读取现有字段；RSIP 使用冻结、计时和逻辑日习惯记录。预约是可选步骤，所以仅突出当前段，不把经过的段默认标为完成。空任务组不会算作本轮完成，昨天的打卡不会成为今日结算。阶段带在 320×568、200% 文字下显示完整当前名称，宽窗显示三段名称；屏幕阅读器能读取阶段序列及当前值。协议页签与 CTDP 卡改用 24dp 代码矢量册页/书签标记。编辑继续走统一 180ms 淡入弹窗，减少动效时直接显示；相关交互和截图结果见上表。RSIP 按日记录与父子索引在页面内一次汇总，真实 Windows 大量节点 Profile 尚待测量。

关系选择浮层使用任务、项目、目标、笔记四类分段，每次只创建当前类型的可见结果；180ms 搜索防抖、每批 40 条及已选胶囊保持。选中行 120ms 背景反馈尊重减少动效，独立 Material 层保证点击反馈可见；类型标签去掉与图标叠加的默认勾选，重复结果标题移除。少量记录时按内容收缩，极窄窗保留独立滚动结果区。320×568、200% 文字测试覆盖第 99 条任务和四类共同选择；取消不提交及焦点恢复测试通过。笔记保存/重开和未保存退出、390dp 回顾保存测试确认目标/笔记关系通过原数据库路径持久化；当前笔记、期间回顾和只读归档不作为可选笔记。笔记阅读与回顾预览补上新类型关联名称。相关优化/控制器回归共 67 项通过；320×568、390×844、1200×900 双主题的任务/笔记类型截图共 12 张已更新，浅色极窄窗及深色桌面原图已目检。真实 Windows 高 DPI 与大量关系 Profile 尚待实测。

笔记阅读专项夹具加入任务、项目、目标和笔记四类关系，390×844、1200×900 双主题四张截图重新生成，并断言真实目标名称可见；已目检浅色窄窗与深色桌面原图，名称随宽度换行，正文与附件区没有被关系胶囊遮挡。

Markdown 编辑弹窗与笔记阅读共用正文、引用和代码样式。390×844 窄窗按编辑/预览切换，1200×900 宽窗同时显示两栏；正文预览在输入后 180ms 防抖更新，切换时立即同步。交互测试确认缩放往返与预览切换后光标位置保留，短窗和大字号下仍可输入、保存；空标题在标题下提示并聚焦。双主题共 8 张截图已生成并抽查，完整测试同时完成截图比对。已有笔记的附件在预览区按需加载；大量附件滚动性能尚未 Profile 验证。

全局搜索浮层在宽窗保持 720dp 居中，窄窗改为 8dp 外边距；分类标签可以横向滚动，结果按类型分组并懒构建。320×568、200% 文字测试发现固定 56dp 结果行溢出 1px，现将行高随文字缩放；长列表键盘导航测试确认选中项始终留在可见区域。搜索 200ms 防抖，过时定时器取消，结果 120ms 更新动画尊重减少动效。截图检查又发现任务定义与任务实例重复显示，现从结果中过滤内部定义。双主题共 6 张结果截图已生成并抽查。

最近搜索新增当前会话内最多五条查询，打开结果时记录，重开弹窗可复用或清除；登录、注册与退出成功后清空，避免跨账号残留。空态及少量历史记录按内容收缩，结果较多时扩至 680dp 上限。320×568、200% 文字与 200dp 软键盘测试确认清除动作可见、查询复用和清除有效；账号退出清空另有控制器测试。最近查询的 320×568、390×844、1200×900 双主题截图六张已生成，浅色极窄窗及深色桌面原图已目检；桌面面板高度另有小于 450dp 的断言。真实 Windows 高 DPI 与大数据性能仍待实测。

快速新增项目选择器原来一次构建所有项目行；现按需构建前 40 条，滚动接近末尾再加载下一批，搜索输入 180ms 防抖。320×568、200% 文字及模拟 200dp 软键盘测试确认第 75 个项目可经滚动和搜索选中，固定提交按钮保持可见；空标题就地提示并聚焦输入。捕获层与项目选择器在 320×568、390×844、1200×900 双主题共 12 张截图及 1 张浅色校验截图已生成并抽查。该 Widget 测试不等同于大量真实项目的内存/耗时 Profile。

相关 Widget 测试记录中，1000 条任务列表的构建加滚动约 2.89 秒；这不是 Windows Release 帧耗或真实用户数据性能指标。

## Windows 运行检查

- 使用 `WORKBENCH_DATABASE_PATH` 指向独立临时 SQLite 数据库构建并启动 Release 程序，不读取用户现有工作台数据库；检查后已关闭该进程。
- 目标机窗口 1272×712 物理像素，`GetDpiForWindow` 返回 96（100%）。今日空态截图见 `screenshots/windows_release_empty_today_light.png`；人工确认导航、双栏、时间轴、空态与窗口控件可见且无溢出。
- 当次空态进程工作集约 199.6 MiB、私有内存约 164.2 MiB。此为整个进程指标，不能推导装饰图片解码内存；未测到首帧或 99 分位帧耗。
- 2026-10-12 在同一 Windows 11 专业版 26200、1920×1080 显示器、Flutter 3.47.5/Impeller OpenGLESSDF 下，用独立空 SQLite 运行 Profile。单次启动首帧 1681ms；随后在已启动进程上五次改变外窗，实际内容区依次为 1184×861、374×805、304×529、784×411、1424×861 物理像素。42 个 UI 帧中位数 2.609ms、p95 5.734ms；42 个栅格帧中位数 4.781ms、p95 15.918ms。进程 RSS 约 314–332 MiB。测量脚本 `tool/profile_window_probe.dart` 和原始报告 `WINDOWS_PROFILE_2026-10-12.json` 保留；原始时间线位于本地 `build/`。Profile 进程检查后已关闭。
- 同日另以独立临时数据库构造 600 个任务实例、600 个定义、12 个项目和一份今日计划，今天有 120 个任务。最初 24 个窗口变换 UI 帧 p95 72.725ms、11 帧超 16.67ms；时间线显示主要耗在构建和布局。今日长列表改用有界可见区，控制器在同一构建帧复用任务、定义、项目、关系和每日计划索引后，32 个 UI 帧 p95 48.146ms、最大 48.972ms、15 帧超限。进一步将按日筛选改为只匹配请求日期的绝对时间区间，避免每帧给所有任务构造日期键并排序所有日期；同一数据库重复两次五档窗口缩放，各 42 个 UI 帧，p95 为 5.040/6.363ms，最大为 9.490/8.197ms，均无 UI 超限；栅格各有 4 帧超限。前后帧数及运行状态不同，不计算严格改善百分比。三份报告均保留在本目录，原始时间线保存在本地 `build/`。任务卡按需构建、窄窗滚动和逻辑日边界另有 Widget 回归测试。
- 此次执行会话的系统截图脚本在 `CopyFromScreen` 返回“句柄无效”，因而上述五档 Profile 窗口未作画面目检；可用的 Windows Release 100% 截图仍是上文独立运行的证据。帧耗只覆盖已启动状态下的今日页及窗口变化，不代表各页面、连续操作或 p99；RSS 也不能推出图片解码内存。
- 今日首屏及成长、笔记、回顾、收件箱的装饰图均由代码绘制；旧 WebP 已从 Windows Release 资源包移除。导航图标和叶影亦使用 CustomPainter。整应用其他图像的首屏解码内存、GPU 图层与 20 MiB 目标仍需 Profile 实测确认。
- 2026-10-14 在 1920×1080 的同一 Windows 主机上实际切换系统显示缩放，逐次重新启动隔离数据库的 Release 进程；`GetDpiForWindow` 分别返回 120（125%）、144（150%）、168（175%）。已目检 125% 的任务群短窗、150% 的今日短窗和 175% 的今日最大化窗口，截图见 `screenshots/windows_release_125pct_tasks_groups.png`、`screenshots/windows_release_150pct_today_short.png`、`screenshots/windows_release_175pct_today_max.png`。三张画面的可见区域未见控件重叠或横向溢出；长页仍需纵向滚动。该显示器的标准缩放列表最高为 175%，200% 需要自定义缩放及注销，故未在本会话执行。检查后已恢复原有 100%，新启动窗口的 DPI 再次确认为 96。
- 同日把 35 个审计页面的 320×568/200% 文字、800×450/200% 文字、1200×900 原图按页面拼成浅/深色对照，逐页查看首屏内容、按钮边界、折行和留白。未见明显重叠或横向溢出；月回顾的窄窗双位日期间距过近，日期数字现按单元格可用宽度缩放并留 3dp 内边距。此检查只覆盖六个代表场景的可见首屏，不能代替其余尺寸和滚动区域的逐图检查。

## 尚待验收

- 49 项规范中的 35 个审计目标已生成双主题断点截图，并对每页六个代表场景的首屏做了人工对照；630 张截图尚未逐张核对全部滚动区域，六维规范也未逐项验收完成。现有基线和无溢出断言不能证明所有内容状态的视觉细节。
- Windows 125%、150%、175% 系统缩放已有 Release 空数据库首屏实测；200% 在当前显示器需自定义缩放和注销，尚未实测。今日以外各页面大量数据时的 Profile/Release 帧耗、图片解码与模糊层预算也未实测。96 DPI 的 600 任务今日页复测中 UI 帧未超预算，但栅格各有 4 帧超预算；Widget 测试的 200% 文字场景不能替代 200% 系统缩放。
- 登录、远端同步、离线和冲突状态尚未用真实服务流程验证；现有本地模拟测试不计作远端验收。
- 初始化错误页已用不可打开的本地数据库路径验证失败与重试反馈，但尚未用真实受损数据库及迁移备份恢复流程端到端验证。
- 各页图标、功能图形、动效和空态仍需按 `REQUIREMENT_MATRIX.md` 的六维要求补齐；目前标为“部分实现”的页面不算完成。
