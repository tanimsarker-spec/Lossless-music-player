import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import '../app.dart';
import '../core/log.dart';
import 'scanner.dart';

/// User-facing library flows. Each returns a short message for a SnackBar.
class LibraryActions {
  static Future<bool> ensurePermission() async {
    if (!Platform.isAndroid) return true;
    var s = await Permission.audio.request();
    if (!s.isGranted) s = await Permission.storage.request();
    return s.isGranted;
  }

  static List<String> get roots => [
        ...App.library.defaultRoots,
        if (!Platform.isIOS) ...App.settings.roots,
      ];

  static Future<String> rescan() async {
    if (!await ensurePermission()) {
      return 'Audio permission denied. Enable it in system settings to scan.';
    }
    await App.library.scan(roots);
    return App.library.status;
  }

  static Future<String> addFolder() async {
    if (!await ensurePermission()) {
      return 'Audio permission denied. Enable it in system settings to scan.';
    }
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return 'No folder selected';
    await App.settings.addRoot(dir);
    return rescan();
  }

  /// Copies picked files into the app's own Music folder so they stay
  /// readable after restart (required on iOS, optional elsewhere).
  static Future<String> importFiles() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions:
          audioExts.map((e) => e.replaceFirst('.', '')).toList(),
    );
    if (res == null) return 'No files selected';
    var n = 0;
    for (final f in res.files) {
      final src = f.path;
      if (src == null) continue;
      try {
        var dest = p.join(App.library.importDir, p.basename(src));
        var i = 1;
        while (File(dest).existsSync()) {
          dest = p.join(App.library.importDir,
              '${p.basenameWithoutExtension(src)} ($i)${p.extension(src)}');
          i++;
        }
        await File(src).copy(dest);
        n++;
      } catch (e) {
        Log.e('import', 'copy failed for $src', e);
      }
    }
    await App.library.scan(roots);
    return 'Imported $n file(s). ${App.library.status}';
  }
}
