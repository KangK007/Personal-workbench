import 'dart:async';

import 'package:flutter/foundation.dart';

enum FocusMode { stopwatch, pomodoro25, pomodoro50, custom }

class FocusService extends ChangeNotifier {
  FocusService({
    DateTime Function()? now,
    Duration tickInterval = const Duration(seconds: 1),
    this.onTargetReached,
  }) : _now = now ?? DateTime.now,
       _tickInterval = tickInterval;

  final DateTime Function() _now;
  final Duration _tickInterval;
  final VoidCallback? onTargetReached;

  Timer? _timer;
  DateTime? _startedAt;
  Duration _elapsedBeforeStart = Duration.zero;
  FocusMode _mode = FocusMode.stopwatch;
  bool _running = false;
  bool _targetReached = false;
  Duration _customTarget = const Duration(minutes: 25);

  FocusMode get mode => _mode;
  bool get running => _running;
  bool get targetReached => _targetReached;
  DateTime? get startedAt => _startedAt;

  Duration get target => switch (_mode) {
    FocusMode.stopwatch => Duration.zero,
    FocusMode.pomodoro25 => const Duration(minutes: 25),
    FocusMode.pomodoro50 => const Duration(minutes: 50),
    FocusMode.custom => _customTarget,
  };

  Duration get elapsed {
    if (!_running || _startedAt == null) return _elapsedBeforeStart;
    final live = _now().difference(_startedAt!);
    return _elapsedBeforeStart + (live.isNegative ? Duration.zero : live);
  }

  Duration get displayDuration {
    if (_mode == FocusMode.stopwatch) return elapsed;
    final remaining = target - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  double get progress {
    if (_mode == FocusMode.stopwatch || target.inMilliseconds == 0) return 0;
    return (elapsed.inMilliseconds / target.inMilliseconds).clamp(0, 1);
  }

  void start(FocusMode mode, {Duration? customTarget}) {
    if (_running) return;
    if (_targetReached ||
        (_elapsedBeforeStart > Duration.zero && mode != _mode)) {
      _elapsedBeforeStart = Duration.zero;
    }
    _mode = mode;
    if (customTarget != null && customTarget > Duration.zero) {
      _customTarget = customTarget;
    }
    _targetReached = false;
    _startedAt = _now();
    _running = true;
    _startTicker();
    notifyListeners();
  }

  void pause() {
    if (!_running || _startedAt == null) return;
    if (_mode != FocusMode.stopwatch && elapsed >= target) {
      _completeTarget();
      return;
    }
    _elapsedBeforeStart = elapsed;
    _startedAt = null;
    _running = false;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  Duration finish() {
    final result = elapsed;
    reset();
    return result;
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    _startedAt = null;
    _elapsedBeforeStart = Duration.zero;
    _running = false;
    _targetReached = false;
    notifyListeners();
  }

  void refresh() {
    if (!_running) return;
    if (_mode != FocusMode.stopwatch && elapsed >= target) {
      _completeTarget();
    } else {
      notifyListeners();
    }
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(_tickInterval, (_) => refresh());
  }

  void _completeTarget() {
    if (_targetReached) return;
    _elapsedBeforeStart = target;
    _startedAt = null;
    _running = false;
    _targetReached = true;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
    onTargetReached?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
