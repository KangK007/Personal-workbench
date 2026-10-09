# 双主题升级实施与验收记录

执行日期：2026-10-08。设计依据：[完整执行方案](DUAL_THEME_EXECUTION_PLAN.md)。资源来源与压缩记录：[插画清单](DUAL_THEME_ASSET_MANIFEST.md)。

2026-10-09 的后续窗口自适应修正及最新验证结果见[全页面自适应布局修正与验收](RESPONSIVE_LAYOUT_VALIDATION.md)。下文 313 项测试为本次双主题升级当日的历史记录。

## 1. 已实施的设计系统

- 柔壤图鉴：新芽绿、浅纸面、陶土成果色，文楷标题与植物插画。
- 夜航工作室：深靛蓝工作面、冷青操作色、琥珀成果色，IBM Plex Sans SC 标题与工作台插画。
- 正文使用 IBM Plex Sans SC，计时和统计使用 IBM Plex Mono；延续项目内置字体及许可证。
- 颜色、表面、边界、阴影、形状、交互状态集中于 `app_theme.dart` 与 `WorkbenchTokens`；CSS 预览令牌同步校验。
- 最终对比度微调：白天主色 `#347340`、辅助文字 `#4F6959`、次级小字 `#586F60`；夜间次级小字 `#99AEBF`。正文、辅助小字和主操作文字在画布、工作面、分组面和选中面均按 4.5:1 检查，不能把有意义的小字按“装饰”放宽。
- 维持 `system / light / dark` 与 `theme_mode` 持久化。系统模式跟随设备亮度；不依据时钟自动换肤。
- 统一按钮、导航、页面标题、表单、状态标签、任务行、弹层、提示及减少动态效果规则。Android 按钮、习惯日期格和快速收集工具按钮采用至少 48dp 触控盒。
- 14 张透明、无文字 WebP 插画已纳入应用，其中复用 4 张入选原画、新生成 10 张；生产素材共 1,868,718 字节。图像稳定占位、限制解码宽度并排除装饰性读屏内容。

## 2. 逐领域实施与证据

下表对应 Windows 与 Android 的响应式原生页面；业务图形从控制器数据计算。Golden 中使用隔离测试数据库，不向真实数据库注入演示数据。

| 界面范围 | 特色元素、主操作及交互 | 主要证据 |
| --- | --- | --- |
| 今日 | 时间尺、任务概览、承诺、下一项任务、今日重点；空任务显示“今日尚未安排”，不伪造百分比 | `today_page.dart`；`game_ui_test.dart`；今日双主题 Goldens |
| 全部任务 | 层级连接线、状态/日期筛选、排期/截止/更新/优先级排序、批量选择 | `plan_page.dart`；`plan_filter_test.dart`；`ui_coverage_regression_test.dart` |
| 收集箱、快速收集 | 来源类型、待归位队列、日期与项目选择；键盘上方固定“收下”，保留输入 | `inbox_page.dart`；`quick_capture_sheet.dart`；`mobile_fab_clearance_regression_test.dart` |
| 周计划、任务群 | 真实时间块、冲突与当前时间；顺序/并行关系、成员展开及重排 | `calendar_page.dart`；`plan_page.dart`；周冲突 Golden 与交互回归 |
| 项目概览/任务/任务群/里程碑/笔记 | 项目主从结构、真实完成比例、状态清单/看板、成员、里程碑时间线、文档索引；历史回顾进入对应期间并可返回项目 | `projects_page.dart`；`optimization_regression_test.dart`；项目桌面及双主题手机截图 |
| 专注准备/会话 | 预设轨道、任务选择、稳定计时、阶段与证据；预设名称/时长校验、保存失败及关闭保护 | `focus_page.dart`；`focus_preset_editor_validation_test.dart`；专注 Goldens |
| 执行/行为协议、判例、分析 | 执行阶段、规则与证据索引、真实协议统计；高级功能切换时同步页签数量 | `protocols_page.dart`；`game_ui_test.dart`；协议交互及布局矩阵 |
| 自律 | 时段、规则、应用/网站分组与运行状态；Android 可查看/编辑规则，隐藏 Windows 原生保护动作 | `restriction_page.dart`；`android_platform_ui_regression_test.dart`；双端编辑器截图 |
| 笔记、阅读、附件 | 文档索引、长文阅读列、关系与版本；附件加载/容量/解析/导入/删除失败可重试，永久删除需确认 | `notes_page.dart`；`attachment_panel_error_test.dart`；笔记桌面及双主题手机截图 |
| 日/周/月回顾、历史库 | 日期事实、七日条/月历、心情、正文、关系与版本；换期间/类型/历史记录前处理未保存内容 | `review_page.dart`；`optimization_regression_test.dart`；回顾截图 |
| 目标、习惯、行为中心 | 目标路径、下一里程碑；今日打卡与可滚动月矩阵，完成/失败/未记录形状和语义区分 | `goals_page.dart`；`habits_page.dart`；`habit_month_strip_test.dart` |
| 国策树/库/历史/分析 | 八类节点与真实关系、文库搜索/筛选、可展开审计时间轴、14 日数据趋势与无样本说明 | `policies_page.dart`；`policies_page_test.dart`；国策指南截图 |
| 成长账本 | 签到、日期证据矩阵、最近证据及下一行动；关闭本地激励后隐藏 XP/奖励视图 | `growth_page.dart`；`game_ui_test.dart`；成长 Golden |
| 设置 | 原生主题预览卡、分组设置、同步及危险操作反馈；换主题保留输入与滚动位置 | `settings_page.dart`；`ui_coverage_regression_test.dart`；Android 主题切换实测 |
| 共享编辑面与导航 | 记录/笔记/任务群/快速收集关闭时可继续编辑或明确放弃；保存中阻止误关闭；320dp 和 200% 字体下表单改为纵向 | `UnsavedChangesGuard`；`unsaved_editor_test.dart`；共享弹窗、菜单及键盘矩阵 |

## 3. 自动验收

`test/ui_audit_screenshot_test.dart` 映射 35 个页面/子页视图：

- 内容场景：两主题分别覆盖 320×700、375×812、390×844、412×915、768×864、1024×864、1200×864、1440×900、1536×864。
- 减少动态效果：两主题分别在 390×844、1200×864 检查。
- 200% 字体：两主题分别在 320×700 检查；另有表单、国策库、记录页面专项。
- 空场景：两主题分别覆盖 320×700、390×844、1200×864。
- 检查布局异常、卸载异常及语义结构；另测悬停、按压、键盘焦点、菜单、下拉与共享弹窗的打开/关闭。此矩阵共进行 1,050 次页面布局检查，不等同于每个画面的人工像素验收。
- Golden 基准及文档截图已经实际渲染并检查。快速收集截图明确等待背景插画解码，避免孤立运行与全套运行的图片加载差异。

### 最终命令与结果

| 检查 | 结果 |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test` | 113 个文件，0 个格式变化 |
| `flutter analyze --no-pub` | No issues found |
| `flutter test --concurrency=1 --reporter expanded --no-pub` | **313/313 通过**，耗时约 4 分 15 秒；[完整日志](qa/dual-theme-2026-10-08/flutter-test.log) |
| `python tool/verify_colors.py` | 0 个失败配对，包含辅助小字与操作色在分组/选中底面上的 4.5:1 检查 |
| `python tool/verify_token_parity.py` | Flutter/CSS 令牌 70 对一致 |
| `git diff --check` | 通过 |
| `flutter run -d windows --debug --no-pub` | 最新 debug 原生构建成功并实际启动 |
| `flutter build apk --debug --no-pub` | 成功；最新 APK 已重新安装并实际运行 |

一次与原生构建并行的回归中，千条任务的 5 秒性能门槛因资源争用超时。未放宽门槛；停止构建后以低并发完整复跑，上述 313 项全部通过。

## 平台运行复核

- Windows 最新原生构建正常启动，Inspector 获取的真实渲染画面为 1264×681；已检查今日空态、导航、插画、时间尺与按钮。
- Android 最新 APK 已安装到 `sdk_gphone64_x86_64` 模拟器，实际截图为 1080×2400。已复核白天/夜间切换、重启后的主题保持、今日空态、快速收集与系统键盘、关闭确认、“继续编辑”保留输入、明确放弃后返回今日。测试草稿没有写入数据库。
- 键盘弹出后，“收下”固定在键盘上方，其他表单内容可独立滚动；系统状态栏与底部栏跟随主题。

## 4. 验证边界

- Android 使用本机模拟器；本轮没有可连接的 Android 物理设备，不能据此宣称完成真机性能、厂商休眠或系统分享兼容性验收。
- Windows 原生应用可构建、启动；通过 Flutter Inspector 获取渲染画面，通过调试接口触发并恢复 10 个实际滚动位置。当前环境的系统窗口截图存在旧画面缓存，原生鼠标输入自动化没有取得可靠证据；键盘、拖拽、菜单和表单交互以 Flutter 回归测试为证。
- 本轮没有使用真实账号做 Supabase 联网同步、修改系统 hosts、终止用户进程或验证 UAC 保护；相关业务逻辑保持原有实现，平台入口差异有回归覆盖。
- Android 构建仍提示既有 Gradle/AGP/Kotlin 版本将来需要升级；当前 debug 构建成功。未制作签名发行包或进行商店发布。

## 5. 截图索引

- [桌面白天今日](../test/goldens/wide_shell_today_light.png)、[桌面夜间今日](../test/goldens/wide_shell_today_dark.png)。
- [桌面项目](images/guide_projects.png)、[专注](images/guide_focus.png)、[笔记](images/guide_notes.png)、[回顾](images/guide_review.png)。
- [手机白天项目](../test/goldens/ui_audit/projects_mobile_day.png)、[手机夜间项目](../test/goldens/ui_audit/projects_mobile_night.png)。
- 手机专注、笔记、回顾的双主题裁切证据见[资源清单](DUAL_THEME_ASSET_MANIFEST.md#手机裁切验收图)。
- 平台实际运行：[Windows 白天](images/dual-theme-runtime/windows-day.png)、[Android 白天](images/dual-theme-runtime/android-day.png)、[Android 夜间](images/dual-theme-runtime/android-night.png)、[Android 快速收集与键盘](images/dual-theme-runtime/android-capture-keyboard.png)。

以上 Golden/指南图与平台运行截图将明确分开标注，避免把测试渲染当作实际设备画面。
