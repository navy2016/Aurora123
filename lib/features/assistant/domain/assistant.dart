class Assistant {
  final String id;
  final String name;
  final String? avatar;
  final String description;
  final String systemPrompt;
  final String? preferredModel;
  final String? providerId;
  final List<String> skillIds;
  final bool enableMemory;

  const Assistant({
    required this.id,
    required this.name,
    this.avatar,
    this.description = '',
    this.systemPrompt = '',
    this.preferredModel,
    this.providerId,
    this.skillIds = const [],
    this.enableMemory = false,
  });

  Assistant copyWith({
    String? name,
    String? avatar,
    String? description,
    String? systemPrompt,
    String? preferredModel,
    String? providerId,
    List<String>? skillIds,
    bool? enableMemory,
  }) {
    return Assistant(
      id: id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      description: description ?? this.description,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      preferredModel: preferredModel ?? this.preferredModel,
      providerId: providerId ?? this.providerId,
      skillIds: skillIds ?? this.skillIds,
      enableMemory: enableMemory ?? this.enableMemory,
    );
  }
}
