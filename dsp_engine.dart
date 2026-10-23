import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../core/log.dart';
import 'eq.dart';

/// Applies the EQ model to the platform audio path.
///
/// Android: drives the system equalizer effect (device-defined bands, usually
/// 5), by sampling our curve at each hardware band centre. iOS/Windows/Linux:
/// no DSP path is connected yet and the UI says so.
class DspEngine extends ChangeNotifier {
  DspEngine(this._eq);
  final AndroidEqualizer? _eq;

  String status = '';
  List<double> hardwareFreqs = const [];

  bool get available => _eq != null;

  String get capabilityText => available
      ? 'Applied through the Android system equalizer. The hardware exposes '
          '${hardwareFreqs.isEmpty ? 'a limited number of' : hardwareFreqs.length} '
          'bands, so the real response approximates the curve shown.'
      : 'Not applied on this platform yet. Settings are saved, but no audio '
          'processing path is connected here.';

  Future<void> apply(EqState s) async {
    final eq = _eq;
    if (eq == null) return;
    try {
      await eq.setEnabled(s.enabled);
      if (!s.enabled) {
        status = 'Bypassed';
        notifyListeners();
        return;
      }
      final params = await eq.parameters;
      hardwareFreqs = [for (final b in params.bands) b.centerFrequency];
      for (final band in params.bands) {
        final db = (responseDb(s, band.centerFrequency) + s.preampDb)
            .clamp(params.minDecibels, params.maxDecibels)
            .toDouble();
        await band.setGain(db);
      }
      status = 'Active';
    } catch (e) {
      status = 'Equalizer unavailable: $e';
      Log.e('dsp', 'apply failed', e);
    }
    notifyListeners();
  }
}
