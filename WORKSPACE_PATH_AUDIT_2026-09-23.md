# 三个工作区路径审查报告（2026-09-23）

审查对象：`D:\pw`、`D:\pwb`、`D:\Project\个人工作台`。

## 结论摘要

1. `D:\pw` 是指向 `D:\Project\个人工作台` 的 NTFS Junction，不是第二份源码副本。两处的 Git HEAD、Git 索引、跟踪路径和文件 SHA-256 均一致；在任一处编辑会修改同一份文件。
2. `D:\Project\个人工作台` 是当前主工作区：版本 `0.2.1+6`，Git `main` 与 `origin/main` 的 `d62540f` 对齐，但存在本地未提交的审查/文档/导入校验改动。
3. `D:\pwb` 是独立的旧 Flutter 工作区：版本 `0.1.0+3`，无有效分支提交可用，Git 索引引用了缺失对象；工作区保留旧功能、旧资源和大量生成物，不能直接当作当前版本的替代目录。
4. 推荐只保留 `D:\Project\个人工作台` 作为源码目录，同时保留 `D:\pw` 这个兼容路径（继续作为 Junction）或在确认没有外部调用后删除该 Junction。`D:\pwb` 应先归档为只读快照，完成差异取证后再删除；不建议把三个目录内容直接合并覆盖。

## 一、路径身份与规模

| 路径 | 身份 | 版本 | Git 状态 | 文件规模（含生成物） |
|---|---|---:|---|---:|
| `D:\pw` | `D:\Project\个人工作台` 的 Junction | 0.2.1+6 | `main`=`origin/main`=`d62540f`，11 个工作区改动 | 521 文件，约 367.3 MiB |
| `D:\Project\个人工作台` | 当前真实目录/主工作区 | 0.2.1+6 | 同上 | 521 文件，约 367.3 MiB |
| `D:\pwb` | 独立旧工作区 | 0.1.0+3 | 无可用分支提交；索引有缺失 blob | 2466 文件，约 2.76 GB |

规模统计包含 `.git`、构建和缓存目录。排除这些目录后，当前主工作区约 330 个项目文件；`D:\pwb` 的源码/文档部分约 200 余个文件，额外空间主要来自 `build/`（约 2.28 GiB）和 `.dart_tool/`（约 229 MiB）。

### `D:\pw` 与 `D:\Project\个人工作台` 的关系

PowerShell 文件属性显示：

```text
D:\pw  LinkType=Junction  Target=D:\Project\个人工作台
```

两处的以下内容已核对一致：

- Git HEAD：`d62540f32ab6c3f5f1a42f71b281da61ca974ed7`；
- Git 索引大小和 SHA-256；
- `git ls-files` 跟踪路径集合；
- 376 个已跟踪文件的内容哈希；
- `git status` 输出。

因此不应对这两处做“目录合并”；它们本质上是同一个工作区的两个访问入口。

## 二、三个目录各自包含的内容

### 1. 当前主工作区：`D:\Project\个人工作台`

这是完整的 Flutter Windows + Android 项目，包含：

- `lib/`：应用入口、模型、SQLite 数据层、备份/迁移、专注/通知/附件/搜索/自律/Supabase 服务、状态控制器、桌面与移动页面和通用组件；
- `android/`：Android Manifest、Gradle/Kotlin 配置、通知/分享相关声明、图标资源和签名配置示例；
- `windows/`：Flutter Windows Runner、托盘/原生活动桥、自律 hosts 原生桥、插件注册和图标；
- `test/`：数据库、备份、附件、控制器、协议、自律、UI、Golden、可靠性和迁移测试；
- `docs/`：用户指南、项目维护、功能对照、QA 报告、截图、UI 审计证据和 Word 手册；
- `design_preview/`、`design-system/`、`.impeccable/`：设计预览、设计令牌和审查记录；
- `packaging/windows/`：Windows 安装、卸载、发布和紧急恢复脚本；
- `tool/`：Windows/Android 构建、发布校验、字体/图标/文档生成和视觉门禁脚本；
- `supabase/migrations/`：云同步表和 RLS 迁移；
- 根目录 `pubspec.yaml`、`analysis_options.yaml`、`README.md`、审计文档和版本锁定文件。

主工作区不包含当前有效的 `.dart_tool/`、`build/`、`dist/` 等构建缓存（这些目录已清理或被忽略）。

### 2. 兼容路径：`D:\pw`

内容与主工作区完全相同，所有文件职责也完全相同。它的用途是提供短 ASCII 路径，历史上可能用于：

- 缩短 Flutter/CMake/Gradle 路径；
- 兼容旧脚本、IDE 配置或快捷方式中写死的 `D:\pw`；
- 在中文路径构建受阻时作为访问入口。

当前构建脚本已经使用 `%LOCALAPPDATA%\PersonalWorkbenchBuild\...` 的 ASCII 暂存/镜像机制，因此 `D:\pw` 不再是唯一的构建规避方案，但仍可能有外部快捷方式依赖。

### 3. 旧工作区：`D:\pwb`

这是 0.1 主线时代的独立副本，包含旧版源码和较早的验证资产：

- 旧版控制器和页面仍包含 `diary_page.dart`、`more_page.dart` 等当前主线已移除/合并的页面；
- 自律模块、行为页面、批量操作、任务层级和新的工作台控制器拆分尚未完整同步；
- 使用旧的 `BarlowCondensed` 字体和旧图标资源，当前主线已改为 IBM Plex/LXGW 字体和新版图标；
- 保留旧版 `test/goldens/windows_*` 基线和 `docs/images/ui_audit/` 截图；当前主线已迁移到 `wide_*`、`ui_audit/` 和新的 QA 证据结构；
- 保留旧版 Windows/Android 构建和桌面测试脚本，当前主线增加了发布打包、ASCII 构建镜像和校验门禁；
- 根目录有 3 个旧 Word 文档，其中一个是“去除宠物版”变体；
- 生成物包括 `build/` 约 2.28 GiB、`.dart_tool/` 约 229 MiB、`android/.gradle/` 约 17 MiB、`coverage/`、`.workbuddy/` 和 `windows/flutter/ephemeral/`。

`D:\pwb` 的 Git 曾有 0.1 时代的提交记录（reflog 中可见），但当前没有有效 refs，且 `git fsck` 报告索引 cache-tree 和多个 blob 缺失。因此它只能作为文件快照/历史取证来源，不能作为可靠的 Git 备份。

## 三、差异分类

### A. 版本和依赖差异

主工作区相对 `D:\pwb`：

- 版本从 `0.1.0+3` 升为 `0.2.1+6`；
- `supabase_flutter` 从 `^2.17.1` 升为 `^2.17.2`；
- 移除了旧的 `fluentui_system_icons`、`google_fonts` 依赖；
- 增加并注册 IBM Plex Sans SC、IBM Plex Mono、LXGW WenKai GB 字体；
- Android Manifest 增加精确闹钟、备份控制和新版自律/通知相关配置；
- 构建脚本改为 ASCII 暂存/镜像构建并增加 Release、ABI、产物校验和发布清理逻辑。

### B. 生产代码差异

旧目录独有的生产文件包括：

- `lib/ui/pages/diary_page.dart`、`lib/ui/pages/more_page.dart`；
- `assets/fonts/BarlowCondensed-SemiBold.ttf`；
- 旧版 Windows Golden 基线。

主工作区新增或拆分出的生产能力包括：

- `restriction_*` 自律模型、策略、监控和安全服务；
- `self_control_importer.dart`；
- `restriction_controller.dart`、`rsip_controller.dart`、`workbench_controller_base.dart`；
- 行为、限制、移动底栏、批量任务、任务层级和关系选择等页面/组件；
- Windows hosts 原生桥和紧急恢复脚本。

这不是简单的文件移动，而是 0.1 到 0.2.1 的功能演进和页面架构调整。

### C. 文档和证据差异

`D:\pwb` 的文档集中在功能复刻、旧 UI 优化和基础用户指南；主工作区增加了项目维护、文件清单、QA 矩阵、发布清单、代码审查、平台阻塞和 UI 审计证据。旧文档中的版本、页面名称、构建命令和测试数字不能直接用于当前版本。

### D. 生成物差异

`D:\pwb` 的绝大多数额外文件不是源码，而是本地构建缓存：

- `build/`：APK、Windows Release、Flutter 资产、Gradle/CMake 中间物；
- `.dart_tool/`：Dart/Flutter 包解析和编译缓存；
- `android/.gradle/`、`android/build/`：Gradle 缓存和问题报告；
- `windows/flutter/ephemeral/`：Flutter 生成的 Windows 插件/引擎中间物；
- `coverage/`、`.workbuddy/`、`tool/__pycache__/`：测试覆盖率、工具缓存和 Python 字节码。

这些目录不应从旧目录复制到主工作区，也不应作为版本或功能差异判断依据。

## 四、为什么会拆成三个路径

综合文件、版本和 Git 证据，拆分原因是三种因素叠加：

1. **路径兼容**：`D:\pw` 是为中文项目路径准备的短路径别名，后续通过 Junction 保持与真实工作区同步。
2. **版本演进**：`D:\pwb` 是早期 0.1 主线的独立 checkout/工作副本，后来主线迁移到中文目录并继续演进到 0.2.1+6。
3. **构建残留**：旧目录曾运行过 Android/Windows 构建，因此缓存和产物长期留在 `D:\pwb`，使它看起来像“另一套完整项目”。

没有证据表明三个目录是按运行时功能拆分的三个子项目；它们不是“Windows 版、Android 版、服务端版”这种功能划分。

## 五、能否合并或只保留一个目录

### 明确结论

- `D:\pw` 与 `D:\Project\个人工作台`：不需要合并。它们是同一目录的两个入口。建议主开发统一使用 `D:\Project\个人工作台`，短路径只作为兼容别名保留。
- `D:\pwb`：不能直接并入或覆盖主工作区。它是旧版本快照，存在未同步功能、旧测试基线、旧文档和损坏 Git 索引。
- 最终可以只保留一个真实源码目录：`D:\Project\个人工作台`。是否删除 `D:\pw` 取决于外部快捷方式/脚本是否仍引用它。

### 推荐整合方案

1. **先冻结旧目录**：关闭 IDE、Flutter、Gradle 和应用进程；将 `D:\pwb` 压缩为只读归档（至少保留源码、`.git`、`pubspec.*`、`docs/`、`test/`，不必归档 2.5 GiB 生成物）。
2. **记录旧目录哈希**：对归档和 `D:\pwb` 的源码文件生成 SHA-256 清单；明确标注旧数据库/密钥若存在则单独加密保存。当前扫描未发现 `.sqlite`、`.db`、`key.properties`、`.env`、keystore 或证书文件。
3. **以主工作区为唯一开发源**：只在 `D:\Project\个人工作台` 执行 `flutter pub get`、分析、测试和构建；不要从 `D:\pwb` 复制缓存或整个目录覆盖主线。
4. **验证兼容入口**：搜索桌面快捷方式、CI、IDE 配置和外部脚本对 `D:\pw`/`D:\pwb` 的引用；确认无依赖后保留 `D:\pw` Junction，或将其删除并让调用方改用主路径。
5. **清理旧生成物**：归档校验完成后，删除 `D:\pwb\build`、`.dart_tool`、`android\.gradle`、`android\build`、`windows\flutter\ephemeral`、`coverage`、`.workbuddy` 和 `tool\__pycache__`；这一步应使用明确路径，不要对 `D:\pwb` 根目录做递归删除。
6. **最终验收**：在主工作区运行 `flutter analyze --no-pub`、全量 `flutter test --no-pub --reporter compact`、`git diff --check`，并检查 Git 状态没有意外生成物。

## 六、风险点

- **数据风险**：应用运行数据位于系统应用支持目录而非项目源码目录；整合前仍应查找并备份实际 SQLite/附件目录，不能只看项目树。
- **密钥风险**：不要从旧目录复制未知来源的 `key.properties`、keystore、Supabase 私钥或环境文件；当前扫描未发现这些文件，但应在用户目录和 CI secret 中另行确认。
- **Git 风险**：`D:\pwb` 的索引损坏且无有效 refs，不能用 `git merge` 或 `git checkout` 从它恢复历史。若需恢复旧提交，应先从 reflog 指针和工作区文件制作独立归档，并在副本上运行 `git fsck`/人工校验。
- **路径风险**：删除 `D:\pw` Junction 可能使旧快捷方式、脚本或构建缓存失效；先搜索引用并保留短路径兼容层更稳妥。
- **功能回退风险**：旧目录的 `diary_page.dart`、`more_page.dart` 和旧 Golden 不是“缺失文件”，而是当前导航重构后的历史实现；不要为“文件数量一致”把它们复制回来。
- **缓存污染风险**：复制 `build/`、`.dart_tool/`、Gradle 或 CMake 中间物可能带入旧绝对路径、旧依赖和错误插件注册；整合时必须重新生成。
- **未提交改动风险**：当前主工作区有文档、代码和测试未提交改动；任何归档、切换或清理操作都必须避开这些改动，并先保留差异补丁。

## 七、最终建议

本次路径清理完成后的实际布局为“一份真实源码目录”，不再保留短路径别名：

```text
D:\Project\个人工作台      唯一开发、测试和发布源
```

此前执行过程与每阶段状态见下节；其后旧目录、归档和 Junction 均已按用户要求处理。

## 八、2026-09-23 整合执行记录

### 已完成

- 确认 `D:\pwb` 下没有 Flutter、Dart、Gradle、MSBuild、CMake 或工作区应用进程；当前运行的 `personal_workbench.exe` 位于已安装应用目录，未强制终止。
- 检查用户桌面、开始菜单和任务栏固定快捷方式，未发现指向 `D:\pwb` 或 `D:\pw` 的快捷方式。
- 搜索项目、用户配置和 D 盘脚本/配置引用；未发现活动脚本或 IDE 配置引用旧路径。仅命中此前 WorkBuddy 生成的历史目录审计清单，其中的路径是文件清单记录，不是运行配置。
- 创建只读归档：`D:\pwb_legacy_archive_2026-09-23.zip`。
- 归档包括 215 个旧项目/文档/测试/资源/Git 元数据文件，未包含构建缓存、Gradle/CMake 输出、IDE 工作区设置和本机 `local.properties`。
- 将每个归档条目与归档前源文件 SHA-256 逐项比对，全部匹配；ZIP SHA-256 为 `f6855b55543ad729b91af70760faf5fe5a18132708e40d17b305c47fa6a489e3`。
- 校验文件：`D:\pwb_legacy_archive_2026-09-23.zip.sha256`；清单和范围说明：`D:\pwb_legacy_archive_2026-09-23.manifest.txt`。ZIP、哈希 sidecar 和说明文件均设置为只读。

### 尚未完成及原因

- 对 `D:\pwb\build`、`.dart_tool`、`dist`、`coverage`、`.workbuddy`、`.idea`、`android\.gradle`、`android\.kotlin`、`android\build`、`windows\flutter\ephemeral`、`tool\__pycache__` 的精确清理命令被当前命令执行策略拒绝；重试前后均确认这些目录仍存在。
- 随后的删除 `D:\pwb` 操作因此没有执行。未使用其他命令绕过策略。
- `windows\flutter\ephemeral\.plugin_symlinks` 内含 8 个指向用户 Pub 缓存的目录符号链接。即使之后清理，也应先仅删除链接本身，再移除 ephemeral 目录，避免触及链接目标。
- `D:\pw` Junction 按建议保留，仍指向 `D:\Project\个人工作台`。

因此当前安全状态为：**主工作区未变；旧工作区已完整归档且哈希可验；旧工作区未删除；短路径兼容 Junction 保留。** 归档可通过下列命令独立校验：

```powershell
Get-FileHash -Algorithm SHA256 'D:\pwb_legacy_archive_2026-09-23.zip'
Get-Content 'D:\pwb_legacy_archive_2026-09-23.zip.sha256'
```

## 九、2026-09-23 后续清理请求

用户在本地执行了清理脚本。本次复核确认：

- `D:\pwb` 已删除；
- `D:\pwb_legacy_archive_2026-09-23.zip`、`.zip.sha256` 和 `.manifest.txt` 均已删除；
- `D:\Project\个人工作台` 仍存在，版本为 `0.2.1+6`；
- `D:\pw` 仍是 Junction，目标为 `D:\Project\个人工作台`，通过该入口读取 `pubspec.yaml` 正常；
- 主工作区既有 Git 改动保持不变，`git diff --check` 通过。

据此，旧目录缓存、旧工作区和用户要求的归档均已清理完成；短路径兼容入口和当前主工作区保留。

## 十、2026-09-23 Junction 移除复核

用户决定只保留 `D:\Project\个人工作台`。在确认 `D:\pw` 是指向该主目录的 Junction 后，仅移除了 Junction 本身；没有对目标目录执行递归删除。复核结果：

- `D:\pw` 不存在；
- `D:\Project\个人工作台` 和其中的 `pubspec.yaml` 存在，版本 `0.2.1+6`；
- `D:\pwb` 和此前三个归档文件继续保持不存在；
- `git diff --check` 通过，主工作区既有未提交改动保留。

最终只保留 `D:\Project\个人工作台` 这一份项目工作区。
