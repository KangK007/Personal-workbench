# 项目维护与迁移说明

> 更新日期：2026-09-19（Asia/Shanghai）

本文是当前仓库的维护入口，说明哪些文件需要进入 Git、哪些内容由 Flutter 自动生成，以及把项目迁移到另一台电脑后的最短恢复路径。

## 当前状态

- 当前分支：`main`；远程：`origin`（GitHub `KangK007/Personal-workbench`）。
- 应用版本：`0.1.0+4`。
- 本轮界面与导航整理已完成：主题令牌、通用组件、6 域桌面导航、移动端“今日/计划/记录/成长/更多”底栏、页面配色、预览站和 Golden 基线已同步；被新导航取代的 `DiaryPage`、`MorePage` 及对应旧基线已移除。
- 本轮还新增了 `ORGANIC_UI_SPEC.md`、`FILE_INVENTORY_AUDIT.md`、`design_preview/organic/index.html` 以及颜色、APK、Windows 构建验证脚本；`tool/build_android.ps1` 已同步签名和路径校验流程。
- 已在本机完成 `dart format --output=none --set-exit-if-changed lib test`（无差异）、`flutter analyze`（无问题）和 `flutter test --reporter compact`（242/242 通过）；测试输出中的“磁盘满”仅为错误恢复测试主动注入的预期异常。
- Windows Release、Android Debug/Profile 的既有验收记录保存在 `docs/qa/`。Android Release 仍需要本地签名文件，不能在仓库中伪造或提交。
- `flutter_markdown` 已被上游标记为 discontinued；当前版本保持 API 稳定，迁移到 `flutter_markdown_plus` 应单独安排兼容性和视觉回归，不作为整理工作的一部分。

## 当前进度与待办

### 已完成

- [x] “柔壤·年轮”色彩、圆角、间距和排版令牌落地到 Flutter 主题与 HTML 预览站。
- [x] 导航收敛为 6 个用户心智域，桌面端采用手风琴，移动端统一由底栏“更多”打开系统层入口。
- [x] 页面级语义色、`VineRail` 芽点组件、容器对比度和底部导航净空完成同步；Golden 与回归测试已更新。
- [x] 全量文件盘点、重复/死代码清理和维护文档更新完成；未发现应提交的密钥或发布签名文件。

### 待办

- [ ] 在真实 Windows 会话和 Android 真机上复核本轮视觉 Golden 变化、触控/键盘焦点和底栏安全区；仓库测试不能替代平台验收。
- [ ] 完成 Android Release 签名构建、Windows 原生托盘/限制能力、通知休眠恢复和文件选择器窗口激活的外部条件验收。
- [ ] 使用隔离账号复核 Supabase 分页、冲突、失败恢复和 RLS；不要把任何私有密钥写入仓库。
- [ ] 单独评估 `flutter_markdown` → `flutter_markdown_plus` 的兼容性、视觉回归和迁移窗口。

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

平台构建：

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_windows.ps1 -Configuration release
powershell -ExecutionPolicy Bypass -File .\tool\build_android.ps1 -Configuration debug -AbiMode arm64
```

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
