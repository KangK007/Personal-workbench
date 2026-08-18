import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ShareCapture {
  const ShareCapture({required this.text, required this.isUrl});

  final String text;
  final bool isUrl;
}

class ShareCaptureService {
  static const _channel = MethodChannel('personal_workbench/share');
  Future<void> Function(ShareCapture)? _onCapture;
  Future<void> _pendingCapture = Future.value();
  bool _initialized = false;

  Future<void> initialize(Future<void> Function(ShareCapture) onCapture) async {
    if (!Platform.isAndroid || _initialized) return;
    _initialized = true;
    _onCapture = onCapture;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedText') {
        final text = call.arguments?.toString().trim() ?? '';
        if (text.isNotEmpty) await _enqueue(text);
      }
      return null;
    });
    try {
      final initial = await _channel.invokeMethod<String>('getInitialText');
      if (initial != null && initial.trim().isNotEmpty) {
        await _enqueue(initial);
      }
    } on PlatformException catch (error) {
      debugPrint('Unable to read initial shared text: $error');
    }
  }

  Future<void> _enqueue(String text) {
    final next = _pendingCapture.then((_) => _emit(text));
    _pendingCapture = next.catchError((Object error, StackTrace stackTrace) {
      debugPrint('Unable to capture shared text: $error\n$stackTrace');
    });
    return next;
  }

  Future<void> _emit(String text) {
    final uri = Uri.tryParse(text.trim());
    return _onCapture?.call(
          ShareCapture(
            text: text.trim(),
            isUrl:
                (uri?.scheme == 'http' || uri?.scheme == 'https') &&
                uri?.host.isNotEmpty == true,
          ),
        ) ??
        Future.value();
  }

  void dispose() {
    _onCapture = null;
    if (_initialized) _channel.setMethodCallHandler(null);
    _initialized = false;
  }
}
