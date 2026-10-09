import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_workbench/app.dart';
import 'package:personal_workbench/core/theme/app_theme.dart';

void main() {
  testWidgets('independent desktop lists scroll without orphaned scrollbars', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light().copyWith(platform: TargetPlatform.windows),
        scrollBehavior: const WorkbenchScrollBehavior(),
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 220,
                child: ListView.builder(
                  itemCount: 60,
                  itemBuilder: (context, index) =>
                      ListTile(title: Text('导航 $index')),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: 60,
                  itemBuilder: (context, index) =>
                      ListTile(title: Text('正文 $index')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
