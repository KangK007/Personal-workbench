# 个人工作台最终质量审查报告

> 审查完成日期：2026-08-29（Asia/Shanghai）  
> 最终安装包刷新：2026-08-30（Asia/Shanghai）  
> Git 基线：`05f1827ae654637954395df8d453136837950606`  
> 测试基准：`docs/qa/PROJECT_MAP.md` 与 `docs/qa/TEST_MATRIX.md`

## 1. 结论

本轮发布级质量审查已经完成，完整功能清单和测试矩阵均已闭环。最终矩阵包含 208 个 Case：199 个 `PASS`、9 个 `BLOCKED`、0 个失败、0 个未闭环项。

整体发布判定：**NO-GO**。Windows Release 和 Android Debug 均能干净构建，核心本地工作流可用；但 Android Release 缺少签名凭据，真实 Supabase、Windows 系统级热键/托盘/开机启动/进程与 hosts 副作用、原生文件选择器修复后复验，以及 Android 休眠/重启定时通知仍受环境或安全条件阻塞。解除相应阻塞前，不应宣称完整平台发布验收通过。

## 2. 覆盖规模

| 指标 | 结果 |
| --- | ---: |
| 测试 Case | 208 |
| PASS / BLOCKED | 199 / 9 |
| Flutter 自动测试 | 229 / 229 通过 |
| Dart 测试文件 | 35 |
| 页面与子页表面 | 39 |
| 全页面布局场景 | 546 |
| Golden 基线 | 33 |
| 真实运行截图 | 15 |
| Word 用户手册 | 29 页 / 21 张界面截图，逐页检查 PASS |
| 已登记缺陷 | 13 |

546 个布局场景由 39 个表面分别覆盖 7 个浅色视口、2 个深色视口、2 个减少动效视口、1 个 200% 文字缩放视口和 2 个空数据视口。

## 3. 最终命令结果

| 检查 | 结果 |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test` | 96 个文件，0 个变更，PASS |
| `flutter analyze` | No issues found，PASS |
| `flutter test --reporter compact` | 229/229，PASS |
| Windows Debug 隔离数据库构建 | 37.9 s，PASS |
| Windows Release 干净构建 | PASS |
| Android Debug 干净构建 | PASS |
| Android Release | BLOCKED：缺少 `android/key.properties` 与私有 keystore |

## 4. 真实 Windows 验证

测试使用独立 SQLite 数据库，不读取或覆盖用户正式数据。本轮新增路径已由 Widget、Golden、控制器回归和一次 Windows Debug 隔离数据库启动覆盖；启动进程保持运行并创建 `PWB-QA-20260829\qa.sqlite`。

首次 Debug 启动约 950 ms，第二次约 922 ms。第一轮自动输入会话出现重复空 JSON 解析日志；第二个干净会话 stderr 为 0 字节，因此归类为自动化输入噪声而非稳定应用异常。

## 5. 真实 Android 验证

环境为 Android 15 / API 35 Pixel 6 模拟器，SDK 36、JDK 21。已完成：

- 冷启动：`Status: ok`，首次测量 2023 ms；修复后重装测量 2831 ms。
- 首屏像素与 UIAutomator 语义树。
- 快速新增 IME 显示、Back 先关闭 IME再关闭 Sheet。
- 创建任务并验证数据持久化。
- 通知权限拒绝与允许两条真实分支；允许后系统通知中心收到即时通知。
- `ACTION_SEND` 文本分享进入收件箱，正文完整。
- 系统 Back 返回 Launcher。
- 2400×1080 横屏和 800×1200 窗口尺寸变化。
- logcat 未发现应用 `FATAL EXCEPTION`、`E/flutter` 或未处理 Flutter 异常。

模拟器宿主发生 ADB 协议/图形后端离线，导致休眠或重启后的定时通知无法可靠完成，已标记 `BLOCKED`。

## 6. 产物

| 产物 | 大小 | SHA-256 |
| --- | ---: | --- |
| Windows Release 目录 | 20 文件，80,120,030 bytes | 目录不计算单一哈希 |
| `personal_workbench.exe` | 243,712 bytes | `237D329F5DD8829252FFF4C61C9BE6393684FF21275FCB1F20C35905E19DB561` |
| Windows 安装 ZIP | 44,963,971 bytes | `DEEA3E4A0BD586351A09542CAE485B2CF91B6827BF0CC6911FCB680BA7E903FC` |
| Android Debug APK | 192,805,677 bytes | `2DCD656C07D5D2F8F69A5B16F8D4795664FB553AA2DC71F687B63651EF9AB442` |
| Debug 分发 APK | 192,805,677 bytes | 与构建 APK 相同 |
| Android Profile APK | 121,121,250 bytes | `A13B34CB7FA7192B8ABEDFF3A0ED47A916D0F1ACCF7E9C913E41FAC8CD9BC237` |

桌面及两个开始菜单快捷方式均指向最终 Windows Release 可执行文件，目标存在。

## 7. 阻塞项

1. `ENV-003`：Stitch MCP 不可用，已用真实 GUI、Golden 和人工逐图替代。
2. `BLD-009`：缺少 Android Release 签名配置。
3. `GLB-002`：共享桌面有用户活动，未安全触发系统级 `Ctrl+Shift+Space`。
4. `RST-008`：无隔离 Windows VM，不执行真实进程终止与托盘受保护退出。
5. `RST-009`：无隔离 Windows VM，不修改用户 hosts/UAC 状态。
6. `ATT-004`：焦点修复自动回归通过，但修复后原生选择器真实复验被前台用户活动阻塞。
7. `SET-006`：缺少隔离 Supabase 端点、密钥和测试账号。
8. `PLT-001`：真实托盘、开机启动和 Windows 通知需要隔离用户会话。
9. `PLT-003`：Android 定时通知在休眠/重启后的送达受模拟器宿主不稳定阻塞。

## 8. 风险

- `flutter_markdown 0.7.7+1` 已停用，迁移需单独做 Markdown 兼容与视觉回归。
- Android 构建存在第三方 Manifest、Java 8 目标和 Gradle 9 兼容性警告。
- Android Debug APK 包含多 ABI 与调试符号，体积不能代表最终 Release 体积。
- 当前无远端云测试和真实设备后台策略数据，不应推断长期通知准时性。
