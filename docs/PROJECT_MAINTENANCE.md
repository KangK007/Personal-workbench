# 项目维护与迁移说明

> 更新日期：2026-09-20（Asia/Shanghai）

本文是当前仓库的维护入口，说明哪些文件需要进入 Git、哪些内容由 Flutter 自动生成，以及把项目迁移到另一台电脑后的最短恢复路径。

## 当前状态

- 当前分支：`main`；远程：`origin`（GitHub `KangK007/Personal-workbench`）。
- 应用版本：`0.2.1+6`（上一轮为 `0.2.0+5`）。
- 本轮聚焦 0.2.1+6 发布链：把「柔壤 · 年轮」的**形态**落到页面（上一轮只换了色）、应用图标全链路重制、新增两项门禁，并重新构建两端安装包。
- 当前可用产物为 `dist/PersonalWorkbench_0.2.1+6_windows.zip`（SHA-256 `CD4C2654BB89172D3D02683BEBE26DACFF68FFFB281B7CCDABF3E8CC08BB3F96`）与 `dist/apk/PersonalWorkbench_0.2.1_6_debug-arm64-v8a.apk`（SHA-256 `A5EF2F83962152BC7A1E6BDFD446D28AE400AC99DEF517663DDA1D1EFBFA445B`）；它们属于构建产物，按约定不进入 Git。2026-09-20 已从当前工作区重新构建并安装 Windows Release，Android arm64 Debug 分发副本也已刷新；当日二次复核后又重跑了一次 Windows 打包，使 `dist/` 里的安装器带上快捷方式重试修复。
- Windows Release EXE 与稳定安装目录 EXE 的 SHA-256 均为 `6354AB9BD6E00C791DA1A472A25BDB0DFB608339AA49FF7230B412841032A8D3`，版本资源为 `0.2.1+6`；三个快捷方式（桌面 `Personal Workbench.lnk`、开始菜单 `Personal Workbench.lnk` 和 `个人工作台.lnk`）均已刷新并全部指向 `%LOCALAPPDATA%\Programs\PersonalWorkbench\personal_workbench.exe`。
  - ⚠️ **Windows 构建不是逐字节可复现的**：同一份源码两次构建的 `personal_workbench.exe` 体积相同（575,488 字节）但哈希不同。因此「产物一致」的判据是**版本资源 + AOT 符号探针 + 打包副本与安装副本哈希相同**，不要拿跨构建的哈希互相比对，也不要把某一轮的哈希当成不变量写进验收项。
- Android 分发 APK 的清单版本元数据经 `aapt dump badging` 实测为 `versionCode=6 / versionName=0.2.1`，与 `pubspec.yaml` 一致。
- 本轮界面形态改动已落地：今日页新增概览 Hero 与「下一步行动」层级、列表语言统一为「一行一卡」、语义/分类色按 `rsipNodeTypeColor` 纯函数归位、移动端底栏抽为独立文件 `lib/ui/widgets/mobile_bottom_bar.dart`、`workbench_shell.dart` 导航骨架与 `quick_capture_sheet.dart` 捕获面板重构；`app_theme.dart` 令牌同步扩充。
- 本轮应用图标重制为「新芽 · 破土」：`tool/build_app_icon.py` 为**单一真源**，一次重出品牌母版、Windows `.ico`（7 档逐档渲染）、Android 传统档 + 自适应三层矢量 + 单色档和 `design_preview/icon/` 预览页；规范见 `APP_ICON_SPEC.md`。Windows 图标由 41 KB 增至约 372 KB，是 `personal_workbench.exe` 体积由 243 KB 增至 575 KB 的主因。
- 本轮新增两项门禁：`tool/verify_token_parity.py`（`design_preview/assets/tokens.css` 与 `app_theme.dart` 逐值对应，56 对）与 `tool/verify_glyph_coverage.py`（界面字面量高位字符 vs 5 份字体 cmap）。另有 `tool/build_scheme_c_compare.py`（配色方案对照）与 `tool/fix-symlink-privilege.ps1`（管理员授权符号链接权限）。
- 已在本机完成 `dart format --output=none --set-exit-if-changed lib test`（99 个文件，0 差异）、`flutter analyze`（`No issues found!`）和 `flutter test --reporter compact`（**243/243 通过**）；`tool/verify_colors.py`（未达标配对 0）、`tool/verify_token_parity.py`、`tool/verify_glyph_coverage.py`（无缺字）、`tool/verify_windows_build.py`（探针全部通过）与 `tool/verify_apk.py`（7/7 符合预期）均通过。测试输出中的「磁盘满」仅为错误恢复测试主动注入的预期异常。
- Windows Release、Android Debug/Profile 的既有验收记录保存在 `docs/qa/`。Android Release 仍需要本地签名文件，不能在仓库中伪造或提交。
- `flutter_markdown` 已被上游标记为 discontinued；当前版本保持 API 稳定，迁移到 `flutter_markdown_plus` 应单独安排兼容性和视觉回归，不作为整理工作的一部分。

## 当前进度与待办

### 已完成

- [x] “柔壤·年轮”色彩、圆角、间距和排版令牌落地到 Flutter 主题与 HTML 预览站。
- [x] 导航收敛为 6 个用户心智域，桌面端采用手风琴，移动端统一由底栏“更多”打开系统层入口。
- [x] 页面级语义色、`VineRail` 芽点组件、容器对比度和底部导航净空完成同步；Golden 与回归测试已更新。
- [x] 「柔壤·年轮」的**形态**落地本轮补齐：今日概览 Hero、列表语言统一、移动端底栏独立文件、捕获面板与导航骨架重构；对应的 Golden/UI 审计基线已重录。
- [x] 应用图标全链路重制完成（`tool/build_app_icon.py` 单一真源 → 品牌母版 / Windows ICO / Android 三份矢量 / 预览页），并以 `APP_ICON_SPEC.md` 固化为规范。
- [x] 新增 `verify_token_parity.py` 与 `verify_glyph_coverage.py` 两项门禁，均通过。
- [x] 全量文件盘点、重复/死代码清理和维护文档更新完成；未发现应提交的密钥或发布签名文件。
- [x] 0.2.1+6 的版本号、设置页显示、Windows 资源回退值、用户手册版本行和发布清单已同步。
- [x] Windows/Android 构建脚本的产物清理改为状态校验式删除；Windows 构建增加插件符号链接预建。
- [x] 从当前工作区重建 Windows Release 安装包并刷新桌面/开始菜单三个快捷方式；Windows EXE、安装目录和快捷方式目标已统一到 `0.2.1+6`。
- [x] 从当前工作区重建 Android arm64 Debug APK；构建副本和 `dist/apk` 分发副本已通过 SHA-256 一致性检查，清单版本元数据为 `0.2.1 / 6`。
- [x] 用户手册 DOCX 的版本号已同步至 0.2.1+6；结构化 OOXML 校验通过；当前环境缺少 LibreOffice，尚未完成 PNG 视觉渲染复核。

### 已完成（2026-09-20 二次复核：发布链加固）

- [x] **快捷方式写入不再因瞬时锁致发布失败**。`tool/update_all_shortcuts.ps1` 的 `Update-Shortcut` 与 `packaging/windows/Install-PersonalWorkbench.ps1` 的写入循环各改为 **5 次指数退避重试**（250/500/1000/2000 ms，合计约 3.75 s），每次重试重建 COM 对象（失败的 `Save()` 会让原实例不可用）。安装器随包分发、不能 dot-source 工具库，故该循环在其中刻意重写一份。
- [x] **`build_windows.ps1` 的快捷方式步骤降级为非致命**。该步骤包进 `try/catch`，失败只 `Write-Warning` 并追加一行 `NOTE: software entry points were NOT refreshed…`，脚本退出码仍为 0。判据依据：`package_windows_release.ps1` 只看本脚本的**进程退出码**，而「退出码 1」并不等于「构建失败」；且这一步只是把入口临时指向产物目录，最终由 `Install-PersonalWorkbench.ps1` 收敛到稳定安装目录。
- [x] **三层故障注入验证**（全部实测，非推演）：
  - 用「另一进程以 `FileShare.None` 独占 `.lnk`」注入故障，报错与线上逐字一致（`无法保存快捷方式…`，`FileLoadException`）。
  - 瞬时锁（持锁 4 s）→ `RETRY 1/5…4/5` 后**成功恢复**，退出码 0，耗时 4,078 ms。
  - 持续锁（持锁 60 s）→ 4 次重试后**如实抛错**，耗时 4,071 ms（≈250+500+1000+2000），说明重试没有吞掉真错误。
  - 无锁 → 310 ms 直接成功，零重试。
  - **端到端**：持锁 1800 s 期间跑完真实 `build_windows.ps1`（61 s，`√ Built …exe` 已打印）→ 快捷方式步骤失败 → 只告警 → **退出码 0**，`dist/` 可正常发布。修复前同一路径会以退出码 1 结束。
- [x] **`$LASTEXITCODE` 泄漏一并修掉**。该变量只由原生命令设置，且会**从调用方会话继承**；子脚本自己不归零，调用方拿到的就还是它进来时的值。`package_windows_release.ps1` 与 `build_android.ps1` 末尾缺少归零，于是**成功的打包**可能对外报非零码 —— 实测：直接调用 `package_windows_release.ps1 -SkipBuild` 返回 `-1`，而 `dist/` 已正确刷新、`$?` 为 `True`。两个脚本已与 `build_windows.ps1` 统一补上 `$global:LASTEXITCODE = 0`；回归验证：先把会话里的 `$LASTEXITCODE` 污染成 1，再直接调用，结果为 0。
- [x] **`test/failures/` 陈旧产物已清理**：100 个文件 / 8.22 MB（时间戳 2026-09-18 22:18 ~ 2026-09-20 11:35）。陈旧判定基于证据而非时间窗 —— 最近一次全绿测试（2026-09-20 16:50，`+243 All tests passed!`）之后，该目录**新增文件数为 0**。目录本身也已删除；`flutter_test` 用 `output.parent.createSync(recursive: true)` 按需重建，故不会影响后续失败产物的落盘。清理走项目约定的 `Remove-Verified` 状态校验式删除。

### 待办

- [ ] 在真实 Windows 会话和 Android 真机上复核本轮视觉 Golden 变化、触控/键盘焦点和底栏安全区；仓库测试不能替代平台验收。
- [ ] 完成 Android Release 签名构建、Windows 原生托盘/限制能力、通知休眠恢复和文件选择器窗口激活的外部条件验收。
- [ ] 使用隔离账号复核 Supabase 分页、冲突、失败恢复和 RLS；不要把任何私有密钥写入仓库。
- [ ] 单独评估 `flutter_markdown` → `flutter_markdown_plus` 的兼容性、视觉回归和迁移窗口。
- [ ] 在管理员/真实 Windows 会话中复验插件符号链接预建和 Release 安装包清理；当前自动化环境无法替代系统权限与原生副作用验收。本会话实测 `whoami /priv` 中 `SeCreateSymbolicLinkPrivilege` 仍为「已禁用」，`tool/fix-symlink-privilege.ps1` 的授权尚未在当前令牌生效（改完需重启或注销重登）。
- [ ] 在具备 LibreOffice 的环境中渲染 `docs/manual/个人工作台_用户使用手册.docx`，逐页复核分页、字体、图片和表格布局。
- [ ] `SealLogo`（`lib/ui/widgets/ink_decoration.dart`）与新应用图标**形态不同源**（只共用色板与 0.22 圆角比）。统一需同时改 `shell`/`app` 并重录 golden。
- [ ] `tool/generate_user_manual.py` 的配色常量仍是上一代**整片**色板（`2F7D57`/`1F4D3A`/`1B2B20`/`617268`/`E8F2EC`/`B9CEC0`），会原样印进手册 docx；需先换成现行 `app_theme.dart` 令牌再重生成手册。

## 目录约定

| 目录 | 内容 | 是否提交 |
| --- | --- | --- |
| `lib/` | Flutter 应用源码、模型、数据库、服务、状态和页面 | 是 |
| `test/` | 单元、Widget、Golden 和回归测试 | 是 |
| `assets/` | 应用图标和经过子集化的字体 | 是 |
| `android/`、`windows/` | 平台源码与构建配置 | 是（平台生成文件除外） |
| `supabase/migrations/` | 云同步数据库迁移 | 是 |
| `tool/`、`packaging/` | 构建、打包、字体和文档工具 | 是 |
| `docs/` | 用户手册、设计交接、QA 证据和本文件 | 是 |
| `.dart_tool/`、`build/`、`coverage/`、`dist/` | 依赖缓存、构建结果、覆盖率和分发包 | 否，可删除并重新生成 |
| `android/.gradle/`、`android/local.properties`、`windows/flutter/ephemeral/` | 本机工具链缓存或路径配置 | 否 |
| `*.log`、`.idea/`、`.workbuddy/`、`*.iml` | 本机日志、IDE 配置或工作区状态 | 否 |

原始科研数据不属于本应用仓库。若以后在工作区放置 `raw/`、`data/`、`original/`、`experiment/` 或 `measurements/`，构建脚本会主动排除这些目录，且不得把它们当作应用备份。

## 迁移到新电脑

1. 安装 Flutter 3.38.9 stable（或在完成兼容性验证后使用更新版本）、Dart 3.10.8、Android SDK/Java 17+；Windows 构建还需要 Visual Studio 2022 C++ 桌面工具。
2. 克隆仓库并进入项目根目录：

   ```powershell
   git clone https://github.com/KangK007/Personal-workbench.git
   Set-Location Personal-workbench
   flutter pub get
   flutter analyze
   flutter test --reporter compact
   ```

3. 运行开发版本：

   ```powershell
   flutter devices
   flutter run -d windows
   # 或连接 Android 设备后：
   flutter run -d android
   ```

4. Windows 使用 `tool/build_windows.ps1`；Android 使用 `tool/build_android.ps1`。这些脚本会把源码复制到 ASCII 临时目录，避免中文路径导致 Gradle/MSBuild 问题，并自动生成本机所需的 `local.properties`、Gradle 缓存和构建目录。
5. 若需要 Android Release，先在本机创建 `android/key.properties` 和独立 keystore。两者已被 `.gitignore` 排除，密码不得写入脚本、README 或 Git 历史。
6. 若启用云同步，在运行时通过 `--dart-define=SUPABASE_URL=...` 和 `--dart-define=SUPABASE_ANON_KEY=...` 注入公开客户端配置，并在 Supabase SQL Editor 执行 `supabase/migrations/001_workspace_records.sql`。不要使用 service-role key。

## 可复现检查

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --reporter compact
```

门禁脚本（配色、令牌一致性、字形覆盖、两端产物探针）：

```powershell
python tool/verify_colors.py
python tool/verify_token_parity.py
python tool/verify_glyph_coverage.py
python tool/verify_windows_build.py
python tool/verify_apk.py
```

> `verify_glyph_coverage.py` 依赖 `fontTools`；本机仅系统 Python 3.11 装有该包。

平台构建：

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_windows.ps1 -Configuration release
powershell -ExecutionPolicy Bypass -File .\tool\build_android.ps1 -Configuration debug -AbiMode arm64
```

Windows 的「构建 + 打包 + 安装」一步到位用 `tool/package_windows_release.ps1 -Configuration release -Install`；只重新打包不重建用 `-SkipBuild`。

构建生成物只用于本机测试或分发，不应通过 `git add -A` 加入仓库。提交前使用 `git status --short --ignored` 检查缓存、日志、APK、ZIP 和签名文件是否仍被忽略。

## 尚未闭环的外部条件

以下事项需要真实设备、隔离账号、隔离 Windows 会话或用户私有凭据，不能通过整理代码伪造为完成：

- Android Release 签名构建；
- 真实 Supabase 分页、冲突、失败恢复和 RLS 验收；
- Windows 托盘、开机启动、系统级热键、进程限制及 hosts/UAC 副作用验收；
- Android 休眠/重启后的定时通知；
- 原生文件选择器的真实窗口激活复验和 Windows 全状态指针/键盘遍历。

这些事项及证据状态以 `docs/qa/RELEASE_CHECKLIST.md`、`docs/qa/FINAL_QA_REPORT.md` 和 `docs/qa/TEST_MATRIX.md` 为准。它们是发布前置条件，不是当前代码整理遗漏。

## Git 协作约定

- 只提交源码、测试、配置模板、迁移脚本和说明文档；不提交数据库、用户备份、密钥、缓存或构建产物。
- 修改前检查 `git status --short`；提交前查看 `git diff --cached`。
- 发布前至少运行格式检查、`flutter analyze`、完整测试和目标平台构建。
- README、用户手册或 QA 文档发生变化时，在提交说明中写明变更范围和验证命令。
