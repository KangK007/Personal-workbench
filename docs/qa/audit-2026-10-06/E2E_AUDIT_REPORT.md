# Windows + Android 端到端质量审计

> 日期：2026-10-06（Asia/Shanghai）
> 范围：当前工作树中的 Flutter Windows + Android 应用
> 原则：不覆盖已有未提交修改；对本轮发现且可安全修复的问题直接修复并回归。

## 结论

核心流程通过。当前没有未处理的可复现 P0/P1 代码缺陷。Windows Release 和 Android Debug 均已实际构建；Windows 完成稳定安装目录验证，Android 在 API 35 模拟器完成真实启动和核心交互验证。

## 本轮修复

- `test/game_ui_test.dart` 与 `test/review_behavior_merge_test.dart` 的内存数据库替身补齐 `loadRecords({String? accountId})`，修复生产接口变更导致的分析和测试编译失败。
- `test/windows_runner_regression.Tests.ps1` 将本地化快捷方式断言改为不依赖 PowerShell 中文源文件编码的结构断言，消除测试误报。
- Android 计划页页签改为显式 `TabController`，保留当前页签与各页内容状态；小屏使用四等分布局并保留选中指示器，支持点击和左右方向键切换。
- `test/android_platform_ui_regression_test.dart` 增加 Android 页签状态、键盘切换、等宽布局和父级重建回归覆盖。
- Windows 计划、执行、成长页隐藏页签，保留 Shell 传入的当前导航子页；Android 执行/成长页签改为小屏等宽分布。
- Windows 页签可见性与 Android 执行/成长页签间距加入平台回归覆盖。
- 运行 Dart formatter 规范化已有格式漂移；这些格式化变化涉及当前工作树中已有业务、测试和平台脚本修改，未回退或覆盖其它用户修改。

## 实际验证

| 检查 | 结果 |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test` | PASS（格式化后复跑通过） |
| `flutter analyze` | PASS，No issues found |
| `flutter test` | PASS，266/266 |
| Windows Release 构建 | PASS，`build/windows/x64/runner/Release/personal_workbench.exe` |
| Windows Release 安装包 | PASS，版本 `0.2.1+7`，Authenticode 与 CMS 签名通过 |
| 稳定安装目录/快捷方式 | PASS，三个入口均指向 `%LOCALAPPDATA%\\Programs\\PersonalWorkbench` |
| Windows 实际启动 | PASS，安装产物存活且有有效窗口句柄 |
| Windows worker/uninstall 回归 | PASS，4/4 |
| Windows 页签行为 | PASS，平台回归确认计划/执行/成长均无页签 |
| Android Debug 构建 | PASS，`build/app/outputs/flutter-apk/app-debug.apk` |
| APK 内容校验 | PASS，7/7 |
| Android 模拟器冷启动 | PASS，API 35，`-gpu off` |
| 当前 APK 新鲜安装冒烟 | PASS，`adb install -r` 后清除数据再安装，主 Activity 前台可见，日志无 `FATAL EXCEPTION`、`ANR` 或 `E/flutter` |
| Android 核心导航 | PASS，今日/计划/执行/成长语义选中状态逐一切换 |
| Android 本地持久化 | PASS，创建任务后退后台再恢复仍可见 |
| Android 分享 | PASS，SEND 文本进入收件箱并显示“来自 Android 的收集” |
| Android 横屏/低高度 | PASS，2400x1080 仍使用 4 项移动导航，无 RenderFlex overflow |
| Android IME/FAB/Bottom Sheet | PASS，快速新增获得焦点、键盘可用、弹层可返回 |
| Android 可访问性 | PASS，当前页面 9 个可点击启用节点均有文本或 content-desc |
| Android 计划页页签 | PASS，API 35 模拟器实际显示四个等宽页签；点击“任务群”后节点 `selected=true` 且内容切换 |
| Android 执行/成长页签 | PASS，320dp 自动化视口验证两项与四项页签均分布且无布局溢出 |
| 1000 条任务列表性能 | PASS，约 1.14 秒渲染并滚动 |

## 同步与异常

- 本地数据库账户分区、分页下载、上传、冲突副本、远端删除、同步中本地编辑和网络失败均由 fake remote 测试覆盖。
- Android “执行 → 协议”中的“行为协议、判例、分析”由“高级工作流”设置控制；新安装默认关闭时只显示“执行协议”。打开设置 → 实验功能 → 高级工作流即可显示完整集合。
- 真实 Supabase 双端同步未执行：当前没有隔离 Supabase URL、密钥和测试账号，避免写入真实环境。
- 备份密码错误、附件事务回滚、磁盘写入失败、重复提交、初始化失败恢复等自动化回归通过。
- Android `POST_NOTIFICATIONS`、分享入口、通知渠道和系统栏由代码/模拟器冒烟覆盖；休眠、系统杀进程和重启后的定时通知仍需稳定设备时序验证。

## 环境限制

- Android 模拟器默认 GPU 模式会在应用启动后掉线；`-gpu off` 模式稳定，应用日志无 `FATAL EXCEPTION`、`ANR` 或 `E/flutter`。
- `gradlew lintDebug` 在当前 JDK/Gradle 进程因 loopback socket `Invalid argument` 阻塞；同一工具链的完整 `assembleDebug` 已通过。
- Android Release 构建需要未提交的发布 keystore；本轮只验证 Debug 构建。
- Windows 原生完整鼠标/键盘捕获、真实 hosts/UAC/托盘副作用、原生文件选择器窗口激活仍受共享桌面限制，自动化护栏和语义测试已通过。

## 当前工作树

本轮没有提交、推送、分支切换或 destructive Git 操作。仓库开始审计时已有大量未提交修改，均保留；本轮直接修改的是 Windows/Android 页签布局、对应回归测试、此前测试替身、Windows 回归断言和本报告，另外执行 formatter 规范化了工作树中已有的业务、测试和平台脚本文件。
