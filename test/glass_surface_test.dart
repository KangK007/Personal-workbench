import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/theme/app_theme.dart';
import 'package:personal_workbench/ui/widgets/common.dart';
import 'package:personal_workbench/ui/widgets/glass.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('glass surface applies backdrop blur by default', (tester) async {
    GlassConfig.blurEnabled = true;
    addTearDown(() => GlassConfig.blurEnabled = true);
    await tester.pumpWidget(
      _host(const GlassSurface(child: SizedBox(width: 100, height: 100))),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('glass surface falls back to solid panel when blur disabled', (
    tester,
  ) async {
    GlassConfig.blurEnabled = false;
    addTearDown(() => GlassConfig.blurEnabled = true);
    await tester.pumpWidget(
      _host(const GlassSurface(child: SizedBox(width: 100, height: 100))),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    // 降级面板仍保留 1px 边框与常规阴影，层次不丢失。
    final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.border, isNotNull);
  });

  testWidgets('per-instance enabled=false falls back even with blur enabled', (
    tester,
  ) async {
    GlassConfig.blurEnabled = true;
    addTearDown(() => GlassConfig.blurEnabled = true);
    await tester.pumpWidget(
      _host(
        const GlassSurface(
          enabled: false,
          child: SizedBox(width: 100, height: 100),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('workbench dialog does not create a full-screen glass panel', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showWorkbenchDialog<void>(
              context: context,
              builder: (context) => const AlertDialog(
                title: Text('确认操作'),
                content: Text('对话框内容'),
              ),
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(GlassSurface), findsNothing);
    expect(find.byType(BackdropFilter), findsOneWidget);
  });
}
