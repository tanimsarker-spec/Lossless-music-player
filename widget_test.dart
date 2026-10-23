import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lossless/core/branding.dart';
import 'package:lossless/core/theme.dart';

void main() {
  test('all three themes build', () {
    for (final m in LThemeMode.values) {
      expect(buildTheme(m).scaffoldBackgroundColor, isNotNull);
    }
    expect(buildTheme(LThemeMode.amoled).scaffoldBackgroundColor,
        LColors.trueBlack);
  });

  testWidgets('brand header shows LOSSLESS and the TanimSarker signature',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: BrandHeader())));
    expect(find.text('LOSSLESS'), findsOneWidget);
    expect(find.text('TanimSarker'), findsOneWidget);
  });
}
