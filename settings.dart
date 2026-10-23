import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../audio/eq.dart';
import '../audio/replaygain.dart';
import 'theme.dart';

/// Persisted user settings. Everything is local; nothing is uploaded.
class Settings extends ChangeNotifier {
  Settings._(this.prefs);
  final SharedPreferences prefs;

  static Future<Settings> load() async =>
      Settings._(await SharedPreferences.getInstance());

  LThemeMode get theme => LThemeMode.values.firstWhere(
      (e) => e.name == prefs.getString('theme'),
      orElse: () => LThemeMode.amoled);
  RgMode get rgMode => RgMode.values.firstWhere(
      (e) => e.name == prefs.getString('rgMode'),
      orElse: () => RgMode.off);
  double get rgPreamp => prefs.getDouble('rgPreamp') ?? 0;
  bool get preventClipping => prefs.getBool('rgClip') ?? true;
  double get sleepFadeSec => prefs.getDouble('sleepFade') ?? 20;
  List<String> get roots => prefs.getStringList('roots') ?? const [];

  EqState get eq {
    try {
      final s = prefs.getString('eq');
      if (s != null) {
        return EqState.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map));
      }
    } catch (_) {}
    return EqState.flat();
  }

  Future<void> setTheme(LThemeMode v) => _set(() => prefs.setString('theme', v.name));
  Future<void> setRgMode(RgMode v) => _set(() => prefs.setString('rgMode', v.name));
  Future<void> setRgPreamp(double v) => _set(() => prefs.setDouble('rgPreamp', v));
  Future<void> setPreventClipping(bool v) => _set(() => prefs.setBool('rgClip', v));
  Future<void> setSleepFade(double v) => _set(() => prefs.setDouble('sleepFade', v));
  Future<void> setEq(EqState v) => _set(() => prefs.setString('eq', jsonEncode(v.toJson())));
  Future<void> addRoot(String r) => _set(() => prefs.setStringList(
      'roots', {...roots, r}.toList()));
  Future<void> removeRoot(String r) => _set(() => prefs.setStringList(
      'roots', roots.where((e) => e != r).toList()));

  Future<void> _set(Future<bool> Function() w) async {
    await w();
    notifyListeners();
  }
}
