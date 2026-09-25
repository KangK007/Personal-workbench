# 个人工作台发布级项目地图

> 审查起点：`1d9c633`（2026-08-31）；本轮发布级复核：2026-09（Asia/Shanghai）
> 覆盖规则：本文件同时记录真实导航面、条件入口、兼容别名、平台集成和仅由组合页调用的子页面。测试状态以 `docs/qa/TEST_MATRIX.md` 为唯一明细基准。
> 当前入口和文件职责总表见根目录 `PROJECT_REVIEW.md`。本文件记录 QA 覆盖，不固定历史测试数量；测试 Case 和 Golden 数量以同日期的 `TEST_MATRIX.md` 与命令输出为准。
> 本轮前置变更（上一轮至本轮之间）：`WorkbenchController` 按领域拆分为控制器 + 自律/国策 mixin（公共 API 不变）；中文字体子集化（-8.9MB）；构建脚本新增 `-AbiMode` 分 ABI 打包；supabase 补丁升级；新增任务完成"航迹节点落定"动效、日结收尾仪式、今日空态升级与 2 项动效测试；修复减少动效下任务行 AnimatedSize 崩溃。

## 1. 技术栈与运行边界

| 层 | 实际实现 | 入口或证据 | 发布级关注点 |
| --- | --- | --- | --- |
| 跨端 UI | Flutter 3.38.9、Dart 3.10.8、Material 3 | `lib/main.dart`、`lib/app.dart` | Windows 与 Android 自适应、浅/深色、中文字体、系统文本缩放 |
| 桌面框架 | Flutter Windows runner + C++ MethodChannel | `windows/runner/` | 1280×720 初始窗口、托盘、通知、开机启动、进程快照、强制结束、hosts 管理 |
| Android | Flutter Android embedding v2 | `android/app/src/main/AndroidManifest.xml` | 分享文本、通知、开机恢复、系统返回、IME、旋转/字号/多窗口 |
| 状态管理 | `WorkbenchControllerBase` + `WorkbenchController` + `RestrictionControllerMixin` + `RsipControllerMixin` | `lib/state/` | 初始化、派生状态、事务失败回滚、并发保存、计时和监听器释放 |
| 本地数据 | SQLite / `sqflite_common_ffi` | `lib/data/app_database.dart` | 本地优先、软删除、metadata、附件事务、升级迁移、关闭重开持久化 |
| 云同步 | 可选 Supabase | `lib/services/supabase_sync_service.dart`、`supabase/migrations/001_workspace_records.sql` | 未配置时离线可用、分页、冲突副本、RLS、错误恢复 |
| 备份与文件 | PBKDF2-HMAC-SHA256 + AES-256-GCM、FilePicker | `lib/data/backup_service.dart`、`lib/services/attachment_service.dart` | 密码错误、大小限制、哈希、恢复预览、原子替换、路径隐私 |
| 搜索 | 内存索引 | `lib/services/search_service.dart` | 标题/正文/标签、多词排序、索引刷新、空结果 |
| 通知与分享 | 本地通知、Android 分享接收 | `notification_service.dart`、`share_capture_service.dart` | 权限拒绝、通知 ID 稳定、后台/重启、非法分享内容 |
| 设计系统 | 自定义 Flutter ThemeExtension + 离线字体 | `lib/core/theme/app_theme.dart`、`MASTER.md` | token、对比度、48dp 触控、焦点、减少动效、无嵌套卡片/玻璃拟态 |
| 测试 | Flutter unit/widget/golden | `test/` | 最终 241 项测试全部通过；自动化证据与真实 Windows/Android 运行证据分开记录 |

## 2. 应用入口与全局状态

| 模块 | 入口 | 主要功能/状态 | 关联数据或服务 | 测试状态 |
| --- | --- | --- | --- | --- |
| 启动 | `PersonalWorkbenchApp` | Loading 骨架、初始化成功、初始化失败、重试 | 数据库、迁移、通知、分享、同步 | PASS |
| 主题 | `MaterialApp` + `AppTheme` | 浅色、深色、跟随系统、主题切换动画 | metadata `themeMode` | PASS |
| 桌面壳 | `_desktopLayout` | 236px/80px 侧栏、分组展开、折叠、全局搜索、快速新增、同步状态 | 导航 metadata | PASS |
| 移动壳 | `_mobileLayout` | 顶栏、五项底部导航、更多 Sheet、FAB、返回历史、同步状态 | 最近子页、行为模式 | PASS |
| 全局快捷键 | `CallbackShortcuts` / `hotkey_manager` | `Ctrl+K` 搜索、Windows `Ctrl+Shift+Space` 快速新增 | 系统热键注册 | `Ctrl+K` PASS；系统级热键真实触发 BLOCKED（共享桌面前台活动） |
| 首次提示 | `_showGameFeaturesPrompt` | 本地激励开启/暂不开启、只出现一次 | 本地游戏 metadata | PASS |

## 3. 导航与页面清单

| 页面族 | 页面/入口 | 源码 | 主要功能与可达子状态 | 关联数据 | 测试状态 |
| --- | --- | --- | --- | --- | --- |
| 工作台 | 今日 | `today_page.dart` | 未开始、承诺 1–3 项、开始/撤销今天、替换承诺、时间线冲突、计分习惯、日结与恢复 | task、habit、focus、review、XP | PASS |
| 任务 | 全部 | `plan_page.dart` | 全部任务、筛选/排序/选择、批量状态/日期/项目/任务群/删除、新建编辑 | task、project、taskGroup | PASS |
| 任务 | 收件箱 | `plan_page.dart` → `inbox_page.dart` | 快速捕获记录、转换/编辑/删除、空态 | task/note/link | PASS |
| 任务 | 周视图 | `plan_page.dart` → `calendar_page.dart` | 06:00–02:00 工作周、时间块、新建/编辑/拖拽、冲突、桌面/移动布局 | task schedule/dueAt | PASS |
| 任务 | 任务群 | `plan_page.dart` | 新建/编辑/删除/恢复任务群、顺序模式、成员冲突与重排 | taskGroup、task | PASS |
| 项目 | 概览 | `projects_page.dart` | 项目主从布局、选择、新建/编辑/软删除/恢复、状态/元数据 | project | PASS |
| 项目 | 任务 | `projects_page.dart` | 项目任务列表/看板、完成/编辑/删除、主项目与关联项目 | project、task | PASS |
| 项目 | 任务群 | `projects_page.dart` | 项目内任务群和成员 | project、taskGroup | PASS |
| 项目 | 里程碑 | `projects_page.dart` | 新建/编辑/完成/删除里程碑 | project、milestone | PASS |
| 项目 | 笔记与回顾 | `projects_page.dart` | 项目笔记、事实与回顾入口 | project、note、review | PASS |
| 执行 | 专注 | `focus_page.dart` | 正计时、25/50 分钟、自定义倒计时、开始/暂停/继续/完成/取消、目标关联、后台刷新、庆祝 | focus session、task、notification、XP | PASS |
| 执行 | 自律 | `restriction_page.dart` | 规则列表、编辑、时段/星期/跨午夜、黑白名单、提醒/强制结束、保护密码/应急码/冷静期、hosts、事件日志 | restrictionProfile、本机安全状态 | PASS |
| 记录 | 笔记 | `notes_page.dart` | 索引、搜索/筛选、Markdown 阅读、编辑、版本、附件、软删除 | note、attachment | PASS |
| 记录 | 日回顾 | `review_page.dart` | 日期切换、事实快照、Markdown 字段、保存、版本/回顾库 | daily review、diary 兼容数据 | PASS |
| 记录 | 周回顾 | `review_page.dart` | 周期切换、快照刷新、保存、版本 | weekly review | PASS |
| 记录 | 月回顾 | `review_page.dart` | 月份切换、快照刷新、保存、版本 | monthly review | PASS |
| 成长 | 目标 | `goals_page.dart` | 目标树、父子关系、里程碑、新建/编辑/完成/删除 | goal、milestone | PASS |
| 行为 | 习惯追踪 | `behavior_page.dart` → `habits_page.dart` | 普通/RSIP 习惯区分、28 日矩阵、打卡/撤销、新建编辑 | habit、checkin | PASS |
| 行为 | 国策树 | `behavior_page.dart` → `policies_page.dart` | RSIP 节点树、新建/编辑/拆分/熄灭/恢复、违反预览 | RSIP node/group/run | PASS |
| 行为 | 国策库 | `policies_page.dart` | 归档记录、恢复/查看 | RSIP archived node | PASS |
| 行为 | 轮次历史 | `policies_page.dart` | 执行轮次与证据 | RSIP run/execution | PASS |
| 行为 | 高级分析 | `policies_page.dart` | 指标、洞察、筛选 | RSIP insight | PASS |
| 成长 | 成长 | `growth_page.dart` | XP、等级、签到、积分、押注、证据账本、连续记录、里程碑章 | local game state、XP ledger | PASS |
| 系统 | 设置 | `settings_page.dart` | 外观、导航、激励/高级功能、账号别名、云同步、通知、导入导出、加密备份、回收站、示例内容 | metadata、sync、backup、trash | PASS |

## 4. 条件入口、兼容面与非独立导航页面

| 类型 | 表面 | 可达性事实 | 验证要求 |
| --- | --- | --- | --- |
| 兼容别名 | `tasks/projects/review/plan/inbox/calendar/diary/habits/policies` | `_select` 统一映射到当前导航节点；`diary` 归一到 `ReviewPage` | 验证旧入口不落入空白页且保持预期子页 |
| 条件/兼容 | `protocols` / `ProtocolsPage` | 壳层仍可构建，但 `_select` 将兼容目标归一到目标页；页面由自动测试直接覆盖 | 作为兼容组件测试，不宣称当前普通用户有独立导航入口 |
| 组合子页 | `CalendarPage`、`InboxPage` | 由任务周视图/收件箱组合页调用 | 与父页面共同做运行时验证 |
| 兼容子页 | `ReviewPage` 的日回顾 Tab | 当前主导航使用合并后的 `ReviewPage`；仓库已无独立 `diary_page.dart` | 验证日回顾入口和旧别名不崩溃 |
| 移动辅助 | `_MobileNavigationSheet` | 移动端更多入口；仓库已无独立 `more_page.dart` | 验证所有桌面页面在移动导航中可达 |

## 5. 全局弹层、菜单和编辑器

| 表面 | 源码 | 主要操作/分支 | 测试状态 |
| --- | --- | --- | --- |
| 全局搜索 Dialog | `global_search_dialog.dart` | 输入、类型过滤、结果高亮、空结果、键盘选择、打开记录 | PASS |
| 快速新增 Sheet/Dialog | `quick_capture_sheet.dart` | 任务/笔记/今日记录/链接、标题/说明/日期/项目、保存错误 | PASS |
| 通用记录编辑器 | `record_editor_dialog.dart` | task/project/milestone/note/habit/goal/link 等；标题、正文、标签、状态、日期、重复、协议、关联、验证、保存错误 | PASS |
| Markdown 编辑器 | `markdown_editor_dialog.dart` | 工具栏、预览、保存/取消、未保存输入 | PASS |
| 附件面板 | `attachment_panel.dart` | 添加链接/本地图片、打开、删除、文件错误/大小限制 | 自动化 PASS；修复后原生选择器真实复验 BLOCKED（共享桌面前台活动） |
| 批量任务工具栏 | `batch_task_toolbar.dart` | 选择、全选、状态、日期、项目、任务群、删除、冲突确认 | PASS |
| 项目/任务/习惯/国策菜单 | 页面内 Popup/Menu | 编辑、完成、恢复、删除、协议状态动作 | PASS |
| 危险确认 Dialog | 通用 `showWorkbenchDialog` | 删除、清空回收站、恢复备份、保护设置 | PASS |
| 日期/时间选择器 | 多页面 | 选择、取消、边界日期、跨日 | PASS |
| Toast/SnackBar | 页面内 `_message` 等 | 成功、失败、权限拒绝、重复提交 | PASS |

## 6. 数据对象与业务能力

| 领域 | 主要对象 | 核心规则 | 测试状态 |
| --- | --- | --- | --- |
| 统一记录 | `WorkspaceRecord` / `RecordKind` | JSON 往返、软删除、syncState、标签/关联、状态 | PASS |
| 任务 | `TaskDefinition` / `TaskInstance` | 重复、实例结算、04:00 逻辑日、子任务、主/关联项目、任务群 | PASS |
| 回顾 | `PeriodReview` / `ReviewSnapshot` | 日/周/月周期、事实冻结、版本、旧日记迁移 | PASS |
| CTDP | task data / protocol service | 主链/辅助链、预约、延迟、完成/失败证据、前置规则 | PASS |
| RSIP | `RsipNode*` / `RsipRunRecord` | 八类节点、拆分批次、熄灭/恢复、违反、任务联动 | PASS |
| 自律 | `RestrictionProfile` 等 | 跨午夜、黑白名单、动作覆盖、强保护、安全恢复 | PASS |
| 成长 | `GameProfile` / `PointTransaction` / `BetSession` | 每日签到一次、余额保护、每日押注限制、XP 仅来自证据 | PASS |
| 附件 | `Attachment` | 20MB 上限、复制/哈希/解析/删除、备份恢复 | PASS |

## 7. 平台与后台能力

| 能力 | Windows | Android | 测试状态 |
| --- | --- | --- | --- |
| 系统通知 | 原生 Toast / Flutter 通知 | 通知渠道与权限 | Android 即时通知 PASS；Windows 原生通知及 Android 休眠/重启定时送达 BLOCKED |
| 系统托盘 | 打开/退出、受保护退出 | 不适用 | 自动化 PASS；真实 OS 状态变更 BLOCKED |
| 开机启动 | 注册表 Run | Boot receiver 用于通知恢复 | 自动化 PASS；真实 OS 状态变更/重启送达 BLOCKED |
| 快速新增 | 系统级热键 | 分享菜单文本/链接 | Android 分享 PASS；Windows 系统级热键真实触发 BLOCKED |
| 自律执行 | 进程快照/结束、窗口标题、hosts/UAC | 只查看和同步规则，不结束进程/改 hosts | 规则与护栏 PASS；真实进程/hosts/UAC 副作用 BLOCKED |
| 数据持久化 | 应用支持目录 SQLite | 应用沙箱 SQLite | PASS |
| 云同步 | 可选 Supabase | 可选 Supabase | 本地与 fake 自动化 PASS；真实远端 BLOCKED（无隔离 Supabase 配置） |

## 8. 当前环境能力审计

| 能力 | 结果 | 影响 |
| --- | --- | --- |
| Windows Flutter GUI | PARTIAL | 最终代码的隔离 Debug 已创建真实窗口和独立数据库，Release 随后重建；Computer Use 无法激活捕获窗口，完整原生指针/键盘状态遍历记为 `BLOCKED` |
| Edge / Flutter Web | AVAILABLE | 可补充浏览器语义与多视口视觉验证，但不能替代 Windows 原生能力 |
| Android 真机/模拟器 | AVAILABLE：OnePlus Ace 2 Pro（`PJA110`，Android 16 / API 36，ADB `ec47ee9f`）及 Android 15 / API 35 模拟器、SDK 36、JDK 21、ADB | 已真实验证冷启动、IME、Back、权限拒绝/允许、即时通知、分享、横屏、尺寸变化与持久化；PJA110 已确认系统通知权限和 `workbench_updates` 渠道可用；休眠/重启/进程被杀后的定时送达仍 BLOCKED |
| 截图 | AVAILABLE | Flutter Golden、Widget 截图与真实运行截图均可保存到 `docs/qa/screenshots/` |
| Stitch MCP | BLOCKED | 当前没有 Stitch 工具、资源或模板；使用真实 GUI、Golden 和人工像素检查替代 |
| Word 生成 | PASS | 已重新生成真实 DOCX；包含 20 个章节和 21 张真实界面截图，OOXML 结构检查通过 |
| Word 渲染 | PASS | Microsoft Word 导出三份 PDF；PyMuPDF 完成三份联系页及全部 92 页 PNG 的尺寸与视觉完整性检查 |

## 9. 覆盖闭环规则

1. 每发现新入口、菜单、设置项、快捷键或状态分支，先更新本文件和 `TEST_MATRIX.md`。
2. `PASS` 必须对应已执行的自动化、真实运行或可审计的人工视觉证据。
3. 代码阅读只能支持“已识别”，不能单独支持 `PASS`。
4. 任务结束前重新读取本文件和 `TEST_MATRIX.md`；任何未执行项必须继续测试或改为带具体原因的 `BLOCKED`。

## 10. 本轮功能优化动态覆盖（实施前基准）

| 模块 | 新增或变更表面 | 入口与状态分支 | 关联数据 | 测试状态 |
| --- | --- | --- | --- | --- |
| 任务群 | 独立任务群编辑 Dialog | 新建、编辑、取消、保存中、校验失败、重复提交、主项目可选、模式锁定 | taskGroup、project | PASS |
| 任务卡片 | 完整元数据与父子关系 | 安排/截止、状态、优先级、循环、缺失占位、父路径、关系异常 | task、task definition | PASS |
| 任务树 | 线性清单递归层级 | 多级展开/折叠、筛选缺父、回收站父项、循环引用、非树形视图关系提示 | task.parentId | PASS |
| 关联设置 | 共用任务/项目关联 Dialog | 确认、取消、Esc、遮罩关闭、焦点恢复、长列表滚动 | note/review relations | PASS |
| 周视图 | 今天表头与完整日期列 | 本周/非本周、浅色/深色、拖拽悬停、时间块对比 | task schedule/timeBlock | PASS |
| 项目 | 单入口项目主界面 | 项目切换、五个单开面板、数量、空态、任务清单/看板、五类 CRUD | project、task、taskGroup、milestone、note、review | PASS |
| 导航 | 项目/收件箱/回顾扁平化 | 桌面顺序、任务子项、移动更多、旧枚举兼容映射、返回历史 | navigation metadata | PASS |
| 习惯 | 独立习惯卡与今日打卡 | 04:00 日界、过去只读、今日打卡/撤销、RSIP 失败/熄灭、空态新增 | habit、habitLog、RSIP | PASS |
| 今日 | 04:00–04:00 时间进度尺 | 0%/50%/跨日近 100%、分钟刷新、前台恢复、计时器释放、减少动效 | logical day clock | PASS |
| 回顾 | 编辑/回顾库/预览三状态 | 日周月切换、当前可编辑、历史/旧数据只读、未来禁止、关联与附件预览 | periodReview、diary、attachment | PASS |
| 成长 | 顶部积分面板间距 | 游戏功能开/关、最近反馈有/无、窄屏、200% 字号 | game profile | PASS |

## 11. Page × State × Interaction × Window Size 覆盖

当前 `_auditSurfaces` 由实际枚举展开为 37 个表面，而不是旧文档中的 39 个。逐表面明细见 `TEST_MATRIX.md` 的 `U4D-001`～`U4D-037`。

| 维度 | 已执行组合 | 结果 |
| --- | ---: | --- |
| Page × Default/Layout × Window/Theme | 37 × 14 = 518 | PASS |
| Page × Hover/Pressed/Focus/Keyboard × 375/1200/1536 | 37 × 3 = 111 | PASS |
| Page × Popup/Dropdown Open/Close × 375/1200/1536 | 37 × 3 = 111 | PASS |
| Dialog × Focus/Tab/Escape/Long Text × 4 个窗口/字号场景 | 6 × 4 = 24 | PASS |
| 专注预设 × Tab/4 Dropdown/Escape × 375×812 | 1 个完整场景 | PASS；4 个下拉无溢出，Escape 只关闭顶层菜单 |
| Windows 原生 Page × State × Interaction × Window Size | 1 个完整复验 Case | BLOCKED：自动化驱动无法激活已捕获窗口；隔离启动和语义读取成功 |

Disabled、Selected、Loading、Empty、Error、长文本和 200% 字号由主题测试、功能回归、空数据矩阵、故障注入及 Dialog 长文本场景共同覆盖。自动化 `PASS` 与原生视觉 `BLOCKED` 分开记录。
