import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'novel_state.dart';
import 'package:aurora/features/chat/domain/message.dart';
import 'package:aurora/shared/services/openai_llm_service.dart';
import 'package:aurora/features/settings/presentation/settings_provider.dart';

final novelProvider = StateNotifierProvider<NovelNotifier, NovelWritingState>((ref) {
  return NovelNotifier(ref);
});

// Preset prompts for model roles
class NovelPromptPresets {
  // 拆解模型：将用户需求/大纲拆解为章节列表
  static const String decompose = '''你是一个小说章节规划助手。用户会给你一个故事需求或粗略大纲，你需要将其拆解为章节列表。

请以JSON数组格式返回章节列表，每个章节是一个对象，包含标题和简述：
[
  {"title": "第一章 标题", "description": "本章简述..."},
  {"title": "第二章 标题", "description": "本章简述..."}
]

要求：
- 每个章节应该是一个完整的故事单元
- 章节标题要吸引人
- 简述要包含本章的核心事件和情感走向
- 只返回JSON数组，不要有其他内容''';

  // 写作模型：根据章节要求写完整章节
  static const String writer = '''你是一个专业的小说作家。请根据给定的章节要求，写出完整的章节正文。

要求：
- 文笔流畅，描写生动
- 情节合理，人物丰满
- 注意上下文连贯性，承接前文内容
- 对话自然，符合人物性格
- 每章字数在2000-5000字左右
- 只输出正文内容，不要输出章节标题或其他元信息''';

  // 审查模型：审查章节质量
  static const String reviewer = '''你是一个严格的小说编辑。请审查以下章节内容是否符合要求。

审查标准：
1. 文字质量：是否有错别字、语病
2. 情节合理性：是否有逻辑漏洞
3. 人物一致性：角色行为是否符合设定
4. 完整性：是否完成了章节要求
5. 连贯性：与前文是否衔接自然

请返回JSON格式的审查结果：
{
  "approved": true/false,
  "issues": ["问题1", "问题2"],
  "suggestions": "改进建议"
}

只返回JSON，不要有其他内容。''';

  // 大纲模型：生成故事大纲
  static const String outline = '''你是一个小说大纲规划师。请根据用户的故事需求，创建详细的小说大纲。

大纲应包括：
- 故事背景设定（世界观、时代背景）
- 主要人物介绍（姓名、性格、关系）
- 核心冲突和主线剧情
- 重要转折点
- 结局走向

请用清晰的结构化格式输出。''';

  // 上下文提取模型：从章节内容中提取设定变化
  static const String contextExtractor = '''你是一个小说分析助手。请从以下章节内容中提取关键信息的变化。

请返回JSON格式：
{
  "newCharacters": {"角色名": "描述"},
  "updatedRelationships": {"关系key": "关系描述"},
  "newLocations": {"地点名": "描述"},
  "newForeshadowing": ["伏笔1", "伏笔2"],
  "resolvedForeshadowing": ["已解决的伏笔"]
}

只返回JSON，不要有其他内容。如果没有变化，返回空对象。''';
}

class NovelNotifier extends StateNotifier<NovelWritingState> {
  final Ref _ref;
  bool _shouldStop = false;
  
  NovelNotifier(this._ref) : super(const NovelWritingState()) {
    _loadState();
  }

  Future<File> get _stateFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/novel_writing_state.json');
  }

  Future<void> _loadState() async {
    try {
      final file = await _stateFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        state = NovelWritingState.fromJson(json);
      }
    } catch (e) {
      // Ignore load errors, start with empty state
    }
  }

  Future<void> _saveState() async {
    try {
      final file = await _stateFile;
      final json = state.toJson();
      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      // Ignore save errors
    }
  }

  // ========== LLM Call Helper ==========
  Future<String> _callLLM(NovelModelConfig config, String systemPrompt, String userMessage) async {
    final settings = _ref.read(settingsProvider);
    
    // Find the provider config
    final provider = settings.providers.firstWhere(
      (p) => p.id == config.providerId,
      orElse: () => settings.activeProvider,
    );
    
    // Create a temporary settings state with the selected model
    final tempSettings = settings.copyWith(
      activeProviderId: provider.id,
    );
    
    // Update the provider's selected model temporarily
    final updatedProvider = provider.copyWith(selectedModel: config.modelId);
    final updatedProviders = tempSettings.providers.map((p) {
      return p.id == updatedProvider.id ? updatedProvider : p;
    }).toList();
    
    final finalSettings = tempSettings.copyWith(providers: updatedProviders);
    
    final llmService = OpenAILLMService(finalSettings);
    
    final messages = [
      Message(
        id: const Uuid().v4(),
        content: systemPrompt,
        isUser: false,
        timestamp: DateTime.now(),
        role: 'system',
      ),
      Message.user(userMessage),
    ];
    
    final response = await llmService.getResponse(messages);
    return response.content ?? '';
  }

  // ========== Workflow Engine ==========
  Future<void> runWorkflow() async {
    if (state.isRunning) return;
    _shouldStop = false;
    state = state.copyWith(isRunning: true, isPaused: false);
    _saveState();
    
    await _processTaskQueue();
  }
  
  Future<void> _processTaskQueue() async {
    while (!_shouldStop && mounted) {
      // Find next pending task for current project
      final pendingTask = state.allTasks.firstWhere(
        (t) => t.status == TaskStatus.pending && _isTaskInCurrentProject(t),
        orElse: () => NovelTask(id: '', chapterId: '', description: ''),
      );
      
      if (pendingTask.id.isEmpty) {
        // No more pending tasks
        state = state.copyWith(isRunning: false);
        _saveState();
        return;
      }
      
      // Check if paused
      while (state.isPaused && !_shouldStop) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      if (_shouldStop) break;
      
      // Execute the task
      await _executeTask(pendingTask.id);
    }
    
    state = state.copyWith(isRunning: false);
    _saveState();
  }
  
  bool _isTaskInCurrentProject(NovelTask task) {
    if (state.selectedProject == null) return false;
    return state.selectedProject!.chapters.any((c) => c.id == task.chapterId);
  }
  
  Future<void> _executeTask(String taskId) async {
    // Mark task as running
    _updateTaskStatus(taskId, TaskStatus.running);
    
    final task = state.allTasks.firstWhere((t) => t.id == taskId);
    
    try {
      // Use writer model to execute the task
      final writerConfig = state.writerModel;
      if (writerConfig == null) {
        throw Exception('Writer model not configured');
      }
      
      final systemPrompt = writerConfig.systemPrompt.isNotEmpty 
          ? writerConfig.systemPrompt 
          : NovelPromptPresets.writer;
      
      // Build context from all chapters in the project (outlines only, not full content)
      final allChapters = state.selectedProject?.chapters ?? [];
      final currentChapterIndex = allChapters.indexWhere((c) => c.id == task.chapterId);
      
      // Get chapter title for context
      final chapter = currentChapterIndex >= 0 ? allChapters[currentChapterIndex] : null;
      final chapterTitle = chapter?.title ?? '未知章节';
      final projectName = state.selectedProject?.name ?? '未知项目';
      
      final StringBuffer contextBuffer = StringBuffer();
      
      // Add project info
      contextBuffer.writeln('【项目】$projectName');
      contextBuffer.writeln();
      
      // Add world context (dynamic settings)
      final worldContextStr = state.selectedProject?.worldContext.toPromptString() ?? '';
      if (worldContextStr.isNotEmpty) {
        contextBuffer.writeln(worldContextStr);
      }
      
      // Add outline of all chapters (descriptions only, not full content)
      if (allChapters.length > 1) {
        contextBuffer.writeln('【全书大纲】');
        for (int i = 0; i < allChapters.length; i++) {
          final c = allChapters[i];
          final tasks = state.tasksForChapter(c.id);
          final taskDesc = tasks.isNotEmpty ? tasks.first.description : '';
          final marker = c.id == task.chapterId ? '→' : ' ';
          contextBuffer.writeln('$marker ${c.title}: $taskDesc');
        }
        contextBuffer.writeln();
      }
      
      // Add current chapter info
      contextBuffer.writeln('【当前章节】$chapterTitle');
      contextBuffer.writeln();
      
      // Add current task requirement
      contextBuffer.writeln('【本章要求】');
      contextBuffer.writeln(task.description);
      contextBuffer.writeln();
      contextBuffer.writeln('请根据以上大纲和本章要求，写出本章完整正文（2000-5000字）。');
      
      final String fullPrompt = contextBuffer.toString();
      
      final result = await _callLLM(writerConfig, systemPrompt, fullPrompt);
      
      // Update task with content
      final updatedTasks = state.allTasks.map((t) {
        if (t.id == taskId) {
          return t.copyWith(content: result, status: state.isReviewEnabled ? TaskStatus.reviewing : TaskStatus.success);
        }
        return t;
      }).toList();
      state = state.copyWith(allTasks: updatedTasks);
      _saveState();
      
      // Auto-extract context updates from the generated content
      if (!state.isReviewEnabled) {
        _extractContextUpdates(result);
      }
      
      // If review is enabled, run the review
      if (state.isReviewEnabled && !_shouldStop) {
        await _reviewTask(taskId, result);
      }
      
    } catch (e) {
      _updateTaskStatus(taskId, TaskStatus.failed);
      // Store error in reviewFeedback field
      final updatedTasks = state.allTasks.map((t) {
        if (t.id == taskId) {
          return t.copyWith(reviewFeedback: 'Error: $e');
        }
        return t;
      }).toList();
      state = state.copyWith(allTasks: updatedTasks);
      _saveState();
    }
  }

  String exportChapterContent(String chapterId) {
    final tasks = state.tasksForChapter(chapterId);
    final buffer = StringBuffer();
    
    // Find chapter title
    final chapter = state.selectedProject?.chapters.firstWhere(
      (c) => c.id == chapterId,
      orElse: () => NovelChapter(id: '', title: 'Unknown Chapter', order: 0),
    );
    
    if (chapter != null) {
      buffer.writeln('# ${chapter.title}');
      buffer.writeln();
    }
    
    for (final task in tasks) {
      if (task.status == TaskStatus.success && task.content != null) {
        buffer.writeln(task.content);
        buffer.writeln();
      }
    }
    
    return buffer.toString();
  }
  
  Future<void> _reviewTask(String taskId, String content) async {
    final reviewerConfig = state.reviewerModel;
    if (reviewerConfig == null) {
      // No reviewer configured, auto-approve
      _updateTaskStatus(taskId, TaskStatus.success);
      return;
    }
    
    final task = state.allTasks.firstWhere((t) => t.id == taskId);
    
    try {
      final systemPrompt = reviewerConfig.systemPrompt.isNotEmpty 
          ? reviewerConfig.systemPrompt 
          : NovelPromptPresets.reviewer;
      
      final reviewPrompt = '''
任务描述: ${task.description}

生成的内容:
$content

请审查以上内容。''';
      
      final reviewResult = await _callLLM(reviewerConfig, systemPrompt, reviewPrompt);
      
      // Try to parse review result
      try {
        final reviewJson = jsonDecode(reviewResult) as Map<String, dynamic>;
        final approved = reviewJson['approved'] as bool? ?? true;
        
        final updatedTasks = state.allTasks.map((t) {
          if (t.id == taskId) {
            return t.copyWith(
              status: approved ? TaskStatus.success : TaskStatus.reviewing,
              reviewFeedback: reviewResult,
            );
          }
          return t;
        }).toList();
        state = state.copyWith(allTasks: updatedTasks);
        _saveState();
        
      } catch (e) {
        // Review result is not valid JSON, treat as approved
        _updateTaskStatus(taskId, TaskStatus.success);
      }
      
    } catch (e) {
      // Review failed, but still mark task as needing attention
      final updatedTasks = state.allTasks.map((t) {
        if (t.id == taskId) {
          return t.copyWith(reviewFeedback: 'Review error: $e');
        }
        return t;
      }).toList();
      state = state.copyWith(allTasks: updatedTasks);
      _saveState();
    }
  }
  
  void _updateTaskStatus(String taskId, TaskStatus status) {
    final updatedTasks = state.allTasks.map((t) {
      return t.id == taskId ? t.copyWith(status: status) : t;
    }).toList();
    state = state.copyWith(allTasks: updatedTasks);
    _saveState();
  }

  // ========== Project Management ==========
  void createProject(String name) {
    final project = NovelProject.create(name);
    state = state.copyWith(
      projects: [...state.projects, project],
      selectedProjectId: project.id,
      selectedChapterId: project.chapters.isNotEmpty ? project.chapters.first.id : null,
    );
    _saveState();
  }

  void selectProject(String projectId) {
    final project = state.projects.firstWhere((p) => p.id == projectId);
    state = state.copyWith(
      selectedProjectId: projectId,
      selectedChapterId: project.chapters.isNotEmpty ? project.chapters.first.id : null,
      selectedTaskId: null,
    );
    _saveState();
  }

  void deleteProject(String projectId) {
    final updatedProjects = state.projects.where((p) => p.id != projectId).toList();
    final project = state.projects.firstWhere((p) => p.id == projectId);
    final updatedTasks = state.allTasks.where((t) {
      return !project.chapters.any((c) => c.id == t.chapterId);
    }).toList();
    
    state = state.copyWith(
      projects: updatedProjects,
      allTasks: updatedTasks,
      selectedProjectId: updatedProjects.isNotEmpty ? updatedProjects.first.id : null,
      selectedChapterId: null,
      selectedTaskId: null,
    );
    _saveState();
  }

  // ========== Outline Management ==========
  Future<void> generateOutline(String requirement) async {
    if (state.selectedProject == null) return;
    
    final outlineConfig = state.outlineModel;
    
    if (outlineConfig == null) {
      // Fallback: use requirement as outline directly
      _updateProjectOutline('【故事需求】\n$requirement\n\n（请编辑此大纲后点击"生成章节"）');
      return;
    }
    
    try {
      final systemPrompt = outlineConfig.systemPrompt.isNotEmpty 
          ? outlineConfig.systemPrompt 
          : NovelPromptPresets.outline;
      
      final result = await _callLLM(outlineConfig, systemPrompt, requirement);
      _updateProjectOutline(result);
      
    } catch (e) {
      _updateProjectOutline('生成大纲失败：$e\n\n原始需求：\n$requirement');
    }
  }

  void _updateProjectOutline(String outline) {
    if (state.selectedProject == null) return;
    
    final updatedProject = state.selectedProject!.copyWith(outline: outline);
    final updatedProjects = state.projects.map((p) => p.id == updatedProject.id ? updatedProject : p).toList();
    
    state = state.copyWith(projects: updatedProjects);
    _saveState();
  }

  void updateProjectOutline(String outline) {
    _updateProjectOutline(outline);
  }

  void clearChaptersAndTasks() {
    if (state.selectedProject == null) return;
    
    final updatedProject = state.selectedProject!.copyWith(chapters: []);
    final updatedProjects = state.projects.map((p) => p.id == updatedProject.id ? updatedProject : p).toList();
    
    // Remove all tasks for this project's chapters
    final projectChapterIds = state.selectedProject!.chapters.map((c) => c.id).toSet();
    final updatedTasks = state.allTasks.where((t) => !projectChapterIds.contains(t.chapterId)).toList();
    
    state = state.copyWith(
      projects: updatedProjects,
      allTasks: updatedTasks,
      selectedChapterId: null,
      selectedTaskId: null,
    );
    _saveState();
  }

  // ========== World Context Management ==========
  void updateWorldContext(WorldContext context) {
    if (state.selectedProject == null) return;
    
    final updatedProject = state.selectedProject!.copyWith(worldContext: context);
    final updatedProjects = state.projects.map((p) => p.id == updatedProject.id ? updatedProject : p).toList();
    
    state = state.copyWith(projects: updatedProjects);
    _saveState();
  }

  void toggleContextCategory(String category, bool enabled) {
    if (state.selectedProject == null) return;
    
    final ctx = state.selectedProject!.worldContext;
    WorldContext updated;
    switch (category) {
      case 'characters':
        updated = ctx.copyWith(includeCharacters: enabled);
        break;
      case 'relationships':
        updated = ctx.copyWith(includeRelationships: enabled);
        break;
      case 'locations':
        updated = ctx.copyWith(includeLocations: enabled);
        break;
      case 'foreshadowing':
        updated = ctx.copyWith(includeForeshadowing: enabled);
        break;
      case 'rules':
        updated = ctx.copyWith(includeRules: enabled);
        break;
      default:
        return;
    }
    updateWorldContext(updated);
  }

  /// Auto-extract context changes from completed chapter content
  Future<void> _extractContextUpdates(String content) async {
    if (state.selectedProject == null) return;
    
    final writerConfig = state.writerModel;
    if (writerConfig == null) return;
    
    try {
      final result = await _callLLM(
        writerConfig, 
        NovelPromptPresets.contextExtractor, 
        content,
      );
      
      final updates = jsonDecode(result) as Map<String, dynamic>;
      final ctx = state.selectedProject!.worldContext;
      
      // Merge updates into existing context
      final newCharacters = Map<String, String>.from(ctx.characters);
      final newRelationships = Map<String, String>.from(ctx.relationships);
      final newLocations = Map<String, String>.from(ctx.locations);
      final newForeshadowing = List<String>.from(ctx.foreshadowing);
      
      if (updates['newCharacters'] != null) {
        newCharacters.addAll(Map<String, String>.from(updates['newCharacters'] as Map));
      }
      if (updates['updatedRelationships'] != null) {
        newRelationships.addAll(Map<String, String>.from(updates['updatedRelationships'] as Map));
      }
      if (updates['newLocations'] != null) {
        newLocations.addAll(Map<String, String>.from(updates['newLocations'] as Map));
      }
      if (updates['newForeshadowing'] != null) {
        final newItems = List<String>.from(updates['newForeshadowing'] as List);
        for (final item in newItems) {
          if (!newForeshadowing.contains(item)) {
            newForeshadowing.add(item);
          }
        }
      }
      if (updates['resolvedForeshadowing'] != null) {
        final resolved = List<String>.from(updates['resolvedForeshadowing'] as List);
        newForeshadowing.removeWhere((f) => resolved.contains(f));
      }
      
      updateWorldContext(ctx.copyWith(
        characters: newCharacters,
        relationships: newRelationships,
        locations: newLocations,
        foreshadowing: newForeshadowing,
      ));
      
    } catch (e) {
      // Silently ignore extraction errors
    }
  }

  // ========== Chapter Management ==========
  void addChapter(String title) {
    if (state.selectedProject == null) return;
    
    final newChapter = NovelChapter(
      id: const Uuid().v4(),
      title: title,
      order: state.selectedProject!.chapters.length,
    );
    
    final updatedProject = state.selectedProject!.copyWith(
      chapters: [...state.selectedProject!.chapters, newChapter],
    );
    
    final updatedProjects = state.projects.map((p) {
      return p.id == updatedProject.id ? updatedProject : p;
    }).toList();
    
    state = state.copyWith(
      projects: updatedProjects,
      selectedChapterId: newChapter.id,
    );
    _saveState();
  }

  void selectChapter(String chapterId) {
    state = state.copyWith(selectedChapterId: chapterId, selectedTaskId: null);
    _saveState();
  }

  void deleteChapter(String chapterId) {
    if (state.selectedProject == null) return;
    
    final updatedChapters = state.selectedProject!.chapters.where((c) => c.id != chapterId).toList();
    final updatedProject = state.selectedProject!.copyWith(chapters: updatedChapters);
    final updatedProjects = state.projects.map((p) => p.id == updatedProject.id ? updatedProject : p).toList();
    final updatedTasks = state.allTasks.where((t) => t.chapterId != chapterId).toList();
    
    state = state.copyWith(
      projects: updatedProjects,
      allTasks: updatedTasks,
      selectedChapterId: updatedChapters.isNotEmpty ? updatedChapters.first.id : null,
    );
    _saveState();
  }

  // ========== Task Management ==========
  void addTask(String description) {
    if (state.selectedChapterId == null) return;
    
    final task = NovelTask(
      id: const Uuid().v4(),
      chapterId: state.selectedChapterId!,
      description: description,
      status: TaskStatus.pending,
    );
    state = state.copyWith(allTasks: [...state.allTasks, task]);
    _saveState();
  }

  void selectTask(String taskId) {
    state = state.copyWith(selectedTaskId: taskId);
  }

  /// Decompose the project's outline into chapters
  Future<void> decomposeFromOutline() async {
    if (state.selectedProject == null) return;
    
    final outline = state.selectedProject!.outline;
    if (outline == null || outline.isEmpty) return;
    
    final decomposeConfig = state.decomposeModel;
    
    if (decomposeConfig == null) {
      // Fallback to mock decomposition if no model configured
      final newChapters = <NovelChapter>[];
      final newTasks = <NovelTask>[];
      
      for (int i = 1; i <= 3; i++) {
        final chapterId = const Uuid().v4();
        newChapters.add(NovelChapter(
          id: chapterId,
          title: '第$i章 示例章节',
          order: state.selectedProject!.chapters.length + i - 1,
        ));
        newTasks.add(NovelTask(
          id: const Uuid().v4(),
          chapterId: chapterId,
          description: '根据大纲写作第$i章',
          status: TaskStatus.pending,
        ));
      }
      
      final updatedProject = state.selectedProject!.copyWith(
        chapters: [...state.selectedProject!.chapters, ...newChapters],
      );
      final updatedProjects = state.projects.map((p) => p.id == updatedProject.id ? updatedProject : p).toList();
      
      state = state.copyWith(
        projects: updatedProjects,
        allTasks: [...state.allTasks, ...newTasks],
        selectedChapterId: newChapters.first.id,
      );
      _saveState();
      return;
    }
    
    try {
      final systemPrompt = decomposeConfig.systemPrompt.isNotEmpty 
          ? decomposeConfig.systemPrompt 
          : NovelPromptPresets.decompose;
      
      final result = await _callLLM(decomposeConfig, systemPrompt, outline);
      
      // Parse JSON result - format: [{title, description}, ...]
      final List<dynamic> chapterList = jsonDecode(result);
      final newChapters = <NovelChapter>[];
      final newTasks = <NovelTask>[];
      
      for (int i = 0; i < chapterList.length; i++) {
        final chapterData = chapterList[i] as Map<String, dynamic>;
        final chapterId = const Uuid().v4();
        final title = chapterData['title'] as String? ?? '第${i + 1}章';
        final description = chapterData['description'] as String? ?? '';
        
        newChapters.add(NovelChapter(
          id: chapterId,
          title: title,
          order: state.selectedProject!.chapters.length + i,
        ));
        
        // Create a writing task for this chapter
        newTasks.add(NovelTask(
          id: const Uuid().v4(),
          chapterId: chapterId,
          description: description.isNotEmpty ? description : '写作：$title',
          status: TaskStatus.pending,
        ));
      }
      
      final updatedProject = state.selectedProject!.copyWith(
        chapters: [...state.selectedProject!.chapters, ...newChapters],
      );
      final updatedProjects = state.projects.map((p) => p.id == updatedProject.id ? updatedProject : p).toList();
      
      state = state.copyWith(
        projects: updatedProjects,
        allTasks: [...state.allTasks, ...newTasks],
        selectedChapterId: newChapters.isNotEmpty ? newChapters.first.id : state.selectedChapterId,
      );
      _saveState();
      
    } catch (e) {
      // If parsing fails, create a single chapter
      final chapterId = const Uuid().v4();
      final newChapter = NovelChapter(
        id: chapterId,
        title: '第${state.selectedProject!.chapters.length + 1}章',
        order: state.selectedProject!.chapters.length,
      );
      final task = NovelTask(
        id: const Uuid().v4(),
        chapterId: chapterId,
        description: '根据大纲写作本章',
        status: TaskStatus.pending,
      );
      
      final updatedProject = state.selectedProject!.copyWith(
        chapters: [...state.selectedProject!.chapters, newChapter],
      );
      final updatedProjects = state.projects.map((p) => p.id == updatedProject.id ? updatedProject : p).toList();
      
      state = state.copyWith(
        projects: updatedProjects,
        allTasks: [...state.allTasks, task],
        selectedChapterId: chapterId,
      );
      _saveState();
    }
  }

  void updateTaskStatus(String taskId, TaskStatus status) {
    _updateTaskStatus(taskId, status);
  }

  /// Execute a single task (called when user clicks "Run Task" button)
  Future<void> runSingleTask(String taskId) async {
    final task = state.allTasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => NovelTask(id: '', chapterId: '', description: '', status: TaskStatus.pending),
    );
    
    if (task.id.isEmpty) return;
    if (task.status == TaskStatus.running) return; // Already running
    
    await _executeTask(taskId);
  }

  void updateTaskDescription(String taskId, String newDescription) {
    final updatedTasks = state.allTasks.map((t) {
      if (t.id == taskId) {
        return t.copyWith(description: newDescription);
      }
      return t;
    }).toList();
    state = state.copyWith(allTasks: updatedTasks);
    _saveState();
  }
  
  void deleteTask(String taskId) {
    state = state.copyWith(
      allTasks: state.allTasks.where((t) => t.id != taskId).toList(),
      selectedTaskId: state.selectedTaskId == taskId ? null : state.selectedTaskId,
    );
    _saveState();
  }

  // ========== Controls ==========
  void togglePause() {
    state = state.copyWith(isPaused: !state.isPaused);
    _saveState();
  }

  void toggleReviewMode(bool enabled) {
    state = state.copyWith(isReviewEnabled: enabled);
    _saveState();
  }
  
  void startQueue() {
    runWorkflow();
  }
  
  void stopQueue() {
    _shouldStop = true;
    state = state.copyWith(isRunning: false, isPaused: false);
    _saveState();
  }

  // ========== Model Configuration ==========
  void setOutlineModel(NovelModelConfig? config) {
    state = state.copyWith(outlineModel: config);
    _saveState();
  }
  
  void setOutlinePrompt(String prompt) {
    if (state.outlineModel != null) {
      state = state.copyWith(outlineModel: state.outlineModel!.copyWith(systemPrompt: prompt));
      _saveState();
    }
  }

  void setDecomposeModel(NovelModelConfig? config) {
    state = state.copyWith(decomposeModel: config);
    _saveState();
  }
  
  void setDecomposePrompt(String prompt) {
    if (state.decomposeModel != null) {
      state = state.copyWith(decomposeModel: state.decomposeModel!.copyWith(systemPrompt: prompt));
      _saveState();
    }
  }

  void setWriterModel(NovelModelConfig? config) {
    state = state.copyWith(writerModel: config);
    _saveState();
  }
  
  void setWriterPrompt(String prompt) {
    if (state.writerModel != null) {
      state = state.copyWith(writerModel: state.writerModel!.copyWith(systemPrompt: prompt));
      _saveState();
    }
  }

  void setReviewerModel(NovelModelConfig? config) {
    state = state.copyWith(reviewerModel: config);
    _saveState();
  }
  
  void setReviewerPrompt(String prompt) {
    if (state.reviewerModel != null) {
      state = state.copyWith(reviewerModel: state.reviewerModel!.copyWith(systemPrompt: prompt));
      _saveState();
    }
  }
}
