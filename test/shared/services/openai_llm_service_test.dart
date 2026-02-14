import 'package:flutter_test/flutter_test.dart';
import 'package:aurora/features/chat/domain/message.dart';
import 'package:aurora/features/settings/presentation/settings_provider.dart';
import 'package:aurora/shared/services/openai_llm_service.dart';

void main() {
  group('OpenAILLMService', () {
    test('returns missing model message when model is not configured',
        () async {
      final settings = SettingsState(
        providers: [
          ProviderConfig(
            id: 'openai',
            name: 'OpenAI',
            apiKeys: const ['test-key'],
            selectedModel: null,
          ),
        ],
        activeProviderId: 'openai',
        viewingProviderId: 'openai',
        language: 'en',
      );
      final service = OpenAILLMService(settings);

      final response = await service.getResponse([Message.user('hello')]);

      expect(response.content, contains('no model selected'));
    });

    test('returns empty API key message before sending request', () async {
      final settings = SettingsState(
        providers: [
          ProviderConfig(
            id: 'openai',
            name: 'OpenAI',
            apiKeys: const [],
            selectedModel: 'gpt-4.1',
          ),
        ],
        activeProviderId: 'openai',
        viewingProviderId: 'openai',
        language: 'en',
      );
      final service = OpenAILLMService(settings);

      final response = await service.getResponse([Message.user('hello')]);

      expect(response.content, contains('API key is empty'));
    });
  });
}
