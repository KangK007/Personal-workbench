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
    // 普通实色面板只使用 1px 边框，避免边框与宽阴影重复表达层级。
    final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.border, isNotNull);
    expect(decoration.boxShadow, isEmpty);
    expect(decoration.color, isNotNull);
  });

  testWidgets('log surface stays solid and never applies backdrop blur', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const LogSurface(child: SizedBox(width: 100, height: 100))),
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

  testWidgets('log rail exposes structural status beyond color', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 320,
          child: VineRail(
            entries: [
              VineRailEntry(label: '已完成时段', state: VineRailState.completed),
              VineRailEntry(label: '当前时段', state: VineRailState.current),
              VineRailEntry(label: '冲突时段', state: VineRailState.warning),
              VineRailEntry(label: '下一时段'),
            ],
          ),
        ),
      ),
    );

    final labels = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((widget) => widget.properties.label)
        .whereType<String>();
    expect(labels, contains('已完成时段，已完成'));
    expect(labels, contains('当前时段，进行中'));
    expect(labels, contains('冲突时段，需要注意'));
    expect(labels, contains('下一时段，待进行'));
    // 状态由「形状」承载（不依赖颜色，也不再依赖图标）：四态各有独立芽点结构。
    for (final state in VineRailState.values) {
      expect(
        find.byKey(ValueKey('vine-bud:${state.name}')),
        findsOneWidget,
        reason: '${state.name} 态必须有独立芽点结构',
      );
    }

    BoxDecoration budDecoration(String state) {
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(ValueKey('vine-bud:$state')),
              matching: find.byType(Container),
            )
            .first,
      );
      return container.decoration! as BoxDecoration;
    }

    // 未开始 = 空心芽点；已结果 = 实心芽点。颜色之外，填充方式本身即可区分。
    final pending = budDecoration('pending');
    expect(pending.color, isNull);
    expect(pending.border, isNotNull);

    final completed = budDecoration('completed');
    expect(completed.color, isNotNull);
    expect(completed.border, isNull);

    // 进行中 = 实心芽点 + 外环（两层同心圆）。
    expect(budDecoration('current').border, isNotNull);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('vine-bud:current')),
        matching: find.byType(Container),
      ),
      findsNWidgets(2),
    );

    // 断口 = 缺口弧（CustomPaint 绘制的 3/4 圆弧），不是圆点。
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('vine-bud:warning')),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
  });
}
