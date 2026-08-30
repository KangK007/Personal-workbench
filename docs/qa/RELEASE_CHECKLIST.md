# 个人工作台发布检查清单

> 检查日期：2026-08-29  
> 最终安装包刷新：2026-08-30  
> 总体判定：**NO-GO**

## 1. 已满足

- [x] 项目地图覆盖所有实际页面、组合子页、兼容页、Dialog、Sheet、菜单、设置项和平台入口。
- [x] TEST_MATRIX 有 208 个 Case，0 失败、0 未闭环项。
- [x] 代码格式检查通过。
- [x] `flutter analyze` 为 0 问题。
- [x] `flutter test` 229/229 通过。
- [x] 39 个表面、546 个布局场景和 33 张 Golden 通过。
- [x] Windows Release 干净构建通过。
- [x] Android Debug 干净构建通过。
- [x] Windows 隔离数据库真实核心流通过。
- [x] Android 启动、IME、Back、权限、即时通知、分享、横屏和尺寸变化通过。
- [x] 三个 Windows 快捷方式指向最终 Release 产物。
- [x] 源码敏感信息扫描未发现提交的密钥。
- [x] 缺陷、回归、UI/UX 和最终 QA 报告齐全。
- [x] Word 用户手册已生成并完成 29/29 页原始分辨率视觉检查。

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
| Windows 安装 ZIP | `dist/PersonalWorkbench_0.1.0+4_windows.zip` | 已刷新并验证包含安装器与应用 EXE |
| Android Debug | `build/app/outputs/flutter-apk/app-debug.apk` | QA 侧载 PASS，不是正式发布包 |
| Android Debug 分发副本 | `dist/apk/PersonalWorkbench_0.1.0_4_debug.apk` | 与构建 APK 哈希一致 |
| Android Profile | `build/app/outputs/flutter-apk/app-profile.apk` | 构建 PASS，用于性能验证，不是正式发布包 |
| Android Profile 分发副本 | `dist/apk/PersonalWorkbench_0.1.0_4_profile.apk` | 与构建 APK 哈希一致 |
| Android Release | 无 | BLOCKED：缺少签名配置 |

Windows 安装 ZIP SHA-256：`DEEA3E4A0BD586351A09542CAE485B2CF91B6827BF0CC6911FCB680BA7E903FC`。  
Android Debug APK SHA-256：`2DCD656C07D5D2F8F69A5B16F8D4795664FB553AA2DC71F687B63651EF9AB442`。  
Android Profile APK SHA-256：`A13B34CB7FA7192B8ABEDFF3A0ED47A916D0F1ACCF7E9C913E41FAC8CD9BC237`。

## 4. 发布决策

可以继续用于隔离 QA、开发演示和本地数据试用；不应在当前状态下宣布 Windows/Android 全平台正式发布。解除 9 个矩阵阻塞项并执行相应定向回归后，再把总体判定改为 `GO`。
