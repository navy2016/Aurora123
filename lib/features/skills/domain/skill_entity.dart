class Skill {
  final String id;
  final String name;
  final String description;
  final String instructions;
  final List<SkillTool> tools;
  final Map<String, dynamic> metadata;
  final String path;
  final bool isEnabled;
  final bool isLocked;
  final bool forAI;
  final List<String> platforms;

  const Skill({
    required this.id,
    required this.name,
    required this.description,
    required this.instructions,
    this.tools = const [],
    this.metadata = const {},
    required this.path,
    this.isEnabled = true,
    this.isLocked = false,
    this.forAI = true,
    this.platforms = const ['all'],
  });

  Skill copyWith({
    String? id,
    String? name,
    String? description,
    String? instructions,
    List<SkillTool>? tools,
    Map<String, dynamic>? metadata,
    String? path,
    bool? isEnabled,
    bool? isLocked,
    bool? forAI,
    List<String>? platforms,
  }) {
    return Skill(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      instructions: instructions ?? this.instructions,
      tools: tools ?? this.tools,
      metadata: metadata ?? this.metadata,
      path: path ?? this.path,
      isEnabled: isEnabled ?? this.isEnabled,
      isLocked: isLocked ?? this.isLocked,
      forAI: forAI ?? this.forAI,
      platforms: platforms ?? this.platforms,
    );
  }

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      instructions: json['instructions'] as String,
      tools: (json['tools'] as List<dynamic>?)
              ?.map((e) => SkillTool.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
      path: json['path'] as String,
      isEnabled: json['isEnabled'] as bool? ?? true,
      isLocked: json['isLocked'] as bool? ?? false,
      forAI: json['forAI'] as bool? ?? true,
      platforms: (json['platforms'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['all'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'instructions': instructions,
      'tools': tools.map((e) => e.toJson()).toList(),
      'metadata': metadata,
      'path': path,
      'isEnabled': isEnabled,
      'isLocked': isLocked,
      'forAI': forAI,
      'platforms': platforms,
    };
  }

  bool isCompatible(String currentPlatform) {
    if (platforms.contains('all') || platforms.isEmpty) return true;
    final normalized = currentPlatform.toLowerCase();
    if (platforms.contains(normalized)) return true;

    if (platforms.contains('desktop') &&
        const ['windows', 'macos', 'linux'].contains(normalized)) {
      return true;
    }
    if (platforms.contains('mobile') &&
        const ['android', 'ios'].contains(normalized)) {
      return true;
    }

    return false;
  }
}

class SkillTool {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
  final String type; // 'shell', 'api', etc.
  final String command; // The script or endpoint
  final Map<String, dynamic>
      extra; // Extra fields from YAML (method, headers, etc.)
  final List<Map<String, dynamic>> inputExamples; // Examples for the tool

  const SkillTool({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.type,
    required this.command,
    this.extra = const {},
    this.inputExamples = const [],
  });

  factory SkillTool.fromJson(Map<String, dynamic> json) {
    return SkillTool(
      name: json['name'] as String,
      description: json['description'] as String,
      inputSchema: json['inputSchema'] as Map<String, dynamic>,
      type: json['type'] as String,
      command: json['command'] as String,
      extra: json['extra'] as Map<String, dynamic>? ?? const {},
      inputExamples: (json['inputExamples'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'inputSchema': inputSchema,
      'type': type,
      'command': command,
      'extra': extra,
      'inputExamples': inputExamples,
    };
  }
}
