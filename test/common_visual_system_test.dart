import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/theme/app_theme.dart';
import 'package:personal_workbench/ui/widgets/common.dart';

Widget _host(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  home: Scaffold(body: child),
);

void main() {
  for (final entry in {
    'light': AppTheme.light(),
    'dark': AppTheme.dark(),
  }.entries) {
    testWidgets(
      '${entry.key} page context and section count use readable text',
      (tester) async {
        final tokens = entry.value.extension<WorkbenchTokens>()!;
        await tester.pumpWidget(
          _host(
            entry.value,
            const Column(
              children: [
                PageHeader(title: '今日', kicker: '10月7日 星期三'),
                SectionHeading(title: '今日重点', scale: '3 项'),
              ],
            ),
          ),
        );

        expect(
          tester.widget<Text>(find.text('10月7日 星期三')).style!.color,
          tokens.mutedText,
        );
        expect(
          tester.widget<Text>(find.text('3 项')).style!.color,
          tokens.mutedText,
        );
        expect(tokens.mutedText, isNot(tokens.inkFaint));
      },
    );
  }

  testWidgets(
    'empty state and status label retain readable hierarchy on phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _host(
          AppTheme.light(),
          const SingleChildScrollView(
            child: Column(
              children: [
                EmptyState(
                  icon: Icons.inbox_outlined,
                  title: '暂无记录',
                  message: '记录会出现在这里。',
                ),
                StatusPill(label: '待处理', dense: true),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final heading = tester.widget<Text>(find.text('暂无记录'));
      final status = tester.widget<Text>(find.text('待处理'));
      expect(heading.style!.fontSize, 18);
      expect(status.style!.fontSize, greaterThanOrEqualTo(12));
      expect(tester.takeException(), isNull);
    },
  );
}
