# 个人工作台发布检查清单

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
> Windows Release EXE 与稳定安装目录 EXE SHA-256 一致（`02EA7753…`），版本资源 `0.2.1+6`；三个快捷方式全部指向稳定安装目录。
> Android 分发 APK 经 `aapt dump badging` 实测 `versionCode=6 / versionName=0.2.1`。
> ⚠️ 构建期异常：`build_windows.ps1` 的快捷方式步骤因桌面 `.lnk` 瞬时占用抛错，导致该次构建以退出码 1 结束、`dist/` 未发布；事后单独重跑同一调用即成功，未复现。详见 `docs/PROJECT_MAINTENANCE.md` 待办第 1 项。

## 1. 已满足

- [x] 项目地图覆盖所有实际页面、组合子页、兼容页、Dialog、Sheet、菜单、设置项和平台入口。
- [x] TEST_MATRIX 有 261 个 Case：250 PASS、0 FAIL、11 BLOCKED、0 未闭环项。
- [x] 代码格式检查通过。
- [x] `flutter analyze` 为 0 问题。
- [x] `flutter test` 243/243 通过。
- [x] 37 个表面、518 个布局场景、222 个交互-尺寸场景、24 个 Dialog-尺寸场景和 33 张 Golden 通过。
- [x] Windows Release 干净构建通过。
- [x] Android Debug 干净构建和 Android Profile 构建通过。
- [x] Windows 隔离数据库真实核心流通过。
- [x] Android 启动、IME、Back、权限、即时通知、分享、横屏和尺寸变化通过。
- [x] 三个 Windows 快捷方式（桌面、开始菜单英文、开始菜单中文）均指向稳定安装目录；安装 EXE 与本次 Release EXE SHA-256 一致，版本资源均为 `0.2.1+6`。
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
| Windows 安装 ZIP（当前版本） | `dist/PersonalWorkbench_0.2.1+6_windows.zip` | 已用当前 Release 刷新并安装；SHA-256 `48D5FFBF4A331BA64CC54D766D501715A718077B375C443269B76D9BB1D52200` |
| Android Debug | `build/app/outputs/flutter-apk/app-debug.apk` | QA 侧载 PASS，不是正式发布包 |
| Android Debug 分发副本 | `dist/apk/` | 本轮只重新生成 arm64-v8a |
| Android Debug arm64-v8a（当前版本） | `dist/apk/PersonalWorkbench_0.2.1_6_debug-arm64-v8a.apk` | 当前 arm64 分架构侧载包；SHA-256 `A5EF2F83962152BC7A1E6BDFD446D28AE400AC99DEF517663DDA1D1EFBFA445B`；`aapt` 实测 `versionCode=6 / versionName=0.2.1`，不是正式发布包 |
| Android Debug armeabi-v7a | `dist/apk/` | 本轮未重新生成该 ABI 包 |
| Android Debug x86_64 | `dist/apk/` | 本轮未重新生成该 ABI 包 |
| Android Profile | `build/app/outputs/flutter-apk/app-profile.apk` | 构建 PASS，用于性能验证，不是正式发布包 |
| Android Profile 分发副本 | `dist/apk/` | 本轮未重新生成 Profile 包 |
| Android Release | 无 | BLOCKED：缺少签名配置 |
| —— 历史记录（0.2.0+5） | `dist/PersonalWorkbench_0.2.0+5_windows.zip`、`dist/apk/PersonalWorkbench_0.2.0_5_debug-arm64-v8a.apk` | 已被本轮新包替换，旧文件由构建脚本按「同形态模式清理」自动删除 |

Windows 安装 ZIP SHA-256（0.2.1+6）：`48D5FFBF4A331BA64CC54D766D501715A718077B375C443269B76D9BB1D52200`。

Windows Release EXE / 稳定安装目录 EXE SHA-256（0.2.1+6，两者一致）：`02EA7753F96D7C43266F833D8DC0FB4B4376A1FB1E5A424CD2AA9E3132B257EF`。

Android Debug arm64-v8a APK SHA-256（0.2.1+6）：`A5EF2F83962152BC7A1E6BDFD446D28AE400AC99DEF517663DDA1D1EFBFA445B`。

以下为历史版本 SHA-256，保留以备比对：

Android Debug APK SHA-256（0.2.0+5）：`4E7AF7045ECE9369B5AFBE8017963EA0124AD5F9C153E92855B25021BA6E6B0B`。

Android Debug arm64-v8a APK SHA-256（0.2.0+5）：`7D3948347389F5A01C65EFF3E7D10F1353272B3A730E04719F93D3EE245C6F8F`。

Android Debug armeabi-v7a APK SHA-256（0.1.0+4）：`654B5BC6A8AC2D8339BA86529EC4643C4E03CA058697C3D6743E2C332F77DB93`。

Android Debug x86_64 APK SHA-256（0.1.0+4）：`52962B03829A798A9275B8A14A121209B658DA851FB6F92C819658F558F3C320`。

Android Profile APK SHA-256（0.1.0+4）：`E25A58D5050060B88A49AB103DF90DD4CB0E7DB92EAA4754DB5F7F5A389EA71A`。

## 4. 发布决策

可以继续用于隔离 QA、开发演示和本地数据试用；不应在当前状态下宣布 Windows/Android 全平台正式发布。解除 11 个矩阵阻塞项并执行相应定向回归后，再把总体判定改为 `GO`。
