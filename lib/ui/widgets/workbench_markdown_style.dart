import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/theme/app_theme.dart';

MarkdownStyleSheet workbenchMarkdownStyle(BuildContext context) {
  final theme = Theme.of(context);
  final clay = context.accents.clay;
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    a: theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
    ),
    p: theme.textTheme.bodyMedium?.copyWith(fontSize: 16, height: 1.65),
    h1: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
    h2: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
    h3: theme.textTheme.titleMedium?.copyWith(fontSize: 17),
    blockquote: theme.textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
    blockquotePadding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
    blockquoteDecoration: BoxDecoration(
      color: clay.container,
      border: Border(left: BorderSide(color: clay.color, width: 2)),
      borderRadius: BorderRadius.circular(AppRadius.xs),
    ),
    code: theme.textTheme.bodyMedium?.copyWith(
      fontFamily: AppFonts.numeric,
      fontSize: 14,
    ),
    codeblockPadding: const EdgeInsets.all(12),
    codeblockDecoration: BoxDecoration(
      color: context.tokens.subtle,
      borderRadius: BorderRadius.circular(AppRadius.xs),
    ),
    blockSpacing: 16,
  );
}
