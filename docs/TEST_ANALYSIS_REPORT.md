# Windows 工作台全流程检测分析报告

**检测日期：** 2026-08-14
**检测分支：** `main`
**软件版本：** `0.1.0+1`（界面显示 `0.1`）
**软件代码基线：** `74d53cf`（版本 0.1 主线整理提交）
**检测环境：** Windows 11 专业版 64 位，Flutter 3.38.9，Dart 3.10.8

## 1. 结论摘要

自动化验证全部通过，当前版本可以进入下一轮真实 Windows 原生验收：

| 检测项 | 结果 |
| --- | --- |
| 静态分析 | 通过：`flutter analyze --no-pub` 无问题 |
| 非视觉测试 | 通过：22 个测试文件，126 项断言 |
| 视觉 Golden 测试 | 通过：19 项 |
| 全量覆盖率测试 | 通过：145 项 |
| Dart 行覆盖率 | 67.46%（8,670 / 12,853，44 个源码文件） |
| Windows Profile 构建（0.1） | 通过 |
| Windows Release 构建（0.1） | 被运行中的旧实例锁定，需关闭实例后重试 |
| Android Debug 构建 | 通过 |
| 隔离 Windows 软件入口 | 已生成并检查运行目录 |
| 最新版本首屏手测 | 已观察到：窗口、八栏导航、空白测试数据库、今日页 |
| Windows Toast/托盘/休眠/锁屏原生联调 | 当前环境未完成 |

“全部通过”只适用于上表中已执行的自动化和构建检查，不等同于已经覆盖每种真实硬件、系统策略和用户操作时序。

## 2. 执行的命令

```powershell
flutter analyze --no-pub
flutter test <22 个非视觉测试文件> --no-pub
flutter test test/visual_golden_test.dart --no-pub
flutter test --coverage --no-pub
powershell -ExecutionPolicy Bypass -File .\tool\build_windows.ps1 -Configuration release
powershell -ExecutionPolicy Bypass -File .\tool\build_android.ps1 -Configuration debug
powershell -ExecutionPolicy Bypass -File .\tool\package_windows_test_entry.ps1 -Configuration release -SkipBuild
```

覆盖率文件位于 `coverage/lcov.info`。构建产物位于：

- `build/windows/x64/runner/Profile/personal_workbench.exe`（0.1，可运行）
- `build/windows/x64/runner/Release/personal_workbench.exe`（旧实例占用，未完成 0.1 Release 重建）
- `build/app/outputs/flutter-apk/app-debug.apk`
- 最新隔离软件入口：`build/desktop_test_entry_20260814_122536/personal_workbench.exe`

软件入口必须与同目录的 DLL 和 `data` 文件夹一起使用，不能只复制单个 exe。

## 3. 功能覆盖矩阵

| 功能域 | 已检测内容 | 自动化证据 |
| --- | --- | --- |
| 今日 | 逻辑日、逾期、今日、已结算、完成/失败/跳过/改期、今日重点、收尾 | `workbench_controller_test.dart`、`ui_coverage_regression_test.dart`、`visual_golden_test.dart` |
| 任务 | 收件箱、周视图、任务群、周期任务、任务详情、失败原因、改期来源 | `recurrence_test.dart`、`full_function_regression_test.dart`、`ui_coverage_regression_test.dart` |
| 项目 | 项目创建、编辑、软删除、恢复、任务关联、详情布局 | `page_smoke_test.dart`、`ui_coverage_regression_test.dart`、视觉测试夹具 |
| 专注 | 正计时、倒计时、自定义时长、CTDP 中断、完成证据、定时置前配置 | `focus_service_test.dart`、`protocol_ui_flow_test.dart`、`reliability_regression_test.dart` |
| 笔记与附件 | Markdown、链接、图片元数据、附件备份、回收站和清理路径 | `attachment_service_test.dart`、`attachment_backup_test.dart`、`full_function_regression_test.dart` |
| 回顾 | 日/周/月切换、期间事实、唯一主回顾、快照、版本和回顾库入口 | `workbench_controller_test.dart`、`ui_coverage_regression_test.dart`、视觉测试夹具 |
| RSIP | 八类节点、国策组容错、拆分、严格/自由模式、E0/E1/E2、执行/违反/跳过、强化、归档、恢复、轮次、分析、任务联动 | `protocol_test.dart`、`protocol_ui_flow_test.dart`、`policies_page_test.dart`、`workspace_migration_test.dart` |
| 设置与数据 | 主题、别名、通知状态、备份、回收站、实验功能和本地数据状态 | `ui_coverage_regression_test.dart`、`backup_service_test.dart`、`app_database_test.dart` |
| 同步与搜索 | Supabase 读写模型、冲突处理路径、全局搜索 | `supabase_sync_service_test.dart`、`search_service_test.dart` |
| 视觉与响应式 | Windows/Android、亮色/暗色、空白态、未收尾态、文档截图、RSIP 树和分析页 | `visual_golden_test.dart`，19 项通过 |

## 4. 最新软件入口检查

当前 `0.1` Profile 软件入口已生成并成功启动；隔离测试入口仍可通过脚本生成，并使用独立数据库：

```text
build/desktop_test_entry_20260814_122536/personal_workbench.exe
```

实际观察到的 `0.1` Profile 首屏状态：

- 窗口标题为“个人工作台”。
- 显示“本地数据已就绪”。
- 默认进入“今日”。
- 左侧八栏“今日、任务、项目、专注、笔记、回顾、国策、设置”均出现在可访问树中。
- 空白测试数据库显示“添加今天的第一项任务”、逾期待结算、今日、已结算和时间安排区域。

UI 自动化过程中检测到用户正在操作窗口，因此没有强行抢占焦点或继续点击；任务、项目、专注、笔记、回顾、国策和设置的完整状态流以自动化 Widget/回归测试为准。

## 5. 检测到并修复的问题

首次重新打包软件入口时，已有 `desktop_test_entry` 进程锁定了 `data/icudtl.dat`，覆盖复制失败。已修复 `tool/package_windows_test_entry.ps1`：

1. 检测目标目录是否有正在运行的个人工作台进程。
2. 若目标被占用，自动创建 `desktop_test_entry_YYYYMMDD_HHMMSS` 目录。
3. 输出实际可执行入口路径。
4. 不强制关闭旧软件，不覆盖锁定文件。

修复后的打包脚本已成功生成时间戳版本入口。

## 6. 警告与剩余风险

### 已知但不影响自动化结果的警告

- 测试环境没有原生 `flutter_timezone` 宿主实现，出现 `MissingPluginException(getLocalTimezone)`；应用当前按失败关闭路径继续运行。
- sqflite 测试反复替换 FFI factory，输出开发测试警告。
- Android Gradle 报告存在弃用 API 和一个已弃用依赖包，但构建成功。

### 尚未完成的真实设备/系统验收

- Windows Toast 实际弹出、托盘隐藏/恢复、关闭窗口与真正退出的差异。
- 前台应用检测、黑白名单提醒、锁屏继续计时、系统休眠与唤醒中断。
- Windows 系统通知权限和焦点抢占失败时的任务栏闪烁。
- Android 真机安装、通知权限、后台存活和系统分享菜单。
- Supabase 真实账户冲突、网络中断和跨设备同步。

这些项目需要在真实用户 Windows/Android 环境中手动验收，不能由当前 Flutter 测试进程完全替代。

## 7. 建议的人工验收顺序

1. 关闭旧版本个人工作台，只启动最新时间戳目录中的 `personal_workbench.exe`。
2. 创建任务、项目、任务群和 RSIP 节点，验证今日页摘要和展开详情。
3. 完成、失败、跳过、改期各一次，确认原因和历史不被覆盖。
4. 创建专注预设，测试定时提醒、托盘恢复、锁屏和休眠恢复。
5. 创建 Markdown 笔记和图片附件，执行回收站、恢复和永久清理。
6. 保存日回顾、周回顾、月回顾，刷新事实快照并检查回顾库。
7. 在国策页测试拆分、容错扣减、强化、子树归档、恢复和轮次历史。
8. 最后执行加密备份、恢复预览、通知权限和 Android 真机冒烟测试。

## 8. 交付结论

当前 `0.1` 版本的代码级功能、数据迁移、RSIP 状态机、页面回归、视觉基线、Windows Profile 构建和 Android 构建均已通过检测。交付前需要关闭正在运行的旧 Windows 实例后重新生成 Release 构建，并按照第 6、7 节完成真实 Windows 原生服务和 Android 真机验收。
