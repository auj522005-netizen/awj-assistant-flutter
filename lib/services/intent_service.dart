/// Intent detection service for the OWJ Assistant.
///
/// Supports 50+ Arabic and English regex patterns for detecting
/// user intents from natural language input. Returns an IntentResult
/// with type, extracted params, and confidence score.
class IntentService {
  IntentService();

  /// All registered intent patterns.
  late final List<_IntentPattern> _patterns = _buildPatterns();

  /// Detect the intent from user input text.
  ///
  /// Returns the highest-confidence match, or a default
  /// [IntentType.unknown] result if no pattern matches.
  IntentResult detect(String input) {
    if (input.trim().isEmpty) {
      return IntentResult(
        type: IntentType.unknown,
        params: {},
        confidence: 0.0,
      );
    }

    final normalized = _normalize(input);
    IntentResult? bestMatch;
    double bestConfidence = 0.0;

    for (final pattern in _patterns) {
      for (final regex in pattern.regexes) {
        final match = regex.firstMatch(normalized);
        if (match != null) {
          final confidence = _calculateConfidence(
            match,
            normalized,
            pattern.weight,
          );
          if (confidence > bestConfidence) {
            bestConfidence = confidence;
            final params = _extractParams(match, pattern.type, input);
            bestMatch = IntentResult(
              type: pattern.type,
              params: params,
              confidence: confidence,
            );
          }
        }
      }
    }

    return bestMatch ??
        IntentResult(
          type: IntentType.unknown,
          params: {'raw_input': input},
          confidence: 0.0,
        );
  }

  /// Detect all matching intents (for multi-intent support).
  List<IntentResult> detectAll(String input) {
    if (input.trim().isEmpty) return [];

    final normalized = _normalize(input);
    final results = <IntentResult>[];

    for (final pattern in _patterns) {
      for (final regex in pattern.regexes) {
        final match = regex.firstMatch(normalized);
        if (match != null) {
          final confidence = _calculateConfidence(
            match,
            normalized,
            pattern.weight,
          );
          if (confidence >= 0.3) {
            final params = _extractParams(match, pattern.type, input);
            results.add(IntentResult(
              type: pattern.type,
              params: params,
              confidence: confidence,
            ));
          }
        }
      }
    }

    // Sort by confidence descending
    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results;
  }

  /// Normalize input text for matching.
  String _normalize(String input) {
    var text = input.toLowerCase().trim();
    // Normalize Arabic characters
    text = text
        .replaceAll('إ', 'ا')
        .replaceAll('أ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي');
    // Normalize whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    return text;
  }

  /// Calculate confidence score for a match.
  double _calculateConfidence(
    RegExpMatch match,
    String input,
    double weight,
  ) {
    final matchLength = match.end - match.start;
    final inputLength = input.length;
    final coverage = inputLength > 0 ? matchLength / inputLength : 0.0;
    // Combine coverage with pattern weight
    final confidence = (coverage * 0.4 + weight * 0.6).clamp(0.0, 1.0);
    return double.parse(confidence.toStringAsFixed(3));
  }

  /// Extract parameters from the match based on intent type.
  Map<String, dynamic> _extractParams(
    RegExpMatch match,
    IntentType type,
    String originalInput,
  ) {
    final params = <String, dynamic>{};

    switch (type) {
      case IntentType.addTask:
        params['task'] = match.groupCount >= 1 ? match[1] : originalInput;
        break;
      case IntentType.addAppointment:
        params['event'] = match.groupCount >= 1 ? match[1] : originalInput;
        if (match.groupCount >= 2 && match[2] != null) {
          params['time'] = match[2];
        }
        break;
      case IntentType.youtubeSearch:
        params['query'] = match.groupCount >= 1 ? match[1] : originalInput;
        break;
      case IntentType.openApp:
        params['app'] = match.groupCount >= 1 ? match[1] : '';
        break;
      case IntentType.webSearch:
        params['query'] = match.groupCount >= 1 ? match[1] : originalInput;
        break;
      case IntentType.captureIdea:
        params['idea'] = match.groupCount >= 1 ? match[1] : originalInput;
        break;
      case IntentType.openLink:
        params['url'] = match.groupCount >= 1 ? match[1] : '';
        break;
      case IntentType.fetchUrl:
        params['url'] = match.groupCount >= 1 ? match[1] : '';
        break;
      case IntentType.thinkDeep:
        params['topic'] = match.groupCount >= 1 ? match[1] : originalInput;
        break;
      case IntentType.thinkDecision:
        params['decision'] = match.groupCount >= 1 ? match[1] : originalInput;
        break;
      case IntentType.thinkProblem:
        params['problem'] = match.groupCount >= 1 ? match[1] : originalInput;
        break;
      case IntentType.thinkReflect:
        params['topic'] = match.groupCount >= 1 ? match[1] : originalInput;
        break;
      case IntentType.speak:
        params['text'] = match.groupCount >= 1 ? match[1] : originalInput;
        break;
      case IntentType.translate:
        params['text'] = match.groupCount >= 1 ? match[1] : originalInput;
        if (match.groupCount >= 2 && match[2] != null) {
          params['target_language'] = match[2];
        }
        break;
      case IntentType.mapsSearch:
        params['query'] = match.groupCount >= 1 ? match[1] : originalInput;
        break;
      case IntentType.mapsNearby:
        params['place_type'] = match.groupCount >= 1 ? match[1] : '';
        break;
      case IntentType.mapsDirections:
        if (match.groupCount >= 2 && match[2] != null) {
          params['from'] = match[1];
          params['to'] = match[2];
        } else if (match.groupCount >= 1) {
          params['to'] = match[1];
        }
        break;
      case IntentType.mapsFood:
        params['cuisine'] = match.groupCount >= 1 ? match[1] : '';
        break;
      case IntentType.sendGmail:
        params['content'] = match.groupCount >= 1 ? match[1] : originalInput;
        break;
      case IntentType.summarize:
        params['content'] = match.groupCount >= 1 ? match[1] : originalInput;
        break;
      default:
        break;
    }

    return params;
  }

  /// Build all intent patterns with Arabic and English regexes.
  List<_IntentPattern> _buildPatterns() {
    return [
      // ─── Task Management ────────────────────────────────────────────
      _IntentPattern(
        type: IntentType.addTask,
        weight: 0.9,
        regexes: [
          RegExp(r'(?:add|create|new)\s+(?:a\s+)?task[:\s]+(.+)'),
          RegExp(r'(?:ضيف|أضف|انشئ|أنشئ|عمل|مهمه|مهمة)\s+(?:مهمة|تاسك|عمل)[:\s]*(.+)'),
          RegExp(r'خلي\s+(?:في|لي)\s+(?:مهمة|تاسك)[:\s]*(.+)'),
          RegExp(r'(?:عامل|ساوي|اعمل)\s+(?:لي\s+)?مهمة[:\s]*(.+)'),
          RegExp(r'todo[:\s]+(.+)'),
          RegExp(r'عامل\s+تاسك\s+(.+)'),
        ],
      ),
      _IntentPattern(
        type: IntentType.addAppointment,
        weight: 0.9,
        regexes: [
          RegExp(r'(?:schedule|book|set)\s+(?:an?\s+)?(?:appointment|meeting|event)[:\s]+(.+?)(?:\s+(?:at|on|for)\s+(.+))?'),
          RegExp(r'(?:ضيف|أضف|انشئ|حجز)\s+(?:موعد|اجتماع|ميتنج|حجز)[:\s]*(.+?)(?:\s+(?:في|يوم|الساعه|الساعة)\s+(.+))?'),
          RegExp(r'(?:عندك|عندي)\s+(?:موعد|اجتماع)[:\s]*(.+?)(?:\s+(?:في|يوم)\s+(.+))?'),
          RegExp(r'خلي\s+(?:لي|في)\s+(?:موعد|اجتماع)[:\s]*(.+?)(?:\s+(?:في|يوم)\s+(.+))?'),
        ],
      ),

      // ─── YouTube ────────────────────────────────────────────────────
      _IntentPattern(
        type: IntentType.youtubeSearch,
        weight: 0.85,
        regexes: [
          RegExp(r'(?:search|find|look\s+up)\s+(?:on\s+)?(?:youtube|yt)[:\s]*(.+)'),
          RegExp(r'youtube\s+(?:search|find)[:\s]*(.+)'),
          RegExp(r'(?:دور|ابحث|لقّي|لقى)\s+(?:على|في|لي)\s*(?:يوتيوب|youtube)[:\s]*(.+)'),
          RegExp(r'(?:يوتيوب|youtube)\s+(?:دور|ابحث|بحث)[:\s]*(.+)'),
          RegExp(r'yt\s+(.+)'),
        ],
      ),
      _IntentPattern(
        type: IntentType.youtubeRecommend,
        weight: 0.8,
        regexes: [
          RegExp(r'(?:recommend|suggest)\s+(?:youtube|yt)?\s*videos?\s*(?:about|on)?[:\s]*(.+)'),
          RegExp(r'(?:اقترح|وريني|جبلّي)\s+(?:فيديو|فيديوهات)?\s*(?:يوتيوب)?[:\s]*(.+)'),
          RegExp(r'(?:يوتيوب|youtube)\s+(?:اقترح|توصيات|recommend)[:\s]*(.+)'),
        ],
      ),
      _IntentPattern(
        type: IntentType.youtubeUnderstand,
        weight: 0.85,
        regexes: [
          RegExp(r'(?:understand|explain|summarize|analyze)\s+(?:this\s+)?(?:video|yt|youtube)[:\s]*(.+)'),
          RegExp(r'(?:افهم|اشرح|لخّص|حلّل)\s+(?:ال)?فيديو\s*(?:ده|دا)?[:\s]*(.+)'),
          RegExp(r'(?:يوتيوب|youtube)\s+(?:افهم|اشرح|تلخيص)[:\s]*(.+)'),
        ],
      ),
      _IntentPattern(
        type: IntentType.youtubeTrending,
        weight: 0.75,
        regexes: [
          RegExp(r'(?:youtube|yt)\s+(?:trending|popular|hot)\s*(?:videos)?'),
          RegExp(r'(?:يوتيوب|youtube)\s+(?:ترند|شائع|رايج|اكتر|الأكثر)'),
          RegExp(r'(?:ايه|ايش|شنو)\s+(?:الترند|الرايج)\s*(?:على|في)?\s*(?:يوتيوب)?'),
        ],
      ),

      // ─── App Control ────────────────────────────────────────────────
      _IntentPattern(
        type: IntentType.openApp,
        weight: 0.85,
        regexes: [
          RegExp(r'(?:open|launch|start)\s+(?:the\s+)?(?:app|application)?\s*(.+)'),
          RegExp(r'(?:افتح|شغّل|شغل|فتح)\s+(?:التطبيق|الاب|ابليكيشن)?\s*(.+)'),
          RegExp(r'(?:افتح|شغّل)\s+(.+)'),
        ],
      ),

      // ─── Web Search ─────────────────────────────────────────────────
      _IntentPattern(
        type: IntentType.webSearch,
        weight: 0.8,
        regexes: [
          RegExp(r'(?:search|google|look\s+up|find\s+info)\s+(?:for|about)?[:\s]*(.+)'),
          RegExp(r'(?:دور|ابحث|بحدّث|جوجل)\s+(?:على|عن|لي)?[:\s]*(.+)'),
          RegExp(r'(?:ايه|ايش|شنو)\s+(?:هو|هي)?\s*(.+)'),
          RegExp(r'خلي\s+(?:ني|الي)\s+ادور\s+(.+)'),
        ],
      ),

      // ─── Ideas & Knowledge ──────────────────────────────────────────
      _IntentPattern(
        type: IntentType.captureIdea,
        weight: 0.85,
        regexes: [
          RegExp(r'(?:save|note|remember|capture|jot)\s+(?:this\s+)?(?:idea|thought)?[:\s]*(.+)'),
          RegExp(r'(:(?:احفظ|خلّي|سجّل|اكتب|نوّت)\s+(?:الفكرة|الفكره|الفكر|idea)?[:\s]*(.+)'),
          RegExp(r'فكرة[:\s]*(.+)'),
          RegExp(r'(?:idea|note)[:\s]*(.+)'),
        ],
      ),
      _IntentPattern(
        type: IntentType.dailyBrief,
        weight: 0.8,
        regexes: [
          RegExp(r'(?:daily\s+)?brief(?:ing)?'),
          RegExp(r'(?:ملخص|بريفينج|بريف)\s*(?:يومي|اليوم)?'),
          RegExp(r'ايه\s+(?:احوال|اخبار|اللي\s+عندي)\s*(?:اليوم|النهارده)?'),
          RegExp(r'(?:عامل\s+ايه|كيف\s+حالك)\s*(?:اليوم|النهارده)?'),
        ],
      ),
      _IntentPattern(
        type: IntentType.goalDecomp,
        weight: 0.8,
        regexes: [
          RegExp(r'(?:break\s+down|decompose|split)\s+(?:this\s+)?(?:goal|task|project)[:\s]*(.+)'),
          RegExp(r'(?:قسّم|فكّك|جزّئ)\s+(?:ال)?(?:هدف|تاسك|مشروع)[:\s]*(.+)'),
          RegExp(r'(?:ازاي|كيف)\s+(?:أحقق|احقق|أوصل)\s+(?:ال)?هدف[:\s]*(.+)'),
        ],
      ),
      _IntentPattern(
        type: IntentType.hardQuestions,
        weight: 0.75,
        regexes: [
          RegExp(r'(?:hard|difficult|deep|tough)\s+(?:question|questions)\s*(?:about)?[:\s]*(.+)'),
          RegExp(r'(?:اسئله|اسئلة|أسئلة)\s+(?:صعبه|صعبة|عميقه|عميقة)\s*(?:عن|في)?[:\s]*(.+)'),
          RegExp(r'(?:سؤال|سوال)\s+(?:صعب|عميق)[:\s]*(.+)'),
        ],
      ),
      _IntentPattern(
        type: IntentType.reflection,
        weight: 0.75,
        regexes: [
          RegExp(r'(?:reflect|reflection|think\s+about)\s+(?:on\s+)?(.+)'),
          RegExp(r'(?:تأمّل|تأمل|تفكّر|تفكر|تأملّي)\s*(?:في|عن)?[:\s]*(.+)'),
          RegExp(r'(?:خلّيني|خليّني)\s+(?:أتأمل|اتفكر)\s*(?:في)?[:\s]*(.+)'),
        ],
      ),

      // ─── Habits & Patterns ──────────────────────────────────────────
      _IntentPattern(
        type: IntentType.habitCheck,
        weight: 0.8,
        regexes: [
          RegExp(r'(?:habit|routine)\s+(?:check|tracker|status)'),
          RegExp(r'(?:عاده|عادة|روتين)\s+(?:تتبع|شيك|حاله|حالة|تشيك)'),
          RegExp(r'(?:ازاي|كيف)\s+(?:عاداتي|روتيني)'),
          RegExp(r'(?:هل)\s+(?:خلّصت|عملت|ساويت)\s+(?:ال)?(?:عاده|عادة|روتين)'),
        ],
      ),
      _IntentPattern(
        type: IntentType.weeklyRetro,
        weight: 0.75,
        regexes: [
          RegExp(r'(?:weekly\s+)?retro(?:spective)?'),
          RegExp(r'(?:مراجعه|مراجعة)\s*(?:أسبوعي|اسبوعي|الأسبوع|الاسبوع)'),
          RegExp(r'(?:راجع|راجعي)\s+(?:الأسبوع|الاسبوع)'),
        ],
      ),
      _IntentPattern(
        type: IntentType.moodPattern,
        weight: 0.75,
        regexes: [
          RegExp(r'(?:mood|emotion|feeling)\s+(?:pattern|analysis|tracker|trend)'),
          RegExp(r'(?:مود|مزاج|احساس|إحساس)\s+(?:نمط|تحليل|تتبع|ترند)'),
          RegExp(r'(?:ازاي)\s+(?:مودي|مزاجي|احساسي)\s*(?:النهارده|اليوم)?'),
        ],
      ),
      _IntentPattern(
        type: IntentType.energyMapping,
        weight: 0.75,
        regexes: [
          RegExp(r'(?:energy|vitality|stamina)\s+(?:map|mapping|level|tracker)'),
          RegExp(r'(?:طاقه|طاقة|نشاط|حيويه|حيوية)\s+(?:خريطه|خريطة|مستوى|تتبع)'),
          RegExp(r'(?:ازاي|كيف)\s+(?:طاقتي|نشاطي|حيويتي)'),
        ],
      ),
      _IntentPattern(
        type: IntentType.financialAwareness,
        weight: 0.75,
        regexes: [
          RegExp(r'(?:finance|financial|money|budget|spending)\s+(?:awareness|tracker|summary|overview)'),
          RegExp(r'(?:ماليّه|مالية|فلوس|ميزانيه|ميزانية|مصاريف)\s+(?:تتبع|ملخص|نظره|نظرة|وعي)'),
          RegExp(r'(?:ازاي|كيف)\s+(?:ميزانيتي|فلوسي|مصاريفي)'),
        ],
      ),
      _IntentPattern(
        type: IntentType.contentMirror,
        weight: 0.75,
        regexes: [
          RegExp(r'(?:content|media|consumption)\s+(?:mirror|analysis|review)'),
          RegExp(r'(?:محتوى|محتوي|كوتنت)\s+(?:مرايه|مرآة|تحليل|مراجعه|مراجعة)'),
        ],
      ),
      _IntentPattern(
        type: IntentType.patternDetection,
        weight: 0.75,
        regexes: [
          RegExp(r'(?:pattern|behavior|behaviour)\s+(?:detection|analysis|insight)'),
          RegExp(r'(?:نمط|سلوك)\s+(?:كشف|تحليل|رؤيه|رؤية)'),
          RegExp(r'(?:ايه|ايش)\s+(?:النمط|الانماط|أنماط)\s*(?:بتاعي|الي|اللي)?'),
        ],
      ),

      // ─── Links & URLs ───────────────────────────────────────────────
      _IntentPattern(
        type: IntentType.openLink,
        weight: 0.9,
        regexes: [
          RegExp(r'(?:open|visit|go\s+to|navigate\s+to)\s+(https?://\S+)'),
          RegExp(r'(?:افتح|روح|اذهب)\s+(https?://\S+)'),
          RegExp(r'(https?://\S+)'),
        ],
      ),
      _IntentPattern(
        type: IntentType.fetchUrl,
        weight: 0.85,
        regexes: [
          RegExp(r'(?:fetch|get|retrieve|read|extract)\s+(?:content\s+)?(?:from|of)?\s*(https?://\S+)'),
          RegExp(r'(?:اجيب|جيب|نزّل|نزل|اقرأ|اقرا)\s+(?:محتوى|كوتنت)?\s*(?:من|عن)?\s*(https?://\S+)'),
        ],
      ),
      _IntentPattern(
        type: IntentType.fetchExtract,
        weight: 0.85,
        regexes: [
          RegExp(r'(?:extract|parse|scrape)\s+(?:data|info|text)?\s*(?:from)?\s*(https?://\S+)'),
          RegExp(r'(?:استخرج|استخلص|فرّز)\s+(?:بيانات|معلومات|نص)?\s*(?:من)?\s*(https?://\S+)'),
        ],
      ),

      // ─── Social Analysis ────────────────────────────────────────────
      _IntentPattern(
        type: IntentType.socialAnalysis,
        weight: 0.75,
        regexes: [
          RegExp(r'(?:social|relationship|people)\s+(?:analysis|insight|map)'),
          RegExp(r'(?:اجتماعي|علاقات|ناس)\s+(?:تحليل|رؤيه|رؤية|خريطه|خريطة)'),
          RegExp(r'(?:ازاي|كيف)\s+(?:علاقتي|علاقاتي)\s*(?:بالناس|بالناسس)?'),
        ],
      ),

      // ─── Deep Thinking ──────────────────────────────────────────────
      _IntentPattern(
        type: IntentType.thinkDeep,
        weight: 0.85,
        regexes: [
          RegExp(r'(?:think\s+deep|analyze\s+deeply|deep\s+thought|philosophize)\s*(?:about)?[:\s]*(.+)'),
          RegExp(r'(?:فكّر|فكر|تأمّل|تأمل)\s+(?:بعمق|عميق|كويس|جيداً)\s*(?:في|عن)?[:\s]*(.+)'),
          RegExp(r'(?:خلّيني|خليّني)\s+(?:افكر|أتأمل)\s+(?:بعمق|كويس)\s*(?:في)?[:\s]*(.+)'),
        ],
      ),
      _IntentPattern(
        type: IntentType.thinkDecision,
        weight: 0.85,
        regexes: [
          RegExp(r'(?:help\s+me\s+)?(?:decide|decision|choose|choice)\s*(?:about|between)?[:\s]*(.+)'),
          RegExp(r'(?:ساعدني|ساعدني\s+على)\s+(?:أقرر|اختار|أختار|اتخذ\s+قرار)\s*(?:في|بين)?[:\s]*(.+)'),
          RegExp(r'(?:ايه|ايش)\s+(?:أختار|اختار|الاحسن|الأحسن)\s*[:\s]*(.+)'),
        ],
      ),
      _IntentPattern(
        type: IntentType.thinkProblem,
        weight: 0.85,
        regexes: [
          RegExp(r'(?:solve|problem\s+solve|troubleshoot|debug)\s*(.+)'),
          RegExp(r'(?:حلّ|حل|حلل)\s+(?:مشكله|مشكلة|مسأله|مسألة|issue|bug)\s*[:\s]*(.+)'),
          RegExp(r'(?:ازاي|كيف)\s+(?:احل|أحل|أحلّ)\s*(?:المشكله|المشكلة)?[:\s]*(.+)'),
        ],
      ),
      _IntentPattern(
        type: IntentType.thinkReflect,
        weight: 0.8,
        regexes: [
          RegExp(r'(?:reflect|contemplate|mull\s+over)\s*(?:on|about)?[:\s]*(.+)'),
          RegExp(r'(?:تأمّل|تأمل|تفكّر|تفكر)\s*(?:في|عن)?[:\s]*(.+)'),
        ],
      ),

      // ─── Time ───────────────────────────────────────────────────────
      _IntentPattern(
        type: IntentType.timeInfo,
        weight: 0.8,
        regexes: [
          RegExp(r'(?:what\s+)?time\s+(?:is\s+it|now|currently)'),
          RegExp(r'(?:الساعه|الساعة)\s*(?:كام|اد ايه|كم)'),
          RegExp(r'(?:ايه|ايش)\s+(?:الساعه|الساعة|الوقت)'),
          RegExp(r'الوقت\s+(?:كام|اد ايه|كم)'),
        ],
      ),
      _IntentPattern(
        type: IntentType.timeSchedule,
        weight: 0.8,
        regexes: [
          RegExp(r'(?:schedule|agenda|calendar|itinerary)\s*(?:for\s+)?(?:today|tomorrow|this\s+week)?'),
          RegExp(r'(?:جدول|سكيول|اجنده|أجندة)\s*(?:اليوم|بكره|الاسبوع|الأسبوع)?'),
          RegExp(r'(?:ايه|ايش)\s+(?:جدولي|سكيولي)\s*(?:اليوم|بكره)?'),
        ],
      ),

      // ─── Git ────────────────────────────────────────────────────────
      _IntentPattern(
        type: IntentType.gitStatus,
        weight: 0.85,
        regexes: [
          RegExp(r'git\s+status'),
          RegExp(r'(?:حاله|حالة)\s+(?:ال)?(?:جيت|git|ريبو|repository)'),
          RegExp(r'git\s+(?:حاله|حالة)'),
        ],
      ),
      _IntentPattern(
        type: IntentType.gitNote,
        weight: 0.8,
        regexes: [
          RegExp(r'git\s+(?:note|comment|annotate)\s*(.+)'),
          RegExp(r'(?:ملاحظه|ملاحظة|كومنت)\s+(?:جيت|git)\s*(.+)'),
        ],
      ),
      _IntentPattern(
        type: IntentType.gitCommits,
        weight: 0.8,
        regexes: [
          RegExp(r'(?:git\s+)?(?:commits?|log|history)'),
          RegExp(r'(?:جيت|git)\s+(?:كوميت|commits?|log|سجل)'),
          RegExp(r'(?:سجل|تاريخ)\s+(?:ال)?(?:كوميت|commits?|جيت|git)'),
        ],
      ),

      // ─── Summarization ──────────────────────────────────────────────
      _IntentPattern(
        type: IntentType.summarize,
        weight: 0.8,
        regexes: [
          RegExp(r'(?:summarize|summarise|summary|tldr|tl;dr)\s*(.+)'),
          RegExp(r'(?:لخّص|لخص|ملخص|ملخّص)\s*(.+)'),
          RegExp(r'(?:اعمل|ساوي|خلي)\s+(?:ملخص|تلخيص)\s*(.+)'),
        ],
      ),
      _IntentPattern(
        type: IntentType.dailyDigest,
        weight: 0.75,
        regexes: [
          RegExp(r'(?:daily\s+)?digest'),
          RegExp(r'(?:دايجست|هضم)\s*(?:يومي)?'),
          RegExp(r'ملخص\s*(?:اليوم|النهارده)'),
        ],
      ),

      // ─── Email & Google Integration ─────────────────────────────────
      _IntentPattern(
        type: IntentType.sendGmail,
        weight: 0.85,
        regexes: [
          RegExp(r'(?:send|compose|write)\s+(?:an?\s+)?(?:email|mail|gmail|message)\s*(?:to|about)?[:\s]*(.+)'),
          RegExp(r'(?:ابعث|ابعت|ارسل|أرسل)\s+(?:ايميل|رساله|رسالة|جيميل|gmail)\s*(?:ل|عن)?[:\s]*(.+)'),
        ],
      ),
      _IntentPattern(
        type: IntentType.googleTasks,
        weight: 0.8,
        regexes: [
          RegExp(r'(?:google\s+)?tasks?\s*(?:list|add|create|show)?'),
          RegExp(r'(?:جوجل|google)\s+(?:تاسك|مهام|tasks?)'),
          RegExp(r'(?:مهامي|تاسكاتي)'),
        ],
      ),
      _IntentPattern(
        type: IntentType.googleCalendar,
        weight: 0.8,
        regexes: [
          RegExp(r'(?:google\s+)?calendar(?:\s+events?)?'),
          RegExp(r'(?:جوجل|google)\s+(?:تقويم|كالندر|calendar)'),
          RegExp(r'(?:تقويمي|كالندري)'),
        ],
      ),

      // ─── News ───────────────────────────────────────────────────────
      _IntentPattern(
        type: IntentType.newsPersonal,
        weight: 0.8,
        regexes: [
          RegExp(r'(?:my\s+)?(?:personalized|personal|custom)?\s*news'),
          RegExp(r'(?:اخباري|أخباري|نيوز\s*(?:شخصي|لي))'),
        ],
      ),
      _IntentPattern(
        type: IntentType.newsTrending,
        weight: 0.8,
        regexes: [
          RegExp(r'(?:trending|top|latest|breaking)\s+news'),
          RegExp(r'(?:اخبار|أخبار)\s+(?:ترند|رايجه|رائجة|اخيرة|أخيرة|عاجله|عاجلة)'),
          RegExp(r'(?:ايه|ايش)\s+(?:الاخبار|الأخبار|النيوز)'),
        ],
      ),
      _IntentPattern(
        type: IntentType.newsTech,
        weight: 0.8,
        regexes: [
          RegExp(r'(?:tech|technology)\s+news'),
          RegExp(r'(?:اخبار|أخبار)\s+(?:تكنولوجي|تقنيه|تقنية|تيك)'),
        ],
      ),

      // ─── Team ───────────────────────────────────────────────────────
      _IntentPattern(
        type: IntentType.teamTask,
        weight: 0.8,
        regexes: [
          RegExp(r'(?:team|group)\s+(?:task|tasks|assignment|todo)'),
          RegExp(r'(?:فريق|تيم)\s+(?:مهمه|مهمة|تاسك|مهام)'),
        ],
      ),

      // ─── Speech ─────────────────────────────────────────────────────
      _IntentPattern(
        type: IntentType.speak,
        weight: 0.8,
        regexes: [
          RegExp(r'(?:speak|say|read\s+aloud|pronounce)\s*(.+)',
              caseSensitive: false),
          RegExp(r'(?:قل|نطّق|نطق|اقرأ|اقرا)\s*(.+)'),
          RegExp(r'(?:انطق|نطّي)\s*(.+)'),
        ],
      ),

      // ─── Translation ────────────────────────────────────────────────
      _IntentPattern(
        type: IntentType.translate,
        weight: 0.85,
        regexes: [
          RegExp(r'(?:translate|trans)\s+(.+?)(?:\s+(?:to|into)\s+(\w+))?'),
          RegExp(r'(?:ترجم|ترجّم)\s+(.+?)(?:\s+(?:ل|الى|إلى)\s+(\w+))?'),
        ],
      ),

      // ─── Maps ───────────────────────────────────────────────────────
      _IntentPattern(
        type: IntentType.mapsSearch,
        weight: 0.85,
        regexes: [
          RegExp(r'(?:find|search|locate)\s+(.+?)\s+(?:on\s+)?(?:map|maps|location)'),
          RegExp(r'(?:map|maps|location)\s+(?:search|find)[:\s]*(.+)'),
          RegExp(r'(?:دور|ابحث|لقّي)\s+(.+?)\s+(?:على|في)\s*(?:الخريطه|الخريطة|ماب|خرائط)'),
          RegExp(r'(?:خريطه|خريطة|ماب)\s+(?:دور|ابحث)[:\s]*(.+)'),
        ],
      ),
      _IntentPattern(
        type: IntentType.mapsNearby,
        weight: 0.8,
        regexes: [
          RegExp(r'(?:nearby|near\s+me|close\s+by|around\s+me)\s*(\w+)?'),
          RegExp(r'(?:قريب|جمبي|حولّي|حولي)\s*(\w+)?'),
          RegExp(r'(?:اقرب|أقرب)\s*(\w+)?'),
        ],
      ),
      _IntentPattern(
        type: IntentType.mapsDirections,
        weight: 0.85,
        regexes: [
          RegExp(r'(?:directions|navigate|route|way)\s+(?:from\s+)?(.+?)(?:\s+to\s+(.+))?'),
          RegExp(r'(?:اتجاهات|نافيجيت|طريق|كيف\s+أروح)\s+(.+?)(?:\s+(?:ل|الى|إلى)\s+(.+))?'),
          RegExp(r'(?:ازاي|كيف)\s+(?:أروح|اروح|أوصّل|اوصل)\s+(.+?)(?:\s+(?:من)\s+(.+))?'),
        ],
      ),
      _IntentPattern(
        type: IntentType.mapsFood,
        weight: 0.8,
        regexes: [
          RegExp(r'(?:find|search)\s+(?:restaurants?|food|dining|cafes?|coffee)\s*(.*)?'),
          RegExp(r'(?:دور|ابحث)\s+(?:على|عن)\s+(?:مطعم|اكل|مأكولات|كافيه|قهوه|قهوة)\s*(.*)?'),
          RegExp(r'(?:اقرب|أقرب)\s+(?:مطعم|اكل|كافيه|مقهى)\s*(.*)?'),
        ],
      ),
    ];
  }
}

/// Intent types enum covering all supported intents.
enum IntentType {
  // Task management
  addTask,
  addAppointment,
  // YouTube
  youtubeSearch,
  youtubeRecommend,
  youtubeUnderstand,
  youtubeTrending,
  // App control
  openApp,
  // Web
  webSearch,
  openLink,
  // Ideas & Knowledge
  captureIdea,
  dailyBrief,
  goalDecomp,
  hardQuestions,
  reflection,
  // Habits & Patterns
  habitCheck,
  weeklyRetro,
  moodPattern,
  energyMapping,
  financialAwareness,
  contentMirror,
  patternDetection,
  socialAnalysis,
  // URLs
  fetchUrl,
  fetchExtract,
  // Deep thinking
  thinkDeep,
  thinkDecision,
  thinkProblem,
  thinkReflect,
  // Time
  timeInfo,
  timeSchedule,
  // Git
  gitStatus,
  gitNote,
  gitCommits,
  // Summarization
  summarize,
  dailyDigest,
  // Email & Google
  sendGmail,
  googleTasks,
  googleCalendar,
  // News
  newsPersonal,
  newsTrending,
  newsTech,
  // Team
  teamTask,
  // Speech
  speak,
  // Translation
  translate,
  // Maps
  mapsSearch,
  mapsNearby,
  mapsDirections,
  mapsFood,
  // Default
  unknown,
}

/// Result of intent detection.
class IntentResult {
  /// The detected intent type.
  final IntentType type;

  /// Extracted parameters from the input.
  final Map<String, dynamic> params;

  /// Confidence score between 0.0 and 1.0.
  final double confidence;

  const IntentResult({
    required this.type,
    required this.params,
    required this.confidence,
  });

  /// Whether this is a high-confidence detection.
  bool get isHighConfidence => confidence >= 0.7;

  /// Whether this is a medium-confidence detection.
  bool get isMediumConfidence => confidence >= 0.4 && confidence < 0.7;

  /// Whether this is a low-confidence detection.
  bool get isLowConfidence => confidence < 0.4;

  /// Human-readable intent name.
  String get intentName => type.name;

  @override
  String toString() =>
      'IntentResult(type: $type, confidence: ${confidence.toStringAsFixed(2)}, params: $params)';
}

/// Internal representation of an intent pattern with regexes and weight.
class _IntentPattern {
  final IntentType type;
  final double weight;
  final List<RegExp> regexes;

  const _IntentPattern({
    required this.type,
    required this.weight,
    required this.regexes,
  });
}
