import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/core/theme/app_theme.dart';
import 'package:personal_workbench/ui/widgets/common.dart';
import 'package:personal_workbench/ui/widgets/solid_panel.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('solid panel never applies backdrop blur', (tester) async {
    await tester.pumpWidget(
      _host(const SolidPanel(child: SizedBox(width: 100, height: 100))),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    // 实色面板：1px 边框 + 微阴影双保险。
    final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.border, isNotNull);
    expect(decoration.boxShadow, isNotEmpty);
    expect(decoration.color, isNotNull);
  });

  testWidgets('glass surface applies blur and supports a solid fallback', (
    tester,
  ) async {
    GlassConfig.blurEnabled = true;
    addTearDown(() => GlassConfig.blurEnabled = true);

    await tester.pumpWidget(
      _host(const GlassSurface(child: SizedBox(width: 100, height: 100))),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);

    GlassConfig.blurEnabled = false;
    await tester.pumpWidget(
      _host(const GlassSurface(child: SizedBox(width: 100, height: 100))),
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('elevated panel uses raised shadow depth', (tester) async {
    await tester.pumpWidget(
      _host(
        const SolidPanel(
          elevated: true,
          child: SizedBox(width: 100, height: 100),
        ),
      ),
    );
    final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    final decoration = box.decoration as BoxDecoration;
    final shadow = decoration.boxShadow!.single;
    // 浮层投影：blur 16 / y+6。
    expect(shadow.blurRadius, 16);
    expect(shadow.offset, const Offset(0, 6));
  });

  testWidgets('selected panel draws 3px primary accent bar', (tester) async {
    await tester.pumpWidget(
      _host(
        const SolidPanel(
          selected: true,
          child: SizedBox(width: 100, height: 100),
        ),
      ),
    );
    final containers = tester
        .widgetList<Container>(find.byType(Container))
        .toList();
    // 左缘强调条是一个 3px 宽的 Container。
    final accentBar = containers.any((c) {
      final constraints = c.constraints;
      return constraints is BoxConstraints &&
          constraints.minWidth == 3 &&
          constraints.maxWidth == 3;
    });
    expect(accentBar, isTrue);
  });

  testWidgets('workbench dialog uses solid raised surface', (tester) async {
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
    expect(find.byType(SolidPanel), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
