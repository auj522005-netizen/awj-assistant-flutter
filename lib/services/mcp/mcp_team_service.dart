import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:owj_assistant/config/api_keys.dart';
import 'package:owj_assistant/services/storage_service.dart';

/// MCP Team service — multi-agent orchestration.
///
/// Coordinates 5 specialist agents that execute sequentially,
/// passing context between them:
///   1. **Researcher**  – gathers information and data
///   2. **Analyst**     – interprets and finds patterns
///   3. **Coder**       – writes code / technical solutions
///   4. **Writer**      – crafts clear, well-structured output
///   5. **Reviewer**    – quality-checks and refines
class McpTeamService {
  McpTeamService({Dio? dio, StorageService? storage})
      : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 120),
        )),
        _storage = storage ?? StorageService.instance;

  final Dio _dio;
  final StorageService _storage;

  static const _historyKey = 'team_task_history';

  /// The five specialist agents, in execution order.
  static const List<TeamAgent> agents = [
    TeamAgent(
      id: 'researcher',
      name: 'الباحث',
      nameEn: 'Researcher',
      role: 'يجمع المعلومات والبيانات المتعلقة بالمهمة',
      systemPrompt: _researcherPrompt,
      icon: '🔍',
    ),
    TeamAgent(
      id: 'analyst',
      name: 'المحلل',
      nameEn: 'Analyst',
      role: 'يحلل البيانات ويكتشف الأنماط والرؤى',
      systemPrompt: _analystPrompt,
      icon: '📊',
    ),
    TeamAgent(
      id: 'coder',
      name: 'المبرمج',
      nameEn: 'Coder',
      role: 'يكتب الحلول التقنية والأكواد البرمجية',
      systemPrompt: _coderPrompt,
      icon: '💻',
    ),
    TeamAgent(
      id: 'writer',
      name: 'الكاتب',
      nameEn: 'Writer',
      role: 'يصيغ النتائج بشكل واضح ومنظم',
      systemPrompt: _writerPrompt,
      icon: '✍️',
    ),
    TeamAgent(
      id: 'reviewer',
      name: 'المراجع',
      nameEn: 'Reviewer',
      role: 'يراجع الجودة ويحسن النتيجة النهائية',
      systemPrompt: _reviewerPrompt,
      icon: '✅',
    ),
  ];

  // ── Public API ──

  /// Executes a team task by running all 5 agents sequentially.
  ///
  /// Each agent receives the [task] plus the accumulated context from
  /// all previously executed agents. Optional [context] can provide
  /// additional background.
  Future<TeamTaskResult> executeTeamTask(
    String task, {
    String? context,
  }) async {
    final startTime = DateTime.now();
    final agentResults = <AgentResult>[];
    var accumulatedContext = context ?? '';

    for (final agent in agents) {
      final agentStartTime = DateTime.now();

      try {
        final agentInput = _buildAgentInput(task, agent, accumulatedContext, agentResults);
        final output = await _executeAgent(agent, agentInput);

        final result = AgentResult(
          agentId: agent.id,
          agentName: agent.name,
          input: agentInput,
          output: output,
          duration: DateTime.now().difference(agentStartTime),
          status: AgentStatus.completed,
          timestamp: DateTime.now(),
        );

        agentResults.add(result);
        accumulatedContext = _appendContext(accumulatedContext, agent, output);
      } catch (e) {
        final result = AgentResult(
          agentId: agent.id,
          agentName: agent.name,
          input: '',
          output: 'خطأ: $e',
          duration: DateTime.now().difference(agentStartTime),
          status: AgentStatus.failed,
          timestamp: DateTime.now(),
          error: e.toString(),
        );
        agentResults.add(result);
        // Continue to next agent even if one fails
      }
    }

    final totalDuration = DateTime.now().difference(startTime);

    // Extract final output from the reviewer (last agent)
    final finalOutput = agentResults.isNotEmpty
        ? agentResults.last.output
        : 'لم يتم إنجاز المهمة';

    final taskResult = TeamTaskResult(
      task: task,
      initialContext: context,
      agentResults: agentResults,
      finalOutput: finalOutput,
      totalDuration: totalDuration,
      completedAt: DateTime.now(),
      successCount: agentResults.where((r) => r.status == AgentStatus.completed).length,
    );

    // Save to history
    await _saveTaskHistory(taskResult);

    return taskResult;
  }

  /// Gets task execution history.
  Future<List<TeamTaskResult>> getTaskHistory({int limit = 20}) async {
    final history = _storage.getJsonList(_historyKey) ?? [];
    return history.take(limit).map(_parseTaskResult).toList();
  }

  // ── Private helpers ──

  String _buildAgentInput(
    String task,
    TeamAgent agent,
    String accumulatedContext,
    List<AgentResult> previousResults,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('═══ المهمة ═══');
    buffer.writeln(task);
    buffer.writeln();

    if (accumulatedContext.isNotEmpty) {
      buffer.writeln('═══ السياق السابق ═══');
      buffer.writeln(accumulatedContext);
      buffer.writeln();
    }

    if (previousResults.isNotEmpty) {
      buffer.writeln('═══ نتائج الوكلاء السابقين ═══');
      for (final result in previousResults) {
        buffer.writeln('── ${result.agentName} ──');
        buffer.writeln(result.output);
        buffer.writeln();
      }
    }

    buffer.writeln('══─ دورك: ${agent.name} ──');
    buffer.writeln(agent.role);
    buffer.writeln('قم بتنفيذ دورك بناءً على ما سبق.');

    return buffer.toString();
  }

  String _appendContext(String existing, TeamAgent agent, String output) {
    if (existing.isNotEmpty) existing += '\n\n';
    return '$existing── نتائج ${agent.name} ──\n$output';
  }

  Future<String> _executeAgent(TeamAgent agent, String input) async {
    // Try Groq for speed
    if (ApiKeys.hasGroq) {
      try {
        return await _callLlm(
          'https://api.groq.com/openai/v1/chat/completions',
          apiKey: ApiKeys.groqApiKey,
          model: 'llama-3.3-70b-versatile',
          systemPrompt: agent.systemPrompt,
          userPrompt: input,
        );
      } catch (_) {}
    }

    // Try OpenAI
    if (ApiKeys.hasOpenAI) {
      try {
        return await _callLlm(
          'https://api.openai.com/v1/chat/completions',
          apiKey: ApiKeys.openaiApiKey,
          model: 'gpt-4o-mini',
          systemPrompt: agent.systemPrompt,
          userPrompt: input,
        );
      } catch (_) {}
    }

    // Try BigModel
    if (ApiKeys.hasBigModel) {
      try {
        return await _callLlm(
          'https://open.bigmodel.cn/api/paas/v4/chat/completions',
          apiKey: ApiKeys.bigModelApiKey,
          model: 'glm-4',
          systemPrompt: agent.systemPrompt,
          userPrompt: input,
        );
      } catch (_) {}
    }

    return '[${agent.name}] لا يمكن تنفيذ الدور - لا يوجد اتصال بنموذج لغوي';
  }

  Future<String> _callLlm(
    String url, {
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      url,
      options: Options(headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      }),
      data: {
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': 0.7,
        'max_tokens': 2048,
      },
    );

    final data = response.data!;
    final choices = data['choices'] as List;
    if (choices.isEmpty) throw FormatException('No choices returned');
    return (choices[0]['message'] as Map<String, dynamic>)['content'] as String? ?? '';
  }

  Future<void> _saveTaskHistory(TeamTaskResult result) async {
    final history = _storage.getJsonList(_historyKey) ?? [];
    history.insert(0, {
      'task': result.task,
      'finalOutput': result.finalOutput,
      'successCount': result.successCount,
      'totalDurationMs': result.totalDuration.inMilliseconds,
      'completedAt': result.completedAt.toIso8601String(),
    });
    // Keep only last 50
    if (history.length > 50) history.removeRange(50, history.length);
    await _storage.setJsonList(_historyKey, history);
  }

  TeamTaskResult _parseTaskResult(Map<String, dynamic> data) {
    return TeamTaskResult(
      task: data['task'] as String? ?? '',
      initialContext: null,
      agentResults: [],
      finalOutput: data['finalOutput'] as String? ?? '',
      totalDuration: Duration(milliseconds: data['totalDurationMs'] as int? ?? 0),
      completedAt: DateTime.tryParse(data['completedAt'] as String? ?? '') ?? DateTime.now(),
      successCount: data['successCount'] as int? ?? 0,
    );
  }

  // ── Agent system prompts ──

  static const _researcherPrompt = '''أنت باحث خبير. مهمتك:
1. ابحث عن المعلومات ذات الصلة بالمهمة
2. اجمع حقائق وبيانات من مصادر متعددة
3. نظم المعلومات بشكل منهجي
4. حدد الفجوات في المعلومات المتاحة

قدم النتائج بالعربية مع ذكر المصادر عند الإمكان.''';

  static const _analystPrompt = '''أنت محلل بيانات خبير. مهمتك:
1. حلل المعلومات التي جمعها الباحث
2. اكتشف الأنماط والعلاقات
3. قيّم موثوقية البيانات
4. استخلص رؤى واستنتاجات

قدم التحليل بالعربية مع دعم الأرقام والإحصائيات.''';

  static const _coderPrompt = '''أنت مبرمج خبير. مهمتك:
1. صمم الحل التقني بناءً على التحليل
2. اكتب كود نظيف وموثق
3. اتبع أفضل الممارسات والأنماط البرمجية
4. تأكد من أن الكود قابل للصيانة والتوسع

اكتب الكود باللغة المناسبة مع تعليقات توضيحية.''';

  static const _writerPrompt = '''أنت كاتب محترف. مهمتك:
1. صياغة النتائج بشكل واضح ومنظم
2. تنظيم المحتوى بعناوين وأقسام
3. تبسيط المفاهيم المعقدة
4. ضمان انسيابية القراءة

اكتب بالعربية الفصحى مع دعم المصطلحات التقنية الإنجليزية عند الحاجة.''';

  static const _reviewerPrompt = '''أنت مراجع جودة خبير. مهمتك:
1. راجع العمل الكامل للفريق
2. تحقق من الدقة والاتساق
3. حدد أي أخطاء أو تحسينات ممكنة
4. قدم النسخة النهائية المحسنة

كن دقيقاً وموضوعياً. قدم التوصيات بالعربية.''';
}

// ── Data models ──

class TeamAgent {
  final String id;
  final String name;
  final String nameEn;
  final String role;
  final String systemPrompt;
  final String icon;

  const TeamAgent({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.role,
    required this.systemPrompt,
    required this.icon,
  });
}

enum AgentStatus { pending, running, completed, failed }

class AgentResult {
  final String agentId;
  final String agentName;
  final String input;
  final String output;
  final Duration duration;
  final AgentStatus status;
  final DateTime timestamp;
  final String? error;

  const AgentResult({
    required this.agentId,
    required this.agentName,
    required this.input,
    required this.output,
    required this.duration,
    required this.status,
    required this.timestamp,
    this.error,
  });
}

class TeamTaskResult {
  final String task;
  final String? initialContext;
  final List<AgentResult> agentResults;
  final String finalOutput;
  final Duration totalDuration;
  final DateTime completedAt;
  final int successCount;

  const TeamTaskResult({
    required this.task,
    this.initialContext,
    required this.agentResults,
    required this.finalOutput,
    required this.totalDuration,
    required this.completedAt,
    required this.successCount,
  });

  bool get allSucceeded => successCount == 5;
  double get successRate => successCount / 5.0;
}
