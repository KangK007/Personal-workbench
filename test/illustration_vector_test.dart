import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/theme/app_theme.dart';
import 'package:personal_workbench/ui/widgets/workbench_illustration.dart';

void main() {
  testWidgets(
    'decorative illustrations fit both themes without bitmap assets',
    (tester) async {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        for (final kind in WorkbenchIllustrationKind.values) {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: Center(
                  child: WorkbenchIllustration(
                    kind: kind,
                    width: 74,
                    height: 54,
                  ),
                ),
              ),
            ),
          );
          expect(find.byType(Image), findsNothing);
          expect(find.byType(CustomPaint), findsWidgets);
          expect(
            tester.getSize(find.byType(WorkbenchIllustration)),
            const Size(74, 54),
          );
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
}
