import 'package:flutter/foundation.dart';

/// Tiny structured logger. Keeps the last 300 lines in memory so the
/// Settings screen can show diagnostics. Nothing is sent anywhere.
class Log {
  static final List<String> lines = [];
  static void _add(String lvl, String tag, String msg) {
    final line = '${DateTime.now().toIso8601String()} $lvl [$tag] $msg';
    lines.add(line);
    if (lines.length > 300) lines.removeAt(0);
    debugPrint(line);
  }

  static void i(String tag, String msg) => _add('I', tag, msg);
  static void w(String tag, String msg) => _add('W', tag, msg);
  static void e(String tag, String msg, [Object? err]) =>
      _add('E', tag, err == null ? msg : '$msg: $err');
}
