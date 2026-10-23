import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../core/log.dart';
import '../core/settings.dart';
import '../library/library_store.dart';
import '../library/track.dart';
import 'dsp_engine.dart';
import 'replaygain.dart';
import 'sleep_timer.dart';

/// Playback core: gapless queue, background/lock-screen integration,
/// interruptions, ReplayGain, EQ, A-B repeat, sleep timer, queue persistence.
class LosslessAudioHandler extends BaseAudioHandler with SeekHandler {
  LosslessAudioHandler(this.settings) {
    final eq = Platform.isAndroid ? AndroidEqualizer() : null;
    _player = AudioPlayer(
      audioPipeline: AudioPipeline(androidAudioEffects: [if (eq != null) eq]),
    );
    dsp = DspEngine(eq);
    sleep = SleepTimer(
      onFade: (f) {
        _fade = f;
        _applyVolume();
      },
      onExpire: () => pause(),
    );
  }

  final Settings settings;
  late final AudioPlayer _player;
  late final DspEngine dsp;
  late final SleepTimer sleep;
  LibraryStore? _lib;

  ConcatenatingAudioSource? _source;
  List<Track> _tracks = [];
  double _rg = 1, _fade = 1, _duck = 1;
  Timer? _eqDebounce;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);
  String? _countedPath;

  final ValueNotifier<RgResult?> rgInfo = ValueNotifier(null);
  final ValueNotifier<Duration?> abA = ValueNotifier(null);
  final ValueNotifier<Duration?> abB = ValueNotifier(null);

  AudioPlayer get player => _player;
  List<Track> get tracks => List.unmodifiable(_tracks);
  Track? trackFor(String? path) {
    for (final t in _tracks) {
      if (t.path == path) return t;
    }
    return null;
  }

  Future<void> start(LibraryStore lib) async {
    _lib = lib;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _wireSession(session);
    } catch (e) {
      Log.w('audio', 'audio session unavailable on this platform: $e');
    }
    _wirePlayer();
    settings.addListener(_onSettings);
    await dsp.apply(settings.eq);
    await _restore();
  }

  // ------------------------------------------------------------- wiring
  void _wireSession(AudioSession session) {
    session.becomingNoisyEventStream.listen((_) {
      Log.i('audio', 'output became noisy (unplugged); pausing');
      pause();
    });
    var resumeAfter = false;
    session.interruptionEventStream.listen((e) {
      if (e.begin) {
        if (e.type == AudioInterruptionType.duck) {
          _duck = 0.3;
          _applyVolume();
        } else {
          resumeAfter = _player.playing;
          _player.pause();
        }
      } else {
        if (e.type == AudioInterruptionType.duck) {
          _duck = 1;
          _applyVolume();
        } else if (resumeAfter) {
          _player.play();
          resumeAfter = false;
        }
      }
    });
  }

  void _wirePlayer() {
    _player.playbackEventStream.listen(
      (e) => playbackState.add(_toState(e)),
      onError: (Object err, StackTrace st) {
        Log.e('audio', 'playback error', err);
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
          errorMessage: 'Could not play this file. Skipping.',
        ));
        if (_player.hasNext) {
          _player.seekToNext();
        }
      },
    );
    _player.currentIndexStream.listen((i) {
      if (i == null || i >= _tracks.length) return;
      final t = _tracks[i];
      _countedPath = null;
      abA.value = null;
      abB.value = null;
      mediaItem.add(_item(t));
      _applyReplayGain();
      _saveSession(force: true);
    });
    _player.positionStream.listen((pos) {
      final a = abA.value, b = abB.value;
      if (a != null && b != null && pos >= b) _player.seek(a);
      final i = _player.currentIndex;
      if (_player.playing &&
          i != null &&
          i < _tracks.length &&
          pos.inSeconds >= 10 &&
          _countedPath != _tracks[i].path) {
        _countedPath = _tracks[i].path;
        _lib?.recordPlay(_tracks[i]);
      }
      _saveSession();
    });
    _player.playingStream.listen((playing) {
      if (!playing) _saveSession(force: true);
    });
  }

  void _onSettings() {
    _applyReplayGain();
    _eqDebounce?.cancel();
    _eqDebounce =
        Timer(const Duration(milliseconds: 40), () => dsp.apply(settings.eq));
  }

  PlaybackState _toState(PlaybackEvent e) => PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (_player.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: e.currentIndex,
        repeatMode: const {
          LoopMode.off: AudioServiceRepeatMode.none,
          LoopMode.one: AudioServiceRepeatMode.one,
          LoopMode.all: AudioServiceRepeatMode.all,
        }[_player.loopMode]!,
        shuffleMode: _player.shuffleModeEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
      );

  MediaItem _item(Track t) => MediaItem(
        id: t.path,
        title: t.title,
        artist: t.artist,
        album: t.album,
        genre: t.genre.isEmpty ? null : t.genre,
        duration: t.durationMs > 0 ? t.duration : null,
        artUri: t.coverPath != null ? Uri.file(t.coverPath!) : null,
      );

  void _publishQueue() => queue.add(_tracks.map(_item).toList());

  // ------------------------------------------------------- volume / RG
  void _applyReplayGain() {
    final i = _player.currentIndex;
    final t = (i != null && i < _tracks.length) ? _tracks[i] : null;
    final r = t == null
        ? null
        : computeReplayGain(
            mode: settings.rgMode,
            trackGain: t.rgTrackGain,
            albumGain: t.rgAlbumGain,
            trackPeak: t.rgTrackPeak,
            albumPeak: t.rgAlbumPeak,
            preampDb: settings.rgPreamp,
            preventClipping: settings.preventClipping,
          );
    _rg = r?.volume ?? 1;
    rgInfo.value = r;
    _applyVolume();
  }

  void _applyVolume() => _player.setVolume((_rg * _fade * _duck).clamp(0.0, 1.0));

  // ------------------------------------------------------------ queue
  /// Replaces the queue. Missing files are skipped; decode failures surface
  /// as a playback error without crashing the queue.
  Future<void> playTracks(List<Track> list,
      {int index = 0, bool autoplay = true, Duration? position}) async {
    final usable = <Track>[];
    var start = 0;
    for (var i = 0; i < list.length; i++) {
      if (File(list[i].path).existsSync()) {
        if (i == index) start = usable.length;
        usable.add(list[i]);
      } else {
        Log.w('queue', 'missing file skipped: ${list[i].path}');
      }
    }
    if (usable.isEmpty) {
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        errorMessage: 'Files are missing. Rescan your library.',
      ));
      return;
    }
    _tracks = usable;
    _publishQueue();
    _source = ConcatenatingAudioSource(
      useLazyPreparation: true,
      children: usable.map((t) => AudioSource.file(t.path)).toList(),
    );
    try {
      await _player.setAudioSource(_source!,
          initialIndex: start, initialPosition: position);
      if (autoplay) unawaited(_player.play());
    } on PlayerException catch (e) {
      Log.e('audio', 'setAudioSource failed', e);
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        errorMessage: e.message ?? 'Unsupported or corrupt file',
      ));
    }
  }

  Future<void> playNext(Track t) async {
    if (_source == null) return playTracks([t]);
    final at = (_player.currentIndex ?? -1) + 1;
    await _source!.insert(at, AudioSource.file(t.path));
    _tracks.insert(at, t);
    _publishQueue();
    _saveSession(force: true);
  }

  Future<void> addToQueue(Track t) async {
    if (_source == null) return playTracks([t]);
    await _source!.add(AudioSource.file(t.path));
    _tracks.add(t);
    _publishQueue();
    _saveSession(force: true);
  }

  Future<void> moveQueueItem(int from, int to) async {
    if (_source == null || from == to) return;
    await _source!.move(from, to);
    final t = _tracks.removeAt(from);
    _tracks.insert(to, t);
    _publishQueue();
    _saveSession(force: true);
  }

  Future<void> removeQueueItem(int i) async {
    if (_source == null || _tracks.length <= 1) return;
    await _source!.removeAt(i);
    _tracks.removeAt(i);
    _publishQueue();
    _saveSession(force: true);
  }

  // ------------------------------------------------------- persistence
  void _saveSession({bool force = false}) {
    final now = DateTime.now();
    if (!force && now.difference(_lastSave).inSeconds < 10) return;
    if (_tracks.isEmpty) return;
    _lastSave = now;
    final p = settings.prefs;
    p.setStringList('q.paths', _tracks.map((t) => t.path).toList());
    p.setInt('q.index', _player.currentIndex ?? 0);
    p.setInt('q.pos', _player.position.inMilliseconds);
  }

  Future<void> _restore() async {
    final lib = _lib;
    if (lib == null) return;
    try {
      final paths = settings.prefs.getStringList('q.paths');
      if (paths == null || paths.isEmpty) return;
      final list = paths.map((p) => lib.byPath[p]).whereType<Track>().toList();
      if (list.isEmpty) return;
      await playTracks(list,
          index: (settings.prefs.getInt('q.index') ?? 0).clamp(0, list.length - 1),
          autoplay: false,
          position: Duration(milliseconds: settings.prefs.getInt('q.pos') ?? 0));
      Log.i('queue', 'restored ${list.length} tracks');
    } catch (e) {
      Log.e('queue', 'restore failed', e);
    }
  }

  // ----------------------------------------------------------- A-B loop
  void setLoopA() => abA.value = _player.position;
  void setLoopB() {
    final a = abA.value;
    if (a == null || _player.position <= a) return;
    abB.value = _player.position;
  }

  void clearLoop() {
    abA.value = null;
    abB.value = null;
  }

  // ---------------------------------------------------- BaseAudioHandler
  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> skipToNext() => _player.seekToNext();
  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();
  @override
  Future<void> skipToQueueItem(int index) =>
      _player.seek(Duration.zero, index: index);
  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode m) async {
    final on = m == AudioServiceShuffleMode.all ||
        m == AudioServiceShuffleMode.group;
    if (on) await _player.shuffle();
    await _player.setShuffleModeEnabled(on);
    playbackState.add(playbackState.value.copyWith(shuffleMode: m));
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode m) async {
    await _player.setLoopMode(const {
      AudioServiceRepeatMode.none: LoopMode.off,
      AudioServiceRepeatMode.one: LoopMode.one,
      AudioServiceRepeatMode.all: LoopMode.all,
      AudioServiceRepeatMode.group: LoopMode.all,
    }[m]!);
    playbackState.add(playbackState.value.copyWith(repeatMode: m));
  }

  @override
  Future<void> stop() async {
    _saveSession(force: true);
    await _player.stop();
    return super.stop();
  }
}
