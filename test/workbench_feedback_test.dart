import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/theme/app_theme.dart';
import 'package:personal_workbench/ui/widgets/common.dart';

void main() {
  final themeVariant = ValueVariant<Brightness>(Brightness.values.toSet());
  testWidgets(
    'visible feedback reflows after resizing and changing text size',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final scale = ValueNotifier<TextScaler>(TextScaler.noScaling);
      addTearDown(scale.dispose);
      var undone = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: themeVariant.currentValue == Brightness.dark
              ? AppTheme.dark()
              : AppTheme.light(),
          builder: (context, child) => ValueListenableBuilder<TextScaler>(
            valueListenable: scale,
            builder: (context, scaler, _) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: scaler),
              child: child!,
            ),
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showWorkbenchFeedback(
                    context,
                    '已移到“分析整理待处理任务群”',
                    action: SnackBarAction(
                      label: '撤销',
                      onPressed: () => undone = true,
                    ),
                  ),
                  child: const Text('移动'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('移动'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(320, 568);
      scale.value = const TextScaler.linear(2);
      await tester.pumpAndSettle();
      final feedback = tester.getRect(find.byType(SnackBar));
      expect(feedback.height, lessThan(200));
      final action = tester.getRect(find.widgetWithText(TextButton, '撤销'));
      expect(feedback.contains(action.center), isTrue);
      expect(action.bottom, lessThanOrEqualTo(568));
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(1920, 1080);
      scale.value = TextScaler.noScaling;
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(SnackBar)).height, lessThan(100));
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(320, 568);
      scale.value = const TextScaler.linear(2);
      await tester.pumpAndSettle();
      await tester.tap(find.text('撤销'));
      await tester.pumpAndSettle();
      expect(undone, isTrue);
      expect(find.byType(SnackBar), findsNothing);
    },
    variant: themeVariant,
  );
}
