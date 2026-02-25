import 'package:aurora/features/chat/domain/message.dart';
import 'package:aurora/features/chat/domain/message_transformer.dart';
import 'package:aurora/features/chat/domain/transformers/protocol_tag_transformer.dart';
import 'package:aurora/features/chat/domain/ui_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProtocolTagTransformer', () {
    const transformer = ProtocolTagTransformer();
    const context = MessageTransformContext(
      language: 'en',
      model: null,
      providerName: 'test',
    );

    test('onGenerationFinish extracts <search> and strips it from text',
        () async {
      final msg = UiMessage.fromLegacy(
        Message.ai('Hello\n<search>kotlin ui message</search>'),
      );

      final transformed = transformer.onGenerationFinish(msg, context);

      expect(transformed.text, 'Hello');
      expect(transformed.firstSearchRequest?.query, 'kotlin ui message');
    });

    test('onGenerationFinish tolerates incomplete <search> tag', () async {
      final msg = UiMessage.fromLegacy(Message.ai('Hello\n<search>flutter'));

      final transformed = transformer.onGenerationFinish(msg, context);

      expect(transformed.text, 'Hello');
      expect(transformed.firstSearchRequest?.query, 'flutter');
    });

    test('onGenerationFinish extracts <skill> and strips it from text',
        () async {
      final msg = UiMessage.fromLegacy(
        Message.ai('OK\n<skill name="pdf">extract tables</skill>'),
      );

      final transformed = transformer.onGenerationFinish(msg, context);

      expect(transformed.text, 'OK');
      expect(transformed.firstSkillRequest?.skillName, 'pdf');
      expect(transformed.firstSkillRequest?.query, 'extract tables');
    });

    test('visualTransform hides tags but does not create request parts',
        () async {
      final msg = UiMessage.fromLegacy(Message.ai('Hi\n<search>query'));

      final transformed = transformer.visualTransform(msg, context);

      expect(transformed.text, 'Hi');
      expect(transformed.firstSearchRequest, isNull);
      expect(transformed.firstSkillRequest, isNull);
    });

    test('visualTransform does not trim messages without protocol tags',
        () async {
      final msg = UiMessage.fromLegacy(Message.ai('  hello  '));

      final transformed = transformer.visualTransform(msg, context);

      expect(transformed.text, '  hello  ');
    });
  });
}
