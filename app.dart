import 'audio/audio_handler.dart';
import 'audio/route_monitor.dart';
import 'core/settings.dart';
import 'library/library_store.dart';

/// Simple service holder, initialised once in main().
class App {
  static late Settings settings;
  static late LibraryStore library;
  static late LosslessAudioHandler handler;
  static late RouteMonitor routes;
}
