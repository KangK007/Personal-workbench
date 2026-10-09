import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Gives pages their actual available size after navigation and the wide-screen
/// bound. MediaQuery continues to describe the window for dialogs and keyboards.
class WorkbenchViewport extends StatelessWidget {
  const WorkbenchViewport({super.key, required this.child});

  final Widget child;

  static Size sizeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ViewportScope>()?.size ??
      MediaQuery.sizeOf(context);

  @override
  Widget build(BuildContext context) => WorkbenchContentFrame(
    maxWidth: AppLayout.workspaceMax,
    child: LayoutBuilder(
      builder: (context, constraints) =>
          _ViewportScope(size: constraints.biggest, child: child),
    ),
  );
}

class _ViewportScope extends InheritedWidget {
  const _ViewportScope({required this.size, required super.child});

  final Size size;

  @override
  bool updateShouldNotify(_ViewportScope oldWidget) => size != oldWidget.size;
}

/// Bounds a whole related group instead of centering each column separately.
/// Scroll views keep the complete available height, including short windows.
class WorkbenchContentFrame extends StatelessWidget {
  const WorkbenchContentFrame({
    super.key,
    required this.child,
    this.maxWidth = AppLayout.formMax,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

/// Fits a business diagram to its container on entry and on window resize.
/// Users can still pan, zoom, and explicitly return to the fitted view.
class WorkbenchDiagramViewport extends StatefulWidget {
  const WorkbenchDiagramViewport({
    super.key,
    required this.canvasSize,
    required this.child,
  });

  final Size canvasSize;
  final Widget child;

  @override
  State<WorkbenchDiagramViewport> createState() => _DiagramViewportState();
}

class _DiagramViewportState extends State<WorkbenchDiagramViewport> {
  final _transform = TransformationController();
  Size? _viewportSize;
  Size? _canvasSize;

  void _fit() {
    final viewport = _viewportSize;
    if (viewport == null) return;
    final canvas = widget.canvasSize;
    final scale = math
        .min(
          (viewport.width - 32) / canvas.width,
          (viewport.height - 32) / canvas.height,
        )
        .clamp(0.25, 1.0);
    _transform.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(
        (viewport.width - canvas.width * scale) / 2,
        math.min(16.0, viewport.height - canvas.height * scale - 16),
        0,
      );
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (_viewportSize != constraints.biggest ||
          _canvasSize != widget.canvasSize) {
        _viewportSize = constraints.biggest;
        _canvasSize = widget.canvasSize;
        _fit();
      }
      return Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: 0.25,
              maxScale: 2.5,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(160),
              child: SizedBox(
                width: widget.canvasSize.width,
                height: widget.canvasSize.height,
                child: widget.child,
              ),
            ),
          ),
          PositionedDirectional(
            top: 8,
            end: 8,
            child: IconButton.filledTonal(
              tooltip: '适应窗口',
              onPressed: _fit,
              icon: const Icon(Icons.fit_screen_outlined),
            ),
          ),
        ],
      );
    },
  );
}
