import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'jade_paper_leaf_art.dart';

/// Text-free decoration. Informative numbers and actions are rendered beside it.
enum WorkbenchIllustrationKind {
  today,
  project,
  capture,
  focus,
  notes,
  review,
  growth,
}

class WorkbenchIllustration extends StatelessWidget {
  const WorkbenchIllustration({
    super.key,
    required this.kind,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  });

  final WorkbenchIllustrationKind kind;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final accent = switch (kind) {
      WorkbenchIllustrationKind.capture ||
      WorkbenchIllustrationKind.notes ||
      WorkbenchIllustrationKind.review => context.accents.clay,
      WorkbenchIllustrationKind.growth => context.accents.moss,
      WorkbenchIllustrationKind.project => context.accents.teal,
      _ => context.accents.jade,
    };
    final icon = switch (kind) {
      WorkbenchIllustrationKind.today => Icons.wb_sunny_outlined,
      WorkbenchIllustrationKind.project => Icons.account_tree_outlined,
      WorkbenchIllustrationKind.capture => Icons.move_to_inbox_outlined,
      WorkbenchIllustrationKind.focus => Icons.timer_outlined,
      WorkbenchIllustrationKind.notes => Icons.auto_stories_outlined,
      WorkbenchIllustrationKind.review => Icons.history_edu_outlined,
      WorkbenchIllustrationKind.growth => Icons.spa_outlined,
    };
    final tokens = context.tokens;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          width: width,
          height: height,
          child: FittedBox(
            fit: fit,
            alignment: alignment,
            child: JadePaperLeafArt(
              icon: icon,
              accent: accent.color,
              wash: accent.container,
              paper: tokens.panel,
              border: tokens.panelBorder,
              showGrowthBars: kind == WorkbenchIllustrationKind.growth,
            ),
          ),
        ),
      ),
    );
  }
}
