# 项目全量审查与文件说明

> 审查日期：2026-09-20（Asia/Shanghai）
> 代码版本：`pubspec.yaml` 中的 `0.2.1+6`
> 口径：当前 Git 跟踪文件为 376 个；以工作区文件、`git ls-files`、Dart/Flutter 引用和构建配置为准。`build/`、`dist/`、`.dart_tool/` 等生成目录单独说明，不视为源码。

## 1）项目功能概述

个人工作台是一个 Windows + Android 的本地优先 Flutter 应用，面向科研学习和个人项目执行。它把收集、任务/项目规划、今日安排、专注执行、笔记与附件、日/周/月回顾、目标/习惯成长，以及 SelfControl 风格的 Windows 自律限制放在同一套记录模型中。

运行链路为：`lib/main.dart` 启动 → `lib/app.dart` 初始化数据库、迁移、通知、分享和同步 → `lib/ui/workbench_shell.dart` 提供桌面/移动导航 → 各页面和通用弹层操作 `WorkbenchController` → SQLite、备份、附件、通知、Windows 原生桥和可选 Supabase。

主要能力：

- 任务：收件箱、全部任务、任务群、周期任务、04:00 逻辑日、周时间块和冲突提示。
- 项目：项目概览、任务、任务群、里程碑、笔记和回顾，支持软删除与恢复。
- 执行：正计时、25/50 分钟、自定义倒计时、预设、通知、完成证据和 XP。
- 记录：Markdown 笔记、图片/链接附件、版本、任务/项目关联，日/周/月回顾和快照。
- 成长与行为：目标树、习惯矩阵、CTDP 任务协议、RSIP 国策节点/轮次/违反预览和成长账本。
- 自律：Windows 进程/窗口/网站限制、黑白名单、hosts、托盘、启动项、密码和应急恢复；Android 只查看/编辑/同步规则。
- 数据：SQLite 本地持久化、JSON/CSV/Markdown/TXT 导入、JSON 导出、PBKDF2 + AES-256-GCM 加密备份、回收站和可选 Supabase 同步。
- 移动端：Material 3 底部导航、更多入口、Android 分享文本/链接捕获；Windows 提供托盘、通知和系统级快速新增。

## 2）各文件作用说明

### 根目录配置与说明

| 文件 | 作用 |
| --- | --- |
| `pubspec.yaml` / `pubspec.lock` | Flutter 包元数据、版本 `0.2.1+6`、依赖、字体和锁定版本。 |
| `analysis_options.yaml` | Dart/Flutter 静态分析规则。 |
| `.gitignore` / `.gitattributes` / `.metadata` | Git 忽略、文本换行/二进制属性和 Flutter 工程元数据。 |
| `README.md` | 面向开发者的安装、构建、功能、同步、备份和测试入口。 |
| `PROJECT_REVIEW.md` | 本次全量审查、文件职责、冗余判定和文档更新入口。 |
| `FILE_INVENTORY_AUDIT.md` | 历史文件清理审计与决策记录；保留历史时间线，不替代本文件当前口径。 |
| `docs/PROJECT_MAINTENANCE.md` | 迁移、构建产物、发布链和外部验收条件。 |
| `overview.md` | UI/产品演化记录。 |
| `PRODUCT.md` | 产品定位、用户、边界和原则。 |
| `MASTER.md` / `DESIGN.md` / `ORGANIC_UI_SPEC.md` | 当前视觉令牌、组件、响应式与“柔壤·年轮”设计规范。 |
| `APP_ICON_SPEC.md` | 图标单一真源、各平台产物和重生成规则。 |
| `AUDIT_PLAN_CODEX.md` / `UI_AUDIT_CODEX_OPTIMIZATION.md` / `UI_OPTIMIZATION_ANDROID_CODEX.md` | 历史审查、UI 优化方案和验收记录。 |

### `lib/` 应用源码

#### 入口、主题与模型

| 文件 | 作用 |
| --- | --- |
| `lib/main.dart` | Flutter 进程入口，初始化并运行 `PersonalWorkbenchApp`。 |
| `lib/app.dart` | 应用初始化状态、主题切换、控制器/服务组装、初始化失败重试和全局滚动行为。 |
| `lib/core/theme/app_theme.dart` | 浅色/深色主题、颜色/间距/圆角/字体令牌及主题扩展。 |
| `lib/core/utils/formatters.dart` | 日期、时间、日期时间和时长格式化。 |
| `lib/core/models/workspace_record.dart` | 统一记录、任务定义/实例、回顾周期、软删除、同步状态、JSON 序列化和备份清单。 |
| `lib/core/models/workspace_models_v3.dart` | Review/RSIP v3 模型、周期快照、节点、轮次、任务联动和洞察。 |
| `lib/core/models/restriction_models.dart` | 自律规则、时段、动作、违反、运行快照和 hosts 状态模型。 |
| `lib/core/models/attachment.dart` | 附件元数据、类型和数据库序列化。 |
| `lib/core/models/game_state.dart` | 本地成长/签到/押注/XP 状态模型。 |

#### 数据层

| 文件 | 作用 |
| --- | --- |
| `lib/data/app_database.dart` | SQLite 建库、版本升级、记录/附件/metadata CRUD、软删除和事务替换。 |
| `lib/data/backup_service.dart` | 加密备份、解密校验、大小/嵌套/附件安全限制和 JSON 导出。 |
| `lib/data/workspace_migration.dart` | 旧记录到 v2/v3 领域模型的迁移和迁移报告。 |

#### 服务层

| 文件 | 作用 |
| --- | --- |
| `attachment_service.dart` | 导入、复制、哈希、打开、删除和备份恢复附件。 |
| `focus_service.dart` | 正计时、番茄钟、自定义倒计时、暂停/完成和 ticker。 |
| `game_service.dart` | 签到、押注、结算、退款和每日限制规则。 |
| `growth_service.dart` | XP 证据、连续记录、等级、矩阵和成长摘要。 |
| `notification_service.dart` | Android 本地通知、权限、定时通知和 Windows 通知转发。 |
| `restriction_defaults.dart` | 自律默认规则和默认配置。 |
| `restriction_monitor.dart` | Windows 前台进程轮询、违反检测、强制动作、休息和状态恢复。 |
| `restriction_policy_engine.dart` | 规则匹配、跨午夜时段、黑白名单和执行决策。 |
| `restriction_security_service.dart` | PBKDF2 密码、应急码、运行快照和安全配置。 |
| `search_service.dart` | 记录内存索引、全文搜索、类型过滤和排序。 |
| `self_control_importer.dart` | 脱敏 SelfControl 规则导入和旧数据迁移兼容。 |
| `share_capture_service.dart` | Android 分享文本/URL 接收与回调。 |
| `supabase_sync_service.dart` | 可选 Supabase 登录态、分页同步、冲突副本和远端适配。 |
| `windows_activity_service.dart` | Windows MethodChannel：进程、窗口、hosts、托盘、启动项、通知和文件保护。 |

#### 状态与控制器

| 文件 | 作用 |
| --- | --- |
| `lib/state/workbench_controller_base.dart` | 控制器公共契约，供主控制器和 mixin 访问共享状态/操作。 |
| `lib/state/workbench_controller.dart` | 核心 ChangeNotifier：记录、任务、项目、回顾、导入导出、同步、专注、通知等业务编排；组合两个领域 mixin。 |
| `lib/state/restriction_controller.dart` | `RestrictionControllerMixin`，承载自律规则编辑、监控生命周期和安全动作。 |
| `lib/state/rsip_controller.dart` | `RsipControllerMixin`，承载 RSIP 节点、轮次、违反和任务联动。 |

#### 页面与壳层

`lib/ui/workbench_shell.dart` 是桌面侧栏、移动底栏/更多 Sheet、兼容别名归一化、页面栈、全局搜索/快速新增和快捷键入口。页面文件分别为：`today_page.dart`（今日承诺、时间线和日结）、`plan_page.dart`（任务总览）、`inbox_page.dart`（收件箱）、`calendar_page.dart`（周视图）、`projects_page.dart`（项目五个子面板）、`focus_page.dart`（专注）、`restriction_page.dart`（自律）、`notes_page.dart`（笔记）、`review_page.dart`（日/周/月回顾）、`goals_page.dart`（目标）、`behavior_page.dart`（行为分流）、`habits_page.dart`（习惯）、`policies_page.dart`（RSIP 国策）、`protocols_page.dart`（CTDP/协议兼容页）、`growth_page.dart`（成长）、`settings_page.dart`（设置与数据管理）。`platform_feedback.dart` 提供平台反馈/触感适配。

#### 通用控件

`attachment_panel.dart`（附件面板）、`batch_task_toolbar.dart`（批量任务）、`celebration.dart`（完成动效）、`common.dart`（通用表面/标题/状态控件）、`global_search_dialog.dart`（全局搜索）、`ink_decoration.dart`（品牌装饰）、`markdown_editor_dialog.dart`（Markdown 编辑器）、`mobile_bottom_bar.dart`（移动五项底栏）、`quick_capture_sheet.dart`（快速新增）、`record_editor_dialog.dart`（统一记录编辑器）、`relation_picker_dialog.dart`（关联选择）、`solid_panel.dart`（基础实色面板）、`task_group_editor_dialog.dart`（任务群编辑）、`task_hierarchy.dart`（任务树）、`task_row.dart`（任务行）。

### 平台、工具、测试与资产

- `android/`：Android Gradle 配置、Manifest、MainActivity、通知/分享声明、启动画面和多密度/自适应图标。
- `windows/`：Flutter Windows runner、CMake、托盘/通知/窗口桥、hosts 原生实现和应用图标。
- `packaging/windows/`：安装、卸载和 hosts 紧急恢复脚本。
- `supabase/migrations/001_workspace_records.sql`：云端记录表和 RLS 迁移。
- `assets/branding/`：浅/深色品牌 SVG/PNG；`assets/fonts/`：离线中文、正文和等宽字体及许可证。
- `tool/`：Windows/Android 构建打包、图标生成、字体子集化、用户手册生成、配色/令牌/字形/产物校验和符号链接辅助脚本；`tool/lib/Remove-Verified.ps1` 是状态校验式删除库。
- `design_preview/`：设计系统 HTML/CSS/JS、页面预览、图标预览和配色方案对照；属于可重复生成的设计证据，不是运行时 UI。
- `test/*.dart`：数据库、备份、迁移、服务、控制器、页面、可访问性、回归和 UI 流程测试；`test/goldens/*.png` 是 Golden 基线。
- `docs/`：用户指南、手册、QA 矩阵/截图/UI 审计、Stitch 交接和维护文档；`.docx` 是面向用户的发行文档，`.xml` 是 Android UIAutomator 证据。

平台目录中的文件职责可进一步按文件名核对：`android/app/build.gradle.kts` 是 Android 应用构建/签名配置，`android/build.gradle.kts`、`settings.gradle.kts`、`gradle.properties` 和 `gradle/wrapper/gradle-wrapper.properties` 是 Gradle 工程配置，`android/key.properties.example` 是签名模板；三个 `AndroidManifest.xml` 分别对应 debug/main/profile；`MainActivity.kt` 是 Android embedding 入口；`res/drawable*` 是启动画面、通知图标和自适应图标层，`res/mipmap-*` 是各密度启动图标，`res/values*` 是主题样式。Windows 的 `CMakeLists.txt`/`flutter/CMakeLists.txt` 管理工程，`runner/main.cpp`、`flutter_window.*`、`win32_window.*`、`utils.*` 是窗口启动/消息循环，`restriction_hosts.*` 是 hosts 受管桥，`generated_plugin_registrant.*`/`generated_plugins.cmake` 是插件注册，`Runner.rc`、`resource.h`、`resources/app_icon.ico` 和 `runner.exe.manifest` 是资源与清单。

工具脚本逐文件职责：`build_windows.ps1`/`build_android.ps1` 构建两端；`package_windows_release.ps1`/`package_windows_test_entry.ps1` 打包；`create_desktop_test_entry.ps1`/`run_windows_test.ps1` 创建和运行隔离桌面测试入口；`update_all_shortcuts.ps1` 更新快捷方式；`generate_app_icons.ps1` 是待确认的旧图标生成器，现行实现为 `build_app_icon.py`；`build_scheme_c_compare.py` 生成配色对照；`generate_user_guide_docx.py`/`generate_user_manual.py` 生成两套用户文档；`subset_fonts.py` 子集化字体；`prelink_plugin_symlinks.dart` 和 `fix-symlink-privilege.ps1` 处理 Windows 插件链接；`verify_colors.py`、`verify_token_parity.py`、`verify_glyph_coverage.py`、`verify_apk.py`、`verify_windows_build.py` 执行颜色/令牌/字形/产物门禁；`tool/lib/Remove-Verified.ps1` 提供状态校验式删除；`generate_app_icons.ps1` 外的脚本均在构建、文档生成或门禁说明中有明确用途。

测试文件按职责对应：`app_database_test.dart`、`workspace_migration_test.dart` 覆盖数据库/迁移；`backup_service_test.dart`、`attachment_backup_test.dart`、`attachment_service_test.dart` 覆盖备份和附件；`workbench_controller_test.dart`、`batch_operations_test.dart`、`recurrence_test.dart`、`full_function_regression_test.dart`、`reliability_regression_test.dart` 覆盖核心业务；`focus_service_test.dart`、`game_service_test.dart`、`growth_service_test.dart`、`search_service_test.dart`、`supabase_sync_service_test.dart`、`self_control_importer_test.dart` 覆盖服务；`restriction_*_test.dart` 覆盖自律规则/监控/安全/页面；`protocol_test.dart`、`protocol_ui_flow_test.dart`、`policies_page_test.dart` 覆盖 CTDP/RSIP；`page_smoke_test.dart`、`widget_test.dart`、`game_ui_test.dart`、`solid_panel_test.dart`、`task_completion_pulse_test.dart`、`review_behavior_merge_test.dart` 覆盖页面和组件；`theme_accessibility_test.dart`、`typography_test.dart`、`optimization_regression_test.dart` 覆盖主题/可访问性/优化回归；`ui_audit_screenshot_test.dart`、`ui_coverage_regression_test.dart`、`visual_golden_test.dart` 是截图、覆盖矩阵和 Golden 入口。`test/goldens/` 下的 PNG 是这些测试的基准，不是运行时资源。

## 3）冗余文件清单及处理建议

### 已确认的本地冗余/生成物

| 项目 | 判定 | 建议 |
| --- | --- | --- |
| 根目录 `_d1.log`–`_d7.log` | 未跟踪、被 `*.log` 忽略的调试日志，不被代码引用。 | 可直接删除；如需保留诊断，移出仓库后按日期归档。 |
| `tool/generate_app_icons.ps1` | 未被 README、维护文档或构建流程调用；其实现是旧版单图标生成器，和现行 `tool/build_app_icon.py` 的多平台单一真源重复。 | **建议确认后删除**；删除前先确认不再需要旧版图标回退，保留 `build_app_icon.py`、`APP_ICON_SPEC.md` 和当前生成产物。 |
| `.dart_tool/`、`build/`、`dist/`、`.workbuddy/`、`tool/__pycache__/` | 工具缓存、构建产物、分发包或本机工作区状态；均已被 `.gitignore` 忽略。 | 不纳入版本控制；磁盘紧张时可清理，后续命令会重建。当前 `build/`/`dist/` 约 530 MB。 |
| `test/failures/`（若测试失败时出现） | Flutter 测试失败截图，不是测试基线；已被忽略。 | 全绿测试后清理；失败时只保留用于定位的那一轮。 |

### 不应误删的“看似冗余”文件

- `docs/qa/*_uiautomator.xml`、`docs/qa/screenshots/`、`test/goldens/`：自动化和真机/桌面验收证据，虽然不被运行时代码 import，但用于审计和回归。
- `design_preview/**`、`APP_ICON_SPEC.md`、`ORGANIC_UI_SPEC.md`：设计产物和生成规则；图片可重生成，但需与生成脚本、规范成套保留。
- `self_control_importer.dart`、`protocols_page.dart`、`WorkbenchSection` 中的旧枚举值：迁移/兼容面，不能按“普通导航未出现”删除。
- `android/app/src/main/res/**`、`windows/runner/**`：平台运行和打包必需文件。
- `docs/*.docx`：用户手册/新手指南发行资产，不能按“源码未引用”判为死文件。
- `design_preview/glass_today.*`、旧版 UI 审计/交接文档：属于设计演化证据；若要瘦身，应按“历史归档”整体迁移，而不是孤立删除单张图片。

### 当前未发现

当前跟踪文件中未发现 `*.bak`、`*.tmp`、`*~`、`*副本*`、私钥/数据库备份或未引用的生产 Dart 文件。完全重复的 PNG/XML 主要是平台资源与 Golden/预览之间的有意副本，不建议单独删除。

## 4）需要更新的说明文件及更新要点

本轮已更新或应以本轮同步的文件：

| 文件 | 更新要点 |
| --- | --- |
| `PROJECT_REVIEW.md` | 新增当前四部分审查结论和逐文件职责索引，作为本次审查入口。 |
| `README.md` | 项目结构补充 `mobile_bottom_bar.dart`、RSIP/CTDP 分层和当前入口；测试数字改为“以当前命令为准”，避免沿用 241/242 历史数字。 |
| `docs/qa/PROJECT_MAP.md` | 删除已不存在的 `DiaryPage`/`MorePage` 独立页面表述；明确 `ReviewPage` 合并日记、`_MobileNavigationSheet` 为移动更多入口；控制器改为 Base + 两个 mixin。 |
| `FILE_INVENTORY_AUDIT.md` | 保留历史清理证据，并在顶部链接本报告，明确历史扫描基线不等于当前文件清单。 |
| `docs/PROJECT_MAINTENANCE.md` | 继续维护版本/发布链；当前测试结果、产物哈希和外部 BLOCKED 条件应在每次发布后更新。 |
| `docs/qa/TEST_MATRIX.md`、`FINAL_QA_REPORT.md`、`REGRESSION_REPORT.md` | 保留历史证据，但新增复核日期和当前命令输出，避免把旧测试数误写成当前状态。 |

文档维护规则：源码入口、页面枚举、控制器拆分、构建脚本和测试数量变化时，先同步 `PROJECT_REVIEW.md` 与 `docs/qa/PROJECT_MAP.md`，再更新 README/QA 文档；历史 QA 数字不覆盖，只标明日期和来源。
