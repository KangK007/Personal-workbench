# 双主题插画资源清单

生产文件位于 `assets/illustrations/day/` 与 `assets/illustrations/night/`，均为透明背景、无文字的 WebP。UI 中的标题、数字、状态、按钮和图表由 Flutter 原生控件绘制。生产资源总计 **1,868,718 字节（约 1.87 MB）**。`WorkbenchIllustration` 根据实际亮度选择版本、指定稳定宽高和解码宽度，并从无障碍树中排除装饰图像。

| 主题组 | 白天 / 夜间体积 | 导出尺寸 | 使用位置 |
| --- | ---: | --- | --- |
| `today` | 166 / 112 KB | 1100×801 / 1100×733 | 今日节奏引导面 |
| `project` | 152 / 123 KB | 1100×801 / 1100×733 | 项目概览、项目空态 |
| `capture` | 98 / 60 KB | 1100×761 | 收集箱与快速收集 |
| `focus` | 134 / 93 KB | 1100×761 | 专注准备与计时入口 |
| `notes` | 154 / 130 KB | 1100×761 | 知识索引与笔记空态 |
| `review` | 210 / 147 KB | 1100×762 / 1100×761 | 日周月回顾事实卡 |
| `growth` | 127 / 162 KB | 1100×761 | 成长证据引导面 |

`today` 与 `project` 使用本项目此前已选定的双主题原画；原始 PNG 位于 `design_preview/theme_concepts/assets/green/` 和 `night/`。其余五组由图像生成能力为本项目生成，原始 PNG 位于 `design_preview/theme_concepts/assets/generated/day/` 和 `night/`。所有生产 WebP 都由 `python tool/optimize_illustrations.py` 从原画导出，长边限制为 1100 像素；`test/illustration_asset_test.dart` 验证全部 14 张均可解码。原画保留在设计预览目录用于将来调整，应用包只包含压缩后的 WebP。

插画用于帮助识别业务领域，不承担唯一信息；时间线、进度、关系、统计和国策节点颜色仍直接根据控制器数据渲染。

## 手机裁切验收图

以下截图由 Flutter 页面 Golden 测试以 390×844 渲染并逐张检查；插画主体均在安全范围内，按钮和正文不与插画重叠。今日、快速收集和成长的移动视图也保存在现有 Android Goldens 中。

| 领域 | 柔壤图鉴 | 夜航工作室 |
| --- | --- | --- |
| 项目 | [手机项目](../test/goldens/ui_audit/projects_mobile_day.png) | [手机项目](../test/goldens/ui_audit/projects_mobile_night.png) |
| 专注 | [手机专注](../test/goldens/ui_audit/focus_mobile_day.png) | [手机专注](../test/goldens/ui_audit/focus_mobile_night.png) |
| 笔记 | [手机笔记](../test/goldens/ui_audit/notes_mobile_day.png) | [手机笔记](../test/goldens/ui_audit/notes_mobile_night.png) |
| 回顾 | [手机回顾](../test/goldens/ui_audit/review_mobile_day.png) | [手机回顾](../test/goldens/ui_audit/review_mobile_night.png) |

其他移动基准：[今日](../test/goldens/android_today.png)、[快速收集](../test/goldens/android_capture_sheet.png)、[成长](../test/goldens/android_growth.png)。
