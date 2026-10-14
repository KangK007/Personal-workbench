import 'package:flutter/material.dart';

class ProjectIconOption {
  const ProjectIconOption(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}

abstract final class ProjectIcons {
  static const options = <ProjectIconOption>[
    ProjectIconOption('folder', '项目', Icons.folder_outlined),
    ProjectIconOption('layers', '规划', Icons.layers_outlined),
    ProjectIconOption('lightbulb', '创意', Icons.lightbulb_outline),
    ProjectIconOption('school', '学习', Icons.school_outlined),
    ProjectIconOption('palette', '设计', Icons.palette_outlined),
    ProjectIconOption('eco', '生活', Icons.eco_outlined),
    ProjectIconOption('code', '开发', Icons.code_outlined),
    ProjectIconOption('flag', '目标', Icons.flag_outlined),
  ];

  static ProjectIconOption forKey(Object? key) {
    for (final option in options) {
      if (option.key == key) return option;
    }
    return options.first;
  }
}
