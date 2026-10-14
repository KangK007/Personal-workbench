# 青玉柔光截图索引

截图分为 Flutter Widget 固定数据截图和 Windows Release 实际窗口截图。文件名中的 `day`/`light` 为浅色，`night`/`dark` 为深色；未标主题的现有 Widget 基线均为浅色。Widget 截图由测试夹具中的代表数据生成；Windows 截图使用隔离的空数据库与系统当日日期。两类证据不可互代。

## Windows 实际运行

| 文件 | 页面 / 状态 | 尺寸 / 环境 | 检查 |
|---|---|---|---|
| [`screenshots/windows_release_empty_today_light.png`](screenshots/windows_release_empty_today_light.png) | `today` / 未开始、无任务、无时间块 / 浅色 | 1272×712 px，Windows Release，96 DPI，2026-10-10；独立数据库 | 已目检：窗口控件、双栏与空态正常，无可见溢出 |
| [`screenshots/windows_release_125pct_tasks_groups.png`](screenshots/windows_release_125pct_tasks_groups.png) | `tasks_groups` / 空数据库 / 浅色 | 125% 系统缩放，`GetDpiForWindow=120`，2026-10-14；独立数据库 | 已目检可见区域：标题、导航和空态未重叠 |
| [`screenshots/windows_release_150pct_today_short.png`](screenshots/windows_release_150pct_today_short.png) | `today` / 短窗空数据库 / 浅色 | 150% 系统缩放，`GetDpiForWindow=144`，2026-10-14；独立数据库 | 已目检可见区域：摘要和主按钮可见，无横向溢出 |
| [`screenshots/windows_release_175pct_today_max.png`](screenshots/windows_release_175pct_today_max.png) | `today` / 最大化空数据库 / 浅色 | 175% 系统缩放，`GetDpiForWindow=168`，2026-10-14；独立数据库 | 已目检可见区域：标题与摘要未重叠，后续内容需滚动 |

## Widget 审计基线

2026-10-13：今日桌面右栏改为独立日程滚动区、底部可见的专注入口，统计压缩为单行。`wide_shell_today_<light|dark>.png` 与 35 项双主题尺寸矩阵已按新布局刷新；今日矩阵夹具现传入与实际导航壳相同的专注导航回调，`today_mobile.png` 亦同步更新。目检浅/深色完整导航壳、浅/深色 1200×900 今日页及 390×568、320×568/200% 文字的今日原图：首屏未见重叠和横向溢出；极窄大字窗口的任务列表需继续向下滚动。

同日追加短横向窗口修正：`matrix_today_<light|dark>_800x450_text200.png` 与对应浅/深色总览已刷新。逐张目检两张今日原图，主按钮完整显示、日期仍在页头；桌面有页头时才省略场景卡中的重复日期，其他尺寸保持原排版。

同日复查 320×568、200% 文字总览后更新 `matrix_review_diary_<light|dark>_320x568_text200.png` 与对应总览。逐张目检两张日回顾原图：日期环移至说明上方，说明改为整行排版，不再逐字挤在窄列。

2026-10-14 逐页查看 35 个审计目标在浅/深色的 320×568/200% 文字、800×450/200% 文字和 1200×900 首屏原图对照；月回顾的双位日期间距过近，因此刷新 `matrix_review_monthly_<light|dark>_320x568_text200.png` 及全尺寸矩阵。两张极窄原图已重新目检，日期单元格内保留间距且整月网格未横向溢出。该对照不覆盖滚动到首屏以下的区域。

同档今日概览卡另刷新 `matrix_today_<light|dark>_320x568_text200.png` 与总览，逐张目检浅/深色原图：标题完整、两项统计按词分行，进度环与统计并排且“开始专注”仍完整位于首屏。

专注会话按 PDF 第 6、28 页调整后重新生成双主题尺寸矩阵、独立桌面图及十张总览；另新增 `focus_completion_<light|dark>_<320x568_text200|1200x900>.png` 四张完成状态图。已目检浅色 1200×900 会话、深色 320×568/200% 会话、浅色 320×568/200% 与深色 1200×900 完成状态原图：任务胶囊、低对比叶影和返回动作均清晰，短窗完成按钮完整可见。完成状态图是 Widget 组件截图；真实保存后的转场由交互测试验证。

2026-10-12：协议入口更新后重新生成 35 项双主题断点矩阵及 `protocol_groups_execution_<light|dark>_<390x844|1200x900>.png`、`protocol_groups_behavior_<light|dark>_<390x844|1200x900>.png`，另更新 `test/goldens/wide_protocols_light.png` 与深色窄窗 `protocols_rule_editor_dark_390x844.png`。已目检浅色 390×844 和深色 1200×900 的执行链及行为协议四张原图，以及后两张基线：协议册页、阶段文字和动作保持可见；窄窗逐行换行、宽窗三段展开。随后共享插画改为纸页叶片矢量，35 项双主题断点矩阵与六张总览拼图再次重建；已目检成长、笔记和日回顾的双主题 390×568 原图、收件箱桌面、深色宽窗笔记阅读及深色 800×450 总览。

2026-10-13：专注中心夹具加入 45 分钟倒计时与不限时正计时预设，重新生成 `focus_hub_desktop.png`、`focus_mobile_day.png`、`focus_mobile_night.png`、35 项双主题七档矩阵及六张总览。已目检浅色桌面双列、浅/深色手机单列、浅色 390×568 和深色 800×450：承诺卡、真实统计、预设标题与操作可见；短窗通过页面滚动到达下方卡片。
同日更新 `docs/images/guide_focus.png`：单张预设卡在宽屏扩展至 600dp 并与“专注预设”标题一起居中，目检不存在原先靠左半列导致的右侧大片空白。
自律规则概览改用实际内容宽度分列后，再次刷新 35 项双主题矩阵、独立自律页、规则编辑器背景、六张总览及 `docs/images/guide_focus_restriction.png`。已目检 1200×900 浅色五列、800×450 深色三列与居中末行、390×568 浅色两列：文字、时段条和主要操作均未受挤压。
专注承诺卡接入统一叶环计时矢量、七日统计单位调整为 13dp 后，专注相关独立图、矩阵、到时确认双主题图、`docs/images/guide_focus.png` 及六张总览再次刷新。浅色桌面、深色手机和文档原图已目检：小图标清晰，统计数值和单位没有互相遮挡。
日、周、月回顾另补真实完成记录的双主题 390×844 与 1200×900 截图共 12 张，验证事实环、七日柱、月历强度和有记录的清单布局。已目检浅色手机日回顾、深色手机周/月回顾及浅色桌面周回顾原图；其余截图由自动比对和构建异常检查覆盖。
目标页阅读区宽度调整后，35 项双主题七档矩阵、`goals_desktop.png` 与六张总览拼图已刷新；已目检浅色 1200×900 和深色 800×450 原图，目标路径与目标树共用对齐边界，短宽窗口充分使用可用宽度。
成长页整月日期格改为按实际内容宽度伸展后，35 项双主题七档矩阵、`growth_desktop.png` 与六张总览拼图已刷新；已目检浅色 1200×900、深色 800×450 和 1440×900 原图，月账本网格横向利用可用空间，格子与日期一一对齐。
国策分析 14 日图按内容宽度分配日列后，再次刷新 35 项双主题七档矩阵和六张总览拼图；已目检独立国策浅色 1200×900、行为中心深色 390×844 原图。`docs/images/guide_policies_analytics.png` 也通过截图更新命令复核，保持无结算数据的空态。
另外补齐 320×568、200% 文字的 35 项双主题矩阵与两张总览。原图复核发现周视图五个日期格的双字星期过于拥挤，现按内容宽度改为单字显示，屏幕阅读器仍读完整星期；浅色周视图原图与两主题总览已复核。极窄窗的项目标题和详情需通过页面滚动阅读，不将截断的首屏视作完整内容验收。
再补 800×450、200% 文字的双主题矩阵与两张总览。今日页原图暴露 24 个小时数字挤成一行，时间标尺现根据小时格宽度和字号显示间隔标签，仍保留全部 24 个刻度与语义。更新后已检查浅色短窗今日页和浅色宽窗今日页原图；两主题短横向总览已逐组查看。

以下路径均相对于仓库根目录。`test/goldens/ui_audit/` 中的文件由 `test/ui_audit_screenshot_test.dart` 生成，并已在本轮更新。

### 35 项双主题断点矩阵

`test/goldens/ui_audit/matrix_<目标 ID>_<light|dark>_<宽>x<高>.png` 覆盖 `REQUIREMENT_MATRIX.md` 前 35 项，每项目标有浅色和深色两张，视口分别为 390×568、390×844、767×900、768×900、800×450、1200×900、1440×900，共 490 张。另有 `matrix_<目标 ID>_<light|dark>_<320x568|800x450>_text200.png` 共 140 张，合计 630 张。生成测试明确断言目标数量为 35，并对每张截图检查 Flutter 构建异常。所有截图复用一组隔离代表数据，加入已结算的 RSIP 国策节点、带真实关联专注记录的 CTDP 任务、两条含生效/归档状态的结构化判例、含父子关系及已完成成员的任务群、已完成/待到达且关联任务的项目里程碑、一篇关联笔记和一篇关联周回顾，以及两种不同计时模式的专注预设，使这些页面不再只是空态。兼容目标和习惯截图现在实际显示同源目标与习惯内容；窄习惯页默认展示最近 14 天，整月展开另有截图。RSIP 事件时间在夹具中固定，避免同毫秒创建导致最近记录顺序飘移。紧凑宽度的截图按实际页面嵌入方式隐藏页内标题；完整导航壳截图见下节。

此前夹具的 390×568 与 800×450 全部 35 个浅色页面拼图，以及多个断点的代表画面已目检；抽查发现并修复了单根国策节点被压到首屏底部、行为摘要卡在宽窗口收缩居中、项目详情在 390×568 且 200% 文字下底部溢出 0.4px 的问题。加入任务群、里程碑和关联周回顾后重新生成了全部矩阵截图，已抽查任务群在浅色宽窗、浅色窄窗、深色短窗的折叠态，以及浅色窄窗和深色宽窗的展开态；项目笔记与回顾另抽查浅色窄窗、浅色宽窗及深色窄窗。其余新基线由自动化检查构建异常，尚未逐张人工视觉验收。截图生成通过不等于每项目标六维规范均已完成。

国策库按 260dp 最小卡宽改为三/二/一列后，重新生成 35 项双主题断点矩阵；已目检 `policies_library` 的浅色 1440×900、深色 767×900 与浅色 390×568。三列首版截图暴露长说明末行被裁切，改为自然高度卡片行后重新生成并复核。

窄窗国策页四标签改为完整显示，操作收纳到菜单；已目检 `matrix_behavior_policies_analytics_light_390x568.png` 和 `matrix_behavior_policies_library_dark_390x844.png`。专注会话短窗把操作保留在首屏；已目检 `matrix_focus_session_light_390x568.png` 和 `matrix_focus_session_dark_800x450.png`。这两项调整后的 35 页双主题矩阵已重新生成并通过截图比对。

成长页在低于 768dp 的内容区默认折叠整月账本，首屏保留指标与最近证据，展开后提示可左右滑动；已目检 `matrix_growth_light_390x568.png`、`matrix_growth_dark_390x844.png` 及 767/768dp 浅色断点画面。35 页双主题矩阵和 Android 成长截图已重建。

收件箱置顶输入槽加入后重建 35 页双主题矩阵与 `inbox_desktop.png`；已目检浅色 390×568、深色 800×450、浅色 1440×900 和桌面独立页。手机保留输入框与待整理行，宽窗内容区按 920dp 上限居中，未见遮挡或横向溢出。

周视图日期联动修复后重新生成 35 页双主题矩阵及 `calendar_desktop.png`，并同步刷新浅色 390×568、800×450、1200×900 总览图。390×568 的周五标签与所选日期一致；1440×900 宽窗五日列和选中状态对应。

全局搜索最近查询状态新增 `test/goldens/ui_audit/global_search_recent_<light|dark>_<宽>x<高>.png` 六张：320×568（200% 文字）、390×844、1200×900；已目检浅色极窄窗与深色桌面窗口，历史标记、复用行和清除动作可见。

同一批 35 页截图另生成深色 390×568、800×450、1200×900 总览图：`screenshots/contact_sheet_dark_<宽>x<高>.png`。加上 320×568 和 800×450 的 200% 文字浅色与深色总览，目前共十张，由 `tool/build_audit_contact_sheets.py` 根据当前基线重建；项目图标、22dp 标题和概览摘要接入后已重新生成，并查看项目概览浅色 390×568、深色 1200×900 原图。总览用于比较组距、对齐、窄窗控制区和宽窗留白，缩图不能替代每张原图的逐像素验收。

| 页面 / 状态 | 文件名（前缀 `test/goldens/ui_audit/`） | 视口 / 主题 |
|---|---|---|
| 任务群展开态 / 父子任务、真实完成刻度 | `groups_expanded_<light\|dark>_<宽>x<高>.png` | 390×844、1200×900，双主题，共 4 张；已目检浅色窄窗与深色宽窗 |
| 计划/项目任务群深层钻取 / 当前根、路径和返回 | `groups_drill_<plan\|project>_<light\|dark>_<宽>x<高>.png` | 390×844、1200×900，双主题，共 8 张；已目检浅色计划窄窗、深色项目窄窗与深色项目宽窗 |
| 项目看板 / 单列状态切换及三列布局 | `projects_board_<compact\|wide>_<light\|dark>.png` | 390×844、1440×900，双主题，共 4 张；覆盖待办、进行中、已完成及长标题，已目检浅色窄窗和深色宽窗 |
| 项目任务群展开态 / 父子连接线与进度 | `projects_groups_expanded_<light\|dark>_<宽>x<高>.png` | 390×844、1200×900，双主题，共 4 张；已目检浅色窄窗与深色宽窗 |
| 项目任务群跨组移动 / 目标选择、高亮结果和撤销 | `project_group_move_<picker\|result>_<light\|dark>_<宽>x<高>.png` | 320×568（200% 文字）、1200×900，双主题，共 8 张；已目检浅色极窄选择/结果、深色宽窗结果，极窄成员行与反馈条无重叠另有断言 |
| 项目里程碑 / 日期轨道、完成与待到达节点、关联任务 | `projects_milestones_<compact\|wide>_<light\|dark>.png` | 390×844、1200×900，双主题，共 4 张；已目检浅色窄窗与深色宽窗 |
| 项目笔记与回顾 / 混合记录、日期分隔、类型筛选 | `projects_knowledge_<light\|dark>_<宽>x<高>.png` | 390×844、1200×900，双主题，共 4 张；已目检浅色窄窗、浅色宽窗与深色窄窗 |
| 笔记阅读 / 标题、引用、代码、四类关联名称与窄窗返回 | `notes_reader_<light\|dark>_<宽>x<高>.png` | 390×844、1200×900，双主题，共 4 张；四类关系夹具已更新，已目检浅色窄窗与深色宽窗 |
| 习惯整月展开 / 保留当日打卡和可滚动日期 | `habits_month_expanded_<light\|dark>_390x844.png` | 390×844，双主题，共 2 张；已目检浅色与深色窄窗 |
| 兼容协议目标与习惯 / 正式页面同源内容 | `matrix_legacy_protocols_<goals\|habits>_<light\|dark>_<宽>x<高>.png` | 上述 7 种视口、双主题，共 28 张；已目检浅色 1200×900 目标与习惯 |
| 兼容执行协议 / CTDP 任务与关联专注时间线 | `protocols_linked_<light\|dark>_<宽>x<高>.png` | 390×844、1200×900，双主题，共 4 张；已目检浅色窄窗与深色宽窗 |
| 执行协议入口 / 960dp 宽窗边界和窄窗单列 | `matrix_legacy_protocols_execution_<light\|dark>_<宽>x<高>.png` | 上述 7 种视口、双主题，共 14 张；已目检浅色 1440×900 和深色 390×844 |
| 分组协议入口 / CTDP 任务组与执行链、RSIP 国策组 | `protocol_groups_<execution\|behavior>_<light\|dark>_<宽>x<高>.png` | 390×844、1200×900，双主题，共 8 张；已目检浅色窄窗和深色宽窗 |
| 关系选择浮层 / 四类关系、已选胶囊、任务与笔记类型 | `relation_picker_<light\|dark>_<宽>x<高>.png`, `relation_picker_notes_<light\|dark>_<宽>x<高>.png` | 320×568（200% 文字）、390×844、1200×900，双主题，共 12 张；已目检浅色 320 与深色 1200 |
| Markdown 编辑弹窗 / 标题校验、窄窗编辑与预览、宽窗双栏 | `markdown_editor_<validation\|edit\|preview\|split>_<light\|dark>_<宽>x<高>.png` | 前三态 390×844、双栏 1200×900，双主题，共 8 张；已目检浅色三态与深色预览，另有完整截图比对 |
| 全局搜索浮层 / 分类、匹配强调、分组结果 | `global_search_results_<light\|dark>_<宽>x<高>.png` | 320×568（200% 文字）、390×844、1200×900，双主题，共 6 张；已目检浅色 320/1200 与深色 390，另有完整截图比对 |
| 快速新增与项目选择 / 固定提交区、搜索与懒加载项目 | `quick_capture_<light\|dark>_<宽>x<高>.png`, `quick_project_picker_<light\|dark>_<宽>x<高>.png`, `quick_capture_validation_light_320x568.png` | 320×568（200% 文字）、390×844、1200×900，双主题初始/选择器共 12 张及浅色校验 1 张；已目检浅色 320/1200 与深色 390，另有完整截图比对 |
| 自律规则编辑器 / 影响摘要、逐日预览、时段子弹窗 | `restriction_editor_<top\|schedule>_<light\|dark>_<宽>x<高>.png`, `restriction_schedule_dialog_<light\|dark>_<宽>x<高>.png` | 320×568（200% 文字）、390×844、1200×900，双主题共 18 张；已目检浅色 320/390 与深色 1200，另有完整截图比对 |
| 账号配置与登录 / 表单顶部、动作、空值校验 | `settings_auth_<top\|action>_<light\|dark>_<宽>x<高>.png`, `settings_auth_validation_light_320x568.png` | 320×568（200% 文字）、390×844、1200×900，双主题共 12 张及浅色校验 1 张；已目检浅色 320/390 与深色 1200，发现并修复逻辑日设置窄窗逐字折行 |
| 同步冲突 / 字段差异、版本选择与固定确认区 | `sync_conflict_<diff\|choice>_<light\|dark>_<宽>x<高>.png` | 320×568（200% 文字）、1200×900，双主题共 8 张；已目检浅色窄窗与深色宽窗，状态由隔离数据生成 |
| 兼容判例 / 类型分类、具体范围、生效及归档状态 | `matrix_legacy_protocols_rules_<light\|dark>_<宽>x<高>.png` | 上述 7 种视口、双主题，共 14 张；已目检浅色 1200×900 与深色 390×844 |
| 兼容协议分析 / 真实结算、过程事件和 7 日图 | `matrix_legacy_protocols_analytics_<light\|dark>_<宽>x<高>.png` | 上述 7 种视口、双主题，共 14 张；已目检浅色 390×568 与 1200×900 |
| 全部任务 / 短横向窗口的折叠筛选 | `matrix_tasks_all_<light\|dark>_800x450.png` | 800×450，双主题；已目检浅色，200% 文字另由交互测试验证 |
| 专注计划到时待确认 / 长预设名、跳过与确认操作 | `focus_pending_<light\|dark>_320x568.png` | 320×568、200% 文字，双主题，共 2 张；已目检完整标题、说明与两项操作均在卡内 |
| 专注完成 / 轻量圆环、记录事实、返回动作 | `focus_completion_<light\|dark>_<320x568_text200\|1200x900>.png` | 320×568、200% 文字与 1200×900，双主题，共 4 张；已目检浅色极窄大字和深色桌面原图，按钮完整可见 |
| 日/周/月回顾真实完成记录 / 事实环、七日柱和月历强度 | `review_completed_<diary\|weekly\|monthly>_<light\|dark>_<宽>x<高>.png` | 390×844、1200×900，双主题，共 12 张；已目检浅色手机日回顾、深色手机周/月回顾及浅色桌面周回顾 |
| 结构化判例编辑 / 任务范围、长条件与固定动作区 | `protocols_rule_editor_<light\|dark>_<宽>x<高>.png` | 390×844、1200×900，双主题，共 4 张；已目检浅色窄窗与深色宽窗 |
| 35 页浅色总览拼图 / 人工检查阅读顺序、留白与缩放 | `docs/jade-redesign/screenshots/contact_sheet_light_<宽>x<高>.png` | 390×568、1200×900，各一张；已整体目检，需以原图核查细节 |
| 35 页浅色短横向窗口拼图 / 筛选入口与首屏布局 | `docs/jade-redesign/screenshots/contact_sheet_light_800x450.png` | 800×450；已整体目检，详情以原图核查 |
| 初始化失败 / 隔离模拟错误，详情默认折叠 | `initialization_error_<light\|dark>_<宽>x<高>.png` | 390×568、1200×900，双主题，共 4 张；已目检浅色短窗与深色宽窗 |
| 初始化重试中 / 隔离模拟状态、减少动效 | `initialization_retrying_<light\|dark>_390x568.png` | 390×568，双主题，共 2 张；已目检深色短窗 |
| 日历、专注中心、专注会话 | `calendar_desktop.png`, `focus_hub_desktop.png`, `focus_session_desktop.png` | 1200×900，浅色 |
| 目标、成长、习惯 | `goals_desktop.png`, `growth_desktop.png`, `habits_desktop.png` | 1200×900，浅色 |
| 收件箱、笔记、计划 | `inbox_desktop.png`, `notes_desktop.png`, `plan_desktop.png` | 1200×900，浅色 |
| 国策、项目、协议 | `policies_desktop.png`, `projects_desktop.png`, `protocols_desktop.png` | 1200×900，浅色 |
| 自律规则、规则编辑器、回顾、设置 | `restriction_desktop.png`, `restriction_editor_desktop.png`, `review_desktop.png`, `settings_desktop.png` | 1200×900，浅色 |
| 专注、笔记、项目、回顾移动视图 | `focus_mobile_day.png`, `notes_mobile_day.png`, `projects_mobile_day.png`, `review_mobile_day.png` | 390×844，浅色 |
| 专注、笔记、项目、回顾移动视图 | `focus_mobile_night.png`, `notes_mobile_night.png`, `projects_mobile_night.png`, `review_mobile_night.png` | 390×844，深色 |
| 今日、自律规则、规则编辑器移动视图 | `today_mobile.png`, `restriction_mobile.png`, `restriction_editor_mobile.png` | 412×915，浅色 |

## Widget 场景与文档基线

2026-10-12：反馈组件改为按当前内容宽度和文字缩放实时重排；项目跨组移动的双主题 1200×900 结果基线已更新。已目检浅色 320×568（200% 文字）、浅色 1200×900 和深色 1200×900，移动任务保持在反馈上方，撤销可见。此次未更改其他页面的静态尺寸基线。

| 页面 / 状态 | 文件 | 视口 / 主题 |
|---|---|---|
| 今日实际导航壳 / 代表数据 | `test/goldens/shell_<light\|dark>_<宽>x<高>.png` | 320×568、390×568、767×900、768×900、800×450、1200×900、1440×900，双主题，共 14 张 |
| 今日页面、完整导航壳 / 代表数据 | `test/goldens/wide_today_light.png`, `test/goldens/wide_shell_today_light.png` | 1536×864，浅色 |
| 今日页面、完整导航壳 / 代表数据 | `test/goldens/wide_today_dark.png`, `test/goldens/wide_shell_today_dark.png` | 1536×864，深色 |
| 今日壳 / 未开始、空任务 | `test/goldens/wide_shell_unstarted_today_light.png`, `test/goldens/wide_shell_empty_today_light.png` | 1536×864，浅色 |
| 周视图 / 冲突；行为习惯；执行协议 | `test/goldens/wide_workweek_conflict.png`, `test/goldens/wide_behavior_habits.png`, `test/goldens/wide_protocols_light.png` | 1536×864，浅色 |
| 今日、快速收集、成长、行为国策移动视图 | `test/goldens/android_today.png`, `test/goldens/android_capture_sheet.png`, `test/goldens/android_growth.png`, `test/goldens/android_behavior_policies.png` | 412×915，浅色 |
| 项目、专注、自律、笔记、回顾、国策树、国策统计 | `docs/images/guide_projects.png`, `docs/images/guide_focus.png`, `docs/images/guide_focus_restriction.png`, `docs/images/guide_notes.png`, `docs/images/guide_review.png`, `docs/images/guide_policies_tree.png`, `docs/images/guide_policies_analytics.png` | 1440×900，浅色 |
| CTDP 任务编辑、RSIP 习惯编辑 | `docs/images/create_ctdp_task.png`, `docs/images/create_rsip_habit.png` | 900×1180，浅色 |

已抽查 14 张导航壳断点截图及 `wide_shell_today_light`、`ui_audit/focus_session_desktop`、`ui_audit/plan_desktop`、`ui_audit/restriction_desktop`、`ui_audit/restriction_mobile`、`ui_audit/calendar_desktop`、`ui_audit/goals_desktop`、`ui_audit/habits_desktop`、`guide_focus`、`guide_projects`、`guide_policies_tree`、`guide_policies_analytics` 及 Windows 实际空态。320×568 和 390×568 的截图帮助发现并修复浮动新增按钮遮挡列表入口、320 宽页头日期被动作挤掉的问题。35 项双主题断点截图已经生成，但逐张人工视觉验收与六维规范核对仍需继续。
