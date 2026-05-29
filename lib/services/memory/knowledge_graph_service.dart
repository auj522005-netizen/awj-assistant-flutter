import 'dart:convert';
import 'dart:io';
import 'package:owj_assistant/services/storage_service.dart';

/// Knowledge Graph service compatible with MCP Memory Server.
///
/// Stores entities (name, type, observations) and relations
/// (from, to, relationType). Persists to a JSON file.
/// Supports auto-learning from conversations by extracting
/// preferences, goals, and struggles using regex patterns.
class KnowledgeGraphService {
  KnowledgeGraphService({StorageService? storage})
      : _storage = storage ?? StorageService.instance;

  final StorageService _storage;

  static const _graphKey = 'knowledge_graph';
  static const _entityPrefix = 'kg_entity_';
  static const _relationPrefix = 'kg_relation_';

  // ── Public API ──

  /// Adds an entity to the knowledge graph.
  Future<Entity> addEntity({
    required String name,
    required String entityType,
    List<String> observations = const [],
  }) async {
    final graph = await _loadGraph();
    final id = 'e_${DateTime.now().millisecondsSinceEpoch}';

    // Check for existing entity with same name and type
    final existing = graph.entities.where(
      (e) => e.name.toLowerCase() == name.toLowerCase() && e.type == entityType,
    );

    if (existing.isNotEmpty) {
      // Merge observations into existing entity
      final entity = existing.first;
      final mergedObs = {...entity.observations, ...observations}.toList();
      final updated = entity.copyWith(observations: mergedObs);
      graph.entities.remove(entity);
      graph.entities.add(updated);
      await _saveGraph(graph);
      return updated;
    }

    final entity = Entity(
      id: id,
      name: name,
      type: entityType,
      observations: observations,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    graph.entities.add(entity);
    await _saveGraph(graph);
    return entity;
  }

  /// Adds a relation between two entities.
  Future<Relation> addRelation({
    required String from,
    required String to,
    required String relationType,
  }) async {
    final graph = await _loadGraph();

    // Check for duplicate relation
    final exists = graph.relations.any(
      (r) => r.from == from && r.to == to && r.relationType == relationType,
    );
    if (exists) {
      throw KGException('Relation already exists: $from -$relationType-> $to');
    }

    // Verify both entities exist
    final fromExists = graph.entities.any((e) => e.id == from || e.name == from);
    final toExists = graph.entities.any((e) => e.id == to || e.name == to);

    if (!fromExists || !toExists) {
      throw KGException('One or both entities not found: from=$from, to=$to');
    }

    // Resolve names to IDs
    final fromId = _resolveEntityId(graph, from);
    final toId = _resolveEntityId(graph, to);

    final id = 'r_${DateTime.now().millisecondsSinceEpoch}';
    final relation = Relation(
      id: id,
      from: fromId,
      to: toId,
      relationType: relationType,
      createdAt: DateTime.now(),
    );

    graph.relations.add(relation);
    await _saveGraph(graph);
    return relation;
  }

  /// Adds an observation to an existing entity.
  Future<Entity> addObservation(String entityName, String observation) async {
    final graph = await _loadGraph();
    final entity = graph.entities.firstWhere(
      (e) => e.name.toLowerCase() == entityName.toLowerCase(),
      orElse: () => throw KGException('Entity not found: $entityName'),
    );

    if (entity.observations.contains(observation)) {
      return entity; // Already observed
    }

    final updated = entity.copyWith(
      observations: [...entity.observations, observation],
      updatedAt: DateTime.now(),
    );

    graph.entities.remove(entity);
    graph.entities.add(updated);
    await _saveGraph(graph);
    return updated;
  }

  /// Searches entities by name, type, or observations.
  Future<List<Entity>> searchEntities(String query) async {
    final graph = await _loadGraph();
    final lower = query.toLowerCase();

    return graph.entities.where((e) {
      if (e.name.toLowerCase().contains(lower)) return true;
      if (e.type.toLowerCase().contains(lower)) return true;
      if (e.observations.any((o) => o.toLowerCase().contains(lower))) return true;
      return false;
    }).toList();
  }

  /// Gets all relations for an entity.
  Future<List<Relation>> getEntityRelations(String entityIdOrName) async {
    final graph = await _loadGraph();
    final id = _resolveEntityId(graph, entityIdOrName);

    return graph.relations.where((r) => r.from == id || r.to == id).toList();
  }

  /// Formats the knowledge graph for injection into a system prompt.
  ///
  /// Produces a structured text representation that can be appended
  /// to any LLM system prompt for context.
  Future<String> formatForContext({int maxEntities = 30}) async {
    final graph = await _loadGraph();

    if (graph.entities.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('═══ معرفة المستخدم ═══');
    buffer.writeln();

    // Group entities by type
    final byType = <String, List<Entity>>{};
    for (final entity in graph.entities.take(maxEntities)) {
      byType.putIfAbsent(entity.type, () => []).add(entity);
    }

    for (final entry in byType.entries) {
      buffer.writeln('── ${entry.key} ──');
      for (final entity in entry.value) {
        buffer.writeln('• ${entity.name}');
        for (final obs in entity.observations) {
          buffer.writeln('  - $obs');
        }
      }
      buffer.writeln();
    }

    // Include key relations
    if (graph.relations.isNotEmpty) {
      buffer.writeln('── العلاقات ──');
      for (final relation in graph.relations.take(20)) {
        final fromName = _getEntityName(graph, relation.from);
        final toName = _getEntityName(graph, relation.to);
        buffer.writeln('• $fromName → ${relation.relationType} → $toName');
      }
    }

    return buffer.toString();
  }

  /// Auto-learns from a conversation by extracting preferences,
  /// goals, and struggles using regex patterns.
  Future<void> autoLearnFromConversation(String conversationText) async {
    // Extract preferences
    await _extractPreferences(conversationText);
    // Extract goals
    await _extractGoals(conversationText);
    // Extract struggles
    await _extractStruggles(conversationText);
    // Extract interests
    await _extractInterests(conversationText);
  }

  /// Gets statistics about the knowledge graph.
  Future<KGStats> getStats() async {
    final graph = await _loadGraph();

    final typeCounts = <String, int>{};
    for (final entity in graph.entities) {
      typeCounts[entity.type] = (typeCounts[entity.type] ?? 0) + 1;
    }

    return KGStats(
      entityCount: graph.entities.length,
      relationCount: graph.relations.length,
      entityTypeCounts: typeCounts,
      totalObservations: graph.entities.fold(0, (sum, e) => sum + e.observations.length),
    );
  }

  /// Clears the entire knowledge graph.
  Future<void> clearGraph() async {
    await _storage.delete(_graphKey);
  }

  // ── Auto-learning extractors ──

  Future<void> _extractPreferences(String text) async {
    // Arabic preference patterns
    final arPatterns = [
      RegExp(r'أحب\s+(.+?)(?:\.|،|$)', caseSensitive: false),
      RegExp(r'بحب\s+(.+?)(?:\.|،|$)', caseSensitive: false),
      RegExp(r'بفضل\s+(.+?)(?:\.|،|$)', caseSensitive: false),
      RegExp(r'أفضل\s+(.+?)(?:\.|،|$)', caseSensitive: false),
      RegExp(r'عاجبني\s+(.+?)(?:\.|،|$)', caseSensitive: false),
    ];

    // English preference patterns
    final enPatterns = [
      RegExp(r'I (?:like|love|enjoy|prefer)\s+(.+?)(?:\.|,|$)', caseSensitive: false),
      RegExp(r'my favorite\s+(.+?)(?:is|are)\s+(.+?)(?:\.|,|$)', caseSensitive: false),
    ];

    for (final pattern in [...arPatterns, ...enPatterns]) {
      for (final match in pattern.allMatches(text)) {
        final preference = match.group(1)?.trim();
        if (preference != null && preference.length > 2) {
          await addEntity(
            name: preference,
            entityType: 'Preference',
            observations: ['المستخدم يفضل: $preference'],
          );
        }
      }
    }
  }

  Future<void> _extractGoals(String text) async {
    final patterns = [
      RegExp(r'أريد\s+(.+?)(?:\.|،|$)', caseSensitive: false),
      RegExp(r'هدفي\s+(.+?)(?:\.|،|$)', caseSensitive: false),
      RegExp(r'بدي\s+(.+?)(?:\.|،|$)', caseSensitive: false),
      RegExp(r'نويّة\s+(.+?)(?:\.|،|$)', caseSensitive: false),
      RegExp(r'I want to\s+(.+?)(?:\.|,|$)', caseSensitive: false),
      RegExp(r'my goal is\s+(.+?)(?:\.|,|$)', caseSensitive: false),
      RegExp(r'I plan to\s+(.+?)(?:\.|,|$)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      for (final match in pattern.allMatches(text)) {
        final goal = match.group(1)?.trim();
        if (goal != null && goal.length > 2) {
          await addEntity(
            name: goal,
            entityType: 'Goal',
            observations: ['هدف المستخدم: $goal'],
          );

          // Link to user entity
          final userEntity = await _ensureUserEntity();
          try {
            await addRelation(
              from: userEntity.name,
              to: goal,
              relationType: 'has_goal',
            );
          } catch (_) {}
        }
      }
    }
  }

  Future<void> _extractStruggles(String text) async {
    final patterns = [
      RegExp(r'مشكلتي\s+(.+?)(?:\.|،|$)', caseSensitive: false),
      RegExp(r'بعاني من\s+(.+?)(?:\.|،|$)', caseSensitive: false),
      RegExp(r'صعب علي\s+(.+?)(?:\.|،|$)', caseSensitive: false),
      RegExp(r'مش قادر\s+(.+?)(?:\.|،|$)', caseSensitive: false),
      RegExp(r'I struggle with\s+(.+?)(?:\.|,|$)', caseSensitive: false),
      RegExp(r"I can't\s+(.+?)(?:\.|,|$)", caseSensitive: false),
      RegExp(r"it's hard (?:for me )?to\s+(.+?)(?:\.|,|$)", caseSensitive: false),
    ];

    for (final pattern in patterns) {
      for (final match in pattern.allMatches(text)) {
        final struggle = match.group(1)?.trim();
        if (struggle != null && struggle.length > 2) {
          await addEntity(
            name: struggle,
            entityType: 'Struggle',
            observations: ['يعاني المستخدم من: $struggle'],
          );
        }
      }
    }
  }

  Future<void> _extractInterests(String text) async {
    final patterns = [
      RegExp(r'مهتم بـ?\s*(.+?)(?:\.|،|$)', caseSensitive: false),
      RegExp(r'بتهتم بـ?\s*(.+?)(?:\.|،|$)', caseSensitive: false),
      RegExp(r"I'm interested in\s+(.+?)(?:\.|,|$)", caseSensitive: false),
      RegExp(r"I'm into\s+(.+?)(?:\.|,|$)", caseSensitive: false),
    ];

    for (final pattern in patterns) {
      for (final match in pattern.allMatches(text)) {
        final interest = match.group(1)?.trim();
        if (interest != null && interest.length > 2) {
          await addEntity(
            name: interest,
            entityType: 'Interest',
            observations: ['المستخدم مهتم بـ: $interest'],
          );
        }
      }
    }
  }

  // ── Internal helpers ──

  Future<Entity> _ensureUserEntity() async {
    final graph = await _loadGraph();
    final existing = graph.entities.where((e) => e.type == 'User');
    if (existing.isNotEmpty) return existing.first;

    return addEntity(name: 'المستخدم', entityType: 'User');
  }

  String _resolveEntityId(KnowledgeGraph graph, String idOrName) {
    // If it's already an ID, return it
    if (graph.entities.any((e) => e.id == idOrName)) return idOrName;

    // Try to find by name
    final entity = graph.entities.firstWhere(
      (e) => e.name.toLowerCase() == idOrName.toLowerCase(),
      orElse: () => throw KGException('Entity not found: $idOrName'),
    );
    return entity.id;
  }

  String _getEntityName(KnowledgeGraph graph, String id) {
    final entity = graph.entities.where((e) => e.id == id);
    return entity.isNotEmpty ? entity.first.name : id;
  }

  Future<KnowledgeGraph> _loadGraph() async {
    final json = _storage.getJson(_graphKey);
    if (json == null) return KnowledgeGraph(entities: [], relations: []);

    final entities = (json['entities'] as List<dynamic>? ?? [])
        .map((e) => Entity.fromJson(e as Map<String, dynamic>))
        .toList();

    final relations = (json['relations'] as List<dynamic>? ?? [])
        .map((r) => Relation.fromJson(r as Map<String, dynamic>))
        .toList();

    return KnowledgeGraph(entities: entities, relations: relations);
  }

  Future<void> _saveGraph(KnowledgeGraph graph) async {
    await _storage.setJson(_graphKey, graph.toJson());
  }
}

// ── Data models ──

class KnowledgeGraph {
  final List<Entity> entities;
  final List<Relation> relations;

  const KnowledgeGraph({required this.entities, required this.relations});

  Map<String, dynamic> toJson() => {
    'entities': entities.map((e) => e.toJson()).toList(),
    'relations': relations.map((r) => r.toJson()).toList(),
  };
}

class Entity {
  final String id;
  final String name;
  final String type;
  final List<String> observations;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Entity({
    required this.id,
    required this.name,
    required this.type,
    required this.observations,
    required this.createdAt,
    required this.updatedAt,
  });

  Entity copyWith({
    String? name,
    String? type,
    List<String>? observations,
    DateTime? updatedAt,
  }) =>
      Entity(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        observations: observations ?? this.observations,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  factory Entity.fromJson(Map<String, dynamic> json) => Entity(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    type: json['type'] as String? ?? '',
    observations: (json['observations'] as List<dynamic>? ?? []).cast<String>(),
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'observations': observations,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

class Relation {
  final String id;
  final String from;
  final String to;
  final String relationType;
  final DateTime createdAt;

  const Relation({
    required this.id,
    required this.from,
    required this.to,
    required this.relationType,
    required this.createdAt,
  });

  factory Relation.fromJson(Map<String, dynamic> json) => Relation(
    id: json['id'] as String? ?? '',
    from: json['from'] as String? ?? '',
    to: json['to'] as String? ?? '',
    relationType: json['relationType'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'from': from,
    'to': to,
    'relationType': relationType,
    'createdAt': createdAt.toIso8601String(),
  };
}

class KGStats {
  final int entityCount;
  final int relationCount;
  final Map<String, int> entityTypeCounts;
  final int totalObservations;

  const KGStats({
    required this.entityCount,
    required this.relationCount,
    required this.entityTypeCounts,
    required this.totalObservations,
  });
}

class KGException implements Exception {
  final String message;
  KGException(this.message);
  @override
  String toString() => 'KGException: $message';
}
