# 个人工作台 UI/UX 最终审计

> 日期：2026-08-31
> 范围：37 个当前可构建表面、全局壳、Dialog、Sheet、Popup/Dropdown、编辑器、反馈状态与窗口矩阵

## 1. 覆盖方法

- Default/Layout：7 个浅色视口、2 个深色视口、2 个减少动效视口、1 个 200% 字号视口、2 个空数据视口，共 37 × 14 = 518 个场景。
- Interaction：37 个表面分别在 375×812、1200×864、1536×864 触发 Hover、Pressed、Focus、Tab，并开关每个实际存在的 Popup/Dropdown，共 222 个页面交互-尺寸场景。
- Dialog：记录编辑、任务群、关联选择、Markdown、全局搜索、快速新增 6 类 Dialog × 4 个窗口/字号场景，共 24 个 Focus/Tab/Escape/长文本场景。
- 状态补充：Disabled、Selected、Loading、Empty、Error、权限拒绝、保存失败和回滚由主题与功能故障测试覆盖。
- 像素基线：33 张 Golden；真实运行证据：Windows 7 张、Android 8 张截图。

## 2. 页面逐项覆盖

| 页面族 | 实际表面 | 主要区域与状态 | 结果 |
| --- | --- | --- | --- |
| 今日 | `today` | 时间进度尺、承诺、任务、记录、空态、开始/撤销 | PASS |
| 任务 | `tasks_all/inbox/week/groups` | 筛选、批量栏、任务树、今天列、任务群菜单/Dialog | PASS |
| 项目 | `projects_overview/tasks/groups/milestones/notes` | 项目选择、五面板单开、数量、CRUD、清单/看板 | PASS |
| 专注 | `focus_hub/focus_session` | 预设、计时、暂停/继续、完成/取消、长内容 | PASS |
| 自律 | `restriction` | 规则、诊断、保护设置、菜单与错误 | 自动化 UI PASS；真实系统副作用 BLOCKED |
| 笔记 | `notes` | 搜索、筛选、阅读、编辑、关联 Dialog、附件 | 自动化 UI PASS；原生文件选择器复验 BLOCKED |
| 回顾 | `review_diary/weekly/monthly` | 类别切换、周期、编辑/库/预览、当前/历史/未来 | PASS |
| 兼容记录 | `legacy_diary` | 旧记录读取与操作 | PASS |
| 目标 | `goals` | 目标树、里程碑、节点菜单 | PASS |
| 习惯 | `habits/behavior_habits` | 独立卡片、今日打卡、历史只读、RSIP 禁用 | PASS |
| 行为国策 | `behavior_policies_tree/library/history/analytics` | 节点、归档、轮次、分析与菜单 | PASS |
| 独立国策 | `policies_tree/library/history/analytics` | 兼容独立表面的同类状态 | PASS |
| 兼容协议 | `legacy_protocols_goals/habits/execution/rules/analytics` | 兼容组件与控件状态 | PASS |
| 成长 | `growth` | XP、签到、积分、反馈、窄屏/200% 字号 | PASS |
| 设置 | `settings` | 开关、Dropdown、权限、同步、备份、错误与禁用 | PASS |
| 移动更多 | `more` | 全入口、选中、焦点和触控 | PASS |

## 3. 信息架构与导航

Windows 宽屏使用可折叠侧栏；桌面顺序为项目、收件箱、专注。任务子项只保留全部、周视图、任务群；回顾是单一入口。移动端保留五项底栏，其余页面由“更多”访问。项目主界面使用五个单开面板，笔记和回顾分开计数与编辑。

当前页面 Selected 状态同时使用背景、前景和结构信息，不只依赖绿色。低高度手机横屏使用移动导航，避免桌面侧栏溢出。

## 4. Layout、Typography 与视觉系统

| 项目 | 结果 |
| --- | --- |
| 375–1536 宽度 | 37 表面无未处理 RenderFlex 溢出 |
| 200% 文字 | 37/37 通过；长标题和正文可换行/滚动 |
| 浅色/深色 | 关键层级和文本对比稳定 |
| Spacing | 项目面板、习惯卡、成长顶部与 Dialog 使用统一间距节奏 |
| Border/Radius/Shadow | 克制边框与阴影；Dialog/Popup 负责浮层层级 |
| Icon | 任务状态/优先级为图标 + 文字；导航和按钮语义一致 |
| Z-index | Dialog、Sheet、Popup、Tooltip、Snackbar 和 FAB 无自动化遮挡异常 |

## 5. 组件与交互状态

| 类别 | 检查内容 | 结果 |
| --- | --- | --- |
| Button/Icon Button | Default、Hover、Pressed、Focus、Disabled、48dp | PASS |
| Input/Form | 空值、非法值、长文本、中文/英文/数字、错误、重复提交 | PASS |
| Select/Dropdown/Popup | 三窗口尺寸全部实际入口逐一开关 | PASS |
| Switch/Checkbox/Segmented | Checked/Unchecked、Selected、Disabled、键盘 | PASS |
| Dialog/Modal/Sheet | Open、Focus、Tab、Escape、Cancel、Save、长文本、Resize | PASS；原生第二轮见限制 |
| List/Tree/Card | Empty、Normal、大量数据、展开/折叠、异常关系 | PASS |
| Toast/Snackbar/Error | Success、Failure、Permission denied、Rollback | PASS |

## 6. 可访问性

- 关键前景/背景组合达到至少 4.5:1；状态不只靠颜色。
- Material 按钮、图标按钮和主要移动列表项满足 48dp 触控基线。
- `Ctrl+K` 搜索、Tab/Shift+Tab、Enter、Space、箭头和 Escape 有测试。
- BUG-014 修复后，共享 Dialog 显式请求焦点；根 Focus 不参与 Tab 顺序；Escape 只关闭当前可关闭路由。
- 减少动效使用稳定终态；37 个表面 × 2 个视口通过。
- Android 既有语义树可读取标题、按钮、开关、导航和选中状态。

## 7. 本轮修复

1. 补齐 37 个表面在三种窗口尺寸的 Hover、Pressed、Focus、Keyboard 自动化。
2. 遍历并开关 37 个表面的全部实际 Popup/Dropdown。
3. 新增 6 类共享 Dialog × 4 场景的焦点、Escape、长文本回归。
4. 修复共享 `showGeneralDialog` 未统一取得焦点、不可点遮罩 Dialog 缺少一致 Escape 路径的问题。
5. 修复 Escape 在 Dropdown Open 状态下同时关闭菜单和父 Dialog 的层级错误。
6. 修复专注预设 4 个 Dropdown 在 375px 窄窗下的 3px 溢出，并逐一验证打开/关闭。
7. 修复初版根 Focus 参与 Tab 遍历造成的焦点顺序回归。
8. 纠正 QA 文档把 37 个实际表面误记为 39 个、漏计 `A11Y-*` Case 的统计错误。

## 8. 证据索引

- Golden：`test/goldens/`、`test/goldens/ui_audit/`
- 状态矩阵自动化：`test/ui_audit_screenshot_test.dart`
- 主题状态：`test/theme_accessibility_test.dart`
- Windows/Android 截图：`docs/qa/screenshots/`
- 详细 Case：`docs/qa/TEST_MATRIX.md`
- 缺陷闭环：`docs/qa/BUGS.md`

## 9. 限制与发布影响

`U4D-038` 为 BLOCKED：最终代码的 Windows 隔离 Debug 已创建真实窗口与数据库，Release 随后重建，但 Computer Use 无法激活捕获窗口，不能完成本轮原生指针/键盘的全表面第二轮视觉复验。Stitch、原生文件选择器、真实系统副作用、Supabase、Android 休眠/重启通知和更新后 DOCX 渲染也有明确 BLOCKED。自动化覆盖通过，但这些限制使整体发布结论保持 `NOT READY`。
