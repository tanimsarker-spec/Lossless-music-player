import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import '../core/log.dart';

bool isBluetoothDevice(AudioDevice d) =>
    d.type.name.toLowerCase().contains('bluetooth');

/// Lists output devices the OS reports. It cannot see negotiated sample rate,
/// bit depth or Bluetooth codec; the UI says "not reported" for those.
class RouteMonitor extends ChangeNotifier {
  List<AudioDevice> outputs = const [];
  String? error;
  StreamSubscription<void>? _sub;

  Future<void> start() async {
    try {
      final s = await AudioSession.instance;
      await refresh();
      _sub = s.devicesChangedEventStream.listen((_) => refresh());
    } catch (e) {
      error = 'Output device list is not available on this platform.';
      Log.w('route', 'start failed: $e');
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    try {
      final s = await AudioSession.instance;
      final all = await s.getDevices();
      outputs = all.where((d) => d.isOutput).toList();
      error = null;
    } catch (e) {
      error = 'Output device list is not available on this platform.';
    }
    notifyListeners();
  }

  /// Best guess only; Android picks the route, apps cannot read it directly.
  AudioDevice? get likelyActive {
    int rank(AudioDevice d) {
      final n = d.type.name.toLowerCase();
      if (n.contains('usb')) return 0;
      if (n.contains('wired')) return 1;
      if (n.contains('bluetooth')) return 2;
      return 3;
    }

    if (outputs.isEmpty) return null;
    final l = [...outputs]..sort((a, b) => rank(a).compareTo(rank(b)));
    return l.first;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
