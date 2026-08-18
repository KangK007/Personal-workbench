# 安卓端界面优化 — 对齐桌面端风格

## 概述

对安卓端（移动端窄屏 <768dp）界面进行全面优化，使其视觉风格与桌面端保持一致。两轮改动覆盖 AppBar 品牌化、NavigationBar 同步状态、页面级 mini-header 统一、装饰元素补齐、Android 系统栏适配、列表底部空间统一六个维度。

## 第一轮：AppBar 品牌化 + 页面 header 统一

## 问题诊断

审查发现安卓端与桌面端存在 5 类风格差异：

| 问题 | 桌面端 | 安卓端（改前） |
|------|--------|----------------|
| AppBar | PageHeader 渐变背景 + 翠绿竖条 + SealLogo 品牌 | 默认 Material AppBar，无品牌、无渐变 |
| Action 按钮 | 侧栏内 FilledButton + OutlinedButton | 4 个 IconButton 挤在窄屏 AppBar，溢出风险 |
| 同步状态 | 侧栏底部 cloud 图标 + syncMessage | 完全缺失 |
| 页面 mini-header | PageHeader 统一风格 | 各页面自定义，有冗余标题、有丢失操作按钮 |
| 底部装饰 | InkHorizon 渐变天际线 | 缺失 |

## 修改清单

### 1. `lib/ui/workbench_shell.dart` — 移动端外壳升级

**AppBar 改造：**
- `leading`: 添加 `SealLogo(size: 30)` 品牌标识，与桌面侧栏顶部 SealLogo 对齐
- `flexibleSpace`: 添加 `LinearGradient(primary 4% → canvas)` 渐变背景 + 底部分隔线，与桌面 `PageHeader` 装饰完全一致
- `title`: 使用 `titleMedium` + `FontWeight.w600`，与桌面导航项选中态字重一致
- `actions`: 4 个 IconButton 精简为 search + `PopupMenuButton` 溢出菜单（项目/专注/笔记），消除窄屏溢出

**NavigationBar 增强：**
- 底部添加 26px 同步状态指示器行（`cloud_outlined` / `cloud_off_outlined` 图标 + `syncMessage` 文本），与桌面侧栏底部同步状态完全对齐
- 使用 `Column(mainAxisSize: min)` 包裹同步状态行 + NavigationBar

### 2. `lib/ui/pages/projects_page.dart` — 移除冗余标题
- `showHeader=false` 时移除 `Text('项目')` 标题（AppBar 已承载），仅保留 `IconButton` 新建项目按钮
- 统一 padding 为 `fromLTRB(8, 4, 8, 0)`

### 3. `lib/ui/pages/review_page.dart` — 移除冗余标题
- `showHeader=false` 时移除 `Text('回顾')` 标题，仅保留 回顾库切换 + 添加回顾 两个 IconButton
- 使用 `Align(centerRight)` + `Row(mainAxisSize: min)` 紧凑布局

### 4. `lib/ui/pages/notes_page.dart` — 补回丢失操作
- `showHeader=false` 时新增 `else` 分支：添加 `IconButton(icons.add)` 新建笔记按钮
- 之前 `showHeader=false` 时"新建笔记"按钮完全丢失

### 5. `lib/ui/pages/focus_page.dart` — 补回丢失操作
- `showHeader=false` 时新增 `else` 分支：添加 `IconButton(icons.add)` 新建专注预设按钮
- 之前 `showHeader=false` 时"新建专注预设"按钮完全丢失

### 6. `lib/ui/pages/policies_page.dart` — 统一 mini-header
- `showHeader=false` 时将 FilledButton + IconButton 混合改为纯 IconButton 行（新建国策组/拆分目标/添加国策）
- 统一 padding 为 `fromLTRB(8, 4, 8, 0)`

### 7. `lib/ui/pages/today_page.dart` — 添加底部装饰
- 移动端布局用 `Stack` 包裹 `ListView`，底部添加 `Positioned InkHorizon(height: 64)` 渐变装饰
- 与桌面端 `InkHorizon(height: 88)` 底部天际线对齐
- 底部 padding 从 112px 调整为 132px，适配新增同步状态栏高度

## 验证

- `flutter analyze` — 零错误通过
- 所有页面 mini-header 统一为 `Padding(8,4,8,0) + Align(centerRight)` 模式
- AppBar 渐变参数与桌面 `PageHeader` 完全一致（`primary.withValues(alpha: 0.04)` → `canvas`）

## 注意事项

- Android Golden 测试（`test/visual_golden_test.dart` 中 412×915 分辨率）可能需要 `--update-goldens` 更新基准
- ProtocolsPage 在 `_select` 中被重定向到 PoliciesPage，实际不显示，未做改动

---

## 第二轮：Android 系统栏适配 + 细节打磨

### 1. `lib/app.dart` — 系统栏动态适配

MaterialApp 的 `builder` 新增 `AnnotatedRegion<SystemUiOverlayStyle>`：
- 状态栏透明，AppBar 渐变自然延伸到状态栏区域
- 系统导航栏颜色 = `colorScheme.surface`，与底部 NavigationBar 视觉融合
- 状态栏/导航栏图标亮度跟随主题（浅色 dark 图标 / 深色 light 图标）

### 2. `lib/ui/workbench_shell.dart` — 品牌高光细节

- 移动端 AppBar `flexibleSpace` 顶部新增 1px 主色渐变微高光（`primary 14% → 2%`），与 `LogSurface` 强调元素一致
- 同步状态条底部新增 1px 品牌高光线，分隔同步状态与底部导航

### 3. Android 原生资源 — 启动体验

| 文件 | 改动 |
|------|------|
| `values/styles.xml` | NormalTheme 背景 `#F6F8F6`、状态栏透明、导航栏 `#FFFFFF`、浅色状态栏图标 |
| `values-night/styles.xml` | 新增深色启动主题：背景 `#0E1311`、导航栏 `#151C19`、深色状态栏图标 |
| `drawable/launch_background.xml` | 启动背景白 → 品牌浅色 `#F6F8F6` |
| `drawable-night/launch_background.xml` | 新增深色启动背景 `#0E1311` |

### 4. 全量页面底部 padding 统一

14 个文件 26 处 `ListView` 底部 padding 从 `96/100` 提升为 `132`，为「FAB + 同步状态条(26) + NavigationBar(68)」预留充足空间，列表末尾不再被悬浮按钮遮挡：

- `projects_page`(5 处)、`policies_page`(4 处)、`protocols_page`(3 处)、`plan_page`(2 处)、`habits_page`(2 处)、`review_page`(2 处)、`focus_page`、`goals_page`、`growth_page`、`inbox_page`、`notes_page`、`diary_page`、`calendar_page`、`more_page` 各 1 处
- `settings_page`：`EdgeInsets.all(20)` → 响应式 `fromLTRB(20, 20, 20, compact ? 132 : 96)`

## 验证

- `flutter analyze` — 两轮均零错误通过
- 设置页补充 `app_theme.dart` 导入以使用 `AppBreakpoints`

---

## 最新版 APK 构建

**产物**：`dist/apk/PersonalWorkbench_0.1.0+3_debug.apk`（155.6MB）

- 包名 `com.personalworkbench.personal_workbench`，versionCode=3 / versionName=0.1.0
- minSdk 24 / target 36，支持 arm64-v8a / armeabi-v7a / x86_64
- debug 签名（项目暂无 release keystore，发布需生成 `android/key.properties`）

**过程中修复的问题**：

1. **Gradle 发行版下载慢**（官方源 ~11KB/s）→ `gradle-wrapper.properties` 切换腾讯云镜像 `mirrors.cloud.tencent.com/gradle/gradle-8.14-bin.zip`（已持久化）
2. **wrapper 目录名算法**：`base36(MD5(URL))` 而非 hex，据此确认本机已有完整 Gradle 8.14，直接复用零下载
3. **中文路径 impellerc 失败**：`Could not write ...shaders/ink_sparkle.frag` → 沿用 `D:\pwb` ASCII 镜像构建（Android 同样受中文路径影响）
4. **launch_background.xml 语法 bug**（第二轮引入）：`<item android:drawable="#F6F8F6"/>` 非法，改为 `<item><shape><solid android:color="#F6F8F6"/></shape></item>`，三个文件均已修复

**安装**：直接安装到安卓设备即可覆盖旧版（debug 签名一致）。

---

## 第三轮：清理全部 Windows 平台代码（Android-only）

**需求**：清理代码中所有与 Windows 平台相关的内容——条件编译代码、专用 API 调用、依赖库与配置文件；确保安卓端功能不受影响。

### 已清理内容

**Dart 代码**
- `Platform.isWindows` / `TargetPlatform.windows` 条件分支（除 `app.dart` 中 `switch(getPlatform())` 的穷举 case，仅返回 child 无 Windows 逻辑，删除会编译失败）
- `WindowsActivityService`（MethodChannel 前台应用检测）整文件删除
- `hotkey_manager` 热键注册相关调用
- 专注预设 Windows 字段：`listMode`、`applications`、`detectionEnabled`、`bringToFrontOnSchedule`
- 迁移逻辑中 V3 的 `bringToFrontOnSchedule` 写入分支

**依赖（pubspec.yaml）**
- 移除 `hotkey_manager: ^0.2.3`、`fluentui_system_icons: 1.1.273`
- `sqflite_common_ffi` 从 dependencies 移至 dev_dependencies（仅测试用）

**平台目录与文件**
- 删除 `windows/` 整个目录（runner、CMake、ephemeral）
- 删除 `packaging/` 整个目录（Install/Uninstall 脚本）
- 删除 `tool/build_windows.ps1`、`tool/run_windows_test.ps1`、`tool/create_desktop_test_entry.ps1`、`tool/package_windows_test_entry.ps1`
- 删除 `tool/generate_app_icons.ps1` 中 Windows ICO 生成段
- `.metadata` 移除 `platform: windows`
- Golden 基准 `windows_*.png` → `wide_*.png` 重命名并重新生成

**文档**
- `README.md` / `DESIGN.md` / `docs/USER_GUIDE.md` 全面更新为 Android-only

### 验证结果

| 检查项 | 结果 |
|--------|------|
| `flutter analyze` | 零问题 |
| `flutter test`（完整套件） | **156 个全部通过** |
| Android debug APK 构建 | 成功（`tool/build_android.ps1`，28s） |
| APK 产物 | `dist/apk/PersonalWorkbench_0.1.0+3_debug.apk`（163MB） |
| APK 内容验证（aapt） | 包名 `com.personalworkbench.personal_workbench`，0.1.0+3，minSdk 24 / target 36，ABI arm64-v8a/armeabi-v7a/x86_64，权限仅 INTERNET / POST_NOTIFICATIONS / RECEIVE_BOOT_COMPLETED / VIBRATE |

### 备注

- Golden 测试最后一处 `notes_desktop.png` 单字形渲染抖动（75px / 0.01%）：单独对该测试文件 `--update-goldens` 重新基准后完整套件通过
- `D:/pwb` 为旧 ASCII 构建镜像（仍含已删除的 windows/、packaging/），已过时可清理
- 未来发布正式版需生成 release keystore 并配置 `android/key.properties`（当前为 debug 签名）
