import 'dart:convert';
import 'dart:io';
import 'package:aurora/features/chat/domain/message.dart';
import 'package:aurora/shared/services/llm_service.dart';
import 'package:aurora/features/skills/domain/skill_entity.dart';
import 'package:aurora/features/settings/presentation/settings_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:aurora/shared/utils/platform_utils.dart';

class WorkerService {
  final LLMService _llmService;

  WorkerService(this._llmService);

  Future<String> executeSkillTask(Skill skill, String skillQuery, {String? originalRequest, String? model, String? providerId}) async {
    final systemPrompt = '''
# You are the Technical Executor for: ${skill.name}
Your ONLY task is to look at the Manual and output the correct shell command to fulfill the request.

## Manual
${skill.instructions}

## Context
- **Routing Intent**: $skillQuery
- **Original User Request**: ${originalRequest ?? 'Not provided'}

## Strict Rules
1. **No Chitchat**: Only output tool calls or direct answers.
2. **Follow Examples**: Use the exact format and parameter conventions (e.g., English city names) shown in the Manual.
3. **No Summary**: Do NOT summarize the result. Return the raw data or tool output.
''';

    final messages = [
      Message(
        id: const Uuid().v4(),
        role: 'system',
        content: systemPrompt,
        timestamp: DateTime.now(),
        isUser: false,
      ),
      Message(
        id: const Uuid().v4(),
        role: 'user',
        content: skillQuery,
        timestamp: DateTime.now(),
        isUser: true,
      ),
    ];

    final workerTools = [
      {
        'type': 'function',
        'function': {
          'name': 'run_shell',
          'description': 'Execute a shell command as per the manual.',
          'parameters': {
            'type': 'object',
            'required': ['command'],
            'properties': {
              'command': {
                'type': 'string',
                'description': 'The exact command to execute.',
              },
            },
          },
        },
      }
    ];

    try {
      final response = await _llmService.getResponse(
        messages,
        tools: workerTools,
        model: model,
        providerId: providerId,
      );

      if (response.toolCalls != null && response.toolCalls!.isNotEmpty) {
        final tc = response.toolCalls!.first;
        if (tc.name == 'run_shell') {
           try {
              final args = jsonDecode(tc.arguments ?? '{}');
              final command = args['command']?.toString();
              if (command != null) {
                return await _executeShellCommand(command);
              }
           } catch (e) {
              return "Worker Error: Failed to parse tool arguments.";
           }
        }
      }
      
      return response.content ?? "Worker: No action performed.";
    } catch (e) {
      return "Worker Critical Error: $e";
    }
  }

  Future<String> _executeShellCommand(String command) async {
    try {
        ProcessResult result;

        if (PlatformUtils.isWindows) {
          result = await Process.run('powershell.exe', ['-NoProfile', '-Command', command]);
        } else {
          result = await Process.run('sh', ['-c', command], runInShell: true);
        }
        
        return jsonEncode({
          'stdout': result.stdout.toString(),
          'stderr': result.stderr.toString(),
          'exitCode': result.exitCode,
        });
    } catch (e) {
      return jsonEncode({'error': e.toString()});
    }
  }
}
