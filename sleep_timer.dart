import 'dart:async';
import 'package:flutter/foundation.dart';

/// 0..1 gain for the final [fade] of a sleep timer.
double fadeFactor(Duration remaining, Duration fade) {
  if (fade.inMilliseconds <= 0) return 1;
  return (remaining.inMilliseconds / fade.inMilliseconds).clamp(0.0, 1.0);
}

class SleepTimer extends ChangeNotifier {
  SleepTimer({required this.onFade, required this.onExpire});
  final void Function(double) onFade;
  final Future<void> Function() onExpire;

  Timer? _t;
  Duration? remaining;
  Duration _fade = Duration.zero;

  bool get active => _t != null;

  void start(Duration d, {Duration fade = const Duration(seconds: 20)}) {
    cancel();
    remaining = d;
    _fade = fade;
    _t = Timer.periodic(const Duration(seconds: 1), (_) async {
      final r = remaining! - const Duration(seconds: 1);
      remaining = r;
      onFade(fadeFactor(r, _fade));
      if (r <= Duration.zero) {
        _t?.cancel();
        _t = null;
        await onExpire();
        remaining = null;
        onFade(1);
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void cancel() {
    _t?.cancel();
    _t = null;
    remaining = null;
    onFade(1);
    notifyListeners();
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }
}
