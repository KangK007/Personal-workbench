// 预建 Flutter 插件符号链接 —— 构建前补偿本机一个文件系统怪癖。
//
// ── 现象（2026-09-19 实测，Win11 25H2 / 26100）────────────────────────────
// 本机调用 CreateSymbolicLink 时，链接**已经被正确建好**，调用方却收到
// ERROR_FILE_NOT_FOUND(2)。已用三条独立路径验证同一行为：
//   · Dart  Link.createSync        → 抛 PathNotFoundException ... errno = 2
//   · PowerShell New-Item -ItemType SymbolicLink → 报「系统找不到指定的文件」
//   · 上述两种情况下，链接的 isLinkSync / existsSync / targetSync 全部正常
// 与沙箱无关（沙箱内外均复现），与目标、盘符、中文路径均无关。
//
// ── 后果 ──────────────────────────────────────────────────────────────
// flutter_tools 的 _createPlatformPluginSymlinks（flutter_plugins.dart:1139-1145）
// 直接把这个假错误当失败抛出，构建在 `flutter build windows` 早期中止：
//   PathNotFoundException: Cannot create link, path = '...\.plugin_symlinks\app_links'
//   (OS Error: 系统找不到指定的文件。, errno = 2)
//
// ── 对策 ──────────────────────────────────────────────────────────────
// 该函数的逻辑是「链接已存在就跳过」：
//     final Link link = symlinkDirectory.childLink(name);
//     if (link.existsSync()) { continue; }        // ← 借这一点
//     link.createSync(path);                      // ← 会踩到假错误
// 且 build_windows.dart:82 调用 createPluginSymlinks 时用的是默认 force = false，
// 不会先删掉 .plugin_symlinks。所以在 flutter build 之前先把链接备好，
// 构建就会走「已存在」分支，完全绕开这个假错误。
//
// 判据纪律：这里**不看有没有抛异常**，只按「最终状态」判定 ——
// 链接存在且可解析才算成功（与 tool/lib/Remove-Verified.ps1 同一条纪律）。
//
// ── 用法 ──────────────────────────────────────────────────────────────
//   dart prelink_plugin_symlinks.dart <flutter 项目根目录（即镜像目录）>
// 退出码：0 = 所有链接就绪；1 = 存在真正缺失/无效的链接（逐条打印）

import 'dart:convert';
import 'dart:io';

/// 与 flutter_tools 的 createPluginSymlinks 保持一致：只处理这两个平台。
const _platforms = ['windows', 'linux'];

int main(List<String> args) {
  var root = args.isNotEmpty ? args.first : Directory.current.path;
  root = root.replaceAll('/', Platform.pathSeparator);
  final sep = Platform.pathSeparator;

  final depFile = File('$root$sep.flutter-plugins-dependencies');
  if (!depFile.existsSync()) {
    stdout.writeln('[prelink] 未找到 ${depFile.path}，跳过预建。');
    return 0;
  }

  Object? decoded;
  try {
    decoded = jsonDecode(depFile.readAsStringSync());
  } catch (error) {
    stdout.writeln('[prelink] 解析 .flutter-plugins-dependencies 失败: $error');
    return 1;
  }
  if (decoded is! Map) {
    stdout.writeln('[prelink] 依赖文件结构异常，跳过预建。');
    return 0;
  }

  final plugins = decoded['plugins'];
  if (plugins is! Map) {
    stdout.writeln('[prelink] 依赖文件里没有 plugins 段，跳过预建。');
    return 0;
  }

  var created = 0;
  var existing = 0;
  final problems = <String>[];

  for (final platform in _platforms) {
    final entries = plugins[platform];
    if (entries is! List || entries.isEmpty) {
      continue;
    }
    // 与 flutter_tools 一致：只在该平台目录存在时才处理
    if (!Directory('$root$sep$platform').existsSync()) {
      continue;
    }

    final symlinkDirPath = [
      root,
      platform,
      'flutter',
      'ephemeral',
      '.plugin_symlinks',
    ].join(sep);

    try {
      Directory(symlinkDirPath).createSync(recursive: true);
    } catch (_) {
      // 目录已存在或由后续步骤创建，交给下面的逐条判据
    }

    for (final raw in entries) {
      if (raw is! Map) {
        continue;
      }
      final name = raw['name'];
      final target = raw['path'];
      if (name is! String || target is! String) {
        continue;
      }
      if (name.isEmpty || target.isEmpty) {
        continue;
      }

      final linkPath = '$symlinkDirPath$sep$name';
      final link = Link(linkPath);

      if (link.isLinkSyncPath() && link.existsSync()) {
        existing++;
        continue;
      }

      var thrown = '';
      try {
        link.createSync(target);
      } catch (error) {
        thrown = error.toString();
      }

      // 最终状态判据：链接真的存在且指向正确，就认为成功（吞掉假错误）
      if (FileSystemEntity.isLinkSync(linkPath) && link.existsSync()) {
        created++;
        continue;
      }

      problems.add(
        '$linkPath -> $target'
        '${thrown.isEmpty ? '  [创建后链接仍不存在]' : '  [$thrown]'}',
      );
    }
  }

  stdout.writeln('[prelink] 新建=$created 已存在=$existing 失败=${problems.length}');
  if (problems.isEmpty) {
    return 0;
  }
  for (final problem in problems) {
    stdout.writeln('[prelink] 失败: $problem');
  }
  return 1;
}

extension on Link {
  bool isLinkSyncPath() => FileSystemEntity.isLinkSync(path);
}
