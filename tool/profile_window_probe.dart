import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;

typedef _MoveWindowNative =
    Int32 Function(
      IntPtr handle,
      Int32 x,
      Int32 y,
      Int32 width,
      Int32 height,
      Int32 repaint,
    );
typedef _MoveWindow =
    int Function(int handle, int x, int y, int width, int height, int repaint);
typedef _GetDpiForWindowNative = Uint32 Function(IntPtr handle);
typedef _GetDpiForWindow = int Function(int handle);
typedef _GetRectNative =
    Int32 Function(IntPtr handle, Pointer<_WindowRect> rect);
typedef _GetRect = int Function(int handle, Pointer<_WindowRect> rect);
typedef _CallocNative = Pointer<Void> Function(IntPtr count, IntPtr size);
typedef _Calloc = Pointer<Void> Function(int count, int size);
typedef _FreeNative = Void Function(Pointer<Void> memory);
typedef _Free = void Function(Pointer<Void> memory);

final class _WindowRect extends Struct {
  @Int32()
  external int left;

  @Int32()
  external int top;

  @Int32()
  external int right;

  @Int32()
  external int bottom;
}

class _VmServiceConnection {
  _VmServiceConnection(this.socket) {
    socket.listen(
      (message) {
        final response = jsonDecode(message as String) as Map<String, dynamic>;
        final id = response['id'];
        if (id != null) {
          _pending.remove(id.toString())?.complete(response);
        }
      },
      onError: (Object error) {
        for (final request in _pending.values) {
          request.completeError(error);
        }
        _pending.clear();
      },
    );
  }

  final WebSocket socket;
  final _pending = <String, Completer<Map<String, dynamic>>>{};
  var _nextId = 0;

  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, dynamic> params = const {},
  ]) async {
    final id = (++_nextId).toString();
    final response = Completer<Map<String, dynamic>>();
    _pending[id] = response;
    socket.add(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      }),
    );
    final result = await response.future.timeout(const Duration(seconds: 20));
    if (result['error'] != null) {
      throw StateError('$method failed: ${result['error']}');
    }
    return result['result'] as Map<String, dynamic>;
  }
}

List<double> _durations(List<dynamic> events, String name) {
  final started = <String, List<num>>{};
  final durations = <double>[];
  for (final raw in events) {
    final event = raw as Map<String, dynamic>;
    if (event['name'] != name) continue;
    final phase = event['ph'];
    final key = '${event['pid']}:${event['tid']}';
    final time = event['ts'] as num?;
    if (time == null) continue;
    if (phase == 'B' || phase == 'b') {
      started.putIfAbsent(key, () => []).add(time);
    } else if (phase == 'E' || phase == 'e') {
      final stack = started[key];
      if (stack != null && stack.isNotEmpty) {
        durations.add((time - stack.removeLast()) / 1000);
      }
    } else if (phase == 'X') {
      final duration = event['dur'] as num?;
      if (duration != null) durations.add(duration / 1000);
    }
  }
  return durations;
}

Map<String, dynamic> _summary(List<double> durations) {
  if (durations.isEmpty) return {'count': 0};
  durations.sort();
  double percentile(double fraction) =>
      durations[(math.max(1, (durations.length * fraction).ceil()) - 1).clamp(
        0,
        durations.length - 1,
      )];
  return {
    'count': durations.length,
    'medianMs': percentile(0.5),
    'p95Ms': percentile(0.95),
    'maxMs': durations.last,
    'over16_67ms': durations.where((value) => value > 16.67).length,
  };
}

Future<void> main(List<String> args) async {
  if (!Platform.isWindows || (args.length != 3 && args.length != 4)) {
    stderr.writeln(
      'Usage: dart run tool/profile_window_probe.dart '
      '<vm-service-ws-uri> <window-handle> <output-prefix> [dataset-label]',
    );
    exitCode = 64;
    return;
  }
  final socket = await WebSocket.connect(args[0]);
  final service = _VmServiceConnection(socket);
  final window = int.parse(args[1]);
  final user32 = DynamicLibrary.open('user32.dll');
  final moveWindow = user32.lookupFunction<_MoveWindowNative, _MoveWindow>(
    'MoveWindow',
  );
  final getDpi = user32
      .lookupFunction<_GetDpiForWindowNative, _GetDpiForWindow>(
        'GetDpiForWindow',
      );
  final getWindowRect = user32.lookupFunction<_GetRectNative, _GetRect>(
    'GetWindowRect',
  );
  final getClientRect = user32.lookupFunction<_GetRectNative, _GetRect>(
    'GetClientRect',
  );
  final runtime = DynamicLibrary.open('ucrtbase.dll');
  final allocate = runtime.lookupFunction<_CallocNative, _Calloc>('calloc');
  final free = runtime.lookupFunction<_FreeNative, _Free>('free');
  final sizes = <(int, int)>[
    (1200, 900),
    (390, 844),
    (320, 568),
    (800, 450),
    (1440, 900),
  ];
  final samples = <Map<String, dynamic>>[];
  final allEvents = <dynamic>[];
  try {
    await service.call('setVMTimelineFlags', {
      'recordedStreams': ['Dart', 'Embedder'],
    });
    for (final (width, height) in sizes) {
      await service.call('clearVMTimeline');
      final moved = moveWindow(window, 10, 10, width, height, 1) != 0;
      if (!moved) throw StateError('MoveWindow failed for ${width}x$height');
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final rectangle = allocate(1, sizeOf<_WindowRect>()).cast<_WindowRect>();
      int windowWidth;
      int windowHeight;
      int clientWidth;
      int clientHeight;
      try {
        if (getWindowRect(window, rectangle) == 0) {
          throw StateError('GetWindowRect failed for ${width}x$height');
        }
        windowWidth = rectangle.ref.right - rectangle.ref.left;
        windowHeight = rectangle.ref.bottom - rectangle.ref.top;
        if (getClientRect(window, rectangle) == 0) {
          throw StateError('GetClientRect failed for ${width}x$height');
        }
        clientWidth = rectangle.ref.right - rectangle.ref.left;
        clientHeight = rectangle.ref.bottom - rectangle.ref.top;
      } finally {
        free(rectangle.cast<Void>());
      }
      final vm = await service.call('getVM');
      final timeline = await service.call('getVMTimeline');
      final events = timeline['traceEvents'] as List<dynamic>;
      allEvents.addAll(events);
      final profiledBuilds = <String, int>{};
      for (final event in events.cast<Map<String, dynamic>>()) {
        if (event['ph'] == 'B' &&
            const {
              '_TodayContent',
              '_TodayTaskSection',
              '_TodayStatusTask',
              '_ExpandableTodayTask',
              '_TaskFactDetails',
            }.contains(event['name'])) {
          final name = event['name'] as String;
          profiledBuilds.update(name, (count) => count + 1, ifAbsent: () => 1);
        }
      }
      samples.add({
        'requestedWindowWidthPx': width,
        'requestedWindowHeightPx': height,
        'actualWindowWidthPx': windowWidth,
        'actualWindowHeightPx': windowHeight,
        'clientWidthPx': clientWidth,
        'clientHeightPx': clientHeight,
        'dpi': getDpi(window),
        'rssBytes': vm['_currentRSS'],
        'uiFrames': _summary(_durations(events, 'Frame')),
        'rasterFrames': _summary(_durations(events, 'Rasterizer::DoDraw')),
        if (profiledBuilds.isNotEmpty) 'profiledWidgetBuilds': profiledBuilds,
        'traceEventCount': events.length,
      });
    }
    final report = {
      'recordedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'mode':
          'Windows Profile, isolated ${args.length == 4 ? args[3] : 'empty'} SQLite database',
      'samples': samples,
      'uiFrames': _summary(_durations(allEvents, 'Frame')),
      'rasterFrames': _summary(_durations(allEvents, 'Rasterizer::DoDraw')),
      'traceEventCount': allEvents.length,
    };
    await File(
      '${args[2]}.json',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    await File(
      '${args[2]}-timeline.json',
    ).writeAsString(jsonEncode({'traceEvents': allEvents}));
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
  } finally {
    await service.call('setVMTimelineFlags', {'recordedStreams': <String>[]});
    await socket.close();
  }
}
