# 个人工作台

个人工作台 0.1 是一款面向科研学习与个人项目的本地优先 Flutter 应用。它把“快速收集、项目规划、安排今天、专注执行、知识沉淀、回顾、目标与行为追踪”放在一条可验证的工作流中，并融合了 SelfControl 的 Windows 自律限制能力。当前界面采用“个人航行日志”设计体系：中性画布与实色工作面用于长期阅读，真实时间、任务顺序、里程碑和执行证据使用日志航迹组织，冲突与危险操作使用独立信号色提示。

## 详细使用指南

安装运行、任务结算、项目/笔记回收站、专注后台、日周月回顾、RSIP 国策和备份恢复，请参阅[《个人工作台新手使用指导》](docs/USER_GUIDE.md)。指南包含当前测试界面截图、按钮/字段说明、异常处理和恢复路径。RSIP 的语义依据为 [Momentum 公开源码](https://github.com/KenXiao1/momentum)；参考网页和本项目现状的逐项验收见[《功能复刻验收矩阵》](docs/FEATURE_PARITY.md)。

项目目录、Git 纳入范围、迁移步骤和当前外部阻塞条件集中记录在[《项目维护与迁移说明》](docs/PROJECT_MAINTENANCE.md)。

## 项目简介

首版以个人使用为边界，不包含多人协作、复杂依赖、第三方日历同步或 AI 自动代理。数据先保存到本地 SQLite，网络恢复后可选同步到 Supabase；离线期间仍可新增、编辑、搜索和回顾。

## 研究背景

界面借鉴了工作台类产品的任务、项目和多视图组织方式，以及时间块、专注计时、回顾和本地优先的实践。应用把首页压缩为“今天需要处理的信息”，将笔记、回顾、目标、行为和设置放入清晰的导航分组，避免首屏变成统计卡片墙。

## 项目结构

```text
lib/
  core/models/       记录类型、状态、备份清单与序列化
  core/theme/        浅色/深色主题、离线字体角色和语义颜色令牌
  core/utils/        日期、时间和时长格式化
  data/              SQLite 本地数据库与加密备份
  services/          搜索、专注、成长规则、自律策略/安全/导入、提醒、分享捕获、Supabase 同步
  state/             工作台控制器与业务操作；WorkbenchController（今日/任务/项目/
                      回顾等核心）+ RestrictionControllerMixin（自律）+
                      RsipControllerMixin（国策）+ WorkbenchControllerBase（共享契约）
  ui/pages/          今日、任务、项目、专注、自律、笔记、回顾、国策、设置及 Android 兼容页面
  ui/widgets/        日期刻度带、日志表面、任务行、快速收集、记录编辑、全局搜索等通用界面
assets/branding/     应用图标源文件和主图标
android/             Android 应用清单和构建配置
windows/             Windows 原生进程、托盘、通知、快捷方式和 hosts 受管能力
packaging/windows/   Windows 安装与独立 hosts 恢复脚本
supabase/            云端同步表及 RLS 迁移
  test/                数据、成长规则、备份兼容和 Golden 验收测试
```

## 环境依赖

- Flutter 3.38.9 stable（Dart 3.10.8）或兼容的 Flutter 3.38+。
- Android 构建需要 Android SDK、Android SDK Command-line Tools 和 Java 17+。
- 依赖由 `pubspec.yaml` 管理，主要包括 `sqflite`、`cryptography`、`file_picker`、`supabase_flutter`、`flutter_local_notifications` 和 `receive_sharing_intent`。

## 安装方法

```powershell
flutter pub get
flutter analyze
flutter test
```

首次运行会创建本地数据库，默认保持空白；已有安装中的示例内容可在“设置 → 示例内容”中手动清除。

## 快速开始

```powershell
# 查看可用设备
flutter devices

# Android 运行（连接设备或启动模拟器后）
flutter run -d android

# Windows Release 构建；完成后自动刷新桌面快捷方式
powershell -ExecutionPolicy Bypass -File .\tool\build_windows.ps1 -Configuration release

# 生成可分发 Windows 安装包，并安装到稳定目录后刷新桌面/开始菜单快捷方式
powershell -ExecutionPolicy Bypass -File .\tool\package_windows_release.ps1 -Configuration release -Install

# Android 调试 APK（兼容中文工作区路径）
powershell -ExecutionPolicy Bypass -File .\tool\build_android.ps1 -Configuration debug

# Android Release APK（必须先配置独立发布签名）
powershell -ExecutionPolicy Bypass -File .\tool\build_android.ps1 -Configuration release

# 按 ABI 拆分打包（arm64-v8a / armeabi-v7a / x86_64 各一个 APK）
powershell -ExecutionPolicy Bypass -File .\tool\build_android.ps1 -Configuration debug -AbiMode split

# 只构建单一 ABI（体积最小，适合个人侧载）
powershell -ExecutionPolicy Bypass -File .\tool\build_android.ps1 -Configuration debug -AbiMode arm64
```

Android Release 构建必须在 `android/key.properties` 中提供独立发布密钥配置；该文件和
`*.jks` / `*.keystore` 已被 Git 忽略，不得提交到仓库。`storeFile` 相对于
`android/app/` 解析，例如：

```properties
storeFile=../keystore/personal-workbench-release.jks
storePassword=<本地保存的密钥库密码>
keyAlias=personal-workbench
keyPassword=<本地保存的密钥密码>
```

缺少配置时，Release 构建会明确失败，不再产出容易被误用的未签名 APK。通过
`tool\build_android.ps1` 构建 Release 后，脚本还会调用 Android SDK 中的
`apksigner` 验证签名；只有验证通过才会复制到项目 `build/` 目录。密钥库及密码应另行
安全备份，不能只保存在项目工作区。

Windows 和 Android 构建脚本会把源码镜像到 `%LOCALAPPDATA%\PersonalWorkbenchBuild\` 下的纯 ASCII 暂存目录，再从该副本构建，规避中文工作区路径导致的 Gradle/MSBuild 编码问题。`build/`、`dist/`、`.git/` 等生成内容不会进入暂存副本；构建结果会复制回项目的标准输出目录。Android 脚本还会为 JDK/Gradle 使用短临时路径，避免 Windows AF_UNIX 回环通道的路径长度限制。Release 仅在签名验证通过后复制 APK。如需强制清理构建缓存，可增加 `-Clean` 参数。Android 脚本使用本机缓存的 Gradle 8.14 离线构建；首次使用前若缓存不存在，需要先在网络可用时运行一次 Gradle 下载。

中文字体（LXGW 文楷、IBM Plex Sans SC）已经过 `tool/subset_fonts.py` 子集化：裁掉韩文等本项目用不到的字形，保留 CJK 基本区与扩展 A 全量，用户输入的生僻中文字仍可正常显示。如需恢复原字体或调整字符集，运行 `python tool\subset_fonts.py --restore` 后修改脚本中的 `UNICODE_RANGES` 再重新执行。

Android 使用 Material 3 底部导航，读取与桌面端一致的 v3 记录。全局“快速新增”可以写入任务、笔记、今日记录或链接；定时专注使用 Android 系统通知。
Windows 侧栏按真实页面组织层级：任务和项目展开后显示各自的页面，回顾展开后显示日、周、月回顾；专注、自律、目标和行为是直接入口。Android 保留底部导航，并在“更多”抽屉中提供同样的页面树。Android 可以查看、编辑和同步限制规则，但明确不会结束 Windows 进程或修改 hosts。

## 核心功能

- 今天：开始今天时锁定 1–3 项承诺，支持替换原因、时间线冲突、最多两项计分习惯和日结收尾。
- 成长：承诺、专注、习惯、日结分别记入 XP 证据；使用 04:00 逻辑日、连续日结、14 日恢复资格、28 日矩阵和等级日期章。
- 计划与工作周：计划页汇总周工作；工作周支持 06:00–02:00 的时间格、5 分钟吸附、跨日拖拽和冲突状态。
- 项目：左侧项目列表、右侧概览/任务/任务群/里程碑/笔记与回顾详情，支持编辑、软删除和恢复。
- 执行：正计时、自定义倒计时、预设、白名单/黑名单、定时确认启动、锁屏/休眠中断记录。
- 自律：按星期和跨午夜时段限制应用、窗口标题和网站；支持提醒/强制结束、进程动作覆盖、PBKDF2 保护密码、一次性紧急恢复码、5 分钟冷静期、强保护活动快照、异常退出恢复、托盘退出保护、hosts 备份/UAC/诊断和拦截统计。规则以 `restrictionProfile` 同步，敏感密码和运行快照只保存在本机。
- 协议：CTDP 主链/辅助链、预约缓冲、辅助信号、完成证据和审计统计；RSIP 八类节点、国策组容错、拆分批次、强化层、E0/E1/E2、违反预览、崩塌/恢复、轮次历史、规则启发式和任务双向联动。
- 沉淀：笔记 Markdown 阅读器、链接/本地图片附件、最近 10 个正文版本、任务/项目多关联；回顾单页切换日/周/月、事实快照、正文版本和回顾库。
- 数据：回收站、JSON/CSV/Markdown/TXT 导入、JSON 导出、AES-256-GCM 加密备份与恢复预览。
- SelfControl 规则：应用内置经过脱敏和去重的原项目规则，创建后默认停用；已有用户配置只补齐缺失的应用、关键词和网站条目，不覆盖个人设置。底层导入服务仍保留用于旧数据迁移，但不再向普通用户显示入口。
- 移动端：接收 Android 分享菜单中的文本或网页链接，首版仅保存链接和说明，不下载网页全文。

## 仿真参数说明

本项目当前不是光学仿真程序，没有波长、采样间隔、焦距或数值孔径等物理参数。科研记录可以把实验参数写入任务、笔记或回顾正文，并用标签和项目关联；原始实验数据仍应保存在独立的科研数据目录中。

## 主要脚本说明

当前应用入口是 `lib/main.dart`。业务逻辑集中在 `lib/state/workbench_controller.dart`，本地数据库在 `lib/data/app_database.dart`，加密备份在 `lib/data/backup_service.dart`。没有额外的仿真脚本或论文图生成脚本。

## 输出结果说明

- SQLite 数据库：由 `path_provider` 放在应用支持目录，文件名为 `personal_workbench.sqlite`。
- 加密备份和 JSON 导出：应用文档目录下的 `PersonalWorkbench/` 文件夹。
- Android APK：`build/app/outputs/flutter-apk/app-debug.apk` 或 `app-release.apk`；发布脚本还会更新 `dist/apk/` 下带版本号的侧载副本。
- Windows Release：`build/windows/x64/runner/Release/`；`tool/build_windows.ps1` 会更新开发构建快捷方式，`tool/package_windows_release.ps1 -Install` 会生成 `dist/PersonalWorkbench_<版本>_windows.zip`，并将稳定安装目录及桌面/开始菜单快捷方式更新到最新版。

## 论文图像复现方法

当前版本不生成论文图像。若将来增加科研绘图模块，应把原始数据、参数、脚本和图像分别放入 `data/`、`outputs/`、`scripts/` 和 `figures/`，并在记录中保存输入路径和处理参数，避免把增强图误当成原始定量结果。

## 云同步配置

云同步默认关闭。运行时通过 dart-define 传入 Supabase 项目地址和公开客户端密钥：

```powershell
flutter run -d android `
  --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-publishable-key
```

在 Supabase SQL Editor 执行 `supabase/migrations/001_workspace_records.sql`。该表启用 RLS，用户只能读写自己的记录。首版不是端到端加密；回顾和笔记同步冲突时，会在本地保留冲突副本。旧日记记录仍保留在兼容数据中，并在日回顾中按需迁移。

## 备份与恢复

加密备份使用 PBKDF2-HMAC-SHA256 派生密钥和 AES-256-GCM 加密。密码错误无法解密；恢复前会先显示备份时间和记录数量，用户确认后才替换本地数据。原始实验数据目录不会被应用自动删除或覆盖。

## 测试与验收

```powershell
flutter analyze
flutter test
flutter test test/visual_golden_test.dart
# 自律页面和 Windows 监控专项测试
flutter test test/restriction_policy_test.dart test/restriction_monitor_test.dart test/restriction_security_test.dart test/self_control_importer_test.dart test/restriction_page_test.dart
# 配置 android/key.properties 后执行
powershell -ExecutionPolicy Bypass -File .\tool\build_android.ps1 -Configuration release
# 来源 SelfControl 隔离环境测试（进入来源 checkout 目录并先安装 requirements.txt）
python -m unittest discover -v
```

当前覆盖记录 JSON 往返、SQLite 软删除、AES 备份错误密码与 v1 外层兼容、04:00 边界、周期实例、任务结算、项目/笔记回收站、附件清理、CTDP/RSIP 状态机、RSIP 页面流程、回顾快照、Android 页面 Golden 和指南截图。Golden 使用独立临时数据库；真实数据库必须先手动完成旧版加密备份后再验收。PJA110 真机已验证系统通知权限、通知渠道和即时通知；正式发布前仍需要复验定时通知的休眠/重启/进程恢复、离线同步去重、分享捕获、回收站和多尺寸文字布局。

2026-09-18 本机复核结果：`flutter pub get` 成功，`dart format --output=none --set-exit-if-changed lib test` 无格式变更，`flutter analyze` 无问题，`flutter test --reporter compact` 为 241/241 通过。历史 QA 文档中的测试数量对应各自记录日期，不覆盖本次复核结果。

## 注意事项

- Android 工具链无法正确处理中文工作区路径时，请使用 `tool/build_android.ps1` 从自动创建的 ASCII 暂存副本构建，无需手动复制或移动源码。
- 本地数据库是当前运行设备的数据源，卸载应用前请先导出或备份。
- Supabase 配置只使用公开客户端密钥，不要把服务端密钥写入应用或仓库。
- Android 通知权限申请、通知渠道和即时通知已在连接的 PJA110 真机上验证；厂商后台策略仍可能影响长期驻后台的提醒到达时间。
- Android Release APK 必须使用独立发布密钥签名；缺少 `android/key.properties` 时构建会停止。正式分发前仍需在保留数据的真实设备上验证升级安装，并妥善备份密钥库。

## GitHub / PR 工作流

当前工作区已初始化本地 Git 仓库，并保留基线提交。后续提交应继续拆成小步，先确认 `flutter analyze`、`flutter test` 和目标平台构建，再创建分支、提交和 Draft PR；不要把数据库、备份文件、密钥或实验原始数据提交到仓库。

## 许可证或使用说明

项目尚未指定开源许可证，默认仅供个人研究和学习使用。确定公开发布前，应补充许可证、隐私政策、数据删除说明和 Android 发布签名配置。
