import 'package:flutter/material.dart';
import '../app.dart';
import '../audio/route_monitor.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class OutputScreen extends StatelessWidget {
  const OutputScreen({super.key});

  IconData _icon(String type) {
    final t = type.toLowerCase();
    if (t.contains('bluetooth')) return Icons.bluetooth_audio;
    if (t.contains('usb')) return Icons.usb;
    if (t.contains('wired') || t.contains('headphone') || t.contains('headset')) {
      return Icons.headphones;
    }
    if (t.contains('hdmi')) return Icons.tv;
    if (t.contains('speaker')) return Icons.speaker;
    return Icons.volume_up;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: App.routes,
      builder: (_, __) {
        final r = App.routes;
        final active = r.likelyActive;
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const SectionTitle('Audio outputs reported by the OS'),
            if (r.error != null) InfoCard(r.error!, warn: true),
            if (r.error == null && r.outputs.isEmpty)
              const InfoCard('No output devices reported.'),
            for (final d in r.outputs)
              ListTile(
                leading: Icon(_icon(d.type.name),
                    color: d == active ? LColors.electric : LColors.silverDim),
                title: Text(d.name),
                subtitle: Text(
                  '${d.type.name}${d == active ? ' · likely active' : ''}'
                  '${isBluetoothDevice(d) ? ' · lossy codec' : ''}',
                  style: const TextStyle(fontSize: 12, color: LColors.silverDim),
                ),
              ),
            const SectionTitle('What this means for sound quality'),
            const InfoCard(
              'Source quality describes the file. Output quality is decided by the OS, '
              'the audio route and the hardware. LOSSLESS shows the first and does not '
              'guess the second.',
            ),
            const InfoCard(
              'Output sample rate, bit depth and Bluetooth codec are not exposed to this '
              'app, so they are shown as "not reported". Android normally mixes audio at '
              'a fixed device rate, which can resample your file. Bit-perfect output is '
              'not claimed because it cannot be verified from here.',
            ),
            const InfoCard(
              'Bluetooth always re-encodes audio with a lossy codec (SBC, AAC, aptX, LDAC, '
              'LC3…), even when the file is FLAC.',
              warn: true,
              icon: Icons.bluetooth,
            ),
            const InfoCard(
              'USB DAC: playback goes through the OS audio stack. Direct/exclusive USB '
              'output is not implemented in this version.',
            ),
          ],
        );
      },
    );
  }
}
