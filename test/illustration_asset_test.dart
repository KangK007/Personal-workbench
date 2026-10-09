import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all day and night illustrations decode at production resolution',
    () async {
      for (final theme in ['day', 'night']) {
        for (final kind in [
          'today',
          'project',
          'capture',
          'focus',
          'notes',
          'review',
          'growth',
        ]) {
          final path = 'assets/illustrations/$theme/$kind.webp';
          final data = await rootBundle.load(path);
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(),
          );
          final frame = await codec.getNextFrame();
          expect(frame.image.width, greaterThanOrEqualTo(1000), reason: path);
          expect(frame.image.height, greaterThanOrEqualTo(700), reason: path);
          frame.image.dispose();
          codec.dispose();

          final compactCodec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(),
            targetWidth: 150,
          );
          final compactFrame = await compactCodec.getNextFrame();
          expect(compactFrame.image.width, 150, reason: path);
          compactFrame.image.dispose();
          compactCodec.dispose();
        }
      }
    },
  );
}
