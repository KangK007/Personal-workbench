import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../core/models/restriction_models.dart';

class WindowsActivityService {
  static const _channel = MethodChannel('personal_workbench/windows_activity');
  static final _powerEvents = StreamController<String>.broadcast();
  static final _exitRequests = StreamController<void>.broadcast();
  static bool _handlerInstalled = false;

  WindowsActivityService();

  void _ensureHandler() {
    if (!_handlerInstalled && Platform.isWindows) {
      try {
        _channel.setMethodCallHandler((call) async {
          if (call.method == 'powerEvent') {
            final value = call.arguments?.toString();
            if (value != null) _powerEvents.add(value);
          } else if (call.method == 'exitRequested') {
            _exitRequests.add(null);
          }
        });
        _handlerInstalled = true;
      } catch (_) {
        // Pure Dart tests and pre-binding startup do not have a messenger yet.
      }
    }
  }

  bool get supported => Platform.isWindows;
  Stream<String> get powerEvents {
    _ensureHandler();
    return _powerEvents.stream;
  }

  Stream<void> get exitRequests {
    _ensureHandler();
    return _exitRequests.stream;
  }

  Future<bool> bridgeAvailable() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> foregroundProcess() async {
    if (!supported) return null;
    final String? value;
    try {
      value = await _channel.invokeMethod<String>('foregroundProcess');
    } catch (_) {
      return null;
    }
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  Future<List<RestrictionProcessSnapshot>> processSnapshot() async {
    if (!supported) return const [];
    try {
      final values = await _channel.invokeMethod<List<dynamic>>(
        'processSnapshot',
      );
      return (values ?? const [])
          .whereType<Map>()
          .map(RestrictionProcessSnapshot.fromJson)
          .where((value) => value.pid > 0 && value.name.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<bool> terminateProcess({
    required int pid,
    required String expectedName,
  }) async {
    if (!supported || pid <= 0 || expectedName.trim().isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>('terminateProcess', {
            'pid': pid,
            'expectedName': expectedName,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<RestrictionHostsStatus> hostsStatus(Iterable<String> domains) async {
    if (!supported) return const RestrictionHostsStatus();
    try {
      final value = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'hostsStatus',
        {'domains': domains.toList(growable: false)},
      );
      return RestrictionHostsStatus.fromJson(value ?? const {});
    } catch (error) {
      return RestrictionHostsStatus(supported: true, error: '$error');
    }
  }

  Future<bool> applyHostsPolicy(Iterable<String> domains) async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('applyHostsPolicy', {
            'domains': domains.toList(growable: false),
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> clearHostsPolicy() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('clearHostsPolicy') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isAdministrator() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('isAdministrator') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setExitGuard(bool enabled) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('setExitGuard', enabled);
    } catch (_) {
      return;
    }
  }

  Future<void> setCloseToTray(bool enabled) async {
    if (supported) {
      try {
        await _channel.invokeMethod<void>('setCloseToTray', enabled);
      } catch (_) {
        return;
      }
    }
  }

  Future<bool> startupEnabled() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('startupEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setStartupEnabled(bool enabled) async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('setStartupEnabled', enabled) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> showWindow() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('showWindow') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> exitApplication() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('exitApplication');
    } catch (_) {
      return;
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('showNotification', {
        'title': title,
        'body': body,
      });
    } catch (_) {
      return;
    }
  }

  Future<bool?> protectFile({
    required String sourcePath,
    required String destinationPath,
  }) async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<bool>('protectFile', {
            'sourcePath': sourcePath,
            'destinationPath': destinationPath,
          }) ??
          false;
    } catch (_) {
      return null;
    }
  }

  Future<bool?> unprotectFile({
    required String sourcePath,
    required String destinationPath,
  }) async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<bool>('unprotectFile', {
            'sourcePath': sourcePath,
            'destinationPath': destinationPath,
          }) ??
          false;
    } catch (_) {
      return null;
    }
  }
}
