# Windows + Android 实机端到端质量审计实施计划

> **For agentic workers:** 本计划用于当前会话内的 inline 执行；每个阶段完成后必须读取实际命令输出并记录证据。

**Goal:** 在当前 Windows 主机、PJA110 Android 实机和 Android 模拟器上完成可复核的构建、部署、核心流程、异常边界、性能、稳定性和无障碍验收，并对可安全修复的 P0/P1 问题完成修复与回归。

**Architecture:** 先验证工具链和依赖，再使用仓库现有脚本构建 Android Release/Windows Release；Android 通过 ADB 安装到 `ec47ee9f`，Windows 通过现有安装脚本部署。测试证据分为命令日志、设备状态、应用截图/UIAutomator、性能采样和回归测试结果，所有结论以本次运行的输出为准。

**Tech Stack:** Flutter 3.38.9、Dart 3.10.8、Gradle/Android SDK、PowerShell、ADB、Pester、Flutter widget/unit tests、Windows Release runner。

**Spec:** 用户请求：在该项目上进行实机安装与部署，并执行完整全流程测试，记录每一步实际结果、报错信息、结论、复现步骤和改进建议。

## Global Constraints

- 保留任务开始前的用户修改，不执行 `git reset --hard`、`git clean` 或未经授权的数据清除。
- Android 实机目标为当前已授权的 `ec47ee9f`（PJA110）；卸载旧包前先检查签名和包名，避免破坏本地数据。
- 云同步默认关闭时不伪造 Supabase 结果；网络/同步只记录可实际验证的本地行为和环境限制。
- 每个缺陷必须先复现，再做最小修复，最后重新构建、部署和回归。
- 完成声明前必须重新运行对应的构建、测试和设备检查命令。

### Task 1: 环境和依赖基线

**Files:**
- Read: `pubspec.yaml`, `README.md`, `tool/build_android.ps1`, `tool/build_windows.ps1`, `tool/package_windows_release.ps1`
- Record: `dist/qa/2026-10-04/`

- [ ] 运行 `flutter --version`、`dart --version`、`java -version`、`adb devices -l`、`flutter devices`、`flutter doctor -v`。
- [ ] 运行 `flutter pub get`，记录依赖解析结果和错误。
- [ ] 运行 `dart format --output=none --set-exit-if-changed lib test`、`flutter analyze --no-pub`、`flutter test --reporter compact`。
- [ ] 检查当前 Git 状态和已有未提交修改，避免覆盖用户工作。

### Task 2: Android 实机构建和部署

**Files:**
- Read: `android/key.properties`, `android/app/build.gradle.kts`, `tool/build_android.ps1`
- Output: `dist/apk/`、`dist/qa/2026-10-04/`

- [ ] 使用现有发布脚本构建 Android Release APK，并记录 Gradle/APK 签名校验结果。
- [ ] 用 `adb -s ec47ee9f shell pm path <applicationId>` 检查现有安装；只有在签名兼容且用户数据可保留时才覆盖安装。
- [ ] 使用 `adb install -r` 部署 APK，记录安装输出和退出码。
- [ ] 冷启动应用，采集 `logcat`、首屏截图和 UIAutomator XML，确认无启动异常、ANR、`E/flutter`、通知图标错误。

### Task 3: Android 核心流程与异常边界

**Files:**
- Read: `docs/USER_GUIDE.md`, `test/full_function_regression_test.dart`, `test/page_smoke_test.dart`
- Evidence: `dist/qa/2026-10-04/android/`

- [ ] 验证首次启动、快速新增任务/笔记/链接、编辑、完成/撤销、搜索、项目/回顾/设置导航。
- [ ] 验证重启持久化、返回栈、横竖屏/窗口变化、通知权限允许/拒绝、分享捕获入口。
- [ ] 验证空输入、超长文本、重复提交、错误密码备份恢复、导入非法文件、磁盘/网络不可用等错误提示和恢复路径。
- [ ] 通过 `adb shell dumpsys gfxinfo`、`dumpsys meminfo` 和重复冷启动采样启动时长、帧/内存和进程稳定性。
- [ ] 用 TalkBack/系统无障碍树可见性、触摸目标和大字体/系统缩放检查关键控件；截图证据不能替代屏幕阅读器结论，未执行项必须明确标注。

### Task 4: Windows Release 构建、安装和核心流程

**Files:**
- Read: `packaging/windows/Install-PersonalWorkbench.ps1`, `tool/verify_release_consistency.ps1`
- Output: `dist/qa/2026-10-04/windows/`

- [ ] 构建 Windows Release、生成安装包并执行签名/一致性检查。
- [ ] 安装到稳定目录，启动进程并记录版本、退出码、事件/控制台错误。
- [ ] 验证导航、任务/项目/笔记/回顾、搜索、备份导出/恢复、设置和关闭/重启持久化。
- [ ] 验证错误输入、重复点击、文件导入失败、无权限目录、网络关闭等错误处理。
- [ ] 使用任务管理器/PowerShell 采样进程内存、启动时间和重复启动稳定性。

### Task 5: 修复与回归闭环

- [ ] 对复现的 P0/P1 缺陷建立最小回归测试；先确认测试能暴露原问题，再修改实现。
- [ ] 重新运行受影响测试、全量 `flutter analyze`、全量 `flutter test`、目标平台构建和实机安装。
- [ ] 运行 `git diff --check`，审查 diff 只包含本任务必要变更。
- [ ] 生成最终报告，逐项列出通过/失败/阻塞、实际报错、复现步骤、修复、证据路径和改进建议。

## Verification Checklist

- [ ] Android 实机 `adb devices -l` 显示 `ec47ee9f device`。
- [ ] Android APK 安装成功且冷启动无致命日志。
- [ ] Windows Release 构建、签名、安装和启动成功。
- [ ] 自动化分析和测试无新增失败。
- [ ] 关键流程、异常边界、性能、稳定性和无障碍结果均有实际证据或明确阻塞说明。
