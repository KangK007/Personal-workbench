# 个人工作台 · 三套主题界面例图

这组预览使用同一份知识工作示例数据，方便直接比较视觉风格。每套包含桌面今日页、桌面项目与任务页、手机今日页。独立 PNG 位于 `renders/`，三套并排图为 [`renders/comparison.png`](renders/comparison.png)。

| 主题 | 视觉语言 | 字体与素材 |
| --- | --- | --- |
| 柔壤图鉴 | 新芽绿、陶土色、浅纸感和植物生长线索 | IBM Plex Sans SC 正文、霞鹜文楷标题；透明植物与笔记插画 |
| 夜航工作室 | 深靛蓝、冷青、琥珀光点和时间轨道 | IBM Plex Sans SC 标题与正文；夜间工作台插画 |
| 日光编辑室 | 奶油白、深蓝、珊瑚橘和杂志式留白 | 霞鹜文楷标题、IBM Plex Sans SC 正文；文具拼贴插画 |

## 示例内容

- 今日任务：整理访谈要点（已完成）、完成方案初稿（进行中）、阅读行业报告（待开始）。
- 项目：产品体验优化，6 项任务中已完成 2 项；下一里程碑为“方案评审”，并关联 2 篇笔记。
- 今日和项目视图使用一致的任务名称与完成日期。

## 预览和导出

在仓库根目录运行 `python -m http.server 8765`，打开：

- `http://127.0.0.1:8765/design_preview/theme_concepts/?theme=green&screen=today`
- `http://127.0.0.1:8765/design_preview/theme_concepts/?theme=night&screen=projects`
- `http://127.0.0.1:8765/design_preview/theme_concepts/?theme=sun&screen=mobile`
- `http://127.0.0.1:8765/design_preview/theme_concepts/comparison.html`

`theme` 可选 `green`、`night`、`sun`；`screen` 可选 `today`、`projects`、`mobile`。今日页在窄于 651px 时自动显示手机布局，项目页在平板和手机上改为可滚动布局。预览包含速记表单、任务勾选、页面内搜索、专注计时和键盘焦点反馈。预览交互仅用于验证设计，不连接 Flutter 的业务数据。

透明插画位于 `assets/{green,night,sun}/`，由图像生成制作，无嵌入文字；全部界面文字、数字、图标和控件由 HTML、CSS、SVG 排版。浏览器字形子集可用 `python design_preview/theme_concepts/build_fonts.py` 重建，源字体和 OFL 许可位于仓库 `assets/fonts/`。`capture.js` 与 `verify_preview.js` 可通过 Playwright CLI 的 `run-code --filename` 重复导出与验证。
