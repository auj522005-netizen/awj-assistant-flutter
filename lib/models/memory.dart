/// ═══════════════════════════════════════════════════════════════════════════════
/// 🧠 OWJ Assistant — Memory & Knowledge Graph Models
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Models for persistent memory storage (Mem0) and knowledge graph
/// representation. These enable OWJ to remember user context across
/// conversations and build a structured understanding of the user's world.
///
/// Architecture:
///   - Memory: Individual memory entries with relevance scoring
///   - KnowledgeEntity: Named entities (people, places, concepts)
///   - KnowledgeRelation: Typed relationships between entities
///
/// ═══════════════════════════════════════════════════════════════════════════════

library;

import 'dart:convert';

// ─── Memory ──────────────────────────────────────────────────────────────────

/// A single memory entry stored via Mem0.
/// Represents a fact, preference, or context about the user.
class Memory {
  /// Unique identifier (from Mem0)
  final String id;

  /// The memory content (e.g., "المستخدم بيحب القهوة السودا")
  final String memory;

  /// Relevance score (0.0 to 1.0) — higher = more relevant
  final double score;

  /// When this memory was created
  final DateTime createdAt;

  /// When this memory was last updated
  final DateTime updatedAt;

  /// Additional metadata (source, context, tags, etc.)
  final MemoryMetadata metadata;

  const Memory({
    required this.id,
    required this.memory,
    this.score = 0.5,
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const MemoryMetadata(),
  });

  /// Whether this memory is highly relevant (score ≥ 0.8)
  bool get isHighlyRelevant => score >= 0.8;

  /// Whether this memory is outdated (score ≤ 0.2)
  bool get isOutdated => score <= 0.2;

  /// Age of this memory in days
  int get ageInDays => DateTime.now().difference(createdAt).inDays;

  /// Whether this memory was created recently (within 7 days)
  bool get isRecent => ageInDays <= 7;

  Memory copyWith({
    String? id,
    String? memory,
    double? score,
    DateTime? createdAt,
    DateTime? updatedAt,
    MemoryMetadata? metadata,
  }) {
    return Memory(
      id: id ?? this.id,
      memory: memory ?? this.memory,
      score: score ?? this.score,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  // ─── Serialization ──────────────────────────────────────────────────────

  factory Memory.fromJson(Map<String, dynamic> json) => Memory(
        id: json['id'] as String? ?? '',
        memory: json['memory'] as String? ?? '',
        score: (json['score'] as num?)?.toDouble() ?? 0.5,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : DateTime.now(),
        metadata: json['metadata'] != null
            ? MemoryMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
            : const MemoryMetadata(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'memory': memory,
        'score': score,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'metadata': metadata.toJson(),
      };

  factory Memory.fromJsonString(String source) =>
      Memory.fromJson(jsonDecode(source) as Map<String, dynamic>);

  String toJsonString() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Memory && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Memory(id: $id, score: $score, '
      'memory: ${memory.length > 40 ? '${memory.substring(0, 40)}...' : memory})';
}

/// Metadata associated with a memory entry.
class MemoryMetadata {
  /// Source of the memory (e.g., "chat", "user_input", "inferred")
  final String source;

  /// Category tag (e.g., "preference", "fact", "relationship", "routine")
  final String? category;

  /// Associated pillar ID (if any)
  final String? pillarId;

  /// Confidence level (0.0 to 1.0)
  final double confidence;

  /// Number of times this memory has been referenced
  final int referenceCount;

  /// Custom key-value metadata
  final Map<String, dynamic> extra;

  const MemoryMetadata({
    this.source = 'chat',
    this.category,
    this.pillarId,
    this.confidence = 1.0,
    this.referenceCount = 0,
    this.extra = const {},
  });

  MemoryMetadata copyWith({
    String? source,
    String? category,
    String? pillarId,
    double? confidence,
    int? referenceCount,
    Map<String, dynamic>? extra,
  }) {
    return MemoryMetadata(
      source: source ?? this.source,
      category: category ?? this.category,
      pillarId: pillarId ?? this.pillarId,
      confidence: confidence ?? this.confidence,
      referenceCount: referenceCount ?? this.referenceCount,
      extra: extra ?? this.extra,
    );
  }

  // ─── Serialization ──────────────────────────────────────────────────────

  factory MemoryMetadata.fromJson(Map<String, dynamic> json) => MemoryMetadata(
        source: json['source'] as String? ?? 'chat',
        category: json['category'] as String?,
        pillarId: json['pillarId'] as String?,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
        referenceCount: json['referenceCount'] as int? ?? 0,
        extra: json['extra'] as Map<String, dynamic>? ?? {},
      );

  Map<String, dynamic> toJson() => {
        'source': source,
        'category': category,
        'pillarId': pillarId,
        'confidence': confidence,
        'referenceCount': referenceCount,
        'extra': extra,
      };

  @override
  String toString() => 'MemoryMetadata(source: $source, category: $category)';
}

// ─── Knowledge Graph ─────────────────────────────────────────────────────────

/// Type of knowledge entity
enum EntityType {
  person,
  place,
  organization,
  concept,
  skill,
  event,
  hobby,
  other;

  String get labelAr {
    switch (this) {
      case EntityType.person:
        return 'شخص';
      case EntityType.place:
        return 'مكان';
      case EntityType.organization:
        return 'مؤسسة';
      case EntityType.concept:
        return 'مفهوم';
      case EntityType.skill:
        return 'مهارة';
      case EntityType.event:
        return 'حدث';
      case EntityType.hobby:
        return 'هواية';
      case EntityType.other:
        return 'أخرى';
    }
  }

  String get icon {
    switch (this) {
      case EntityType.person:
        return '👤';
      case EntityType.place:
        return '📍';
      case EntityType.organization:
        return '🏢';
      case EntityType.concept:
        return '💡';
      case EntityType.skill:
        return '🎯';
      case EntityType.event:
        return '📅';
      case EntityType.hobby:
        return '🎮';
      case EntityType.other:
        return '📌';
    }
  }
}

/// A named entity in the knowledge graph.
/// Represents people, places, concepts, etc. that OWJ knows about the user.
class KnowledgeEntity {
  /// Entity name (e.g., "أحمد", "القاهرة", "البرمجة")
  final String name;

  /// Entity type
  final EntityType type;

  /// List of observations/facts about this entity
  final List<String> observations;

  /// Optional: When this entity was first mentioned
  final DateTime? firstMentioned;

  /// Optional: When this entity was last mentioned
  final DateTime? lastMentioned;

  /// Optional: Mention count
  final int mentionCount;

  const KnowledgeEntity({
    required this.name,
    this.type = EntityType.other,
    this.observations = const [],
    this.firstMentioned,
    this.lastMentioned,
    this.mentionCount = 0,
  });

  /// Add an observation to this entity
  KnowledgeEntity addObservation(String observation) => copyWith(
        observations: [...observations, observation],
        lastMentioned: DateTime.now(),
        mentionCount: mentionCount + 1,
      );

  KnowledgeEntity copyWith({
    String? name,
    EntityType? type,
    List<String>? observations,
    DateTime? firstMentioned,
    DateTime? lastMentioned,
    int? mentionCount,
  }) {
    return KnowledgeEntity(
      name: name ?? this.name,
      type: type ?? this.type,
      observations: observations ?? this.observations,
      firstMentioned: firstMentioned ?? this.firstMentioned,
      lastMentioned: lastMentioned ?? this.lastMentioned,
      mentionCount: mentionCount ?? this.mentionCount,
    );
  }

  // ─── Serialization ──────────────────────────────────────────────────────

  factory KnowledgeEntity.fromJson(Map<String, dynamic> json) => KnowledgeEntity(
        name: json['name'] as String? ?? '',
        type: EntityType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => EntityType.other,
        ),
        observations: (json['observations'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        firstMentioned: json['firstMentioned'] != null
            ? DateTime.parse(json['firstMentioned'] as String)
            : null,
        lastMentioned: json['lastMentioned'] != null
            ? DateTime.parse(json['lastMentioned'] as String)
            : null,
        mentionCount: json['mentionCount'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.name,
        'observations': observations,
        'firstMentioned': firstMentioned?.toIso8601String(),
        'lastMentioned': lastMentioned?.toIso8601String(),
        'mentionCount': mentionCount,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KnowledgeEntity && name == other.name && type == other.type;

  @override
  int get hashCode => Object.hash(name, type);

  @override
  String toString() => 'KnowledgeEntity(${type.labelAr}: $name, '
      'observations: ${observations.length})';
}

/// A typed relationship between two knowledge entities.
class KnowledgeRelation {
  /// Source entity name
  final String from;

  /// Target entity name
  final String to;

  /// Relationship type (e.g., "يعمل في", "صديق", "يحب")
  final String relationType;

  /// Optional: Confidence score (0.0 to 1.0)
  final double confidence;

  /// Optional: When this relation was established
  final DateTime? establishedAt;

  const KnowledgeRelation({
    required this.from,
    required this.to,
    required this.relationType,
    this.confidence = 1.0,
    this.establishedAt,
  });

  /// Human-readable description in Arabic
  String get descriptionAr => '$from $relationType $to';

  KnowledgeRelation copyWith({
    String? from,
    String? to,
    String? relationType,
    double? confidence,
    DateTime? establishedAt,
  }) {
    return KnowledgeRelation(
      from: from ?? this.from,
      to: to ?? this.to,
      relationType: relationType ?? this.relationType,
      confidence: confidence ?? this.confidence,
      establishedAt: establishedAt ?? this.establishedAt,
    );
  }

  // ─── Serialization ──────────────────────────────────────────────────────

  factory KnowledgeRelation.fromJson(Map<String, dynamic> json) =>
      KnowledgeRelation(
        from: json['from'] as String? ?? '',
        to: json['to'] as String? ?? '',
        relationType: json['relationType'] as String? ?? '',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
        establishedAt: json['establishedAt'] != null
            ? DateTime.parse(json['establishedAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'relationType': relationType,
        'confidence': confidence,
        'establishedAt': establishedAt?.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KnowledgeRelation &&
          from == other.from &&
          to == other.to &&
          relationType == other.relationType;

  @override
  int get hashCode => Object.hash(from, to, relationType);

  @override
  String toString() => 'KnowledgeRelation($descriptionAr)';
}
