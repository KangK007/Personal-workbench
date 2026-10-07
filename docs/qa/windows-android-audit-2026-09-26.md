# Windows + Android 端到端质量审计（2026-09-26）

## 结论

核心本地工作流通过，已发现的可安全修复 P0/P1 问题已处理并完成回归。Windows 与 Android Debug 均完成实际构建和启动验证；Android 使用 API 35 `pwb_api35` 模拟器。真实 Supabase 双端同步、Android Release 签名和在线 Android lint 没有形成可复现证据，按 `BLOCKED`/`NOT RUN` 记录，不冒充通过。

## 环境与构建证据

| 项目 | 结果 |
| --- | --- |
| Flutter/Dart | Flutter 3.38.9 / Dart 3.10.8 |
| Windows 构建 | PASS：`tool/run_windows_test.ps1 -Configuration debug`，生成 `build/windows/x64/runner/Debug/personal_workbench.exe` |
| Windows 运行 | PASS：真实窗口标题“个人工作台”，1280x720，进程响应正常；重复启动保持单实例 |
| Android 构建 | PASS：`tool/build_android.ps1 -Configuration debug`，Gradle `BUILD SUCCESSFUL`，生成 `build/app/outputs/flutter-apk/app-debug.apk` 和 `dist/apk/PersonalWorkbench_0.2.1_7_debug.apk` |
| Android 运行 | PASS：API 35 `pwb_api35` / `emulator-5554`，冷启动并进入 `MainActivity` |
| Android Release | BLOCKED：未配置 `android/key.properties` 和发布 keystore |
| Android lint | BLOCKED：离线缓存缺少 `desugar_jdk_libs`；在线 lint 进程长时间停在分析阶段且无终态，已停止，未将其记为 PASS |

## 核心流程实测

| 场景 | 结果 | 证据 |
| --- | --- | --- |
| Android 冷启动/空态 | PASS | `topResumedActivity=...MainActivity`，UIAutomator 可读首页语义 |
| 快速新增任务 | PASS | 新增 `QA_Final_20260926` 后在“计划/任务”页出现 |
| 强制停止后重启 | PASS | `am force-stop` 后重启，首页显示 `还剩 1 件事` 和该任务 |
| Windows 启动/渲染 | PASS | PrintWindow 截图显示今日页、侧栏、时间尺和快速新增 |
| Windows 单实例 | PASS | 第二次启动后进程数仍为 1 |
| Android 横屏 | PASS | `adb shell wm size 2400x1080` 下页面完整渲染，底部导航和浮动新增按钮可用 |
| Android 高密度时间尺 | PASS | 视觉标签为 `00`–`23`，不再连成一串；UIAutomator 语义仍包含完整 `00:00`–`23:00` |
| Android 130% 字体 | PASS | 横屏 + `font_scale=1.30` 启动、截图、语义树均正常，随后恢复 `1.0` 和物理尺寸 |
| 异常日志 | PASS | 最终启动日志未发现 `FATAL EXCEPTION`、`ANR in` 或 `E/flutter` |
| Android Back/抽屉/导航 | PASS | 已验证 Back、底部“今日/计划/记录/成长/更多”和更多抽屉入口 |

## 自动化回归

- `flutter analyze --no-pub`：PASS，`No issues found`。
- `flutter test --reporter compact`：PASS，`246` 个测试全部通过。
- 专项覆盖包括数据库持久化、同步冲突/网络失败/重试、备份恢复、核心页面、无障碍主题与触控目标、Golden/UI 审计、1000 条任务滚动性能。
- 新增回归：`test/optimization_regression_test.dart` 验证窄逻辑宽度时间尺使用紧凑视觉标签且保留完整语义标签。
- 因 `habits_page.dart` 既有自适应矩阵修改导致基线过时，更新了 `test/goldens/ui_audit/habits_desktop.png` 与 `test/goldens/wide_behavior_habits.png`；未放宽像素容差或删除断言。

## 修复摘要

`lib/ui/pages/today_page.dart` 在时间尺宽度小于 1200 logical px 时仅缩短视觉标签为小时数字，`Semantics` 继续提供完整 `HH:00`。这解决了 Android 高密度横屏下相邻标签视觉粘连，同时保持桌面宽屏显示完整时间。

## 同步与边界

本地 SQLite 数据一致性、脏记录、冲突副本、重试和网络失败均由自动化 fake/mock 测试覆盖并通过。当前未配置隔离 Supabase endpoint、key 和账号，因此真实 Windows↔Android 远端同步为 `BLOCKED/NOT RUN`，不能宣称端到端云同步通过。

## 性能、稳定性与无障碍

- 1000 条任务列表渲染与滚动回归通过（约 1.64s）。
- Android UIAutomator 读取到按钮、导航、输入框和状态描述；关键按钮触控区域达到约 126–150 px 模拟器像素，对应代码中的 48dp 目标约束。
- Windows 窗口真实响应正常；Android 冷启动约 2 秒内完成首屏绘制，未见崩溃或 ANR。
- 真实 Windows 托盘、hosts/UAC、系统级热键和 Android 锁屏/休眠/杀进程后定时通知未在本环境形成完整证据，保留为后续环境测试项。

## 工作区状态

本轮未执行 commit、reset、clean 或 push；保留任务开始前用户已有修改。最终应以 `git status --short` 和 `git diff --check` 结果为准。
