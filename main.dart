import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'app.dart';
import 'audio/audio_handler.dart';
import 'audio/route_monitor.dart';
import 'core/settings.dart';
import 'core/theme.dart';
import 'features/shell.dart';
import 'library/library_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux) {
    JustAudioMediaKit.ensureInitialized(windows: true, linux: true);
  }
  App.settings = await Settings.load();
  App.library = await LibraryStore.load();

  // audio_service has native support on Android/iOS only. On desktop the
  // handler runs standalone (no OS media-key / lock-screen integration yet).
  if (Platform.isAndroid || Platform.isIOS) {
    App.handler = await AudioService.init<LosslessAudioHandler>(
      builder: () => LosslessAudioHandler(App.settings),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'app.lossless.playback',
        androidNotificationChannelName: 'LOSSLESS playback',
        androidNotificationOngoing: true,
      ),
    );
  } else {
    App.handler = LosslessAudioHandler(App.settings);
  }
  await App.handler.start(App.library);
  App.routes = RouteMonitor();
  App.routes.start();
  runApp(const LosslessApp());
}

class LosslessApp extends StatelessWidget {
  const LosslessApp({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: App.settings,
        builder: (_, __) => MaterialApp(
          title: 'LOSSLESS',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(App.settings.theme),
          home: const Shell(),
        ),
      );
}
