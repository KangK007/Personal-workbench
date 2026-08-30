# 个人工作台回归测试报告

> 日期：2026-08-31
> 最终自动化：234/234 通过

## 1. 缺陷回归

| 缺陷 | 严重度 | 修复摘要 | 回归结果 |
| --- | --- | --- | --- |
| BUG-001 | P3 | 统一 Dart 格式 | 格式、分析、全套测试通过 |
| BUG-002 | P1 | Golden 基线迁入版本控制目录 | 33 张 Golden 随默认套件通过 |
| BUG-003 | P1 | 中文路径构建改用 ASCII 源码镜像 | Windows Debug/Release、Android Debug 通过 |
| BUG-004 | P1 | Gradle 临时目录缩短 | Android Debug 干净构建通过 |
| BUG-005 | P0 | 专注证据对话框移除退场期已释放控制器 | 自动化和真实 Windows 原路径通过 |
| BUG-006 | P2 | 移动今日操作避让 FAB | Android Today Golden 通过 |
| BUG-007 | P2 | 周视图日期条随文字缩放增长 | 37 表面 200% 文字矩阵通过 |
| BUG-008 | P2 | 专注全屏增加滚动退路 | 200% 文字矩阵与专注流程通过 |
| BUG-009 | P1 | 骨架动画控制器按需创建和安全释放 | 三次挂载卸载及 78 个减少动效场景通过 |
| BUG-010 | P1 | 原生选择器返回后恢复附件按钮焦点 | 自动化通过；真实修复后复验 BLOCKED |
| BUG-011 | P2 | Windows 构建成功码归零 | Debug/Release 调用方退出码 0 |
| BUG-012 | P1 | 低高度横屏使用移动导航 | 915×412 自动化和 2400×1080 真实 Android 通过 |
| BUG-013 | P0 | 任务群编辑器改为自持控制器的独立 Stateful Dialog | 新建、编辑、取消、校验和重复提交回归通过 |
| BUG-014 | P1 | 共享 Dialog 统一请求焦点、Tab 约束和 Escape | 24 个 Dialog-尺寸场景及嵌套 Dropdown 单层关闭通过 |
| BUG-015 | P2 | 修正页面表面和 Case 统计逻辑 | 256 个唯一 Case，0 未闭环、0 重复 ID |
| BUG-016 | P2 | 专注预设四个 Dropdown 窄窗自适应 | 375×812 下逐一展开、Escape 和焦点回归通过 |

## 2. 回归层级

1. 每项修复运行直接相关的单元或 Widget 测试。
2. UI 修复进入 37 表面、518 个布局场景与 222 个交互-尺寸场景，不只复测发现页面。
3. Golden 不使用 `--update-goldens` 的最终运行确认基线稳定。
4. 最终运行 234 项完整套件、静态分析和 Windows/Android 构建。
5. P0 专注崩溃、Android 权限/分享/横屏等关键分支补充真实运行证据。

## 3. 最终结果

- 功能、数据、错误注入、持久化和 UI 自动回归：PASS。
- Windows Release、Windows 安装 ZIP、Android Debug 与 Android Profile：PASS。
- TEST_MATRIX：245 PASS、11 BLOCKED、0 失败、0 未闭环。
- BUG-010 的代码修复已自动验证，但其真实原生对话框序列仍保持 BLOCKED，不提升为完整 VERIFIED。
