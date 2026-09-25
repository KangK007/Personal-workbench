# 代码审查、功能分析与端到端验证（2026-09-21；2026-09-23 复核）

> 2026-09-21 内容为历史审查快照。2026-09-23 在其后工作区复核中补充发现 BUG-019/020；当前验证结果见本文“2026-09-23 复核补充”及 `docs/qa/BUGS.md`。

## 1. 审查范围与结论

审查版本：`pubspec.yaml` 中的 `0.2.1+6`。范围包括 `lib/`、`test/`、Windows/Android 原生桥、Supabase 迁移、构建配置和导入/备份数据边界。

结论：核心本地优先流程可稳定通过自动化验证；静态分析无问题；本轮发现并修复 1 个导入边界风险。Windows Release 与 Android arm64 Debug 构建分别被路径编码和 JVM loopback 环境问题阻塞，不能据此判定产品代码失败。

## 2. 架构与依赖关系

```text
main.dart → app.dart → WorkbenchShell → pages/widgets
                         ↓
                 WorkbenchController
             ↙          ↓             ↘
     SQLite/AppDatabase  domain mixins   services
                         (RSIP/限制)     (backup, focus, notice,
                                          attachment, search, sync)
                         ↓
                Windows MethodChannel / Android plugins / Supabase
```

- 入口与壳层：`lib/main.dart`、`lib/app.dart`、`lib/ui/workbench_shell.dart`；负责平台初始化、主题、导航、通知/分享/同步服务组装。
- 状态与领域：`lib/state/workbench_controller.dart` 组合 `restriction_controller.dart`、`rsip_controller.dart`；统一编排任务、项目、回顾、专注、成长、自律和导入导出。
- 数据层：`lib/data/app_database.dart` 管理 SQLite schema v3、软删除、事务恢复和 metadata；`backup_service.dart` 提供 PBKDF2-HMAC-SHA256 + AES-256-GCM；`workspace_migration.dart` 负责 v2/v3 领域迁移。
- 服务层：附件哈希与原子恢复、搜索内存索引、专注计时、通知、SelfControl 导入、自律策略/监控/安全、Windows 桥和可选 Supabase 同步。
- 依赖边界：本地数据库是主数据源；Supabase 仅在配置并登录后参与同步；Windows hosts/进程/托盘通过 MethodChannel；Android 通知、分享捕获和文件选择器通过插件。

## 3. 核心功能预期行为与验证重点

| 流程 | 预期行为 | 验证结果 |
| --- | --- | --- |
| 启动与迁移 | 打开 SQLite、备份旧库、执行 v2/v3 迁移，失败可重试/恢复 | PASS；迁移失败路径有回归测试 |
| 任务/项目/回顾 | CRUD、软删除/恢复、周期实例、逻辑日 04:00、日/周/月快照 | PASS |
| 专注与成长 | 正计时、25/50/自定义倒计时、暂停/完成、XP/押注结算 | PASS |
| RSIP/CTDP | 节点/轮次/违反、严格模式、每日限制、协议结算 | PASS |
| 自律 | 跨午夜规则、黑白名单、窗口标题、hosts、冷却和应急码 | 自动化 PASS；真实进程终止/hosts/UAC 需隔离 VM |
| 数据安全 | 加密备份错误密码、损坏、大小/嵌套/附件限制；附件哈希和原子恢复 | PASS |
| 导入/同步 | JSON/CSV/Markdown/TXT、重复副本、Supabase 分页/冲突 | 自动化 PASS；真实 Supabase 账号/RLS 未执行 |

## 4. 发现的问题、成因、影响与修复

### BUG-019（P2，已修复）：导入记录数没有上限

- 成因：`WorkbenchController.importFile` 只限制单文件 10 MiB；JSON 列表和 CSV 行数会继续累积，并逐条调用 `addRecord`，导致内存、通知和 SQLite 写入峰值不可控；对象 JSON 缺少 `records` 时还会抛出未结构化的类型异常。
- 影响：恶意或异常导入文件可能造成长时间 UI 卡顿、批量写入压力，错误提示不稳定。
- 修复：增加 `_maxImportRecords = 50000`；JSON 在映射前校验根结构与记录列表，并在 JSON/CSV 构造阶段拒绝超限。
- 验证：新增 `imports reject excessive JSON record counts before writes`；与既有导入、可靠性回归共 `14/14` 通过，`flutter analyze --no-pub` 无 issue。
- 后续优化：若未来需要百万级导入，应改为分页解析 + SQLite 单事务批写，并显示进度/取消操作。

### OBS-001（P2，未改）：导入仍逐条写库

- 成因：兼容现有重复副本和逐条业务钩子，当前实现对每条记录调用 `addRecord`。
- 影响：接近 50,000 条上限时写入和 `notifyListeners` 成本较高。
- 建议：下一阶段增加 `addRecordsBatch`，在单事务中写入并合并一次通知；以 1k/10k/50k 基准测试验证。

### OBS-002（P2，平台限制）：真实 Windows 自律副作用未在隔离环境执行

- 成因：进程终止、hosts 写入、UAC、托盘退出会改变宿主机状态。
- 影响：自动化仅验证决策、护栏、回滚和 MethodChannel 参数，未证明真实系统副作用。
- 建议：在一次性 Windows VM 中执行 RST-008/RST-009/PLT-001，并保存 hosts 前后哈希与进程退出证据。

### OBS-003（P2，平台限制）：真实 Supabase 和 Android 长期通知未完成

- 成因：当前环境没有隔离 Supabase URL/密钥/账号；Android 锁屏、休眠、重启和进程被杀时序未具备稳定设备实验条件。
- 影响：只能确认 fake remote、RLS 迁移结构、通知渠道和即时通知；无法声称远端冲突和长期送达已实机验证。
- 建议：配置临时 Supabase 项目并在 API 35/36 真机执行同步矩阵；记录重启前后通知 ID 和 `dumpsys notification`。

## 5. 自动化测试结果

### 静态与格式

- `flutter pub get`：PASS（离线缓存解析）；`flutter_markdown 0.7.7+1` 已停止维护，记录为依赖风险。
- `flutter analyze --no-pub`：PASS，`No issues found`。
- `dart format --output=none --set-exit-if-changed lib test`：修复前 99 个文件、0 变更；修复涉及文件的限定格式检查 PASS。
- `git diff --check`：PASS。

### 端到端/回归

- 全量：`flutter test --no-pub --reporter compact` → **243/243 PASS**。
- 数据库/备份/附件/自律安全重点 → **33/33 PASS**。
- 控制器/导入导出/协议/可靠性重点 → **72/72 PASS**。
- 页面/UI/截图/Golden 重点 → **54/54 PASS**。
- 新增导入上限修复专项与全功能导入 → **14/14 PASS**。
- 性能观察：1000 条任务列表渲染和滚动测试输出约 **1.84 秒**，未出现布局异常。

### 异常表现记录

- `protocol_ui_flow_test.dart` 会故意注入 `disk full`，日志包含保存异常堆栈；断言验证编辑器保留输入并可恢复，属于预期故障注入。
- `ui_coverage_regression_test.dart` 窄屏导航曾输出一次 focus 项目越界 hit-test warning，但测试继续通过；建议后续改为先 `ensureVisible` 再点击，避免测试噪声。

## 6. 构建与平台阻塞

- Windows Release：`flutter build windows --release` 在中文工作区路径下生成 `D:\Project\锟斤拷...\.dart_tool\flutter_build\...\app.dill`，MSBuild 无法读取实际中文路径；使用临时 ASCII 驱动映射仍被 Flutter 解析回真实路径。建议在 ASCII 路径 checkout 或升级 Flutter 工具链后重试。
- Android arm64 Debug：`flutter build apk --debug --target-platform android-arm64 --no-pub` 以及关闭 Gradle daemon/强制 IPv4 后仍报 `java.io.IOException: Unable to establish loopback connection`。建议在允许 JVM loopback 的主机/CI runner 重试。
- Android Release：仍需 `android/key.properties` 和私有 keystore，属于签名凭据阻塞。

## 7. 清理与工作树

本轮测试生成的 `.dart_tool/`、`build/`、`.runtime_data/`、`dist/`（若存在）属于缓存/构建产物，不纳入源码审查；完成报告前会清除。根目录 `_d1.log`–`_d7.log`、`.workbuddy/`、`tool/__pycache__/` 等上一轮已按清理要求移除。`tool/generate_app_icons.ps1` 仍仅作为待确认旧脚本保留，不在本轮擅自删除。

## 8. 下一步

1. 在 ASCII 路径或 CI runner 重跑 Windows Release 与 Android Debug 构建。
2. 在隔离 Windows VM 验证真实 hosts/UAC/进程终止/托盘副作用。
3. 在临时 Supabase 项目和 Android 真机完成远端冲突及长期通知时序矩阵。

## 9. 2026-09-23 复核补充

### 范围与架构复核

- 按 `docs/qa/COMPREHENSIVE_REVIEW_PLAN.md` 对入口、导航枚举/兼容映射、37 个页面表面、状态控制器、SQLite/备份/附件、通知/分享/Supabase、Android Manifest 与 Windows MethodChannel/hosts 代码复核。
- 核心依赖仍为：`PersonalWorkbenchApp` 组装服务与 Controller → `WorkbenchShell` 映射桌面/移动导航 → 页面和共享组件 → `WorkbenchController`/Restriction/RSIP mixin → SQLite、文件、插件、Windows 桥或可选 Supabase。
- Supabase migration 开启 RLS 且 CRUD policy 按 `auth.uid() = user_id` 限制；同步客户端上传/删除/查询均按当前 user id 作用域。Windows hosts/进程操作有桥接和受管区块逻辑，但本轮未对宿主真实 hosts 或进程做副作用操作。

### 本轮缺陷及闭环

| ID | 成因与影响 | 修复 | 验证 |
| --- | --- | --- | --- |
| BUG-019（P2） | 正式应用入口把用户系统字体缩放上限压到 1.3，和 200% UI 矩阵/无障碍预期不符 | `lib/app.dart` 上限改为 2.0；补纯函数边界测试 | 缩放测试 + 37 表面 UI 200% 矩阵通过 |
| BUG-020（P2） | Windows/Android 构建脚本共用同一 `source-copy`，并行时可递归互删缓存 | 两个脚本增加同 checkout 命名互斥锁，并在 `finally` 释放 | 并行验证一个成功、另一个明确快速失败；Android 随后单独构建通过 |

### 2026-09-23 执行结果

| 检查 | 结果 |
| --- | --- |
| `flutter analyze` | PASS，No issues found |
| `flutter test --reporter compact` | PASS，245/245；故障注入 `disk full` 堆栈为预期测试输出 |
| UI 审计 `test/ui_audit_screenshot_test.dart` | PASS，7/7；包括布局、主题、减少动效、200% 字号、焦点、菜单/Dropdown、Dialog/Escape 矩阵 |
| UI 功能专项 `test/ui_coverage_regression_test.dart` + 新增缩放测试 | PASS，20/20；原短视口 navigation hit-test warning 已通过滚动到可视区域后点击消除 |
| 控制器/可靠性/全功能专项 | PASS，54/54 |
| `tool/verify_colors.py` | PASS，浅/深主题 0 个未达标配对 |
| `tool/verify_token_parity.py` | PASS，56 对 Token 逐值一致 |
| `tool/verify_glyph_coverage.py` | PASS，无缺字；工具 Python 3.12 环境依赖可用 |
| `tool/verify_apk.py` | PASS，7/7 符号探针通过 |
| `tool/verify_windows_build.py` | PASS，稳定安装目录探针全部通过；注意它针对现有安装版本，不代表本轮 Debug EXE 探针 |
| Windows Debug build | PASS，`tool/build_windows.ps1 -Configuration debug`，构建过程会临时更新快捷方式 |
| Android arm64 Debug build | PASS，`tool/build_android.ps1 -Configuration debug -AbiMode arm64`，Gradle 8.14 成功；存在 Android SDK XML/第三方 Manifest/Gradle 弃用告警 |
| 格式只读检查 | WARN，`dart format --output=none --set-exit-if-changed lib test` 仍指出 `lib/state/workbench_controller.dart` 与 `test/reliability_regression_test.dart` 两处历史差异；未扩大范围格式化 |

### 当前阻塞与风险

- 已连接隔离 API 35 AVD 并完成 Android x86_64 Debug 冷启动、语义树、权限、通知渠道与重启恢复验证；真实 Android 长期通知送达和完整像素视觉复核仍未闭环。
- 未配置隔离 Supabase 项目/账号，远端 RLS、真实网络冲突及分页一致性本轮只能依赖 fake 自动化；真实远端场景 BLOCKED。
- 未在隔离 Windows VM 执行 hosts 写入/UAC/进程终止；保护逻辑只做代码与自动化审查，副作用场景 BLOCKED。
- Android 重启后的闹钟重新注册已验证；锁屏/休眠/系统杀进程后的定时通知实际送达仍 BLOCKED。
- `flutter_markdown 0.7.7+1` 已弃用，且 50 个依赖存在约束之外的新版本；需单独做依赖升级与 Markdown/通知/文件选择器视觉回归。
- 字体缩放矩阵由 Flutter Widget 测试覆盖到 200%；Android API 35 真实运行已确认首页/设置/成长语义树和截图，Windows 原生完整交互视觉仍受窗口激活能力限制。

总体结论：当前自动化、静态分析、视觉 Token/颜色/字体门禁及 Windows/Android Debug 构建通过；BUG-019/020 已验证关闭。由于真实远端、自律系统副作用、长期通知和本轮原生视觉验收未完成，结论为“自动化稳定，平台集成验收仍有 BLOCKED”，不能宣称所有真实设备流程均已完成。

## 10. 2026-09-24 收尾复核

- `flutter analyze --no-pub`：PASS，`No issues found`。
- `flutter test --no-pub --reporter compact`：PASS，245/245；`disk full` 堆栈仍是故障注入用例的预期输出。
- `tool/build_windows.ps1 -Configuration debug -Clean`：PASS，基于当前最终代码重建 `build/windows/x64/runner/Debug/personal_workbench.exe`（2026-09-24 09:46:29）。直接运行 `flutter build windows` 曾命中旧 CMake 缓存，已由脚本清理/隔离后恢复，不是源码缺陷。
- PowerShell AST：`build_windows.ps1`、`build_android.ps1`、`package_windows_release.ps1`、`update_all_shortcuts.ps1`、`packaging/windows/Install-PersonalWorkbench.ps1` 均为 0 个语法错误。
- `tool/verify_windows_build.py`：PASS；该探针验证的是稳定安装目录已有产物（2026-09-20），不替代本轮 Debug EXE 的构建证据。
- 桌面与开始菜单三个快捷方式已恢复指向稳定安装目录 `C:\Users\Administrator\AppData\Local\Programs\PersonalWorkbench\personal_workbench.exe`。
- `git diff --check`：PASS（仅有 Git 行尾转换提示）；未提交、未覆盖用户工作区改动。

### 2026-09-24 新增平台验证

- Android SDK 已补齐 `emulator 37.1.11` 与 API 35 `google_apis/x86_64` 系统镜像，创建隔离 AVD `pwb_api35`（Android 15/API 35）。
- `tool/build_android.ps1 -Configuration debug -AbiMode x64 -Online`：PASS，生成 `build/app/outputs/flutter-apk/app-x86_64-debug.apk`（SHA-256 `550347BE1544C301E4C0A831798021C4C7B85B930526A900B445396F902619DA`）。直接在中文路径调用 Flutter 构建会触发 Impeller shader 写入失败，使用仓库既有 ASCII 临时源码副本脚本后通过；该现象属于工具链路径限制，不是业务代码错误。
- x86_64 APK 安装到 API 35 AVD：PASS。冷启动后 `MainActivity` resumed，首页语义树完整，截图 `/Users/Administrator/AppData/Local/Temp/pwb_api35_coldstart.png`，应用 logcat 未见 `FATAL EXCEPTION` 或应用 `AndroidRuntime` 崩溃。
- Android 通知权限：PASS。首次请求真实出现系统 `POST_NOTIFICATIONS` 弹窗；点击允许后 `dumpsys package` 显示 `granted=true`，`workbench_updates` 渠道和立即通知 `NotificationRecord`/`PendingIntent` 均存在。
- Android 定时提醒注册：PASS。日/周/月提醒均以 `RTC_WAKEUP` 注册到 `ScheduledNotificationReceiver`；强制停止应用后，Android 按语义取消该包闹钟，不能作为“系统杀进程”证据，故不宣称通过该场景。
- Android 重启恢复：PASS。AVD 重启后 `ScheduledNotificationBootReceiver` 仍注册 `BOOT_COMPLETED`/`MY_PACKAGE_REPLACED`，应用进程被拉起，日/周/月三个提醒重新存在于 `dumpsys alarm`。将 RTC 时钟直接跳过触发点未得到可靠送达证据，仍保留定时通知 BLOCKED。
- Windows：`tool/build_windows.ps1 -Configuration debug -Clean` PASS，Debug EXE 已重建；隔离测试入口可启动。稳定安装目录探针和三个快捷方式核验仍 PASS；构建完成后已恢复快捷方式到 `%LOCALAPPDATA%\\Programs\\PersonalWorkbench\\personal_workbench.exe`。
- DOCX：检测到 Microsoft Word，三份文档均成功导出有效 PDF（`个人工作台新手引导攻略.pdf`、`个人工作台Windows版新手使用指导.pdf`、`个人工作台_用户使用手册.pdf`，均为 `%PDF-1.7` 且文件非空）。使用 PyMuPDF 生成并检查三份联系页及全部 92 页 PNG（612×792），未见空白页、图片裁切、标题越界或明显重叠，DOC-006 已 PASS。

本节仍不改变其余 BLOCKED 清单：真实 Android 定时通知送达（锁屏/休眠/系统杀进程）、真实 Supabase、隔离 Windows 系统副作用及原生窗口完整交互仍需专用环境/凭据。
