/// ═══════════════════════════════════════════════════════════════════════════════
/// 🎭 OWJ Assistant — Character Model
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// AI character/persona model for creating custom AI assistants with
/// unique personalities, skills, and file attachments.
///
/// Users can create characters like:
///   - "المعلم" (The Teacher) — Patient, educational
///   - "المبرمج" (The Programmer) — Technical, code-focused
///   - "الكاتب" (The Writer) — Creative, eloquent
///   - "المستشار" (The Advisor) — Wise, strategic
///
/// ═══════════════════════════════════════════════════════════════════════════════

library;

import 'dart:convert';

/// A skill attached to a character (e.g., "code review", "translation")
class CharacterSkill {
  /// Skill name (e.g., "مراجعة كود", "ترجمة")
  final String name;

  /// System prompt fragment that activates this skill
  final String prompt;

  /// Optional: File name (e.g., "style_guide.md")
  final String? fileName;

  /// Optional: File content (text data for the skill)
  final String? fileContent;

  /// Optional: Additional file attachments (name → content)
  final Map<String, String> files;

  const CharacterSkill({
    required this.name,
    required this.prompt,
    this.fileName,
    this.fileContent,
    this.files = const {},
  });

  /// Whether this skill has file attachments
  bool get hasFiles => fileName != null || files.isNotEmpty;

  CharacterSkill copyWith({
    String? name,
    String? prompt,
    String? fileName,
    String? fileContent,
    Map<String, String>? files,
  }) {
    return CharacterSkill(
      name: name ?? this.name,
      prompt: prompt ?? this.prompt,
      fileName: fileName ?? this.fileName,
      fileContent: fileContent ?? this.fileContent,
      files: files ?? this.files,
    );
  }

  // ─── Serialization ──────────────────────────────────────────────────────

  factory CharacterSkill.fromJson(Map<String, dynamic> json) => CharacterSkill(
        name: json['name'] as String? ?? '',
        prompt: json['prompt'] as String? ?? '',
        fileName: json['fileName'] as String?,
        fileContent: json['fileContent'] as String?,
        files: (json['files'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v as String)) ??
            {},
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'prompt': prompt,
        'fileName': fileName,
        'fileContent': fileContent,
        'files': files,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterSkill && name == other.name && prompt == other.prompt;

  @override
  int get hashCode => Object.hash(name, prompt);

  @override
  String toString() => 'CharacterSkill(name: $name)';
}

/// A custom AI character/persona.
class Character {
  /// Unique identifier
  final String id;

  /// Display name (e.g., "المعلم", "المبرمج")
  final String name;

  /// Emoji avatar (e.g., "👨‍🏫", "💻")
  final String emoji;

  /// Personality description (system prompt fragment)
  final String personality;

  /// Skills attached to this character
  final List<CharacterSkill> skills;

  /// When this character was created
  final DateTime createdAt;

  /// Optional: Last time this character was used
  final DateTime? lastUsedAt;

  /// Optional: Number of conversations with this character
  final int conversationCount;

  /// Optional: Color theme hex for this character
  final String? colorHex;

  /// Optional: Whether this is a built-in character (not user-created)
  final bool isBuiltIn;

  const Character({
    required this.id,
    required this.name,
    this.emoji = '🤖',
    this.personality = '',
    this.skills = const [],
    required this.createdAt,
    this.lastUsedAt,
    this.conversationCount = 0,
    this.colorHex,
    this.isBuiltIn = false,
  });

  /// Full system prompt combining personality and skill prompts
  String get fullSystemPrompt {
    final parts = <String>[];

    // Base personality
    if (personality.isNotEmpty) {
      parts.add(personality);
    }

    // Skill prompts
    for (final skill in skills) {
      parts.add('## مهارة: ${skill.name}\n${skill.prompt}');
      if (skill.fileContent != null && skill.fileContent!.isNotEmpty) {
        parts.add('### محتوى ملف ${skill.fileName ?? "مرفق"}:\n${skill.fileContent}');
      }
      for (final entry in skill.files.entries) {
        parts.add('### ملف ${entry.key}:\n${entry.value}');
      }
    }

    return parts.join('\n\n');
  }

  /// Whether this character has any skills
  bool get hasSkills => skills.isNotEmpty;

  /// Skill names as a comma-separated Arabic string
  String get skillNamesAr => skills.map((s) => s.name).join('، ');

  /// Mark this character as used (increments conversation count)
  Character markUsed() => copyWith(
        lastUsedAt: DateTime.now(),
        conversationCount: conversationCount + 1,
      );

  Character copyWith({
    String? id,
    String? name,
    String? emoji,
    String? personality,
    List<CharacterSkill>? skills,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    int? conversationCount,
    String? colorHex,
    bool? isBuiltIn,
  }) {
    return Character(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      personality: personality ?? this.personality,
      skills: skills ?? this.skills,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      conversationCount: conversationCount ?? this.conversationCount,
      colorHex: colorHex ?? this.colorHex,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  // ─── Serialization ──────────────────────────────────────────────────────

  factory Character.fromJson(Map<String, dynamic> json) => Character(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '🤖',
        personality: json['personality'] as String? ?? '',
        skills: (json['skills'] as List<dynamic>?)
                ?.map((e) => CharacterSkill.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        lastUsedAt: json['lastUsedAt'] != null
            ? DateTime.parse(json['lastUsedAt'] as String)
            : null,
        conversationCount: json['conversationCount'] as int? ?? 0,
        colorHex: json['colorHex'] as String?,
        isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'personality': personality,
        'skills': skills.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'lastUsedAt': lastUsedAt?.toIso8601String(),
        'conversationCount': conversationCount,
        'colorHex': colorHex,
        'isBuiltIn': isBuiltIn,
      };

  factory Character.fromJsonString(String source) =>
      Character.fromJson(jsonDecode(source) as Map<String, dynamic>);

  String toJsonString() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Character && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Character(id: $id, name: $name, skills: ${skills.length})';
}

/// Default built-in characters for new users.
List<Character> getDefaultCharacters() {
  final now = DateTime.now();
  return [
    Character(
      id: 'owj-default',
      name: 'أوج',
      emoji: '🌟',
      personality:
          'أنت أوج، المساعد الذكي المصري. بتتكلم بالمصري بطريقة طبيعية وودودة. بتحب تساعد الناس وبتكون صبور ومتفهم. دايماً بتحاول تقدم حلول عملية وبسيطة.',
      isBuiltIn: true,
      colorHex: '#FFB300',
      createdAt: now,
    ),
    Character(
      id: 'teacher',
      name: 'المعلم',
      emoji: '👨‍🏫',
      personality:
          'أنت معلم صبور وخبير. بتحب تشرح الحاجات خطوة بخطوة وبأمثلة بسيطة. بتستخدم لغة مصري واضحة وبتتأكد إن اللي بيتعلم فهم كويس قبل ما تمشي.',
      isBuiltIn: true,
      colorHex: '#22C55E',
      createdAt: now,
    ),
    Character(
      id: 'programmer',
      name: 'المبرمج',
      emoji: '💻',
      personality:
          'أنت مبرمج خبير. بتكتب كود نظيف وموثوق. بتحب تشرح الكود بطريقة مبسطة وبتقدم حلول عملية. بتتكلم مصري بس الكود بالإنجليزي.',
      skills: [
        CharacterSkill(
          name: 'مراجعة كود',
          prompt: 'راجع الكود المُدخل واقترح تحسينات مع شرح بالعربي.',
        ),
      ],
      isBuiltIn: true,
      colorHex: '#3B82F6',
      createdAt: now,
    ),
    Character(
      id: 'writer',
      name: 'الكاتب',
      emoji: '✍️',
      personality:
          'أنت كاتب مبدع وبليغ. بتكتب بمصري فصيح وبتعرف توصل الفكرة بشكل جميل. بتحب الشعر والأدب وبتقدر الكلمة الحلوة.',
      isBuiltIn: true,
      colorHex: '#8B5CF6',
      createdAt: now,
    ),
    Character(
      id: 'advisor',
      name: 'المستشار',
      emoji: '🎯',
      personality:
          'أنت مستشار حكيم وذو خبرة. بتحلل المواقف بهدوء وبتقدم نصائح عملية ومتوازنة. بتشوف الصورة الكبيرة وبتساعد الناس تاخد قرارات صح.',
      isBuiltIn: true,
      colorHex: '#EC4899',
      createdAt: now,
    ),
  ];
}
