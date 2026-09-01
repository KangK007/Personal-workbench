# 个人工作台 UI/UX 最终审计

> 日期：2026-09（Asia/Shanghai）
> 范围：37 个当前可构建表面、全局壳、Dialog、Sheet、Popup/Dropdown、编辑器、反馈状态与窗口矩阵；真实 Windows 运行复验（本轮）

## 1. 覆盖方法

- Default/Layout：7 个浅色视口、2 个深色视口、2 个减少动效视口、1 个 200% 字号视口、2 个空数据视口，共 37 × 14 = 518 个场景。
- Interaction：37 个表面分别在 375×812、1200×864、1536×864 触发 Hover、Pressed、Focus、Tab，并开关每个实际存在的 Popup/Dropdown，共 222 个页面交互-尺寸场景。
- Dialog：记录编辑、任务群、关联选择、Markdown、全局搜索、快速新增 6 类 Dialog × 4 个窗口/字号场景，共 24 个 Focus/Tab/Escape/长文本场景。
- 状态补充：Disabled、Selected、Loading、Empty、Error、权限拒绝、保存失败和回滚由主题与功能故障测试覆盖。
- 像素基线：33+ 张 Golden 与 21 张 UI 审计截图；54 张截图本轮全部通过空白/全黑健康检查。
- 真实运行：Windows Release 主界面（1280×720）与窄窗移动布局（420×780）截图保存于 `docs/qa/screenshots/`。

## 2. 页面逐项覆盖

| 页面族 | 实际表面 | 主要区域与状态 | 结果 |
| --- | --- | --- | --- |
| 今日 | `today` | 时间进度尺、承诺、任务、记录、空态、开始/撤销、日结收尾仪式、完成节点脉冲 | PASS |
| 任务 | `tasks_all/inbox/week/groups` | 筛选、批量栏、任务树、今天列、任务群菜单/Dialog | PASS |
| 项目 | `projects_overview/tasks/groups/milestones/notes` | 项目选择、五面板单开、数量、CRUD、清单/看板 | PASS |
| 专注 | `focus_hub/focus_session` | 预设、计时、暂停/继续、完成/取消、庆祝、长内容 | PASS |
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

Windows 宽屏使用可折叠侧栏；桌面顺序为项目、收件箱、专注。任务子项只保留全部、周视图、任务群；回顾是单一入口。移动端保留五项底栏，其余页面由"更多"访问。项目主界面使用五个单开面板。

当前页面 Selected 状态同时使用背景、前景和结构信息，不只依赖绿色。低高度手机横屏使用移动导航，避免桌面侧栏溢出。真实运行确认：四档窗口尺寸（800×600 / 420×780 / 1280×800 / 1920×1080）调整无崩溃，窄窗自动切换到移动布局。

## 4. Layout、Typography 与视觉系统

| 项目 | 结果 |
| --- | --- |
| 375–1536 宽度 | 37 表面无未处理 RenderFlex 溢出 |
| 200% 文字 | 37/37 通过；长标题和正文可换行/滚动 |
| 浅色/深色 | 关键层级和文本对比稳定（10 组关键色 ≥4.5:1） |
| Spacing | 项目面板、习惯卡、成长顶部与 Dialog 使用统一间距节奏 |
| Border/Radius/Shadow | 克制边框与阴影；Dialog/Popup 负责浮层层级 |
| Icon | 任务状态/优先级为图标 + 文字；导航和按钮语义一致 |
| Z-index | Dialog、Sheet、Popup、Tooltip、Snackbar 和 FAB 无自动化遮挡异常 |
| 字体覆盖 | 真实数据库 324 条记录全部字符在子集字体覆盖内（无豆腐块） |

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
| 动效 | 任务完成节点脉冲（一次性 180ms）、日结仪式（2s 自动关闭）、减少动效静态终态 | PASS |

## 6. 可访问性

- 关键前景/背景组合达到至少 4.5:1；状态不只靠颜色。
- Material 按钮、图标按钮和主要移动列表项满足 48dp 触控基线。
- `Ctrl+K` 搜索、Tab/Shift+Tab、Enter、Space、箭头和 Escape 有测试。
- 共享 Dialog 显式请求焦点；Escape 只关闭当前可关闭路由；Dropdown Open 时 Escape 只关闭顶层菜单。
- 减少动效使用稳定终态；37 个表面 × 2 个视口通过；任务完成脉冲在减少动效下完全不启动（binding 级检查）。
- 真实运行四档窗口尺寸无崩溃、窄窗布局正常。

## 7. 本轮 UI/UX 改进与修复

1. 任务完成"航迹节点落定"签名动效（黄铜节点 + 短航迹，180ms 一次性）。
2. 日结收尾仪式覆盖层（复用专注庆祝，2 秒自动关闭，减少动效静态版）。
3. 今日"待安排"空态从一行灰字升级为图标 + 双行文案空态。
4. 修复减少动效下任务行 `RenderAnimatedSize` 布局重入崩溃（真实缺陷）。
5. 修复设置页"成长主题"虚假承诺与不可操作候选色块（BUG-017）。
6. Windows 构建脚本对运行实例锁定产物给出可操作提示（BUG-018）。

## 8. 证据索引

- Golden：`test/goldens/`、`test/goldens/ui_audit/`
- 状态矩阵自动化：`test/ui_audit_screenshot_test.dart`
- 动效测试：`test/task_completion_pulse_test.dart`
- 主题状态：`test/theme_accessibility_test.dart`
- 真实运行截图：`docs/qa/screenshots/runtime_smoke_main.png`、`runtime_narrow_mobile.png`
- 详细 Case：`docs/qa/TEST_MATRIX.md`
- 缺陷闭环：`docs/qa/BUGS.md`

## 9. 限制与发布影响

`U4D-038` 为 BLOCKED：缺少可激活捕获窗口的原生自动化，无法完成真实 Windows 指针/键盘全表面第二轮视觉复验；Stitch、原生文件选择器、真实系统副作用、Supabase、Android 休眠/重启通知与 DOCX 逐页渲染亦受环境限制。自动化覆盖全部通过，真实运行冒烟（启动/渲染/尺寸/数据/退出）通过；整体发布结论为 **READY WITH KNOWN ISSUES**。
