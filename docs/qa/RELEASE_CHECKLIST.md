# 个人工作台发布检查清单

> 检查日期：2026-08-29  
> 最终安装包刷新：2026-09-01
> 产物源码基线：`main@bae3402`
> 总体判定：**NO-GO**

## 1. 已满足

- [x] 项目地图覆盖所有实际页面、组合子页、兼容页、Dialog、Sheet、菜单、设置项和平台入口。
- [x] TEST_MATRIX 有 256 个 Case：245 PASS、0 FAIL、11 BLOCKED、0 未闭环项。
- [x] 代码格式检查通过。
- [x] `flutter analyze` 为 0 问题。
- [x] `flutter test` 234/234 通过。
- [x] 37 个表面、518 个布局场景、222 个交互-尺寸场景、24 个 Dialog-尺寸场景和 33 张 Golden 通过。
- [x] Windows Release 干净构建通过。
- [x] Android Debug 干净构建和 Android Profile 构建通过。
- [x] Windows 隔离数据库真实核心流通过。
- [x] Android 启动、IME、Back、权限、即时通知、分享、横屏和尺寸变化通过。
- [x] 三个 Windows 快捷方式指向稳定安装目录，安装 EXE 与最终 Release 哈希一致。
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

| 平台 | 路径 | 状态 |
| --- | --- | --- |
| Windows Release | `build/windows/x64/runner/Release/` | 构建 PASS；平台副作用验收未完成 |
| Windows 安装 ZIP | `dist/PersonalWorkbench_0.1.0+4_windows.zip` | 已用最终 Release 刷新、安装并验证快捷方式 |
| Android Debug | `build/app/outputs/flutter-apk/app-debug.apk` | QA 侧载 PASS，不是正式发布包 |
| Android Debug 分发副本 | `dist/apk/PersonalWorkbench_0.1.0_4_debug.apk` | 与构建 APK 哈希一致 |
| Android Debug arm64-v8a | `dist/apk/PersonalWorkbench_0.1.0_4_debug-arm64-v8a.apk` | 分架构侧载包，不是正式发布包 |
| Android Debug armeabi-v7a | `dist/apk/PersonalWorkbench_0.1.0_4_debug-armeabi-v7a.apk` | 分架构侧载包，不是正式发布包 |
| Android Debug x86_64 | `dist/apk/PersonalWorkbench_0.1.0_4_debug-x86_64.apk` | 分架构侧载包，不是正式发布包 |
| Android Profile | `build/app/outputs/flutter-apk/app-profile.apk` | 构建 PASS，用于性能验证，不是正式发布包 |
| Android Profile 分发副本 | `dist/apk/PersonalWorkbench_0.1.0_4_profile.apk` | 与构建 APK 哈希一致 |
| Android Release | 无 | BLOCKED：缺少签名配置 |

Windows 安装 ZIP SHA-256：`0CF6C45B90BA46A661FB6FEFA7FFD7129DD1AFCD46A5398F0C063ED5AE3B7965`。

Android Debug APK SHA-256：`99FF73B38E2CBDFBAC4CE1057428BE3A9FAF87B829108062CD66AB17D1716F69`。

Android Debug arm64-v8a APK SHA-256：`711E75BB17A976C6BEDDB98BB3E9F8408685FCC34AE3F96A7D5C2F5A35B80161`。

Android Debug armeabi-v7a APK SHA-256：`2B0187D82146887A2C44958F47C12766F4BD3570AFB78E8A3E1A7F6070ECF969`。

Android Debug x86_64 APK SHA-256：`DB59331029EAFD9D2FE90B6464B3B0D7E12D097031102B082CF480F25326FC23`。

Android Profile APK SHA-256：`4955DFDD623C87B450D80319E68A997971F0F711E31A11C4A50CCF722C43241C`。

## 4. 发布决策

可以继续用于隔离 QA、开发演示和本地数据试用；不应在当前状态下宣布 Windows/Android 全平台正式发布。解除 11 个矩阵阻塞项并执行相应定向回归后，再把总体判定改为 `GO`。
