# 项目演化记录（当前状态：Windows + Android 双端）

> 本文件是历史演化记录，早期各轮的内容已过时；以 README.md 与当前代码为准。
> **当前状态**：应用为 Windows + Android 双端。Windows 是完整规划/回顾主环境，
> Android 用于快速捕获与执行；自律（SelfControl 式限制）的进程监控与 hosts 管理
> 仅在 Windows 生效。

## 历史轮次摘要

### 第一轮：AppBar 品牌化 + 页面 header 统一

审查发现安卓端与桌面端存在 5 类风格差异，统一了 AppBar 品牌化、NavigationBar 同步
状态、页面 mini-header、装饰元素与系统栏适配。

### 第二轮：Android 系统栏适配 + 细节打磨

系统栏动态适配、品牌高光细节、Android 原生启动资源、全量页面底部 padding 统一。

### 第三轮：清理全部 Windows 平台代码（Android-only）——已被后续回滚

该轮曾删除 `windows/`、`packaging/`、`hotkey_manager` 等 Windows 相关内容，并宣称
项目转为 Android-only。**该方向后来被回滚**：当前代码恢复了 Windows 双端支持
（`windows/runner/restriction_hosts.cpp`、`packaging/windows/`、`tool/build_windows.ps1`、
`hotkey_manager` 依赖与 `dist/windows/` 产物均存在），README 以双端为准。

### 第四轮：个人航行日志设计体系（当前视觉规范）

界面统一为"个人航行日志"设计体系：中性画布 + 实色工作面 + 日志航迹，详见根目录
`MASTER.md`。

## 结构优化记录（2026-09）

- **字体子集化**：`tool/subset_fonts.py` 裁掉韩文等不需要的字形（LXGW 文楷
  25.75→17.59 MB，合计 -8.9 MB），保留 CJK 基本区与扩展 A 全量；Golden 基准已随
  之重新生成。
- **构建脚本**：`tool/build_android.ps1` 新增 `-AbiMode`（universal/split/arm64/
  arm/x64）按 ABI 打包能力。
- **控制器拆分**：`WorkbenchController`（原 6827 行）按领域拆分为
  `WorkbenchController`（4682 行）+ `RestrictionControllerMixin`（自律）+
  `RsipControllerMixin`（国策）+ `WorkbenchControllerBase`（共享契约），
  公共 API 不变。
