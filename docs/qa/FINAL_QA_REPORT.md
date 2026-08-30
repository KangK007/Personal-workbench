# 个人工作台最终质量审查报告

> 审查完成日期：2026-08-31（Asia/Shanghai）
> Git 审查起点：`618a44a`；合并来源：`1220614` 与 `251684f`
> 应用版本：0.1.0+4
> 测试基准：`docs/qa/PROJECT_MAP.md` 与 `docs/qa/TEST_MATRIX.md`

## 1. 发布结论

**NOT READY**。

Windows Release、Android Debug 与 Android Profile 已用最终代码重新构建，Windows ZIP 已重打包并安装；234 项 Flutter 测试和 33 张 Golden 均通过。但 Android Release 缺少签名凭据，完整 Windows 原生四维交互复验、更新后 DOCX 逐页视觉渲染、真实 Supabase、系统副作用及 Android 休眠/重启通知仍受环境或安全条件阻塞。不能把自动化替代证据写成真实平台 PASS。

## 2. 项目与测试环境

Flutter 3.38.9、Dart 3.10.8、Material 3，目标平台为 Windows 与 Android；本地数据使用 SQLite，可选 Supabase 同步。Windows 使用隔离数据库启动；Android 既有真实运行证据来自 Android 15 / API 35 模拟器，SDK 36、JDK 21。

## 3. 覆盖规模

| 指标 | 结果 |
| --- | ---: |
| 测试 Case | 256 |
| PASS / FAIL / BLOCKED | 245 / 0 / 11 |
| Flutter 自动测试 | 234 / 234 |
| 当前可构建页面/子页表面 | 37 |
| 全页面布局场景 | 518 |
| 页面交互-尺寸场景 | 222 |
| Dialog-尺寸场景 | 24 |
| Golden 基线 | 33 |
| 真实运行截图 | 15 |
| 已登记 / 已修复 / 完整 VERIFIED 缺陷 | 16 / 16 / 15 |

旧文档中的 39 个表面统计已按当前 `_auditSurfaces` 纠正为 37 个；旧矩阵总数还漏计了 ID 含数字的 7 条 `A11Y-*`。纳入专注预设窄窗四下拉场景、Android Profile 和 Windows 安装包 Case 后，逐行解析的实际总数为 256。518 个布局场景为 37 个表面 × 14 个窗口、主题、字号、动效和数据状态组合。

## 4. Page × State × Interaction × Window Size

37 个表面分别在 375×812、1200×864、1536×864 触发 Hover、Pressed、Focus 和键盘状态，并打开/关闭每个实际存在的 Popup/Dropdown，共 222 个页面交互-尺寸场景。6 个共享 Dialog 在 375×812、375×812 + 200% 字号、1200×864、1536×864 下完成 Focus、Tab、Escape 和长文本回归，共 24 个场景。

Disabled、Selected、Loading、Empty、Error、长文本由主题状态测试、空数据矩阵、故障注入和功能测试补足。逐表面明细为 `U4D-001`～`U4D-037`；本轮 Windows 原生完整指针/键盘视觉复验为 `U4D-038 BLOCKED`。

## 5. 功能与回归结果

13 项功能优化均有定向测试：任务群生命周期、任务卡片元数据、多级子任务、关联 Dialog、周视图今天列、项目五面板、习惯按钮与 04:00 日界、成长页间距、收件箱导航、今日时间进度、回顾预览/编辑权限及回顾类别切换。

本轮新增 BUG-014：共享 Dialog 缺少统一的焦点请求和 Escape 路径；BUG-015：QA 统计漏计 `A11Y-*` 且表面总数过期；BUG-016：专注预设 4 个 Dropdown 在 375px 宽下溢出。修复中还验证了 Escape 在 Dropdown Open 时只关闭顶层菜单。搜索焦点陷阱、24 个 Dialog、222 个页面交互、专注预设四下拉、Golden/UI 子集 29/29 和完整测试 234/234 全部通过。BUG-010 已修复但真实原生文件选择器复验仍受阻，因此 16 个缺陷中 15 个达到完整 `VERIFIED`。

## 6. UI/UX、可访问性与性能

- 浅色 7 视口、深色 2 视口、减少动效 2 视口、200% 字号和空数据 2 视口覆盖 37 个表面。
- 33 张 Golden 未更新基线即通过；UI/Golden 定向套件 29/29 通过。
- 主要按钮主题提供 Hover、Focus、Pressed、Disabled 状态；状态文字不只依赖颜色。
- 共享 Dialog 支持路由焦点、Tab 焦点约束和 Escape；任务群保存中的 `PopScope` 仍生效。
- 1000 条任务列表、Timer/监听器释放和既有启动计时测试保持通过；未发现新的用户可感知性能回归。

## 7. 静态检查、测试与构建

| 检查 | 结果 |
| --- | --- |
| `flutter pub get` | PASS；1 个停用依赖，38 个不兼容约束的新版本，作为风险记录 |
| `dart format --output=none --set-exit-if-changed lib test` | PASS |
| `flutter analyze` | PASS，No issues found |
| `flutter test --reporter compact` | PASS，234/234 |
| Golden/UI 子集 | PASS，29/29 |
| Windows Release | PASS，最终代码重建并更新 3 个快捷方式 |
| Android Debug | PASS，干净构建并更新构建/分发 APK |
| Android Profile | PASS，重新构建并更新构建/分发 APK |
| Android Release | BLOCKED：缺少 `android/key.properties` 与私有 keystore |

## 8. 真实运行与日志

最终代码的 Windows Debug 已使用独立数据库 `qa-20260831.db` 真实启动：进程持续运行，主窗口句柄有效，标题为“个人工作台”，SQLite 创建为 40,960 bytes。Windows Release 随后重新构建。Computer Use 可以捕获窗口状态，但多次执行原生点击/激活均返回 `failed to activate captured window`，因此本轮完整原生 Hover/Focus/Pressed/Dialog/Resize 复验不能标记 PASS。

既有 Android 模拟器证据覆盖冷启动、IME/Back、任务持久化、权限拒绝/允许、即时通知、外部分享、横屏、800×1200 窗口和 logcat；宿主 ADB/图形后端不稳定，休眠/重启定时通知保持 BLOCKED。

## 9. 文档结果

最新版 `docs/manual/个人工作台_用户使用手册.docx` 已由 `python-docx` 重新生成：20 个章节、21 张界面截图、199 个段落、2 张表。OOXML 几何断言通过；可访问性审计为 0 high / 0 medium / 0 low，并为两张表补充 Word 表头语义。

当前环境缺少可调用的 LibreOffice/Word 渲染器，`render_docx.py` 返回 `FileNotFoundError [WinError 2]`。因此更新后文件的逐页视觉检查为 `DOC-006 BLOCKED`；历史 29 页检查不能替代当前版本。

## 10. 产物

| 产物 | 大小 | SHA-256 |
| --- | ---: | --- |
| `build/windows/x64/runner/Release/personal_workbench.exe` | 243,712 bytes | `994FC1DD070074E195761DD8B7FDA0A102E06A00D2775778C1CA2A5152B7FC48` |
| `dist/PersonalWorkbench_0.1.0+4_windows.zip` | 44,704,486 bytes | `FA48366AFECAAB018F33EF8366C9662BFA2B52348D4A3787D4B56ACAE9F30FB5` |
| `build/app/outputs/flutter-apk/app-debug.apk` | 192,809,709 bytes | `A3546059ABE8FA5AC188C0F6BBE38C70D84B453D6F6D3FAA512D54DBAE9259AB` |
| `dist/apk/PersonalWorkbench_0.1.0_4_debug.apk` | 192,809,709 bytes | 同上 |
| `build/app/outputs/flutter-apk/app-profile.apk` | 121,121,250 bytes | `2C78B7C3DC37A4F91149E80B301509CE49B7695C88A23F2F6AFAF0912092FC69` |
| `dist/apk/PersonalWorkbench_0.1.0_4_profile.apk` | 121,121,250 bytes | 同上 |
| `docs/manual/个人工作台_用户使用手册.docx` | 1,431,324 bytes | `7CE7058FDA2B1426F4BA3681D760C7E89C2CC0879AE62B5BB0047FCA9693182F` |

稳定安装目录 `%LOCALAPPDATA%\Programs\PersonalWorkbench` 中的 EXE 与上述 Windows Release 哈希一致；桌面和两个开始菜单快捷方式均指向该稳定安装目录，目标存在。

## 11. BLOCKED 清单

1. `ENV-003`：Stitch MCP 未配置。
2. `BLD-009`：缺少 Android Release 签名文件与私有密钥。
3. `GLB-002`：共享桌面下未安全触发系统级快速新增热键。
4. `RST-008`：无隔离 Windows VM，不执行真实进程终止/托盘受保护退出。
5. `RST-009`：无隔离 Windows VM，不修改真实 hosts/UAC 状态。
6. `ATT-004`：原生文件选择器修复后的真实输入复验受窗口激活能力阻塞。
7. `SET-006`：缺少隔离 Supabase 端点、密钥和账号。
8. `PLT-001`：真实托盘、开机启动和 Windows 通知需要隔离用户会话。
9. `PLT-003`：Android 休眠/重启定时通知受模拟器宿主不稳定阻塞。
10. `DOC-006`：更新后的 DOCX 缺少可调用渲染器，无法逐页视觉复验。
11. `U4D-038`：Windows 原生完整四维交互无法激活捕获窗口。

## 12. 已知风险

- `flutter_markdown 0.7.7+1` 已停用；迁移需要独立 Markdown 兼容和视觉回归。
- Android 构建仍有第三方 Manifest namespace、Java 8 目标、SDK XML 与 Gradle 9 兼容警告。
- Android Debug APK 含多 ABI 和调试符号，体积不代表 Release。
- 没有真实远端同步与物理设备后台策略证据，不能推断长期同步或通知可靠性。
