# 个人工作台 UI/UX 最终审计

> 日期：2026-08-29  
> 范围：39 个页面/子页表面、全局壳、Dialog、Sheet、菜单、编辑器、平台对话框和状态反馈

## 1. 覆盖方法

- 7 个浅色视口：375×812、412×915、768×864、1024×864、1200×864、1440×900、1536×864。
- 深色：412×915 与 1200×864。
- 减少动效：412×915 与 1200×864。
- 200% 文字缩放：375×812。
- 空数据：412×915 与 1200×864。
- 合计：39×14 = 546 个布局场景。
- 像素基线：33 张 Golden；真实运行：Windows 7 张、Android 8 张截图。

## 2. 信息架构

Windows 宽屏使用可折叠侧栏；移动端使用今日、任务、回顾、行为、设置五项底栏，其他页面由“更多”Sheet 访问。21 个实际导航目标均进入清单；兼容的 Diary、Protocols 和旧 section 映射单独验证，不把兼容组件误写成普通导航入口。

低高度手机横屏原先误入桌面侧栏并溢出 29px。修复后高度低于 600 逻辑像素时使用移动导航，2400×1080 真实模拟器显示完整五项语义标签。

## 3. 视觉与响应式

| 项目 | 结果 |
| --- | --- |
| 浅色/深色 | 39 表面全覆盖，无错误反转或关键低对比 |
| 375–1536 宽度 | 无未处理 RenderFlex 溢出 |
| 200% 文字 | 周视图和专注页修复后 39/39 通过 |
| 空态 | 每个表面提供状态说明或下一步动作 |
| 大量数据 | 1000 条任务渲染与滚动约 1.442 s，无布局失败 |
| 中文/英文/数字/长文本 | 换行、省略、数字基线和容器边界测试通过 |
| Z 轴 | Dialog、Sheet、Menu、Tooltip、Snackbar 与 FAB 无已知遮挡回归 |

## 4. 可访问性

- 浅深主题 10 组关键前景/背景组合均达到至少 4.5:1。
- Material 按钮、图标按钮、列表项在移动主题中满足 48dp 主要触控目标。
- `Ctrl+K` 打开搜索后输入框聚焦；Tab、Shift+Tab、Enter、Space、箭头和 Escape 路径有 Widget 覆盖。
- Android UIAutomator 能读取页面标题、按钮、开关、导航序号、选中状态和系统权限按钮。
- 减少动效下使用静态终态；SkeletonBlock 生命周期缺陷修复后 78 个页面场景通过。
- 原生图片选择器取消后的焦点恢复已有自动回归；真实修复后平台复验保持 BLOCKED。

## 5. 状态和错误反馈

Loading、empty、selected、disabled、error、success、permission denied、save failure、database rollback、wrong password、invalid import 和无搜索结果均有自动化覆盖。错误信息保留输入并给出恢复动作；危险删除和恢复使用确认流程。

## 6. 本轮视觉相关修复

1. 今日移动端“更换承诺”避让 FAB。
2. 周视图日期条适配 200% 文字缩放。
3. 专注全屏在高内容高度下可滚动。
4. SkeletonBlock 在减少动效卸载时不再访问已停用上下文。
5. Android 低高度横屏改用移动导航。

## 7. 证据索引

- Golden：`test/goldens/` 与 `test/goldens/ui_audit/`。
- Windows 截图：`docs/qa/screenshots/runtime_*.png`。
- Android 截图：`docs/qa/screenshots/android_*.png`。
- Android 语义树：`docs/qa/android_*_uiautomator.xml`。
- 详细 Case：`docs/qa/TEST_MATRIX.md`。
- 缺陷：`docs/qa/BUGS.md`。

## 8. 剩余限制

Stitch 不可用；Windows 原生系统副作用、真实 Supabase、原生选择器修复后复验和 Android 休眠/重启定时通知仍为环境阻塞。它们不影响已完成的 546 个 Flutter 布局场景，但阻止整体正式发布判定为 `GO`。

