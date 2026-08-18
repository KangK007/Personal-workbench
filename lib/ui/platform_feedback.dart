import 'dart:io';

import 'package:flutter/services.dart';

abstract final class WorkbenchFeedback {
  static Future<void> selection() async {
    if (Platform.isAndroid) await HapticFeedback.selectionClick();
  }

  static Future<void> completion() async {
    if (Platform.isAndroid) await HapticFeedback.lightImpact();
  }
}
