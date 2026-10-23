import 'dart:io';
import 'package:flutter/material.dart';
import '../app.dart';
import '../audio/replaygain.dart';
import '../core/log.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../library/actions.dart';
import 'shell.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([App.settings, App.library]),
      builder: (context, _) {
        final s = App.settings;
        final lib = App.library;
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const SectionTitle('Appearance'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<LThemeMode>(
                segments: const [
                  ButtonSegment(value: LThemeMode.amoled, label: Text('AMOLED')),
                  ButtonSegment(value: LThemeMode.dark, label: Text('Dark')),
                  ButtonSegment(value: LThemeMode.light, label: Text('Light')),
                ],
                selected: {s.theme},
                onSelectionChanged: (v) => s.setTheme(v.first),
              ),
            ),
            const SectionTitle('ReplayGain'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<RgMode>(
                segments: const [
                  ButtonSegment(value: RgMode.off, label: Text('Off')),
                  ButtonSegment(value: RgMode.track, label: Text('Track')),
                  ButtonSegment(value: RgMode.album, label: Text('Album')),
                ],
                selected: {s.rgMode},
                onSelectionChanged: (v) => s.setRgMode(v.first),
              ),
            ),
            ListTile(
              title: Text('Preamp: ${s.rgPreamp.toStringAsFixed(1)} dB'),
              subtitle: Slider(
                min: -12,
                max: 0,
                divisions: 24,
                value: s.rgPreamp.clamp(-12.0, 0.0),
                onChanged: s.setRgPreamp,
              ),
            ),
            SwitchListTile(
              title: const Text('Prevent clipping'),
              subtitle: const Text('Limits gain using the file\'s peak tag'),
              value: s.preventClipping,
              onChanged: s.setPreventClipping,
            ),
            const InfoCard(
              'ReplayGain here only turns volume down. Files that ask for a boost are '
              'capped at 0 dB. Gain is read from tags; a ReplayGain scanner is not included yet.',
            ),
            const SectionTitle('Sleep timer'),
            ListTile(
              title: Text('Fade-out: ${s.sleepFadeSec.round()} s'),
              subtitle: Slider(
                min: 0,
                max: 60,
                divisions: 12,
                value: s.sleepFadeSec.clamp(0.0, 60.0),
                onChanged: s.setSleepFade,
              ),
            ),
            const SectionTitle('Library'),
            ListTile(
              title: Text(lib.scanning ? 'Scanning…' : '${lib.tracks.length} tracks'),
              subtitle: Text(lib.status.isEmpty ? 'Not scanned yet' : lib.status),
              trailing: lib.scanning
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : null,
            ),
            if (!Platform.isIOS)
              for (final r in s.roots)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(r, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    tooltip: 'Remove folder',
                    icon: const Icon(Icons.close),
                    onPressed: () => s.removeRoot(r),
                  ),
                ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                if (!Platform.isIOS)
                  OutlinedButton.icon(
                    onPressed: () async => toast(context, await LibraryActions.addFolder()),
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: const Text('Add folder'),
                  ),
                OutlinedButton.icon(
                  onPressed: () async => toast(context, await LibraryActions.importFiles()),
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Import files'),
                ),
                OutlinedButton.icon(
                  onPressed: lib.scanning
                      ? null
                      : () async => toast(context, await LibraryActions.rescan()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Rescan'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _duplicates(context),
                  icon: const Icon(Icons.copy_all),
                  label: const Text('Find duplicates'),
                ),
              ]),
            ),
            const InfoCard(
              'Android can only read folders the system lets this app access. '
              'If a folder is skipped, import files instead. APE, WMA and WavPack are not supported.',
            ),
            const SectionTitle('Privacy'),
            const InfoCard(
              'LOSSLESS is local-first. It has no analytics, no ads and makes no network '
              'requests. Your music, listening history and settings never leave the device.',
              icon: Icons.lock_outline,
            ),
            const SectionTitle('About'),
            ListTile(
              title: const Text('LOSSLESS 0.2.0'),
              subtitle: const Text('by TanimSarker'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Open-source licenses'),
              onTap: () => showLicensePage(
                  context: context, applicationName: 'LOSSLESS', applicationVersion: '0.2.0'),
            ),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Diagnostic log'),
              subtitle: const Text('Stays on this device'),
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Diagnostic log'),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final l in Log.lines.reversed.take(80))
                          Text(l, style: const TextStyle(fontSize: 10)),
                        if (Log.lines.isEmpty) const Text('Empty'),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _duplicates(BuildContext context) {
    final d = App.library.findDuplicates();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(d.isEmpty ? 'No duplicates found' : '${d.length} possible duplicate set(s)'),
        content: d.isEmpty
            ? const Text('Matched by title, artist and duration.')
            : SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final set in d.take(50))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(set.first.title),
                            for (final t in set)
                              Text(t.path,
                                  style: const TextStyle(fontSize: 10, color: LColors.silverDim)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}
