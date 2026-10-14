# 个人工作台发布检查清单

## 2026-10-14 增量检查：0.2.2+8

源码分支：`feature/jade-responsive-layout-20261014`。454 项 Flutter 测试通过，静态分析 0 issue，Windows Release 构建通过。35 个审计页面的双主题断点矩阵已更新并逐页检查代表尺寸；真实 Windows 系统缩放已测 125%、150%、175%，本机 200% 需注销，见 `docs/jade-redesign/VERIFICATION.md`。

| 当前本地分发产物 | SHA-256 | 状态 |
|---|---|---|
| `dist/PersonalWorkbench_0.2.2+8_windows_setup.exe` | `75CB386A2D0D781DD7A9A262092F93C7F70197E6CF9B981DD763100C0CBB2A29` | Inno Setup 7 安装向导；中英文安装说明、可选目录、桌面入口和开机启动、开始菜单与系统卸载入口；本机自签证书已验。自定义目录静默安装、选项勾选/不勾选、快捷方式同步和卸载通过，卸载后程序目录和注册项均清除 |
| `dist/PersonalWorkbench_0.2.2+8_windows.zip` | `98F5D5417A1855325FB26C6D0D1662E2BFBEE62C345032DFFA339AE9D6105355` | Windows 安装 ZIP 已生成，分离式 CMS 签名与本机自签证书指纹已验，4 项签名测试通过；未安装到稳定目录 |
| `dist/apk/PersonalWorkbench_0.2.2_8_debug.apk` | `71FA85ADF917794D25277CEE1E5DBEB2320538216F7D63904B2B91709A9169EB` | 通用 Debug APK；`versionCode=8`、`versionName=0.2.2`、v2 签名已验 |
| `dist/apk/PersonalWorkbench_0.2.2_8_debug-arm64-v8a.apk` | `A7F6947651141FB1713D886F637A61FD6D66D0791B94058CE9350A31D2DC09B3` | ARM64 Debug APK；只含 ARM64 Flutter 引擎库，插件仍含多 ABI 库 |
| `dist/apk/PersonalWorkbench_0.2.2_8_debug-armeabi-v7a.apk` | `F007A3A135B07FBF158D8D1CE7B00D9C2A70C366FD74B329B835813E078F53FF` | ARM32 Debug APK；只含 ARM32 Flutter 引擎库，插件仍含多 ABI 库 |
| `dist/apk/PersonalWorkbench_0.2.2_8_debug-x86_64.apk` | `614781E5BBCA0D96EB318CAE5519AC6D754F28404BF081587EC04BE522554C72` | x86_64 Debug APK；只含 x86_64 Flutter 引擎库，插件仍含多 ABI 库 |

**个人使用打包决定（2026-10-14）：**用户选择暂不配置 Android 发布签名，使用上表已构建并验签的 Debug APK；本轮不生成 Android Release APK，也不创建新发布密钥。当前机器没有原有发布 keystore 和 `android/key.properties`。以后若需要覆盖安装旧版 Release，须使用原发布密钥。Windows 安装 EXE 与 ZIP 使用本机自签证书，目标机器若未信任该证书，会显示发布者未受信任；本次校验未把该证书加入当前用户的受信任根库。

以下为 2026-09-20 的历史检查记录，其版本和分支描述不代表上述当前产物。

> 检查日期：2026-09-20
> 最终安装包刷新：2026-09-20
> 产物源码基线：当前工作区 `main`
> 总体判定：**NO-GO**

> 本轮复核（2026-09-18）：241/241 Flutter 测试通过，Android arm64 Debug 构建与 Golden/UI 回归通过；Android Release 签名、真实设备休眠/重启通知、隔离 Supabase 与 Windows 原生副作用仍保持 BLOCKED。

> **版本变更追加（2026-09-19）**：应用版本由 `0.1.0+4` 升至 **`0.2.0+5`**（含「柔壤 · 年轮」全面界面优化）。
> 下方第 3 节中所有 `0.1.0+4` 的产物文件名均为**旧版记录**，仅作历史留存；
> 当前产物名为 `dist/PersonalWorkbench_0.2.0+5_windows.zip` 与
> `dist/apk/PersonalWorkbench_0.2.0_5_debug-arm64-v8a.apk`。
> 设置页界面显示约定同步为「个人工作台 0.2」。
> **提交前复核（2026-09-19）**：版本同步、产物命名、APK 自动发现、Windows 插件符号链接预建和状态校验式删除已完成；本次重新构建已刷新 Windows 安装包、Android arm64 Debug 分发包和三个快捷方式。

> **版本变更追加（2026-09-20）**：应用版本由 `0.2.0+5` 升至 **`0.2.1+6`**（含「柔壤 · 年轮」形态落地、应用图标全链路重制、新增令牌一致性与字形覆盖门禁）。
> 下表第 3 节中 `0.2.0+5` 的行是**上一版记录**，仅作历史留存；
> 当前产物名为 `dist/PersonalWorkbench_0.2.1+6_windows.zip` 与
> `dist/apk/PersonalWorkbench_0.2.1_6_debug-arm64-v8a.apk`。
> **提交前复核（2026-09-20）**：`dart format` 99 文件 0 差异、`flutter analyze` 无问题、`flutter test` **243/243 通过**；
> `verify_colors` / `verify_token_parity` / `verify_glyph_coverage` / `verify_windows_build` / `verify_apk` 五支门禁全部通过。
> Windows Release EXE 与稳定安装目录 EXE SHA-256 一致（`6354AB9B…`），版本资源 `0.2.1+6`；三个快捷方式全部指向稳定安装目录。
> Android 分发 APK 经 `aapt dump badging` 实测 `versionCode=6 / versionName=0.2.1`。
> **发布链加固（2026-09-20 二次复核）**：上一轮遗留的两项已闭环 —— ① 快捷方式写入改为「有限次重试」，且 `build_windows.ps1` 中该步骤降级为**非致命告警**（原会让成功的构建以退出码 1 结束、`dist/` 完全不发布）；② `test/failures/` 100 个陈旧 golden 产物（8.22 MB）已清理。同时修掉同类隐患：`package_windows_release.ps1` 与 `build_android.ps1` 末尾缺退出码归零，会把调用方遗留的 `$LASTEXITCODE` 原样抛给调用者。三项均已用故障注入逐条验证，详见 `docs/PROJECT_MAINTENANCE.md`。

## 1. 已满足

- [x] 项目地图覆盖所有实际页面、组合子页、兼容页、Dialog、Sheet、菜单、设置项和平台入口。
- [x] TEST_MATRIX 有 261 个 Case：251 PASS、0 FAIL、10 BLOCKED、0 未闭环项。
- [x] 代码格式检查通过。
- [x] `flutter analyze` 为 0 问题。
- [x] `flutter test --no-pub --reporter compact` 245/245 通过。
- [x] 37 个表面、518 个布局场景、222 个交互-尺寸场景、24 个 Dialog-尺寸场景和 33 张 Golden 通过。
- [x] Windows Release 干净构建通过。
- [x] Android Debug 干净构建和 Android Profile 构建通过。
- [x] Windows 隔离数据库真实核心流通过。
- [x] Android 启动、IME、Back、权限、即时通知、分享、横屏和尺寸变化通过。
- [x] 三个 Windows 快捷方式（桌面、开始菜单英文、开始菜单中文）均指向稳定安装目录；安装 EXE 与本次 Release EXE SHA-256 一致，版本资源均为 `0.2.1+6`。
- [x] 快捷方式写入的瞬时锁已可自愈：`tool/update_all_shortcuts.ps1` 与 `packaging/windows/Install-PersonalWorkbench.ps1` 各带 5 次指数退避重试（250/500/1000/2000 ms）；`build_windows.ps1` 的该步骤失败只告警、不再终止发布。已用「另一进程独占句柄」注入故障并跑完真实构建做端到端验证。
- [x] 三个入口脚本（`build_windows.ps1` / `package_windows_release.ps1` / `build_android.ps1`）末尾统一把 `$LASTEXITCODE` 归零，不再把调用方遗留的退出码当作自身结果上报。
- [x] `test/failures/` 的 100 个陈旧 golden 失败产物（8.22 MB）已清理；该目录被 `.gitignore` 忽略，`flutter_test` 需要时按需重建。
- [x] 源码敏感信息扫描未发现提交的密钥。
- [x] 缺陷、回归、UI/UX 和最终 QA 报告齐全。
- [x] Word 用户手册已生成，OOXML 结构与可访问性审计通过。

## 2. 发布前必须解除

- [ ] 提供 `android/key.properties` 和受控私有 keystore，完成 Android Release 签名构建和验签。
- [ ] 在隔离 Windows 用户/VM 中验证系统通知、托盘退出、开机启动、全局快速新增、进程限制与 hosts/UAC。
- [ ] 在无用户前台干扰的 Windows 会话中复验 BUG-010 原生图片选择器取消与焦点恢复。
- [ ] 提供隔离 Supabase 环境，执行真实分页、冲突、失败恢复和 RLS 验收。
- [ ] 在物理 Android 设备或稳定模拟器上验证定时通知经过休眠、重启和升级安装后不丢失、不重复。
- [ ] 为正式分发补充许可证、隐私政策、数据删除说明和版本发布说明。

## 3. 发布产物

> 标「当前版本」的行为本轮 0.2.1+6 的实测产物；末尾一行保留 `0.2.0+5` 作为上一版记录。

| 平台 | 路径 | 状态 |
| --- | --- | --- |
| Windows Release | `build/windows/x64/runner/Release/` | 构建 PASS；平台副作用验收未完成 |
| Windows 安装 ZIP（当前版本） | `dist/PersonalWorkbench_0.2.1+6_windows.zip` | 已用当前 Release 刷新并安装；SHA-256 `CD4C2654BB89172D3D02683BEBE26DACFF68FFFB281B7CCDABF3E8CC08BB3F96` |
| Android Debug | `build/app/outputs/flutter-apk/app-debug.apk` | QA 侧载 PASS，不是正式发布包 |
| Android Debug 分发副本 | `dist/apk/` | 本轮只重新生成 arm64-v8a |
| Android Debug arm64-v8a（当前版本） | `dist/apk/PersonalWorkbench_0.2.1_6_debug-arm64-v8a.apk` | 当前 arm64 分架构侧载包；SHA-256 `A5EF2F83962152BC7A1E6BDFD446D28AE400AC99DEF517663DDA1D1EFBFA445B`；`aapt` 实测 `versionCode=6 / versionName=0.2.1`，不是正式发布包 |
| Android Debug armeabi-v7a | `dist/apk/` | 本轮未重新生成该 ABI 包 |
| Android Debug x86_64 | `dist/apk/` | 本轮未重新生成该 ABI 包 |
| Android Profile | `build/app/outputs/flutter-apk/app-profile.apk` | 构建 PASS，用于性能验证，不是正式发布包 |
| Android Profile 分发副本 | `dist/apk/` | 本轮未重新生成 Profile 包 |
| Android Release | 无 | BLOCKED：缺少签名配置 |
| —— 历史记录（0.2.0+5） | `dist/PersonalWorkbench_0.2.0+5_windows.zip`、`dist/apk/PersonalWorkbench_0.2.0_5_debug-arm64-v8a.apk` | 已被本轮新包替换，旧文件由构建脚本按「同形态模式清理」自动删除 |

Windows 安装 ZIP SHA-256（0.2.1+6）：`CD4C2654BB89172D3D02683BEBE26DACFF68FFFB281B7CCDABF3E8CC08BB3F96`。

Windows Release EXE / 稳定安装目录 EXE SHA-256（0.2.1+6，两者一致）：`6354AB9BD6E00C791DA1A472A25BDB0DFB608339AA49FF7230B412841032A8D3`。

> 注：Windows 构建**不是逐字节可复现的**（同一份源码两次构建的 EXE 哈希不同，体积一致）。因此「产物一致」的判据取**版本资源 + AOT 符号探针 + 打包/安装两份哈希相同**，而非跨构建比较哈希。上一轮的 `02EA7753F96D7C43266F833D8DC0FB4B4376A1FB1E5A424CD2AA9E3132B257EF` 记录作废。

Android Debug arm64-v8a APK SHA-256（0.2.1+6）：`A5EF2F83962152BC7A1E6BDFD446D28AE400AC99DEF517663DDA1D1EFBFA445B`。

以下为历史版本 SHA-256，保留以备比对：

Android Debug APK SHA-256（0.2.0+5）：`4E7AF7045ECE9369B5AFBE8017963EA0124AD5F9C153E92855B25021BA6E6B0B`。

Android Debug arm64-v8a APK SHA-256（0.2.0+5）：`7D3948347389F5A01C65EFF3E7D10F1353272B3A730E04719F93D3EE245C6F8F`。

Android Debug armeabi-v7a APK SHA-256（0.1.0+4）：`654B5BC6A8AC2D8339BA86529EC4643C4E03CA058697C3D6743E2C332F77DB93`。

Android Debug x86_64 APK SHA-256（0.1.0+4）：`52962B03829A798A9275B8A14A121209B658DA851FB6F92C819658F558F3C320`。

Android Profile APK SHA-256（0.1.0+4）：`E25A58D5050060B88A49AB103DF90DD4CB0E7DB92EAA4754DB5F7F5A389EA71A`。

## 4. 发布决策

可以继续用于隔离 QA、开发演示和本地数据试用；不应在当前状态下宣布 Windows/Android 全平台正式发布。解除 11 个矩阵阻塞项并执行相应定向回归后，再把总体判定改为 `GO`。
