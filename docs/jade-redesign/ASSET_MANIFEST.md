# 青玉柔光素材清单

设计资源采用优先级：统一矢量图标与功能图形使用 CustomPainter；装饰只放在文字以外的边缘。旧版 WebP 仍留在源码目录供历史对照，已从 `pubspec.yaml` 资源声明移除，当前界面不加载或打包这些位图。以下大小为磁盘文件实测，解码估算仅作旧素材参考。

| 资源 | 用途 / 变体 | 压缩体积 | 估算完整解码 | 状态 |
|---|---|---:|---:|---|
| `lib/ui/widgets/jade_icon.dart` | 统一导航标记、任务群分枝、协议册页/书签与专注叶环计时图标；浅/深色自动切换，20dp 以下单色 | 0 KiB 位图 | 0 MiB 位图 | 已接入桌面、移动导航、任务群、协议入口与专注承诺卡 |
| `lib/ui/pages/protocols_page.dart` | CTDP 与 RSIP 的代码绘制三段阶段带；按真实记录状态选中，宽窄窗自动重排 | 0 KiB 位图 | 0 MiB 位图 | 仅在协议记录入口构建，无新增位图 |
| `lib/ui/widgets/task_hierarchy_navigation.dart` | 计划/项目共用层级面包屑、上级菜单和返回按钮；采用既有矢量方向图标 | 0 KiB 位图 | 0 MiB 位图 | 深层钻取及窄窗路径已接入，无新增装饰资源 |
| `lib/ui/pages/projects_page.dart` | 跨组拖放目标描边、落点图标与拖动柄；沿用苔绿辅助色及原矢量图标 | 0 KiB 位图 | 0 MiB 位图 | 目标高亮、选择与撤销反馈已接入 |
| `lib/ui/widgets/jade_botanical_edge.dart` | 静态叶影；浅/深色及窄屏单叶变体 | 0 KiB 位图 | 0 MiB 位图 | 已接入今日、项目概览、专注承诺卡与宽窗会话边缘 |
| `lib/ui/widgets/jade_paper_leaf_art.dart` | 成长、笔记、回顾与收件箱的静态纸页叶片图；随页面色族和双主题绘制 | 0 KiB 位图 | 0 MiB 位图 | 已接入 `WorkbenchIllustration`，替代旧蓝色 WebP |
| `lib/ui/widgets/jade_empty_art.dart` | 空态小页框与叶芽线描；由页面图标标识任务、项目、笔记、搜索等语义 | 0 KiB 位图 | 0 MiB 位图 | 已接入公共 `EmptyState`，浅/深色自动切换 |
| `assets/illustrations/day/*.webp` | 旧版 7 张浅色插画，历史留存 | 单张 95.9–204.6 KiB | 单张约 3.19 MiB | 不打包、不在当前 UI 使用 |
| `assets/illustrations/night/*.webp` | 旧版 7 张深色插画，历史留存 | 单张 58.7–158.4 KiB | 单张约 3.19 MiB | 不打包、不在当前 UI 使用 |

## 预算与后续制作

- 当前页面的纸页、叶片和空态图形均由代码绘制，今日首屏装饰不加载位图；`test/illustration_vector_test.dart` 检查所有插画类别在双主题下均无 `Image` widget。Windows Release 的 `AssetManifest.bin` 不含 `assets/illustrations` 路径，`flutter_assets/assets/illustrations` 下文件数为 0；旧 WebP 单个最大约 204.6 KiB，现不纳入安装资源。
- 代码绘制资源无需 Flutter assets 声明；旧 WebP 保留在仓库，供历史对照。
- `empty-state-line-art` 已采用代码矢量实现并接入公共空态；各页功能图形的加载、错误与减少动效变体仍需逐项补齐。既有插画未自动视为新素材验收通过。
- 当前代码绘制插画不占用位图解码内存；整应用的其他图像、GPU 图层和首屏实际内存仍需 Profile 验证。
- 源码静态检索未发现 `BackdropFilter` 或 `ImageFilter.blur`，当前页面没有代码创建的背景模糊层；`blurRadius` 仅用于阴影。这不替代运行时 GPU 图层和帧耗测量。
