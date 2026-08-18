# Momentum CTDP / RSIP 功能复刻验收矩阵

本文档用于逐项核对“个人工作台”与以下参考材料中可观察核心功能的对应关系：

- [Momentum CTDP 参考网页](https://momentumctdp.netlify.app/)
- [Momentum 公开源码](https://github.com/KenXiao1/momentum)，核对版本：`93667599e670b5c18f8349698df14f0be88fd6ff`
- [CTDP / RSIP 方法文章](https://www.zhihu.com/question/19888447/answer/1930799480401293785)

这里的“完整复刻”指核心规则和用户工作流的功能等效实现，并适配本项目已有的 Flutter、本地 SQLite、成长账本、加密备份和 Supabase 同步架构。它不表示复制参考站点的品牌、宣传页面、原文表述或像素级视觉样式。

## 1. CTDP 验收矩阵

| 参考功能 | 本项目入口 | 状态与结果 | 自动化证据 |
| --- | --- | --- | --- |
| 创建链条，定义名称、触发、时长 | 新建任务 → CTDP 字段 | 已实现；支持 1–720 分钟 | `protocol_ui_flow_test.dart` |
| 辅助信号、缓冲时间、辅助完成条件 | 新建任务 → 辅助信号 / 辅助链完成条件 / 预约缓冲 | 已实现 | `protocol_ui_flow_test.dart` |
| 直接开始 | 协议 → CTDP 链 → 直接开始本轮 | 已实现；进入全屏专注 | `protocol_ui_flow_test.dart` |
| 预约后开始 | 协议或任务菜单 → 预约 | 已实现；保存预约、截止时间和审计事件 | `protocol_test.dart` |
| 到期提醒 | Android 系统通知；所有平台显示应用内倒计时 | 已实现；通知失败不阻塞协议落盘 | 控制器测试 + 组件测试 |
| 预约到期自动失败 | 控制器启动时及运行中每 30 秒结算 | 已实现；主链、辅助链归零并记失败事件 | `automatic settlement resets expired CTDP reservations` |
| 截止前确认触发 | 预约卡 → 确认触发并开始 | 已实现；辅助链 `+1` 后自动进入专注 | `protocol_ui_flow_test.dart` |
| 主链与辅助链独立失败 | CTDP 菜单 | 已实现；主动主链失败保留辅助链，辅助失败只重置辅助链 | `protocol_test.dart` |
| 固定时长任务 | 协议时长专注模式 | 已实现 | `focus_service_test.dart`、组件流程 |
| 无固定时长 / 正计时 | 创建任务 → 使用正计时 | 已实现；可定义最低有效时长 | `protocol_test.dart` |
| 暂停必须引用判例 | 专注 → 暂停 | 已实现；无可用判例时恢复计时 | 组件流程 + 判例单元测试 |
| 提前完成必须引用判例 | 未达到协议时长时结算 | 已实现；记录剩余时间和判例 | 判例单元测试 |
| 中断判定 | 关闭专注页 | 已实现；继续、引用判例退出、判定失败三选一 | 组件流程 |
| 完成内容与备注 | 专注 → 结算本轮 | 已实现；CTDP 完成内容必填 | 组件流程 |
| “下必为例” | 任务菜单或协议 → 判例 | 已实现为结构化规则，不只保存自由文本 | `structured precedents...` |
| 判例类型 | 协议 → 判例 | 已实现暂停、提前完成、允许中断 | `protocol_test.dart` |
| 任务级 / 全局判例 | 新建判例 → 作用范围 | 已实现；专注时只显示适用规则 | `structured precedents...` |
| 判例搜索、归档、恢复 | 协议 → 判例 | 已实现 | `protocol_ui_flow_test.dart` |
| 判例使用统计 | 协议 → 判例 / 分析 | 已实现次数、最后使用时间和事件明细 | `protocol_test.dart` |
| 主链累计、完成和失败统计 | 协议 → CTDP 链 / 分析 | 已实现 | `protocol_test.dart` |
| 单元类型 | 创建任务 → CTDP 类型 | 已实现普通、突击、侦察、指挥、特勤、工程、保障 | 表单组件测试 |
| 嵌套任务组 | CTDP 类型选择“任务组”，子任务选择所属组 | 已实现树形显示与循环检查 | `CTDP group completes...` |
| 任务组时限 | 任务组 → 启动任务组时限 | 已实现；到期自动重置组链 | `protocol_test.dart` |
| 任务组完成判定 | 时限内完成全部直接子单元 | 已实现；自动结算组链 | `CTDP group completes...` |
| 复制、移动、编辑、回收 | CTDP 卡片菜单 | 已实现；移动通过编辑所属任务组完成 | 组件流程 + 既有回收站测试 |
| 循环链继承 | 任务循环设置 | 已实现；下一次记录继承链状态 | `recurring CTDP tasks...` |

## 2. RSIP 验收矩阵

| 参考功能 | 本项目入口 | 状态与结果 | 自动化证据 |
| --- | --- | --- | --- |
| 创建节点与父子树 | 国策 → 国策树 → 添加国策 | 已实现；支持根、父节点、移动预览和循环防护 | `policies_page_test.dart`、`workbench_controller_test.dart` |
| 八类节点 | 节点表单 → 节点类型 | 已实现国策、习惯、奖励、惩罚、仪式、目标、触发器、提醒 | `policies_page_test.dart` |
| 精准规则、Emoji、计时和被动标记 | 节点表单 | 已实现；被动节点仍结算但不计主动维护成本 | `workbench_controller_test.dart` |
| 国策组与每轮容错 | 国策 → 新建国策组 | 已实现；容错按轮次持久化，显示剩余值 | `group tolerance...` |
| 拆分模式 | 国策 → 拆分目标 | 已实现目标说明、作息/运动/饮食模板、自定义子国策、逐项被动和批次来源 | `split...` |
| 严格/自由模式 | 国策树顶部开关 | 已实现；运行计时或待结算节点存在时阻止切换，并写轮次历史 | `strict mode switching` |
| 每日唯一结算 | 节点卡片 → 已执行/已违反/跳过 | 已实现；同一节点同一逻辑日重复点击幂等，更正保留原状态和原因 | `idempotent settlements...` |
| 执行和节点计时 | 节点菜单 → 开始计时 / 标记已执行 | 已实现 1–180 分钟；计时结束仍需明确结算 | `RSIP timer...` |
| 违反预览与强化层 | 节点菜单 → 标记已违反 | 已实现违反原因、强化扣减、子树、组容错和归档范围预览 | `reinforcement...` |
| 子树与整组崩塌 | 确认违反 | 已实现无强化时消耗组容错；耗尽归档整组及子树；无组归档自身子树 | `subtree/group collapse...` |
| 跳过今日 | 节点菜单 → 跳过今日 | 已实现打断连续天数但不触发崩塌 | `RSIP skip...` |
| E0/E1/E2 阶段 | 节点卡片、国策库 | 已实现新建、连续 7 天、连续 21 天；旧百分比仅作历史 | `E2/reinforcement...` |
| 国策库和恢复 | 国策库 → 恢复 | 已实现累计执行、阶段、最高强化、最近活动、使用次数；可恢复为根或有效父节点 | `library restore...` |
| 轮次历史 | 轮次历史 | 已实现开始、结束、持续天数、峰值节点、崩塌原因和节点列表 | `new run...` |
| 高级分析 | 高级分析 | 已实现时间窗口、输入指标和规则依据，并标注规则启发式 | `rsipInsights` controller test |
| 任务 → RSIP 自动联动 | 节点菜单 → 任务联动 | 已实现任务完成/中断/群周期完成触发自动执行或违反，同一日去重 | `task auto link` |
| RSIP → 任务确认联动 | 节点菜单 → 任务联动 | 已实现执行后弹出确认，可开始或安排任务/任务群 | `reverse task confirmation` |
| Android/旧 RSIP 兼容 | 旧习惯页和迁移流程 | 已实现旧字段归一化为节点，保留原 ID、内化值和协议事件 | `legacy Android normalization` |

## 3. 平台与数据能力

| 能力 | Windows | Android | 验收说明 |
| --- | --- | --- | --- |
| 协议工作台 | 支持 | 支持 | 响应式四标签页 |
| 应用内秒级倒计时 | 支持 | 支持 | 页面每秒刷新，控制器每 30 秒自动结算 |
| 系统通知 | 支持 Windows Toast、托盘和任务栏闪烁 | 支持 Android 通知 | Windows 关闭到托盘后继续；真正退出不承诺后台提醒 |
| 本地离线 | 支持 | 支持 | 所有协议记录写入 SQLite |
| JSON 导出 / 加密备份 | 支持 | 支持 | 新增判例和协议事件由通用记录层自动包含 |
| Supabase 同步 | 可选 | 可选 | 新记录类型沿用同一同步表，不需要迁移 |
| 回收站 | 支持 | 支持 | CTDP 任务及判例使用现有软删除机制 |

## 4. 自动化验收命令

```powershell
flutter analyze
flutter test test\protocol_test.dart test\protocol_ui_flow_test.dart
flutter test test\visual_golden_test.dart
powershell -ExecutionPolicy Bypass -File .\tool\build_windows.ps1
powershell -ExecutionPolicy Bypass -File .\tool\build_android.ps1 -Configuration release
```

测试覆盖的是确定性状态机和主要界面流程。Android 通知权限弹窗、通知渠道和即时通知已在连接的 PJA110 真机上验收；厂商后台策略下的长期准时性、系统文件选择器、真实 Supabase 账号和不同设备字体缩放仍属于按目标环境进行的真机集成验收，不应由单元测试结果替代。

## 5. 明确边界

- 不复制参考网页的账号、品牌、宣传内容和视觉皮肤；本项目保留自己的本地优先工作台信息架构。
- 参考源码中仅以 TODO、模拟数据或调试入口存在的内容，不作为“已完成能力”照搬。
- 内化进度、连续次数和协议成功率是本应用的行为记录指标，不是医学、心理或科研质量结论。
- 任务中的科研参数仍需用户按真实实验条件填写；协议系统不会猜测波长、单位、采样或仪器条件。
