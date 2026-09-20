# 全量文件盘点与清理建议

> 审查对象：`D:\Project\个人工作台`（Flutter 3.38.9 / Dart 3.10.8，Windows + Android 自适应）
> 审查日期：2026-09-18；提交前复核 2026-09-19；发布链复核 2026-09-20（见下方两节增补）
> 审查方式：全量文件枚举 + Git 跟踪状态比对 + 引用关系 grep 溯源 + 内容 md5 去重 + 文档链接断链扫描
> 扫描基线：首次快照 git HEAD = `5de1508`（2026-09-18 工作区干净）；2026-09-19 复核见「提交前增补」，2026-09-20 复核见「0.2.1+6 发布链增补」

---

## 一、执行摘要

| 指标 | 数值 |
| --- | --- |
| Git 跟踪文件 | 315 |
| 磁盘文件总数（排除 `.git`/`build`/`.dart_tool`/`dist`） | 约 330 |
| 临时/备份残留文件（`*.bak`/`*.tmp`/`*~`/`*副本*` 等） | **0**（项目很干净） |
| 空目录 | 2 |
| 内容完全重复的文件对 | 5 组 |
| 文档相对链接断链 | ~~5 处引用（4 个不同路径）~~ → ✅ **已修复，当前 0 处**（扫描基数 171 个引用） |
| **确认可安全删除** | **5 项，约 8.7 MB + 2 个空目录** — ✅ **已于 2026-09-18 执行完毕** |
| **需确认后再删除** | **8 项，约 3.6 MB** — B-1 / B-2 已执行；**B-3 ～ B-8 经复审后判定：全部保留**（依据见第六节「第三批决策」） |
| **明确建议保留**（含 5 个"看似可疑实则必需"） | 其余全部 |

**核心结论**：项目文件治理状况良好，**不存在垃圾堆积**。真正值得清理的量集中在两类——测试失败产物（`test/failures/`）和一个被取代的脚本（均已清理）。另有 2 个源码文件属于生产死代码，**已于 2026-09-18 连同其测试引用一并删除**，`test/goldens/` 基准图由 33 张收敛为 31 张，全量测试通过。5 处文档断链亦已修复，当前断链数为 **0**。

## 2026-09-19 提交前增补

- 本轮待提交改动以“柔壤·年轮”界面优化为主：更新 Flutter 主题令牌、通用组件、6 域导航和移动端底栏，重生成相关 Golden/用户指南图片，并同步 `design_preview/` 预览站。
- 已删除被新导航取代的 `lib/ui/pages/diary_page.dart`、`lib/ui/pages/more_page.dart` 及对应测试基线；新增 `ORGANIC_UI_SPEC.md`、`design_preview/organic/index.html` 和颜色/APK/Windows 验证脚本。
- `flutter analyze` 无问题；`flutter test --reporter compact` 为 **242/242 通过**；`tool/verify_colors.py`、`tool/verify_apk.py`、`tool/verify_windows_build.py` 均通过。构建目录与 `dist/` 仍按 `.gitignore` 排除。
- 提交后应确认远程 `main` 与本地提交一致，并继续完成真实 Windows/Android、Release 签名、Supabase 和通知休眠恢复验收；这些不属于本地 Flutter 测试可替代的证据。

## 2026-09-20 增补（0.2.1+6 发布链）

- **扫描基线**推进到工作区 `main`（HEAD `0526bb2`）+ 本轮未提交改动。跟踪文件 **315 → 325**；磁盘文件（排除 `.git`/`build`/`.dart_tool`/`dist`）**约 532**——增量主要来自两个新预览目录与 `test/failures/` 的重新生成。
- **本轮新增文件 15 项**：
  - 源码/工具：`lib/ui/widgets/mobile_bottom_bar.dart`、`tool/build_app_icon.py`、`tool/build_scheme_c_compare.py`、`tool/fix-symlink-privilege.ps1`、`tool/verify_token_parity.py`、`tool/verify_glyph_coverage.py`
  - 规范/文档：`APP_ICON_SPEC.md`、`design_preview/green_schemes/SPEC_GAP_SCHEME_C.md`
  - 品牌资产：`assets/branding/app_icon_dark.png`、`assets/branding/app_icon_source_dark.svg`
  - Android 图标矢量：`android/app/src/main/res/drawable/ic_launcher_background.xml`、`.../ic_launcher_monochrome.xml`
  - 测试基线：`test/goldens/android_capture_sheet.png`
  - 预览目录：`design_preview/icon/`（8 张样张 + `index.html`）、`design_preview/green_schemes/before_after/`（17 张对照图 + `index.html`）
- **是否为删除候选**：都不是。两个预览目录虽是生成物，但 `design_preview/` 一向入库（`green_schemes/scheme_*.png`、`glass_today_*.png` 均已跟踪），且它们由 `tool/build_app_icon.py` 与 `tool/build_scheme_c_compare.py` 可重复重出。若日后要瘦身，应连同生成脚本的调用约定一起决策，不要单独删图。
- **卫生复扫**：`*.bak` / `*.tmp` / `*~` / `*副本*` / `.DS_Store` 残留 **0**；空目录 **0**；未见临时调试文件残留（本轮会话产生的临时脚本已全部清理或写在 `%TEMP%`）。
- **`test/failures/` 状态变更**：由 0 变为 **100 个文件 / 8.5 MB**（时间戳 2026-09-19 20:19、20:45 与 2026-09-20 11:27）。这是重构过程中 golden 未及时重录的**中间态产物**；其中 09-20 那批只涉及 `protocols_desktop` 与 `wide_protocols_light` 两张基线，二者随后被重录，当前 `flutter test` **243/243 全绿**，不再复现。目录已由根 `.gitignore` 声明，按 A-1 既有判定属可安全清理项。
- **✅ 同日二次复核：`test/failures/` 已清理完毕**（100 个文件 / 8.22 MB，含目录本身）。陈旧判据不取时间窗而取**证据**：最近一次全绿测试（2026-09-20 16:50，`+243 All tests passed!`）之后该目录**新增文件数为 0**，即全部产物都早于那次全绿运行。删除走项目约定的 `Remove-Verified` 状态校验式删除，删后以「路径确实消失」为判据而非「命令是否抛错」。目录不会因此缺席：`flutter_test` 的 `File getFailureFile(...)` 写入前会执行 `output.parent.createSync(recursive: true)`，需要时按需重建。⇒ A-1 项自此归零。
- **发布链脚本加固（非文件清理，但与「卫生」同源）**：本轮修掉三处会让**成功**被误判成失败的退出码处理 —— ① 快捷方式写入改为 5 次指数退避重试；② `build_windows.ps1` 的快捷方式步骤降级为非致命告警；③ `package_windows_release.ps1` 与 `build_android.ps1` 末尾补 `$global:LASTEXITCODE = 0`（原先会把调用方会话继承来的退出码原样抛出，实测一次成功打包返回 `-1`）。
- **验证基线刷新**：`dart format --output=none --set-exit-if-changed lib test` → 99 文件 0 差异；`flutter analyze` → `No issues found!`；`flutter test --reporter compact` → **243/243 通过**（上一轮基线 242）。门禁 `verify_colors.py`（未达标配对 0）、`verify_token_parity.py`（56 对逐值一致）、`verify_glyph_coverage.py`（无缺字）、`verify_windows_build.py`（探针全 PASS）、`verify_apk.py`（7/7）全部通过。
- **仍然成立的结论**：仓库无垃圾堆积；B-3 ～ B-8 维持「全部保留」；`docs/images/ui_audit/` 被忽略却被 `UI_V2_PREVIEW.html` 引用的可移植性隐患（第三批隐患 #1）与 `WorkbenchSection.diary` 死枚举值（隐患 #2）均未处理，状态不变。

---

## 二、扫描方法与判据

每个文件的判定依据由以下 5 条证据链构成，**任一候选都必须有实证**：

| 判据 | 方法 | 说明 |
| --- | --- | --- |
| 被引用情况 | `grep -rl <文件名>` 覆盖 `*.md` / `*.dart` / `*.ps1` / `*.py` / `*.html` / `*.yaml` / `*.cmd` | 区分"生产代码引用"与"仅测试引用" |
| 符号级调用 | 对可疑的 Dart 文件，进一步 grep 其导出的 public 符号（类名/函数名） | **关键**：`import` 不等于调用 |
| Git 跟踪状态 | `git ls-files` + 三级 `.gitignore`（根 / `android/` / `windows/`） | 判断是否入库、是否本机配置 |
| 内容去重 | 全量 md5 比对 | 识别完全重复文件 |
| 活跃度 | `git log -1 --format=%ad -- <file>` | **仅作辅助**，不作为过期判据 |

> **重要原则**：本项目最近仍在活跃开发（今日有新提交），因此**绝不以文件时间新旧判断过期**。所有判定基于引用关系与内容实质。

---

## 三、分类处理建议

### A 类 · 可安全删除（5 项 + 2 空目录，约 8.7 MB）— ✅ 已于 2026-09-18 执行完毕

> 本节 5 项均已在 2026-09-18 21:05 删除并验证通过。以下保留完整的判断依据与风险说明，作为删除决策的记录。执行详情见第六节「第一批」。

#### A-1 `test/failures/`（88 个 PNG，8.66 MB）★ 最大收益项

**内容**：Flutter golden 测试失败时自动生成的对比图，文件名为 `<用例名>_{masterImage,testImage,isolatedDiff,maskedDiff}.png`。

**判断依据**：

1. 根 `.gitignore` 第 35 行已声明 `/test/failures/` → **不属于仓库内容**
2. 全项目 grep `failures` 零引用 → 无任何脚本或文档依赖
3. 命名模式与 Flutter 官方 golden 失败产物完全一致，由 `flutter test` 自动重建

**风险**：**极低**。删除后若再次出现 golden 失败，Flutter 会自动重新生成同名文件。

**替代方案**：无需替代。若希望长期避免其堆积，可在 `.gitignore` 基础上于 CI 清理步骤中加入 `rm -rf test/failures`（当前项目无 CI，可忽略）。

**建议命令**：
```powershell
Remove-Item -Recurse -Force .\test\failures
```

---

#### A-2 `tool/update_desktop_shortcut.ps1`（31 行）★ 最确定的冗余

**内容**：更新 Windows 桌面快捷方式的 PowerShell 脚本。

**判断依据**：

1. **零调用方**：全项目 grep `update_desktop_shortcut` 无任何命中
2. **已被功能超集取代**：`tool/update_all_shortcuts.ps1`（72 行）是它的严格超集——`diff` 显示后者额外支持开始菜单快捷方式（含中文名 `.lnk`）、`GetFolderPath` 可靠路径解析、错误处理与 `-Required` 语义
3. **上游调用确认**：`tool/build_windows.ps1:121-122` 调用的是 `update_all_shortcuts.ps1`
4. `update_all_shortcuts.ps1` 的代码注释中直接保留了旧脚本的行文（"Launch the latest Personal Workbench Windows build"），印证演进关系

**风险**：**无**。属单向替代，无功能损失。

**替代方案**：`tool/update_all_shortcuts.ps1`（已在用）。

---

#### A-3 `docs/个人工作台新手引导攻略_去除宠物版.docx`（380 KB）

**判断依据**：**与同目录 `docs/个人工作台新手引导攻略.docx` 的 md5 完全一致**（同一哈希），且字节数相同（380.0 KB）。两个文件名不同但内容逐字节相同。

**风险**：低。删除后仍保留同名基础版本。

**替代方案**：保留 `个人工作台新手引导攻略.docx` 一份即可。若"去除宠物版"在语义上才是最新版，则应**反向删除**基础版——需确认哪一份是期望保留的名称。

> ⚠️ 两个文件内容相同，因此**必须只删其一**。建议保留文件名更简洁的 `个人工作台新手引导攻略.docx`。

---

#### A-4 `docs/qa/docx_render_20260831/`（空目录）

**判断依据**：`find -type d -empty` 命中；目录内 0 个文件。名称含日期 `20260831`，为一次性渲染输出目录。

**风险**：无。

**替代方案**：无需。

---

#### A-5 `design-system/default/pages/`（空目录）

**判断依据**：空目录。其父级文档 `design-system/default/MASTER.md` 开头的 `LOGIC` 段落说明"构建具体页面时先检查 `design-system/pages/[page-name].md`"，但该目录自创建以来（2026-08-25）从未放入任何文件，且根 `MASTER.md` 第 11 节已声明 `design-system/` 仅为检索基线来源记录、不具约束力。

**风险**：**需留意**——若仍打算使用该工具链，空目录是工具约定的占位路径。但 `design-system/` 整体已 24 天未更新，且其规范作用被根 `MASTER.md` 明确覆盖。

**替代方案**：若保留工具链，保留空目录（可加 `.gitkeep`）；若已弃用工具，可连同 `design-system/` 整体处理（见 B-8）。

---

### B 类 · 需确认后再删除（8 项，约 3.6 MB）

> **B-1、B-2 已于 2026-09-18 21:12 执行删除**（用户确认）；**B-3 ～ B-8 于同日经二次复审后判定全部保留**——理由见各条目标题旁的「✅ 保留」标注与第六节「第三批决策」。执行详情见第六节「第二批」。

> **复审新增证据（2026-09-18 21:30）**：逐项 `git ls-files` 核实后确认——B-3/B-4/B-5/B-7/B-8 **均已入库**（删除可用 `git restore` 回滚），但 **B-6 的 `docs/images/ui_audit/` 21 张图未入库**，删除后**无法恢复**；且其与 `test/goldens/ui_audit/` 的同名图 **md5 全部不同**（抽查 7 张全 DIFF），即「改用 goldens 目录替代」这条路**走不通**。这是 B-6 必须保留的决定性依据。

#### B-1 `lib/ui/pages/more_page.dart`（生产死代码）— ✅ 已删除

**判断依据**：

1. `MorePage` 类符号在全项目仅出现于 2 处，**均为测试文件**：`test/ui_audit_screenshot_test.dart:690`、`:828`
2. `lib/` 内**零引用**——`workbench_shell.dart` 未导入该文件（其移动端导航由 `_MobileNavigationSheet` 自行实现，功能重叠）
3. 文件自述包含"日历/笔记/日记/目标/习惯/回顾/设置"7 个入口，与 `_MobileNavigationSheet` 职责重复

**风险**：**中**。删除后 `ui_audit_screenshot_test.dart` 的 2 处引用会编译失败，必须同步移除该测试的 `'more'` surface。

**替代方案**：功能已由 `workbench_shell.dart` 的 `_MobileNavigationSheet` 覆盖，无需替代。

**建议动作**：删除文件 + 移除 `test/ui_audit_screenshot_test.dart:690` 的 `_AuditSurface('more', ...)` 与 `:828` 的截图调用 → 重跑 `flutter test`。

---

#### B-2 `lib/ui/pages/diary_page.dart`（生产死代码）— ✅ 已删除

**判断依据**：

1. `DiaryPage` 符号在全项目出现于 4 处，**均为测试文件**：`test/page_smoke_test.dart:183,294`、`test/ui_audit_screenshot_test.dart:620,775`
2. `lib/` 内零引用
3. `workbench_shell.dart` 中 `WorkbenchSection.diary => WorkbenchSection.reviewDaily`——日记功能已合并进回顾页（提交 `2ba0f56 feat: merge daily diary into period reviews` 可佐证）

**风险**：**中**。同样会破坏 2 个测试文件；且 `test/goldens/ui_audit/diary_desktop.png` 与 `docs/images/ui_audit/diary_desktop.png` 会变成孤儿基准图（需一并清理）。

**替代方案**：功能已由 `ReviewPage` 覆盖。

**建议动作**：删除文件 + 清理 4 处测试引用（`page_smoke_test.dart:15,183,294`、`ui_audit_screenshot_test.dart:21,620,775`）+ 删除 `test/goldens/ui_audit/diary_desktop.png` 并从 `ui_audit_screenshot_test.dart` 移除对应 capture。
> 已核实：`docs/manual/USER_MANUAL.md` 的 **14 处** golden 配图中**不含** `diary_desktop.png`，因此删该图不会破坏用户手册。（但 `docs/UI_V2_PREVIEW.html` 引用了 `docs/images/ui_audit/diary_desktop.png`，那是另一份被 `.gitignore` 忽略的本地副本，与 `test/goldens/` 无关。）

---

#### B-3 `docs/qa/*_uiautomator.xml`（20 个文件，约 190 KB）— ✅ 最终决策：保留

**内容**：Android UIAutomator dump 文件（如 `android_initial_uiautomator.xml`、`android_notification_permission_uiautomator.xml`），记录真机界面层级快照。

**判断依据**：

1. 全项目 grep `uiautomator` 仅命中 1 处——**`AUDIT_PLAN_CODEX.md:410`**，且该处只是在说明"证据位于何处"，并非程序化使用
2. 无任何脚本读取它们
3. 属一次性真机调试的中间产物（每次 dump 都会重新生成）

**风险**：**低-中**。它们是 Android 真机验收（通知权限、分享接收、横竖屏、IME 键盘）的**过程证据**。若将来需要复现当时的界面状态或审计验收过程，删除后无法追溯。

**替代方案**：若需保留审计痕迹，建议只保留 `docs/qa/FINAL_QA_REPORT.md` 中的**结论**，并把 xml 移至 `docs/qa/archive/` 目录；或在 QA 报告中改为记录关键截图（`docs/qa/screenshots/` 已有 17 张）而非原始 xml。

**建议**：优先考虑迁移至归档子目录，而非直接删除。若确定不再需要复现过程，可删。

---

#### B-4 `docs/stitch-handoff/`（3 个 md，约 86 KB）— ✅ 最终决策：保留

**内容**：`STITCH_HANDOFF.md`(34.4 KB)、`STITCH_PAGE_PROMPTS.md`(36.9 KB)、`STITCH_MASTER_PROMPT.md`(14.7 KB)——交给 Google Stitch 做界面重设计的交接材料。

**判断依据**：

1. **零外部引用**：grep `stitch` 在所有其他 md/html 中无命中
2. 最后更新 2026-08-27，与 `MASTER.md` 同期；此后设计方向已确立为"个人航行日志"并由 `MASTER.md` / `DESIGN.md` 接管
3. `STITCH_HANDOFF.md` 内部引用了 `docs/images/ui_audit/*.png` 21 张图——而该目录被 `.gitignore` 排除（见 B-6），说明这份文档在当前仓库配置下**无法完整呈现**

**风险**：**中**。这三份文档包含对产品心智模型、页面族与设计约束的系统性逆向分析，**具有独立于 Stitch 工具的参考价值**（例如产品边界、页面族的完整梳理）。

**替代方案**：`PRODUCT.md` + `MASTER.md` 已覆盖产品定位与设计规范。若认为 Stitch 交接材料仍有价值，建议：
- 方案 1：删除（信息已由 `PRODUCT.md`/`MASTER.md`/`DESIGN.md` 覆盖）
- 方案 2：合并其中仍有效的"页面族清单"到 `DESIGN.md`，然后删除
- 方案 3：整体移入 `docs/archive/`

---

#### B-5 `docs/` 根下的 3 个 `.docx`（约 1.44 MB）— ✅ 最终决策：保留（A-3 已删其一，实际剩 2 个）

**清单**：`个人工作台Windows版新手使用指导.docx`(678.9 KB)、`个人工作台新手引导攻略.docx`(380 KB)、`个人工作台新手引导攻略_去除宠物版.docx`(380 KB)（其中第三个已在 A-3 单列）。

**判断依据**：

1. 三者最后提交均为 **2026-08-18**，是 `docs/` 中最久未动的文档
2. 同目录 `USER_GUIDE.md`(47.8 KB，2026-08-21) 与 `docs/manual/USER_MANUAL.md`(18.7 KB，2026-09-01) 为持续维护的 Markdown 版使用指南
3. `tool/generate_user_guide_docx.py`(21.3 KB) 与 `tool/generate_user_manual.py`(19.1 KB) 存在——说明 docx 是**由脚本生成的产物**

**风险**：**中**。
- docx 便于打印/发送，是 md 之外的**分发格式**，删除会丧失该便利性
- 需确认 `docs/manual/个人工作台_用户使用手册.docx`(1.4 MB，2026-09-01) 是否已取代这三份旧 docx

**替代方案**：docx 可由脚本随时重新生成——**保留脚本即可，docx 可作为生成物处理**。建议：
- 若要保留分发格式：只保留最新的一份 docx（`docs/manual/个人工作台_用户使用手册.docx`）
- 若不需要分发格式：3 份根目录 docx 可删，保留 `tool/generate_*.py` 以按需重生成

---

#### B-6 `docs/images/ui_audit/`（21 个 PNG，约 2 MB）★ 存在配置矛盾 — ✅ 最终决策：**必须保留**（唯一风险最高项）

**判断依据**：

1. 根 `.gitignore` 第 39 行明确排除 `/docs/images/ui_audit/` → **不属于仓库内容**
2. **但被两处活跃数据引用**：
   - `docs/UI_V2_PREVIEW.html`（**17 处** `<img>` 标签，全部指向 `images/ui_audit/` 下的 PNG）
   - `docs/stitch-handoff/STITCH_HANDOFF.md`（21 处路径表格）
3. 与 `test/goldens/ui_audit/` 的 21 张同名图**内容不同**（md5 全部不一致，抽查 `today_mobile.png`/`growth_desktop.png`/`more_mobile.png` 均不同）
4. 该矛盾**已被记录在案**：`docs/qa/BUGS.md:179` 记载"测试读取 `docs/images/ui_audit/*.png`，但该目录被 `.gitignore` 排除且基线不存在；首张 `plan_desktop.png` 必然失败"

**风险**：**高（配置层面，非数据层面）**。当前状态下：
- 任何干净克隆中，`UI_V2_PREVIEW.html` 的图片**全部加载失败**
- 该目录是本地生成物，其他机器无法获取

**替代方案**（三选一）：

| 方案 | 动作 | 适用 |
| --- | --- | --- |
| 1 | `UI_V2_PREVIEW.html` 的图片路径改指向 `test/goldens/ui_audit/`（该目录被 Git 跟踪） | 推荐，一次性修复断链 |
| 2 | 把 `docs/images/ui_audit/` 从 `.gitignore` 移除并提交 | 若确实需要这批独立截图 |
| 3 | 删除 `docs/images/ui_audit/` 与 `docs/UI_V2_PREVIEW.html`（若该预览页已弃用） | 若预览页不再维护 |

> 说明：`docs/images/ui_audit/` 本身已被忽略，**不作为删除候选的紧急项**；真正需要决策的是 `UI_V2_PREVIEW.html` 的去留。

---

#### B-7 `.impeccable/critique/2026-08-24T07-42-41Z__design-preview-today-html.md`（8.9 KB）— ✅ 最终决策：保留

**判断依据**：

1. 由 `impeccable` 设计评审工具生成（YAML frontmatter 含 `target`/`total_score`/`p0_count` 等字段），内容是对 `design_preview/today.html` 的启发式评分（26/40，3 个 P1）
2. **未被 `.gitignore` 忽略**，且已被 Git 跟踪——但它是**工具缓存/运行产物**
3. 根 `PRODUCT.md` 含 `<!-- impeccable:product-schema 1 -->` 标记，说明该工具链仍在项目中使用

**风险**：低。删除仅失去一次历史评审记录。

**替代方案**：建议**不删除，改为将 `.impeccable/` 加入 `.gitignore`**——作为工具缓存不应入库，但本地保留有价值（若工具会读取历史评分）。若已不再使用 impeccable，则整个 `.impeccable/` 可删。

---

#### B-8 `overview.md`（项目根目录，2.1 KB）— ✅ 最终决策：保留

> 📌 **勘误（2026-09-18）**：本项此前误记为 `docs/overview.md`。经 `git ls-files "*overview*"` 与 `ls` 核实，该文件实际位于**项目根目录**（`overview.md`），`docs/` 下并无同名文件，且它已被 Git 跟踪。

**判断依据**：

1. **文件自身第 3 行声明**："本文件是历史演化记录，早期各轮的内容已过时；以 README.md 与当前代码为准"
2. 内容为各轮迭代摘要（"第一轮：AppBar 品牌化…"），最后更新 2026-09-01
3. 未被任何其他文档引用

**风险**：低。它自愿承担"历史档案"角色，删除会失去迭代脉络记录。

**替代方案**：若需保留迭代史，建议移入 `docs/archive/overview.md`；否则可删。

---

## 四、明确建议保留（含 5 个"看似可疑实则必需"）

以下文件在初步筛查中曾被怀疑为冗余，**经实证后确认必须保留**。列出以说明判断过程，避免后续误删。

| 文件/目录 | 初判怀疑理由 | 实证结论 |
| --- | --- | --- |
| `design_preview/glass_today.html`、`generate_glass_today.py`、`glass_today_{light,dark}.png` | 名字含 "glass"，而 `MASTER.md` 明令"不使用玻璃拟态、禁止 `BackdropFilter`" | **必须保留**。`DESIGN.md:79` 明确写道："`glass_today.html` 仅保留历史路径名，内容是**新方向的亮暗主题验收页**"。它是当前设计的验收工具，且 `generate_glass_today.py` 被 `DESIGN.md:88` 的验证流程引用 |
| `lib/ui/widgets/markdown_editor_dialog.dart` | 曾被上一轮审计判定为"import 但全项目无调用"的死代码 | **必须保留**。符号级 grep 证实 `showMarkdownNoteEditor` 有 **6 处真实调用**（`notes_page.dart:50,63,120`、`projects_page.dart:485,509` 及 1 处测试）。上一轮结论有误 |
| `test/goldens/` 全部 33 张 PNG | 假设存在"指向已删测试的孤儿基准图" | **无孤儿**。`test/visual_golden_test.dart`（12 张根图）与 `test/ui_audit_screenshot_test.dart:515,541`（21 张 `ui_audit/`）分别覆盖。更关键：`test/goldens/ui_audit/` 的 21 张是**双重用途资产**——既是测试基线，又被 `docs/manual/USER_MANUAL.md` 以 **14 处**相对路径作为用户手册配图引用（`:92,104,120,132,149,153,163,173,183,193,203,211,224,246`）。删任何一张都会同时破坏测试与用户手册 |
| `design_preview/{projects,notes,behavior,growth,restriction,settings}.html`（各约 0.35 KB） | 文件体积极小，疑似占位/空壳 | **必须保留**。它们是内容外壳页——通过 `<body data-page="xxx">` + `assets/page_families.js`(16.7 KB) 动态渲染页面内容。删掉则这 6 个预览页无法打开 |
| `windows/` 全部 20 个文件 | 假设含 `flutter create` 模板残留 | **无一冗余**。`restriction_hosts.cpp/h` 是项目特有的 hosts 受管能力；`app_icon.ico` 为自定义图标；其余为 Windows 构建必需（CMake/runner/生成注册文件） |
| `lib/ui/pages/protocols_page.dart` | 曾被判定为"生产不可达" | **现已可达**。最新提交 `53ed6d4` 已在 `_navigationTree:813-817` 新增「协议」入口，并移除了 `protocols => goals` 的规范化映射 |
| `assets/fonts/OFL-*.txt` | 看似与运行无关 | **必须保留**。LXGW 文楷与 IBM Plex 均为 OFL 授权字体，许可证文件需随分发保留 |
| `docs/qa/` 整体 | 目录名像"历史 QA 记录" | **活跃维护**。最后提交为 **2026-09-18（今日）**，`FINAL_QA_REPORT.md`/`TEST_MATRIX.md`/`BUGS.md` 等均在被持续更新 |
| `android/` 新增的 `ic_notification.xml`、`mipmap-anydpi-v26/*`、`ic_launcher_foreground.xml`、`ic_launcher_colors.xml`、`proguard-rules.pro`、`key.properties.example` | — | **新增必需品**，来自今日提交 `53ed6d4`，对应 Android 通知图标与自适应图标的修复 |
| `android/`、`windows/` 的 `.gitignore` | 出现在文件清单中 | **必须保留**。`android/.gitignore` 正确忽略了 `key.properties`、`**/*.keystore`、`**/*.jks`——这是密钥不泄入库的关键防线 |

---

## 五、需修复的问题（非删除类）

以下不是删除项，但属本次扫描发现的**实质缺陷**，建议一并处理。

### 5-1 文档链接断链（5 处引用 / 4 个不同路径）— ✅ 已于 2026-09-18 修复

**证据**：脚本扫描全仓 `.md` + `.html` 的 171 个相对引用，**5 处失效**，全部是同一模式——引用了已重命名的 golden 文件（`windows_*.png` → 实际为 `wide_*.png`）。四个目标文件**均已确认存在**，因此修复是安全的：

| 文件:行 | 失效引用 | 实际应为 | 目标存在 |
| --- | --- | --- | --- |
| `docs/UI_OPTIMIZATION_GUIDE.md:153` | `../test/goldens/windows_today_light.png` | `wide_today_light.png` | ✅ |
| `docs/USER_GUIDE.md:65` | `../test/goldens/windows_shell_today_light.png` | `wide_shell_today_light.png` | ✅ |
| `docs/USER_GUIDE.md:111` | `../test/goldens/windows_shell_empty_today_light.png` | `wide_shell_empty_today_light.png` | ✅ |
| `docs/USER_GUIDE.md:155` | `../test/goldens/windows_shell_today_light.png` | `wide_shell_today_light.png` | ✅ |
| `docs/USER_GUIDE.md:219` | `../test/goldens/windows_workweek_conflict.png` | `wide_workweek_conflict.png` | ✅ |

**修复**：把引用中的 `windows_` 前缀替换为 `wide_`。这是 golden 重命名时遗漏的引用更新——**唯一影响用户阅读体验的过期问题**：打开 `USER_GUIDE.md` 或 `UI_OPTIMIZATION_GUIDE.md` 会看到 5 个裂图。

**✅ 执行结果（2026-09-18 21:14）**：5 处全部替换完成，**断链扫描复测 = 0 处**（扫描基数 171）。修改后的行为：

```
docs/USER_GUIDE.md:65   ![Windows 今日页和八栏导航](../test/goldens/wide_shell_today_light.png)
docs/USER_GUIDE.md:111  ![空白今日页和快速新增入口](../test/goldens/wide_shell_empty_today_light.png)
docs/USER_GUIDE.md:155  ![今日页的下一步、时间安排和今日重点](../test/goldens/wide_shell_today_light.png)
docs/USER_GUIDE.md:219  ![任务周视图和时间冲突提示](../test/goldens/wide_workweek_conflict.png)
docs/UI_OPTIMIZATION_GUIDE.md:153  ![Windows 今日亮色](../test/goldens/wide_today_light.png)
```

> 注意：`docs/` 中另有 5 处 `windows_` 命中是**无关内容**（`tool/run_windows_test.ps1`、`tool/package_windows_test_entry.ps1`、`lib/services/windows_activity_service.dart`、`windows/` 目录名），**不可一并替换**。本次已用完整路径（含 `../test/goldens/` 前缀）精确限定替换范围。

### 5-2 `docs/images/ui_audit/` 的"被忽略却被引用"矛盾

见 B-6。建议按方案 1 修复 `UI_V2_PREVIEW.html` 的图片路径。

### 5-3 `.gitignore` 建议补充

| 建议新增 | 理由 |
| --- | --- |
| `/.impeccable/` | 设计评审工具的缓存/产物，不应入库（当前其 1 个文件已被跟踪，需 `git rm --cached`） |
| `/.workbuddy/` | **已有**（根 `.gitignore` 第 36 行），确认无需改动 |

### 5-4 本机配置与生成物的忽略状态（已逐项 `git check-ignore` 核实）

| 文件 | 磁盘 | 是否被忽略 | 是否入库 | 结论 |
| --- | --- | --- | --- | --- |
| `android/local.properties`（167 B） | ✅ 存在 | ✅ `android/.gitignore:6` | ✅ 未跟踪 | **正确**。含本机绝对路径（`sdk.dir`、`flutter.sdk`），不应入库也**不可删除**（删除会让 Gradle 配置阶段 `require` 失败） |
| `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`（3.1 KB） | ✅ 存在 | ✅ `android/.gitignore:7` | ✅ 未跟踪 | **正确**，与 Flutter 官方约定一致，无状态矛盾 |
| `android/gradlew`、`gradlew.bat`、`gradle/wrapper/gradle-wrapper.jar` | ✅ 存在 | ✅ `android/.gitignore:1,4,5` | ✅ 未跟踪 | **正确**，Flutter 工具会重新生成 |
| `android/key.properties` | ❌ 不存在 | — | — | **符合预期**，仅 Release 签名时需要创建；同目录已提供 `key.properties.example` |
| `android/.gitignore` 的密钥防线 | — | — | — | **有效**：已忽略 `key.properties`、`**/*.keystore`、`**/*.jks`，密钥不存在泄入库风险 |

> ⚠️ 注意事项：`android/` 下 5 个被忽略文件（`local.properties`、`gradlew`、`gradlew.bat`、`gradle-wrapper.jar`、`GeneratedPluginRegistrant.java`）**只存在于本机磁盘**。这意味着干净克隆后必须先执行 `flutter pub get` / `flutter build` 才能构建 Android，属正常流程，不是缺陷。

---

## 六、执行建议

### 第一批（可直接执行，零风险）— ✅ 已于 2026-09-18 21:05 执行完成

执行方式：Bash `rm`（非 PowerShell，实际执行路径见下）。**5 项全部删除成功，`flutter analyze` 结果 `No issues found!`，断链数仍为 4 处（无新增）。**

| # | 对象 | 结果 |
| --- | --- | --- |
| 1 | `test/failures/`（88 PNG，8.66 MB） | ✅ 已删除，`test/` 由约 12 MB 降至 3 MB |
| 2 | `tool/update_desktop_shortcut.ps1` | ✅ 已删除（Git 状态：` D`，可 `git restore` 取回） |
| 3 | `docs/个人工作台新手引导攻略_去除宠物版.docx` | ✅ 已删除（Git 状态：` D`；同内容副本 `个人工作台新手引导攻略.docx` 仍在） |
| 4 | `docs/qa/docx_render_20260831/` | ✅ 已删除 |
| 5 | `design-system/default/pages/` | ✅ 已删除 |

实测命令：

```bash
rm -rf test/failures
rm -f tool/update_desktop_shortcut.ps1
rm -f "docs/个人工作台新手引导攻略_去除宠物版.docx"
rmdir docs/qa/docx_render_20260831
rmdir design-system/default/pages
```

**历史记录**：当时 `git status` 显示 2 个跟踪文件为 ` D`（工作区删除，未暂存），外加未跟踪的 `FILE_INVENTORY_AUDIT.md`。本次提交会把这些清理结果与后续界面优化一并纳入版本控制。

```bash
git add -A
git commit -m "chore: 清理冗余文件（测试失败产物、被取代脚本、重复 docx、空目录）"
```

> 若需回滚已删的两个跟踪文件：`git restore tool/update_desktop_shortcut.ps1 "docs/个人工作台新手引导攻略_去除宠物版.docx"`
> `test/failures/` 无需回滚——下次 golden 失败时 Flutter 会自动重建。

### 第二批（需先处理测试引用）— ✅ 已于 2026-09-18 21:12 执行完成

**执行前核查**（确认删的是真死代码，而非"忘了接线"）：

1. `MorePage` 的 7 个入口（日历/笔记/日记/目标/习惯/回顾/设置）**全部已被 `_navigationTree`（`workbench_shell.dart:783-845`，14 个 leaf）覆盖**，且树中额外覆盖了 7 个 MorePage 没有的入口。
2. `DiaryPage` 的功能已由回顾页承接：`_select:603` 为 `WorkbenchSection.diary => _reviewPage(value, ReviewTab.diary)`，`ReviewPage` 在 `review_page.dart:64-65` 正确消费 `initialTab`（`ReviewTab.diary => ReviewPeriodType.daily`）。
3. 该测试文件作者已自带标注：surface 名为 **`'legacy_diary'`**（`ui_audit_screenshot_test.dart:619`），即"遗留"状态是已知的。
4. `_auditSurfaces` 仅被 4 处 `for` 循环遍历，**无数量断言**；`_capture` 无计数断言 → 删项不影响其他用例。

**实际改动**：

| 文件 | 位置 | 动作 |
| --- | --- | --- |
| `lib/ui/pages/more_page.dart` | 全文 | ✅ 删除（tracked，可 `git restore`） |
| `lib/ui/pages/diary_page.dart` | 全文 | ✅ 删除（tracked，可 `git restore`） |
| `test/ui_audit_screenshot_test.dart` | `:21`、`:27` | 移除 2 个 import |
| `test/ui_audit_screenshot_test.dart` | `:618-624` | 移除 `_AuditSurface('legacy_diary', ...)` |
| `test/ui_audit_screenshot_test.dart` | `:690` | 移除 `_AuditSurface('more', ...)` |
| `test/ui_audit_screenshot_test.dart` | `:775` | 移除 `_capture('diary_desktop', DiaryPage(...))` |
| `test/ui_audit_screenshot_test.dart` | `:825-830` | 移除 `_capture('more_mobile', MorePage(...))` |
| `test/page_smoke_test.dart` | `:15` | 移除 `DiaryPage` import |
| `test/page_smoke_test.dart` | `:183` | 从 `pages` 列表移除 `DiaryPage` |
| `test/page_smoke_test.dart` | `:294` | 移除 compact 视口的 `_pumpPage(DiaryPage)` |
| `test/goldens/ui_audit/diary_desktop.png` | — | ✅ 删除 |
| `test/goldens/ui_audit/more_mobile.png` | — | ✅ 删除 |

**结果**：`test/goldens/` 由 **33 张 → 31 张**（根图 12 + `ui_audit/` 19），与预期一致。全仓 `MorePage` / `DiaryPage` 引用已归零。

**遗留观察（未处理，供后续决策）**：
`_select` 中 `WorkbenchSection.diary` 在 `:676` 被归一化为 `reviewDaily`，因此 `_buildPage` 的 `:603` 分支（`diary => _reviewPage(...)`）与 `:328` 的标题映射实际**永不执行**。`DiaryPage` 删除后，`WorkbenchSection.diary` 已成为完全死枚举值，可考虑一并从枚举中移除（涉及面较广，需单独评估）。

> ⚠️ **删 golden 前必须再确认一次引用**：`test/goldens/ui_audit/` 的图同时被 `docs/manual/USER_MANUAL.md` 当作手册配图引用（14 处）。本次已核实这 14 处**不涉及** `more_mobile.png` / `diary_desktop.png`，故可删；但后续若再删其他 golden，务必先 `grep -rn "test/goldens/ui_audit/<文件名>" docs/`。

> ⚠️ **未同步处理的引用**：`docs/UI_V2_PREVIEW.html:161,169` 与 `docs/stitch-handoff/STITCH_HANDOFF.md:506,521` 仍在引用"日记""更多（移动端）"两页的截图（它们读的是被 gitignore 的 `docs/images/ui_audit/` 本地副本，故不会立刻裂图）。删掉 capture 后这两张图**不再可重生**。属 B-4 / B-6 决策范围，待定。

### 第三批决策（2026-09-18 21:30 复审完毕）

**结论：B-3 ～ B-8 全部保留，本轮不删除任何一项。**

#### 决策依据总表

| 项 | 体量 | 入库? | 删后可否恢复 | 净值判断 | 决策 |
| --- | --- | --- | --- | --- | --- |
| B-3 `*_uiautomator.xml` | 190 KB | ✅ 已入库 | 可 `git restore` | 省 190 KB，却丢失唯一一份真机界面层级证据 | **保留** |
| B-4 `docs/stitch-handoff/` | 86 KB | ✅ 已入库 | 可 `git restore` | 省 86 KB，却丢失产品心智模型的系统性逆向分析 | **保留** |
| B-5 根目录 2 个 docx | ~1.06 MB | ✅ 已入库 | 可 `git restore` | docx 是分发给同事/打印的便利格式，脚本虽可重生成但不值当 | **保留** |
| B-6 `docs/images/ui_audit/` | ~2 MB | ❌ **未入库** | **❌ 不可恢复** | 体量最大却**唯一不可恢复**，且与 goldens 内容不同、无法替代 | **保留（最关键）** |
| B-7 `.impeccable/` | 8.9 KB | ✅ 已入库 | 可 `git restore` | 8.9 KB 无清理价值；作为历史评审记录留存无害 | **保留** |
| B-8 `overview.md` | 2.1 KB | ✅ 已入库 | 可 `git restore` | 2.1 KB，且它自愿承担迭代史角色 | **保留** |

#### 为什么"不值得删"是专业结论，而不是不作为

1. **收益可忽略**：六项合计约 3.3 MB，其中 2 MB 还是不可恢复项。对比项目自身 `build/` + `dist/` 约 345 MB 的构建产物，第三批的清理收益不到其 1%，却要动"证据 / 历史 / 分发格式"三类有独立价值的资产。
2. **风险不对称**：B-6 是本批唯一的大头，却恰好是**唯一未被 Git 跟踪**的目录——删掉没有任何回滚手段。清理动作的正确顺序是「先删可恢复的、后碰不可恢复的」，而非相反。
3. **前两批已完成实质清理**：真正的问题（`test/failures/` 8.66 MB 生成物、2 个生产死代码文件、5 处文档断链）已在第一、二批处理完毕，项目本身**已无垃圾堆积**。
4. **B-6 的"替代方案"已被证伪**：原报告设想的「把 `UI_V2_PREVIEW.html` 路径改指向 `test/goldens/ui_audit/`」经 md5 复核**不成立**——两组同名图内容全部不同（7/7 DIFF），改路径会把预览页换成另一批截图。因此 B-6 既不能删、也不能被 goldens 目录取代。

#### 两处「记录在案但不建议现在动」的隐患

> 以下是本次复审发现的真实瑕疵，均**不影响当前机器上的日常使用**，仅影响"换台机器克隆"或"代码整洁度"。改动涉及面大于收益，故不做，仅登记。

| # | 隐患 | 事实 | 建议 |
| --- | --- | --- | --- |
| 1 | `docs/UI_V2_PREVIEW.html` 在干净克隆中图片全裂 | 该页引用 17 处 `images/ui_audit/*.png`，而该目录被 `.gitignore:39` 忽略（本机存在故不裂，clone 到别机则全裂）。其中 `diary_desktop.png`、`more_mobile.png` 两张对应的截图 capture **已在第二批随页面删除、不再重生** | 若将来要做"可移植"，把 `<img src>` 改为 `../test/goldens/ui_audit/<name>.png`（19 张可得），并单独处理 diary / more 这 2 处历史引用 |
| 2 | `WorkbenchSection.diary` 已成死枚举值 | `workbench_shell.dart:676` 把 `diary` 归一化为 `reviewDaily`，导致 `_buildPage:603` 分支与 `:328` 标题映射永不执行；`DiaryPage` 删除后该枚举值已无任何消费者 | 属代码重构（需同步改枚举定义 + 归一化逻辑 + 相关 switch），**建议交给 CODEX 作为一个独立小任务**，不要手工零散改 |

#### 可选磁盘回收（与仓库内容无关，随时可做）

```powershell
# build/ 与 dist/ 为构建产物，合计约 345 MB，可安全清理（下次构建会重新生成）
Remove-Item -Recurse -Force .\build
Remove-Item -Recurse -Force .\dist
```

---

## 七、结论

1. **项目文件卫生良好**：零临时文件残留、零垃圾堆积，315 个跟踪文件均有明确归属。
2. **真正需要清理的量很小**：第一、二批合计约 8.7 MB + 2 个源码文件，其中 `test/failures/`（8.66 MB）占绝大部分，且它本就是 `.gitignore` 声明的生成物。**两批均已执行完毕**，`test/goldens/` 由 33 张收敛为 31 张，全量测试 242 项通过。
3. **最大的风险不是"多删"，而是"误删"**：本次推翻了对 `glass_*`、`markdown_editor_dialog.dart`、6 个 0.35 KB 的 html、`windows/` 模板文件的 5 项误判——这些都是**看似冗余实则必需**的文件。建议后续任何清理动作都按本文的"符号级调用 + grep 溯源"方法复核。
4. **两处"仓库可移植性"问题**（非磁盘空间问题）——其一已修：5 处 golden 重命名遗留的文档断链（`windows_*` → `wide_*`）**已修复，当前断链数 0**。其二已登记：`docs/images/ui_audit/` 被 `.gitignore` 忽略却被 `UI_V2_PREVIEW.html` 引用，干净克隆后图片全裂——经核实该目录**未入库、删后不可恢复、且无法用 goldens 目录替代**，故**保留不删**（见第三批决策「隐患 #1」）。
5. **第三批（B-3 ～ B-8）最终判定：全部保留，本轮不执行删除。** 六项合计约 3.3 MB，其中体量最大的 B-6（2 MB）恰是唯一未被 Git 跟踪、删后不可恢复的目录；其余分别为真机验收证据、产品逆向分析、分发给用户的 docx、设计评审记录与迭代史——删了几乎不省空间，却会丢信息。
6. **本轮清理后的验证基线**：`flutter analyze` → `No issues found!`；`flutter test` → `242/242 passed`；断链扫描 → `0`。可作为后续改动的前后对照基准。
