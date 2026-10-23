import 'package:flutter_test/flutter_test.dart';
import 'package:lossless/lyrics/lrc.dart';

void main() {
  test('parses synced lyrics and sorts them', () {
    final l = parseLyrics('[ar:X]\n[00:12.50]Second\n[00:01.00]First')!;
    expect(l.synced, isTrue);
    expect(l.lines.first.text, 'First');
    expect(l.lines.last.time, const Duration(seconds: 12, milliseconds: 500));
  });

  test('multiple timestamps on one line', () {
    final l = parseLyrics('[00:10.00][00:20.00]Chorus')!;
    expect(l.lines.length, 2);
  });

  test('offset tag shifts timing', () {
    final l = parseLyrics('[offset:500]\n[00:02.00]Hi')!;
    expect(l.lines.first.time, const Duration(milliseconds: 1500));
  });

  test('plain text is not given invented timestamps', () {
    final l = parseLyrics('Just words\nno times')!;
    expect(l.synced, isFalse);
    expect(l.plain, contains('Just words'));
  });

  test('empty input returns null', () {
    expect(parseLyrics('   \n'), isNull);
  });

  test('indexAt finds the current line', () {
    final l = parseLyrics('[00:01.00]a\n[00:05.00]b\n[00:09.00]c')!;
    expect(lyricIndexAt(l.lines, Duration.zero), -1);
    expect(lyricIndexAt(l.lines, const Duration(seconds: 5)), 1);
    expect(lyricIndexAt(l.lines, const Duration(seconds: 100)), 2);
  });
}
