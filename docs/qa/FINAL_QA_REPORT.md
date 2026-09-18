# 个人工作台最终质量审查报告

> 审查完成日期：2026-09（Asia/Shanghai）
> Git 审查起点：`1d9c633`（2026-08-31）+ 本轮工作区全部修改
> 应用版本：0.1.0+4
> 测试基准：`docs/qa/PROJECT_MAP.md` 与 `docs/qa/TEST_MATRIX.md`

## 1. 发布结论

**READY WITH KNOWN ISSUES**。

Windows Release 与 Android Debug/Profile 均以最终代码完成干净构建；本轮 241 项 Flutter 测试全部通过；真实 Windows 应用完成启动、窗口渲染、数据库读写、四档窗口尺寸调整、窄窗移动布局、冷启动计时与干净退出验证；54 张 Golden/审计截图健康检查通过；真实用户数据库 324 条记录经字体覆盖检查无缺失字形。

11 个 BLOCKED 项全部为环境或凭据限制（缺少 Android 发布签名密钥、隔离 Supabase 账号、隔离 Windows VM、可调用的 DOCX 渲染器、Stitch MCP），不是产品代码缺陷。Android Release APK 需要用户提供 `android/key.properties` 与私有 keystore 后才能生成。

## 2. 项目与测试环境

Flutter 3.38.9、Dart 3.10.8、Material 3；目标平台 Windows 与 Android；本地数据 SQLite（`sqflite_common_ffi`），可选 Supabase 同步。真实运行在 Windows 11 25H2（1280×720 初始窗口）执行；Android 证据包括既有 API 35 模拟器记录、离线构建验证，以及 2026-09-18 在 OnePlus Ace 2 Pro（型号 `PJA110`，Android 16 / API 36，ADB `ec47ee9f`）上的复核。

## 3. 覆盖规模

| 指标 | 结果 |
| --- | ---: |
| 测试 Case | 261 |
| PASS / FAIL / BLOCKED | 250 / 0 / 11 |
| Flutter 自动测试 | 241 / 241（含本轮 Android/UI 回归） |
| 当前可构建页面/子页表面 | 37 |
| 全页面布局场景 | 518 |
| 页面交互-尺寸场景 | 222 |
| Dialog-尺寸场景 | 24 |
| Golden 基线 | 33+（另 21 张 UI 审计截图） |
| 真实运行截图（本轮新增） | 3（主界面 / 窄窗移动布局 / 早期冒烟） |
| 已登记 / 已修复 / 完整 VERIFIED 缺陷 | 18 / 18 / 17（BUG-010 真实文件选择器复验仍受窗口激活能力阻塞） |

## 4. Page × State × Interaction × Window Size

37 个表面在 375×812、1200×864、1536×864 三尺寸触发 Hover、Pressed、Focus 与键盘状态并开关全部 Popup/Dropdown（222 个场景）；6 个共享 Dialog 在 4 个尺寸/字号场景完成 Focus、Tab、Escape 与长文本回归（24 个场景）。Disable/Selected/Loading/Empty/Error/长文本由主题状态测试、空数据矩阵、故障注入与功能测试补足；逐表面明细 `U4D-001`～`U4D-039`。

## 5. 功能与回归结果

- 全部核心工作流（今日承诺/日结、任务 CRUD 与批量、项目五面板、周视图时间块、专注计时、自律规则、笔记版本、日周月回顾、目标树、习惯矩阵、RSIP 国策、成长 XP/押注、设置）由控制器/Widget 测试真实渲染验证。
- 本轮新增并验证：任务完成"航迹节点落定"脉冲（一次性、减少动效跳过）、日结收尾仪式覆盖层、今日待安排空态升级、减少动效下任务行 AnimatedSize 崩溃修复。
- 真实 Windows 运行补充验证：启动 339ms 出主窗口、工作集 110MB、四档窗口尺寸（800×600/420×780/1280×800/1920×1080）调整无崩溃、420×780 窄窗移动布局渲染正常、真实数据库 324 条记录字体覆盖 100%。

## 6. UI/UX、可访问性与性能

- 浅色 7 视口、深色 2 视口、减少动效、200% 字号与空数据矩阵覆盖 37 个表面；54 张截图全部健康（无空白/全黑页）。
- 对比度：浅深主题 10 组关键色均 ≥4.5:1；状态不只依赖颜色（文字/图标/结构冗余）。
- 键盘：37 表面 × 3 尺寸 Focus/Tab 矩阵、24 个 Dialog Escape/焦点场景、专注预设四下拉窄窗场景均通过。
- 性能：1000 条任务列表渲染+滚动 1.6s；真实 Release 冷启动 339ms；Timer/监听器释放测试通过；无新增用户可感知性能回归。

## 7. 静态检查、测试与构建

| 检查 | 结果 |
| --- | --- |
| `flutter pub get` | PASS；`flutter_markdown 0.7.7+1` 停用（RISK-001）、46 个不兼容新版本作风险记录 |
| `dart format --output=none --set-exit-if-changed lib test` | PASS |
| `flutter analyze` | PASS，No issues found |
| `flutter test --reporter compact` | PASS，241/241 |
| Golden + UI 审计 + 交互矩阵 | PASS，47/47（设置页修复后） |
| Windows Release 干净构建 | PASS，最终代码重建并更新 3 个快捷方式 |
| Android Debug arm64 干净构建 | PASS，构建/分发 APK 已更新 |
| Android Profile | PASS（既有证据） |
| Android Release | BLOCKED：缺少 `android/key.properties` 与私有 keystore |

本轮 Android arm64 Debug 构建产物为 `120,512,575` bytes，构建 APK 与 `dist/apk/` 分发副本 SHA-256 一致；Golden 与 UI 审计基准按实际主题、字号和布局变化更新，未放宽像素容差或修改断言。

## 8. 真实运行与日志

最终代码 Windows Release 真实运行：进程持续存活、主窗口标题"个人工作台"、窗口 1280×720 渲染正常（截图像素健康）、SQLite（`%APPDATA%\com.personalworkbench\个人工作台\personal_workbench.sqlite`，992KB）正常读写、干净退出。四档窗口尺寸调整无崩溃。真实运行截图：

- `docs/qa/screenshots/runtime_smoke_main.png`（1280×720 主界面）
- `docs/qa/screenshots/runtime_narrow_mobile.png`（420×780 移动布局）

Android 真机复核：应用冷启动、主界面/更多抽屉/笔记二级页返回路径正常；系统通知设置显示允许通知，应用设置触发的“通知已启用”即时通知出现在系统通知栏；`dumpsys notification` 可见 `workbench_updates` 渠道和应用 `PendingIntent`。本次未清除应用数据。定时通知经过锁屏、休眠、重启和进程被杀后的送达仍未完成，继续保持 `BLOCKED`。

## 9. 文档结果

`docs/qa/PROJECT_MAP.md`、`TEST_MATRIX.md`、`BUGS.md`、`UI_UX_AUDIT_FINAL.md` 已更新至本轮证据；`docs/manual/个人工作台_用户使用手册.docx` 由 `python-docx` 重新生成（见第 10 节与手册章节）。

## 10. 产物

| 产物 | 大小 | 说明 |
| --- | ---: | --- |
| `build/windows/x64/runner/Release/personal_workbench.exe` | ~0.24 MB | Windows Release（含子集化字体，体积已优化） |
| `dist/PersonalWorkbench_0.1.0+4_windows.zip` | ~40 MB | Windows 安装包 |
| `dist/apk/PersonalWorkbench_0.1.0_4_debug.apk` | ~181 MB | Android universal debug |
| `dist/apk/PersonalWorkbench_0.1.0_4_debug-arm64-v8a.apk` | ~115 MB | Android arm64 侧载（推荐） |
| `dist/apk/PersonalWorkbench_0.1.0_4_debug-armeabi-v7a.apk` | ~115 MB | 32 位兼容 |
| `dist/apk/PersonalWorkbench_0.1.0_4_debug-x86_64.apk` | ~151 MB | 模拟器 |
| `dist/apk/PersonalWorkbench_0.1.0_4_profile.apk` | ~113 MB | 性能分析 |
| `docs/manual/个人工作台_用户使用手册.docx` | 见手册生成记录 | Word 用户手册 |

## 11. BLOCKED 清单（全部为环境/凭据限制）

1. `ENV-003`：Stitch MCP 未配置；以真实 GUI、Golden 与像素检查替代。
2. `BLD-009`：缺少 Android Release 签名文件与私有密钥。
3. `GLB-002`：共享桌面下未安全触发系统级快速新增热键（注册与冲突路径已自动测试）。
4. `RST-008`：无隔离 Windows VM，不执行真实进程终止/托盘受保护退出（护栏已自动测试）。
5. `RST-009`：无隔离 Windows VM，不修改真实 hosts/UAC 状态（备份/解析已自动测试）。
6. `ATT-004`：原生文件选择器修复后真实输入复验受窗口激活能力阻塞（焦点恢复自动回归通过）。
7. `SET-006`：缺少隔离 Supabase 端点、密钥和账号（分页/冲突/并发已由 fake 覆盖）。
8. `PLT-001`：真实托盘/开机启动/Windows 通知需要隔离用户会话（平台通道已自动覆盖）。
9. `PLT-003`：Android 定时通知经过锁屏、休眠、重启和进程被杀后的送达仍需专门时序复验；PJA110 真机已确认通知权限、通知渠道和即时通知通过。
10. `DOC-006`：当前 DOCX 无可调用渲染器，逐页视觉复验需在 Word/LibreOffice 完成。
11. `U4D-038`：Windows 原生完整四维交互无法激活捕获窗口（隔离启动与语义读取成功）。

## 12. 已知风险

- `flutter_markdown 0.7.7+1` 已停用；迁移需要独立 Markdown 兼容与视觉回归（RISK-001）。
- Android 构建仍有第三方 Manifest namespace、Java 8 目标、SDK XML 与 Gradle 9 兼容警告（RISK-002）。
- Android 长期后台、休眠/重启和进程被杀后的送达仍需独立时序复验，厂商后台策略可能影响提醒到达时间（RISK-003）。
- 没有真实远端同步证据；长期同步可靠性需在真实 Supabase 账号下验证。

## 13. 本轮修复摘要

| 编号 | 严重度 | 内容 | 状态 |
| --- | --- | --- | --- |
| BUG-017 | P2 | 设置页"成长主题"虚假承诺与不可操作候选色块 | VERIFIED |
| BUG-018 | P3 | Windows 构建脚本对运行实例锁定产物给出含糊错误 | VERIFIED |

（BUG-001～016 为上一轮已 VERIFIED 缺陷，见 `docs/qa/BUGS.md`。）
