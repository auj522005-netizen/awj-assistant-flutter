import 'dart:convert';

import 'package:owj_assistant/services/storage_service.dart';

/// MCP Memory service compatible with the official MCP Memory Server format.
///
/// Stores entities (name, entityType, observations[]) and relations
/// (from, to, relationType) in JSONL format. Persists via [StorageService].
///
/// Compatible with @modelcontextprotocol/server-memory format, supporting:
///   - Entity creation with typed observations
///   - Directed relations between entities
///   - Full-text search across entity names and observations
///   - Graph read/reset operations
///
/// All user-facing strings are in Egyptian Arabic.
class McpMemoryService {
  McpMemoryService({StorageService? storage})
      : _storage = storage ?? StorageService.instance;

  final StorageService _storage;

  /// Storage keys
  static const _entitiesKey = 'mcp_memory_entities';
  static const _relationsKey = 'mcp_memory_relations';
  static const _jsonlLogKey = 'mcp_memory_jsonl';

  /// In-memory cache of the knowledge graph.
  MemoryGraph? _graphCache;

  // ── Entity Operations ─────────────────────────────────────────────────

  /// Create new entities in the knowledge graph.
  ///
  /// Each entity must have a unique name. If an entity with the same
  /// name already exists, its observations are merged.
  ///
  /// Returns the list of created/updated entities.
  Future<List<MemoryEntity>> createEntities(
    List<CreateEntityInput> entities,
  ) async {
    final graph = await _loadGraph();

    for (final input in entities) {
      final existing = graph.entities[input.name];
      if (existing != null) {
        // Merge observations (avoid duplicates)
        final existingObs = existing.observations.toSet();
        for (final obs in input.observations) {
          if (!existingObs.contains(obs)) {
            existing.observations.add(obs);
          }
        }
        // Update entity type if provided
        if (input.entityType != null && input.entityType!.isNotEmpty) {
          existing.entityType = input.entityType!;
        }
      } else {
        // Create new entity
        graph.entities[input.name] = MemoryEntity(
          name: input.name,
          entityType: input.entityType ?? 'thing',
          observations: List.from(input.observations),
        );
      }
    }

    await _saveGraph(graph);
    await _appendJsonl('create_entities', {
      'entities': entities.map((e) => e.toJson()).toList(),
    });

    return entities
        .map((e) => graph.entities[e.name]!)
        .toList();
  }

  /// Add observations to an existing entity.
  ///
  /// Returns the updated entity, or throws if not found.
  Future<MemoryEntity> addObservations(
    String entityName,
    List<String> contents,
  ) async {
    final graph = await _loadGraph();
    final entity = graph.entities[entityName];

    if (entity == null) {
      throw MemoryException(
        'الكيان "$entityName" مش موجود في الذاكرة 🧠',
      );
    }

    final existingObs = entity.observations.toSet();
    for (final obs in contents) {
      if (!existingObs.contains(obs)) {
        entity.observations.add(obs);
      }
    }

    await _saveGraph(graph);
    await _appendJsonl('add_observations', {
      'entityName': entityName,
      'contents': contents,
    });

    return entity;
  }

  /// Search entities by query string.
  ///
  /// Searches entity names, types, and observations for matches.
  /// Returns entities sorted by relevance score.
  Future<List<MemoryEntity>> searchNodes(String query) async {
    final graph = await _loadGraph();
    final normalizedQuery = query.toLowerCase();
    final results = <_ScoredEntity>[];

    for (final entity in graph.entities.values) {
      double score = 0;

      // Name match (highest weight)
      if (entity.name.toLowerCase().contains(normalizedQuery)) {
        score += 3.0;
        // Exact name match bonus
        if (entity.name.toLowerCase() == normalizedQuery) {
          score += 2.0;
        }
      }

      // Entity type match
      if (entity.entityType.toLowerCase().contains(normalizedQuery)) {
        score += 1.5;
      }

      // Observation match
      for (final obs in entity.observations) {
        if (obs.toLowerCase().contains(normalizedQuery)) {
          score += 1.0;
        }
      }

      if (score > 0) {
        results.add(_ScoredEntity(entity: entity, score: score));
      }
    }

    // Sort by score descending
    results.sort((a, b) => b.score.compareTo(a.score));

    await _appendJsonl('search_nodes', {
      'query': query,
      'resultCount': results.length,
    });

    return results.map((r) => r.entity).toList();
  }

  /// Get specific entities by their names.
  ///
  /// Returns only entities that exist. Missing names are silently skipped.
  Future<List<MemoryEntity>> openNodes(List<String> names) async {
    final graph = await _loadGraph();
    final results = <MemoryEntity>[];

    for (final name in names) {
      final entity = graph.entities[name];
      if (entity != null) {
        results.add(entity);
      }
    }

    return results;
  }

  /// Delete entities by name.
  ///
  /// Also removes any relations connected to the deleted entities.
  /// Returns the number of entities deleted.
  Future<int> deleteEntities(List<String> names) async {
    final graph = await _loadGraph();
    final nameSet = names.toSet();
    int deletedCount = 0;

    for (final name in nameSet) {
      if (graph.entities.remove(name) != null) {
        deletedCount++;
      }
    }

    // Remove relations connected to deleted entities
    graph.relations.removeWhere((rel) =>
        nameSet.contains(rel.from) || nameSet.contains(rel.to));

    await _saveGraph(graph);
    await _appendJsonl('delete_entities', {
      'names': names,
      'deletedCount': deletedCount,
    });

    return deletedCount;
  }

  /// Delete specific observations from an entity.
  ///
  /// Returns the number of observations removed.
  Future<int> deleteObservations(
    String entityName,
    List<String> observations,
  ) async {
    final graph = await _loadGraph();
    final entity = graph.entities[entityName];

    if (entity == null) {
      throw MemoryException(
        'الكيان "$entityName" مش موجود في الذاكرة 🧠',
      );
    }

    final obsSet = observations.toSet();
    final initialLength = entity.observations.length;
    entity.observations.removeWhere((obs) => obsSet.contains(obs));
    final removedCount = initialLength - entity.observations.length;

    // Remove entity if no observations left
    if (entity.observations.isEmpty) {
      graph.entities.remove(entityName);
      graph.relations.removeWhere(
          (rel) => rel.from == entityName || rel.to == entityName);
    }

    await _saveGraph(graph);
    await _appendJsonl('delete_observations', {
      'entityName': entityName,
      'observations': observations,
      'removedCount': removedCount,
    });

    return removedCount;
  }

  // ── Relation Operations ───────────────────────────────────────────────

  /// Create relations between entities.
  ///
  /// Each relation has a `from` entity, a `to` entity, and a `relationType`.
  /// Both entities must exist. Duplicate relations are ignored.
  Future<List<MemoryRelation>> createRelations(
    List<CreateRelationInput> relations,
  ) async {
    final graph = await _loadGraph();
    final created = <MemoryRelation>[];

    for (final input in relations) {
      // Validate that both entities exist
      if (!graph.entities.containsKey(input.from)) {
        throw MemoryException(
          'الكيان "${input.from}" مش موجود — مقدرش أنشئ العلاقة 🔗',
        );
      }
      if (!graph.entities.containsKey(input.to)) {
        throw MemoryException(
          'الكيان "${input.to}" مش موجود — مقدرش أنشئ العلاقة 🔗',
        );
      }

      // Check for duplicate
      final isDuplicate = graph.relations.any((rel) =>
          rel.from == input.from &&
          rel.to == input.to &&
          rel.relationType == input.relationType);

      if (!isDuplicate) {
        final relation = MemoryRelation(
          from: input.from,
          to: input.to,
          relationType: input.relationType,
        );
        graph.relations.add(relation);
        created.add(relation);
      }
    }

    await _saveGraph(graph);
    await _appendJsonl('create_relations', {
      'relations': relations.map((r) => r.toJson()).toList(),
      'createdCount': created.length,
    });

    return created;
  }

  /// Delete specific relations.
  ///
  /// Returns the number of relations removed.
  Future<int> deleteRelations(List<CreateRelationInput> relations) async {
    final graph = await _loadGraph();
    int removedCount = 0;

    for (final input in relations) {
      final initialLength = graph.relations.length;
      graph.relations.removeWhere((rel) =>
          rel.from == input.from &&
          rel.to == input.to &&
          rel.relationType == input.relationType);
      removedCount += initialLength - graph.relations.length;
    }

    await _saveGraph(graph);
    await _appendJsonl('delete_relations', {
      'removedCount': removedCount,
    });

    return removedCount;
  }

  // ── Graph Operations ──────────────────────────────────────────────────

  /// Read the full knowledge graph.
  ///
  /// Returns all entities and relations.
  Future<MemoryGraph> readGraph() async {
    return _loadGraph();
  }

  /// Reset all data in the knowledge graph.
  ///
  /// This operation is irreversible.
  Future<void> resetGraph() async {
    _graphCache = MemoryGraph(entities: {}, relations: []);
    await _saveGraph(_graphCache!);
    await _appendJsonl('reset_graph', {
      'resetAt': DateTime.now().toIso8601String(),
    });
  }

  /// Get graph statistics.
  Future<GraphStats> getStats() async {
    final graph = await _loadGraph();

    final entityTypeCounts = <String, int>{};
    final relationTypeCounts = <String, int>{};

    for (final entity in graph.entities.values) {
      entityTypeCounts[entity.entityType] =
          (entityTypeCounts[entity.entityType] ?? 0) + 1;
    }

    for (final rel in graph.relations) {
      relationTypeCounts[rel.relationType] =
          (relationTypeCounts[rel.relationType] ?? 0) + 1;
    }

    return GraphStats(
      entityCount: graph.entities.length,
      relationCount: graph.relations.length,
      totalObservations: graph.entities.values
          .fold<int>(0, (sum, e) => sum + e.observations.length),
      entityTypeCounts: entityTypeCounts,
      relationTypeCounts: relationTypeCounts,
      label: graph.entities.isEmpty
          ? 'الذاكرة فاضية — ضيف كيانات الأول 🧠'
          : 'في ${graph.entities.length} كيان و ${graph.relations.length} علاقة في الذاكرة 🧠',
    );
  }

  // ── Persistence ───────────────────────────────────────────────────────

  /// Load the knowledge graph from storage.
  Future<MemoryGraph> _loadGraph() async {
    if (_graphCache != null) return _graphCache!;

    final entitiesJson = _storage.getMap(_entitiesKey);
    final relationsList = _storage.getStringList(_relationsKey);

    final entities = <String, MemoryEntity>{};
    for (final entry in entitiesJson.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        entities[entry.key] = MemoryEntity.fromJson(value);
      } else if (value is String) {
        try {
          entities[entry.key] =
              MemoryEntity.fromJson(jsonDecode(value) as Map<String, dynamic>);
        } catch (_) {
          continue;
        }
      }
    }

    final relations = <MemoryRelation>[];
    for (final relStr in relationsList) {
      try {
        relations.add(
          MemoryRelation.fromJson(jsonDecode(relStr) as Map<String, dynamic>),
        );
      } catch (_) {
        continue;
      }
    }

    _graphCache = MemoryGraph(entities: entities, relations: relations);
    return _graphCache!;
  }

  /// Save the knowledge graph to storage.
  Future<void> _saveGraph(MemoryGraph graph) async {
    // Save entities as map
    final entitiesMap = <String, dynamic>{};
    for (final entry in graph.entities.entries) {
      entitiesMap[entry.key] = entry.value.toJson();
    }
    await _storage.setMap(_entitiesKey, entitiesMap);

    // Save relations as string list (JSONL-like)
    final relationsList =
        graph.relations.map((r) => jsonEncode(r.toJson())).toList();
    await _storage.setStringList(_relationsKey, relationsList);

    // Update cache
    _graphCache = graph;
  }

  /// Append an entry to the JSONL audit log.
  Future<void> _appendJsonl(String operation, Map<String, dynamic> data) async {
    final log = _storage.getStringList(_jsonlLogKey);
    final entry = jsonEncode({
      'operation': operation,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
    log.insert(0, entry);
    // Keep only last 500 entries
    if (log.length > 500) log.removeRange(500, log.length);
    await _storage.setStringList(_jsonlLogKey, log);
  }
}

// ── Data models ──

/// The full knowledge graph.
class MemoryGraph {
  /// Map of entity name → entity.
  final Map<String, MemoryEntity> entities;

  /// List of directed relations.
  final List<MemoryRelation> relations;

  MemoryGraph({
    required this.entities,
    required this.relations,
  });

  /// Convert to the official MCP Memory Server JSON format.
  Map<String, dynamic> toMcpFormat() => {
        'entities': entities.values.map((e) => e.toJson()).toList(),
        'relations': relations.map((r) => r.toJson()).toList(),
      };
}

/// A knowledge graph entity.
class MemoryEntity {
  /// Unique entity name (used as key).
  String name;

  /// Entity type (e.g., "person", "project", "concept").
  String entityType;

  /// List of observations (facts about the entity).
  List<String> observations;

  MemoryEntity({
    required this.name,
    required this.entityType,
    required this.observations,
  });

  factory MemoryEntity.fromJson(Map<String, dynamic> json) => MemoryEntity(
        name: json['name'] as String? ?? '',
        entityType: json['entityType'] as String? ?? 'thing',
        observations: (json['observations'] as List<dynamic>? ?? [])
            .cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'entityType': entityType,
        'observations': observations,
      };

  /// Egyptian Arabic summary.
  String get summaryAr {
    final obs = observations.isEmpty
        ? 'مفيش ملاحظات'
        : observations.length <= 3
            ? observations.join(' • ')
            : '${observations.take(3).join(" • ")} (+${observations.length - 3} تانيين)';
    return '$entityType: $name — $obs';
  }
}

/// A directed relation between two entities.
class MemoryRelation {
  /// Source entity name.
  final String from;

  /// Target entity name.
  final String to;

  /// Relation type (e.g., "works_for", "friend_of", "depends_on").
  final String relationType;

  const MemoryRelation({
    required this.from,
    required this.to,
    required this.relationType,
  });

  factory MemoryRelation.fromJson(Map<String, dynamic> json) => MemoryRelation(
        from: json['from'] as String? ?? '',
        to: json['to'] as String? ?? '',
        relationType: json['relationType'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'relationType': relationType,
      };

  /// Egyptian Arabic description.
  String get descriptionAr => '$from —[$relationType]→ $to';
}

/// Input for creating a new entity.
class CreateEntityInput {
  final String name;
  final String? entityType;
  final List<String> observations;

  const CreateEntityInput({
    required this.name,
    this.entityType,
    this.observations = const [],
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'entityType': entityType,
        'observations': observations,
      };
}

/// Input for creating a new relation.
class CreateRelationInput {
  final String from;
  final String to;
  final String relationType;

  const CreateRelationInput({
    required this.from,
    required this.to,
    required this.relationType,
  });

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'relationType': relationType,
      };
}

/// Knowledge graph statistics.
class GraphStats {
  final int entityCount;
  final int relationCount;
  final int totalObservations;
  final Map<String, int> entityTypeCounts;
  final Map<String, int> relationTypeCounts;
  final String label;

  const GraphStats({
    required this.entityCount,
    required this.relationCount,
    required this.totalObservations,
    required this.entityTypeCounts,
    required this.relationTypeCounts,
    required this.label,
  });
}

/// Internal class for scoring search results.
class _ScoredEntity {
  final MemoryEntity entity;
  final double score;

  const _ScoredEntity({required this.entity, required this.score});
}

/// Memory service exception.
class MemoryException implements Exception {
  final String message;
  MemoryException(this.message);

  @override
  String toString() => 'MemoryException: $message';
}
