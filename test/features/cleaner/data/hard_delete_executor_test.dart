import 'dart:io';

import 'package:aurora/features/cleaner/data/hard_delete_executor.dart';
import 'package:aurora/features/cleaner/domain/cleaner_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CleanerHardDeleteExecutor', () {
    test('deletes file directly without trash path', () async {
      final tempDir = await Directory.systemTemp.createTemp('aurora_cleaner_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final source = File('${tempDir.path}${Platform.pathSeparator}sample.tmp');
      const payloadSize = 64;
      await source.writeAsBytes(List<int>.filled(payloadSize, 1));

      final candidate = CleanerCandidate(
        id: 'candidate-1',
        path: source.path,
        sizeBytes: payloadSize,
        modifiedAt: DateTime.now().toUtc(),
        accessedAt: DateTime.now().toUtc(),
        kind: CleanerCandidateKind.temporary,
        recoverable: true,
        isProtected: false,
        source: 'test',
      );

      const executor = CleanerHardDeleteExecutor();
      final batch = await executor.softDelete([candidate]);

      expect(await source.exists(), isFalse);
      expect(batch.results, hasLength(1));
      expect(batch.results.single.success, isTrue);
      expect(batch.results.single.trashPath, isNull);
      expect(batch.results.single.freedBytes, payloadSize);
      expect(batch.totalFreedBytes, payloadSize);
    });

    test('returns failed item result when source file is missing', () async {
      final tempDir = await Directory.systemTemp.createTemp('aurora_cleaner_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final missingPath =
          '${tempDir.path}${Platform.pathSeparator}missing-file.tmp';
      final candidate = CleanerCandidate(
        id: 'candidate-2',
        path: missingPath,
        sizeBytes: 42,
        modifiedAt: DateTime.now().toUtc(),
        accessedAt: DateTime.now().toUtc(),
        kind: CleanerCandidateKind.temporary,
        recoverable: true,
        isProtected: false,
        source: 'test',
      );

      const executor = CleanerHardDeleteExecutor();
      final batch = await executor.softDelete([candidate]);

      expect(batch.results, hasLength(1));
      expect(batch.results.single.success, isFalse);
      expect(batch.results.single.trashPath, isNull);
      expect(batch.results.single.freedBytes, 0);
      expect(batch.totalFreedBytes, 0);
      expect(batch.results.single.error, contains('File does not exist'));
    });
  });
}
