import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/log.dart';
import 'scanner.dart';
import 'track.dart';

/// Local-first library persisted as JSON in the app documents folder.
/// Fine for tens of thousands of tracks; a SQLite store is a planned upgrade.
class LibraryStore extends ChangeNotifier {
  LibraryStore._(this.docsPath)
      : importDir = p.join(docsPath, 'Music'),
        artDir = p.join(docsPath, 'art'),
        _libFile = File(p.join(docsPath, 'library.json')),
        _userFile = File(p.join(docsPath, 'user.json'));

  final String docsPath, importDir, artDir;
  final File _libFile, _userFile;

  List<Track> tracks = [];
  Map<String, Track> byPath = {};
  List<Album> albums = [];
  List<Artist> artists = [];
  Set<String> favorites = {};
  Map<String, int> playCounts = {};
  List<String> recent = []; // newest first
  bool scanning = false;
  String status = '';

  static Future<LibraryStore> load() async {
    final docs = await getApplicationDocumentsDirectory();
    final s = LibraryStore._(docs.path);
    Directory(s.importDir).createSync(recursive: true);
    Directory(s.artDir).createSync(recursive: true);
    await s._read();
    return s;
  }

  /// iOS exposes the Documents folder through Files, so scan it directly.
  List<String> get defaultRoots =>
      Platform.isIOS ? [docsPath] : [importDir];

  Future<void> _read() async {
    try {
      if (await _libFile.exists()) {
        final j = jsonDecode(await _libFile.readAsString()) as List;
        tracks = j
            .map((e) => Track.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      if (await _userFile.exists()) {
        final j = jsonDecode(await _userFile.readAsString()) as Map;
        favorites = Set<String>.from(j['fav'] as List? ?? const []);
        recent = List<String>.from(j['recent'] as List? ?? const []);
        playCounts = Map<String, int>.from(
            (j['counts'] as Map? ?? const {}).map((k, v) => MapEntry('$k', v as int)));
      }
    } catch (e) {
      Log.e('library', 'read failed; starting empty', e);
      tracks = [];
    }
    _index();
  }

  void _index() {
    byPath = {for (final t in tracks) t.path: t};
    int cmp(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());
    final al = <String, List<Track>>{};
    final ar = <String, List<Track>>{};
    for (final t in tracks) {
      (al['${t.album}\u0000${t.artist}'] ??= []).add(t);
      (ar[t.artist] ??= []).add(t);
    }
    albums = al.entries.map((e) {
      final l = e.value
        ..sort((a, b) => (a.trackNo ?? 999).compareTo(b.trackNo ?? 999) != 0
            ? (a.trackNo ?? 999).compareTo(b.trackNo ?? 999)
            : cmp(a.title, b.title));
      return Album(l.first.album, l.first.artist, l);
    }).toList()
      ..sort((a, b) => cmp(a.name, b.name));
    artists = ar.entries.map((e) => Artist(e.key, e.value)).toList()
      ..sort((a, b) => cmp(a.name, b.name));
  }

  Future<void> _saveLib() async {
    try {
      await _libFile
          .writeAsString(jsonEncode(tracks.map((t) => t.toJson()).toList()));
    } catch (e) {
      Log.e('library', 'save library failed', e);
    }
  }

  Future<void> _saveUser() async {
    try {
      await _userFile.writeAsString(jsonEncode(
          {'fav': favorites.toList(), 'recent': recent, 'counts': playCounts}));
    } catch (e) {
      Log.e('library', 'save user data failed', e);
    }
  }

  Future<void> scan(List<String> roots) async {
    if (scanning) return;
    scanning = true;
    status = 'Scanning…';
    notifyListeners();
    try {
      final r = await scanFolders(
          roots: roots, existing: byPath, artDir: artDir);
      tracks = r.tracks
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      _index();
      await _saveLib();
      status = '${tracks.length} tracks'
          '${r.failed > 0 ? ' · ${r.failed} unreadable' : ''}'
          '${r.unreachable.isNotEmpty ? ' · ${r.unreachable.length} folder(s) not accessible' : ''}';
      Log.i('library', status);
    } catch (e) {
      status = 'Scan failed: $e';
      Log.e('library', 'scan failed', e);
    }
    scanning = false;
    notifyListeners();
  }

  bool isFav(Track t) => favorites.contains(t.path);

  Future<void> toggleFav(Track t) async {
    if (!favorites.remove(t.path)) favorites.add(t.path);
    notifyListeners();
    await _saveUser();
  }

  Future<void> recordPlay(Track t) async {
    playCounts[t.path] = (playCounts[t.path] ?? 0) + 1;
    recent
      ..remove(t.path)
      ..insert(0, t.path);
    if (recent.length > 200) recent.removeRange(200, recent.length);
    notifyListeners();
    await _saveUser();
  }

  List<Track> get favoriteTracks =>
      tracks.where((t) => favorites.contains(t.path)).toList();

  List<Track> get recentTracks =>
      recent.map((p) => byPath[p]).whereType<Track>().toList();

  List<Track> get mostPlayed {
    final l = tracks.where((t) => (playCounts[t.path] ?? 0) > 0).toList()
      ..sort((a, b) => playCounts[b.path]!.compareTo(playCounts[a.path]!));
    return l.take(100).toList();
  }

  List<Track> search(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return tracks;
    return tracks
        .where((t) =>
            t.title.toLowerCase().contains(s) ||
            t.artist.toLowerCase().contains(s) ||
            t.album.toLowerCase().contains(s))
        .toList();
  }

  /// Same title + artist and duration within ~2 s.
  List<List<Track>> findDuplicates() {
    final m = <String, List<Track>>{};
    for (final t in tracks) {
      final k =
          '${t.title.toLowerCase().trim()}|${t.artist.toLowerCase().trim()}|${(t.durationMs / 2000).round()}';
      (m[k] ??= []).add(t);
    }
    return m.values.where((l) => l.length > 1).toList();
  }
}
