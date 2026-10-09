import 'package:flutter/material.dart';

/// Finished, text-free artwork. Informative numbers and actions are rendered by
/// Flutter beside the illustration, so the image remains decorative.
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

  static String assetFor(
    Brightness brightness,
    WorkbenchIllustrationKind kind,
  ) {
    final theme = brightness == Brightness.dark ? 'night' : 'day';
    return 'assets/illustrations/$theme/${kind.name}.webp';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final decodedWidth = width == null ? null : (width! * ratio).ceil();
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRect(
          child: Image.asset(
            assetFor(brightness, kind),
            width: width,
            height: height,
            fit: fit,
            alignment: alignment,
            cacheWidth: decodedWidth,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
