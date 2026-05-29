import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:owj_assistant/config/api_keys.dart';

/// MCP Think service for deep, structured thinking and analysis.
///
/// Provides structured reasoning capabilities with step-by-step analysis.
/// Can use an LLM backend for enhanced reasoning when available,
/// otherwise falls back to local structured prompting templates.
class McpThinkService {
  McpThinkService({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ));

  final Dio _dio;

  /// Performs deep thinking on a [prompt] and returns structured analysis.
  Future<ThinkResult> thinkDeep(String prompt) async {
    final systemPrompt = _buildDeepThinkSystemPrompt();
    final steps = _buildDeepThinkSteps(prompt);

    final analysis = await _executeWithLlm(systemPrompt, steps, prompt);

    return ThinkResult(
      prompt: prompt,
      analysis: analysis,
      steps: steps,
      conclusion: _extractConclusion(analysis),
      confidence: _calculateConfidence(analysis),
      timestamp: DateTime.now(),
    );
  }

  /// Helps make a decision among [options] based on [criteria].
  Future<DecisionResult> thinkDecision(
    List<String> options,
    List<String> criteria,
  ) async {
    final systemPrompt = _buildDecisionSystemPrompt();
    final prompt = '''
قرار مطلوب:
الخيارات: ${options.map((o) => '• $o').join('\n')}
المعايير: ${criteria.map((c) => '• $c').join('\n')}

حلل كل خيار بناءً على المعايير المذكورة أعلاه.
''';

    final analysis = await _executeWithLlm(systemPrompt, [], prompt);

    // Score each option against criteria
    final scores = <String, double>{};
    for (final option in options) {
      scores[option] = _scoreOption(analysis, option, criteria);
    }

    // Rank options by score
    final ranked = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return DecisionResult(
      options: options,
      criteria: criteria,
      analysis: analysis,
      scores: scores,
      rankedOptions: ranked.map((e) => e.key).toList(),
      recommendation: ranked.first.key,
      reasoning: analysis,
      timestamp: DateTime.now(),
    );
  }

  /// Analyzes a [problem] with structured problem-solving methodology.
  Future<ThinkResult> thinkProblem(String problem) async {
    final systemPrompt = _buildProblemSolvingSystemPrompt();
    final steps = [
      ThinkStep(order: 1, title: 'تعريف المشكلة', description: 'تحديد المشكلة بدقة', status: ThinkStepStatus.active),
      ThinkStep(order: 2, title: 'تحليل الأسباب الجذرية', description: 'البحث عن الأسباب الحقيقية', status: ThinkStepStatus.pending),
      ThinkStep(order: 3, title: 'توليد الحلول الممكنة', description: 'اقتراح حلول متعددة', status: ThinkStepStatus.pending),
      ThinkStep(order: 4, title: 'تقييم الحلول', description: 'مقارنة إيجابيات وسلبيات كل حل', status: ThinkStepStatus.pending),
      ThinkStep(order: 5, title: 'التوصية بالحل الأمثل', description: 'اختيار وتنفيذ الحل الأنسب', status: ThinkStepStatus.pending),
    ];

    final analysis = await _executeWithLlm(systemPrompt, steps, problem);

    return ThinkResult(
      prompt: problem,
      analysis: analysis,
      steps: steps,
      conclusion: _extractConclusion(analysis),
      confidence: _calculateConfidence(analysis),
      timestamp: DateTime.now(),
    );
  }

  /// Reflects on an [experience] and produces insights.
  Future<ThinkResult> thinkReflect(String experience) async {
    final systemPrompt = _buildReflectionSystemPrompt();
    final steps = [
      ThinkStep(order: 1, title: 'وصف التجربة', description: 'ماذا حدث بالضبط؟', status: ThinkStepStatus.active),
      ThinkStep(order: 2, title: 'المشاعر والأفكار', description: 'ماذا شعرت وفكرت؟', status: ThinkStepStatus.pending),
      ThinkStep(order: 3, title: 'الدروس المستفادة', description: 'ماذا تعلمت؟', status: ThinkStepStatus.pending),
      ThinkStep(order: 4, title: 'التطبيق المستقبلي', description: 'كيف أطبق ما تعلمته؟', status: ThinkStepStatus.pending),
    ];

    final analysis = await _executeWithLlm(systemPrompt, steps, experience);

    return ThinkResult(
      prompt: experience,
      analysis: analysis,
      steps: steps,
      conclusion: _extractConclusion(analysis),
      confidence: _calculateConfidence(analysis),
      timestamp: DateTime.now(),
    );
  }

  // ── System prompt builders ──

  String _buildDeepThinkSystemPrompt() => '''
أنت مساعد تفكير عميق. مهمتك هي تحليل الموضوعات بطريقة منهجية وعميقة.
اتبع هذه الخطوات:
1. فهم الموضوع من جميع الزوايا
2. تحليل الافتراضات الأساسية
3. استكشاف وجهات النظر المختلفة
4. تحديد الأنماط والعلاقات
5. الوصول لاستنتاجات مدعومة بالأدلة

قدم التحليل بالعربية مع دعم المصطلحات الإنجليزية التقنية.
''';

  String _buildDecisionSystemPrompt() => '''
أنت مساعد اتخاذ قرارات. مهمتك هي المساعدة في اتخاذ قرارات مبنية على تحليل منهجي.
لكل خيار:
1. قيّم مدى تحقيقه لكل معيار (ممتاز / جيد / متوسط / ضعيف)
2. حدد الإيجابيات والسلبيات
3. قدم توصية واضحة مع تبرير

قدم التحليل بالعربية.
''';

  String _buildProblemSolvingSystemPrompt() => '''
أنت مساعد حل مشكلات. اتبع منهجية منظمة:
1. عرّف المشكلة بدقة
2. حلل الأسباب الجذرية (استخدم طريقة 5 لماذا)
3. اقترح 3-5 حلول ممكنة
4. قيّم كل حل (فعالية، تكلفة، وقت تنفيذ، مخاطر)
5. أوصِ بالحل الأمثل مع خطة تنفيذ

قدم التحليل بالعربية.
''';

  String _buildReflectionSystemPrompt() => '''
أنت مساعد تأمل ذاتي. ساعدني في التأمل في تجاربي:
1. صف ما حدث بموضوعية
2. استكشف المشاعر والأفكار المصاحبة
3. استخلص الدروس المستفادة
4. اقترح كيفية التطبيق في المستقبل

كن تعاطفياً وصادقاً. قدم التحليل بالعربية.
''';

  List<ThinkStep> _buildDeepThinkSteps(String prompt) => [
    ThinkStep(order: 1, title: 'الفهم الأولي', description: 'تحليل الموضوع الأساسي', status: ThinkStepStatus.active),
    ThinkStep(order: 2, title: 'التحليل العميق', description: 'تفكيك المكونات والعلاقات', status: ThinkStepStatus.pending),
    ThinkStep(order: 3, title: 'وجهات النظر المتعددة', description: 'استكشاف زوايا مختلفة', status: ThinkStepStatus.pending),
    ThinkStep(order: 4, title: 'التركيب والاستنتاج', description: 'بناء استنتاج شامل', status: ThinkStepStatus.pending),
  ];

  // ── LLM execution ──

  Future<String> _executeWithLlm(
    String systemPrompt,
    List<ThinkStep> steps,
    String userPrompt,
  ) async {
    // Try Groq first for speed
    if (ApiKeys.hasGroq) {
      try {
        return await _callGroq(systemPrompt, userPrompt);
      } catch (_) {
        // Fall through to OpenAI
      }
    }

    // Try OpenAI
    if (ApiKeys.hasOpenAI) {
      try {
        return await _callOpenAI(systemPrompt, userPrompt);
      } catch (_) {
        // Fall through to BigModel
      }
    }

    // Try BigModel (GLM-4)
    if (ApiKeys.hasBigModel) {
      try {
        return await _callBigModel(systemPrompt, userPrompt);
      } catch (_) {
        // All LLMs failed
      }
    }

    // Local fallback: return structured template
    return _localFallback(systemPrompt, steps, userPrompt);
  }

  Future<String> _callGroq(String systemPrompt, String userPrompt) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'https://api.groq.com/openai/v1/chat/completions',
      options: Options(headers: {
        'Authorization': 'Bearer ${ApiKeys.groqApiKey}',
        'Content-Type': 'application/json',
      }),
      data: {
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': 0.7,
        'max_tokens': 2048,
      },
    );
    return _parseLlmResponse(response.data!);
  }

  Future<String> _callOpenAI(String systemPrompt, String userPrompt) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'https://api.openai.com/v1/chat/completions',
      options: Options(headers: {
        'Authorization': 'Bearer ${ApiKeys.openaiApiKey}',
        'Content-Type': 'application/json',
      }),
      data: {
        'model': 'gpt-4o-mini',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': 0.7,
        'max_tokens': 2048,
      },
    );
    return _parseLlmResponse(response.data!);
  }

  Future<String> _callBigModel(String systemPrompt, String userPrompt) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'https://open.bigmodel.cn/api/paas/v4/chat/completions',
      options: Options(headers: {
        'Authorization': 'Bearer ${ApiKeys.bigModelApiKey}',
        'Content-Type': 'application/json',
      }),
      data: {
        'model': 'glm-4',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': 0.7,
        'max_tokens': 2048,
      },
    );
    return _parseLlmResponse(response.data!);
  }

  String _parseLlmResponse(Map<String, dynamic> data) {
    try {
      final choices = data['choices'] as List;
      if (choices.isEmpty) throw FormatException('No choices returned');
      final message = choices[0]['message'] as Map<String, dynamic>;
      return message['content'] as String? ?? '';
    } catch (e) {
      throw ThinkException('Failed to parse LLM response: $e');
    }
  }

  String _localFallback(
    String systemPrompt,
    List<ThinkStep> steps,
    String userPrompt,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('═══ تحليل تفكيري ═══');
    buffer.writeln();
    buffer.writeln('الموضوع: $userPrompt');
    buffer.writeln();

    for (final step in steps) {
      buffer.writeln('── الخطوة ${step.order}: ${step.title} ──');
      buffer.writeln(step.description);
      buffer.writeln('[في انتظار تحليل أعمق - لا يوجد اتصال LLM]');
      buffer.writeln();
    }

    buffer.writeln('── الخلاصة ──');
    buffer.writeln('يتطلب تحليلاً أعمق من نموذج لغوي متقدم.');
    buffer.writeln('يرجى التحقق من اتصال الإنترنت ومفاتيح API.');

    return buffer.toString();
  }

  // ── Utility methods ──

  String _extractConclusion(String analysis) {
    // Look for conclusion markers in Arabic and English
    final markers = ['الخلاصة:', 'الاستنتاج:', 'التوصية:', 'Conclusion:', 'In summary:'];
    for (final marker in markers) {
      final idx = analysis.indexOf(marker);
      if (idx != -1) {
        return analysis.substring(idx + marker.length).trim();
      }
    }
    // Return last paragraph
    final paragraphs = analysis.split(RegExp(r'\n\n+'));
    return paragraphs.isNotEmpty ? paragraphs.last.trim() : analysis;
  }

  double _calculateConfidence(String analysis) {
    // Heuristic: longer, more structured analysis → higher confidence
    double score = 0.0;
    // Length factor
    if (analysis.length > 500) score += 0.3;
    else if (analysis.length > 200) score += 0.2;
    // Structure markers
    if (analysis.contains('الخلاصة') || analysis.contains('الاستنتاج')) score += 0.2;
    if (analysis.contains('لأن') || analysis.contains('بسبب')) score += 0.1;
    if (analysis.contains('أولاً') || analysis.contains('ثانياً')) score += 0.1;
    // Caution markers reduce confidence
    if (analysis.contains('قد') || analysis.contains('ربما')) score -= 0.1;
    return score.clamp(0.1, 1.0);
  }

  double _scoreOption(String analysis, String option, List<String> criteria) {
    double score = 0.0;
    final lower = analysis.toLowerCase();
    final optionLower = option.toLowerCase();

    // Option mentioned in analysis
    if (lower.contains(optionLower)) score += 0.3;

    // Positive indicators near option mention
    final optionIdx = lower.indexOf(optionLower);
    if (optionIdx != -1) {
      final context = lower.substring(
        optionIdx > 50 ? optionIdx - 50 : 0,
        optionIdx + optionLower.length + 100 < lower.length
            ? optionIdx + optionLower.length + 100
            : lower.length,
      );
      if (context.contains('ممتاز') || context.contains('أفضل')) score += 0.3;
      if (context.contains('جيد')) score += 0.2;
      if (context.contains('ضعيف') || context.contains('مشكلة')) score -= 0.2;
    }

    // Criteria coverage
    for (final criterion in criteria) {
      if (lower.contains(criterion.toLowerCase())) score += 0.1;
    }

    return score.clamp(0.0, 1.0);
  }
}

// ── Data models ──

enum ThinkStepStatus { active, pending, completed, skipped }

class ThinkStep {
  final int order;
  final String title;
  final String description;
  final ThinkStepStatus status;

  const ThinkStep({
    required this.order,
    required this.title,
    required this.description,
    required this.status,
  });

  ThinkStep copyWith({ThinkStepStatus? status}) => ThinkStep(
    order: order,
    title: title,
    description: description,
    status: status ?? this.status,
  );
}

class ThinkResult {
  final String prompt;
  final String analysis;
  final List<ThinkStep> steps;
  final String conclusion;
  final double confidence;
  final DateTime timestamp;

  const ThinkResult({
    required this.prompt,
    required this.analysis,
    required this.steps,
    required this.conclusion,
    required this.confidence,
    required this.timestamp,
  });
}

class DecisionResult {
  final List<String> options;
  final List<String> criteria;
  final String analysis;
  final Map<String, double> scores;
  final List<String> rankedOptions;
  final String recommendation;
  final String reasoning;
  final DateTime timestamp;

  const DecisionResult({
    required this.options,
    required this.criteria,
    required this.analysis,
    required this.scores,
    required this.rankedOptions,
    required this.recommendation,
    required this.reasoning,
    required this.timestamp,
  });
}

class ThinkException implements Exception {
  final String message;
  ThinkException(this.message);
  @override
  String toString() => 'ThinkException: $message';
}
