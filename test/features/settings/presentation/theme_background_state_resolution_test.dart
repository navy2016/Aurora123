import 'dart:io';

import 'package:aurora/features/settings/presentation/settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveThemeBackgroundState', () {
    test('falls back when custom mode is enabled but background path is missing',
        () {
      const missingPath = '/path/does/not/exist/background.png';

      final resolved = resolveThemeBackgroundState(
        themeMode: 'custom',
        useCustomTheme: true,
        backgroundImagePath: missingPath,
      );

      expect(resolved.themeMode, 'system');
      expect(resolved.useCustomTheme, isFalse);
      expect(resolved.backgroundImagePath, isNull);
    });

    test('keeps explicit light mode when background path is missing', () {
      const missingPath = '/path/does/not/exist/background.png';

      final resolved = resolveThemeBackgroundState(
        themeMode: 'light',
        useCustomTheme: false,
        backgroundImagePath: missingPath,
      );

      expect(resolved.themeMode, 'light');
      expect(resolved.useCustomTheme, isFalse);
      expect(resolved.backgroundImagePath, isNull);
    });

    test('keeps custom mode when background file exists', () {
      final tempDir = Directory.systemTemp.createTempSync('aurora_theme_test_');
      final tempFile = File('${tempDir.path}${Platform.pathSeparator}bg.png')
        ..writeAsBytesSync(<int>[0x89, 0x50, 0x4E, 0x47]);

      try {
        final resolved = resolveThemeBackgroundState(
          themeMode: 'custom',
          useCustomTheme: true,
          backgroundImagePath: tempFile.path,
        );

        expect(resolved.themeMode, 'custom');
        expect(resolved.useCustomTheme, isTrue);
        expect(resolved.backgroundImagePath, tempFile.path);
      } finally {
        if (tempFile.existsSync()) {
          tempFile.deleteSync();
        }
        if (tempDir.existsSync()) {
          tempDir.deleteSync();
        }
      }
    });
  });
}
