import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:owj_assistant/config/api_keys.dart';
import 'package:owj_assistant/services/storage_service.dart';

/// Mem0 cloud memory service with local fallback.
///
/// Provides hybrid memory storage: cloud-first via Mem0 API,
/// falling back to local storage when the cloud is unavailable.
/// Search merges results from both sources for maximum recall.
class Mem0Service {
  Mem0Service({Dio? dio, StorageService? storage})
      : _dio = dio ?? Dio(BaseOptions(
          baseUrl: 'https://api.mem0.ai/v1/memories',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          headers: {
            'Content-Type': 'application/json',
          },
        )),
        _storage = storage ?? StorageService.instance;

  final Dio _dio;
  final StorageService _storage;

  static const _localMemoriesKey = 'mem0_local_memories';
  static const _syncStatusKey = 'mem0_sync_status';

  // ── Public API ──

  /// Adds a memory for [userId] with the given [content].
  ///
  /// Stores in Mem0 cloud first, then saves locally as backup.
  /// If cloud is unavailable, stores locally only.
  Future<MemoryItem> addMemory(String content, {required String userId}) async {
    final id = 'mem_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    final memory = MemoryItem(
      id: id,
      content: content,
      userId: userId,
      createdAt: now,
      updatedAt: now,
      source: MemorySource.cloud,
    );

    // Try cloud first
    if (ApiKeys.hasMem0) {
      try {
        final cloudMemory = await _addCloudMemory(content, userId);
        // Cloud succeeded — also cache locally
        await _addLocalMemory(memory.copyWith(
          id: cloudMemory.id,
          cloudId: cloudMemory.id,
          source: MemorySource.cloud,
        ));
        return cloudMemory;
      } catch (_) {
        // Cloud failed — fall back to local
      }
    }

    // Local fallback
    final localMemory = memory.copyWith(
      id: id,
      source: MemorySource.local,
    );
    await _addLocalMemory(localMemory);
    return localMemory;
  }

  /// Gets memories for [userId], optionally filtered by [query].
  ///
  /// Performs hybrid search:
  ///   1. Search cloud memories via Mem0 API
  ///   2. Search local memories via keyword matching
  ///   3. Merge and deduplicate results
  Future<List<MemoryItem>> getMemories(String userId, {String? query}) async {
    final cloudMemories = <MemoryItem>[];
    final localMemories = <MemoryItem>[];

    // Try cloud search
    if (ApiKeys.hasMem0) {
      try {
        cloudMemories.addAll(await _searchCloudMemories(userId, query: query));
      } catch (_) {}
    }

    // Always search local
    localMemories.addAll(_searchLocalMemories(userId, query: query));

    // Merge: cloud results first, then local-only results
    final merged = _mergeResults(cloudMemories, localMemories);
    return merged;
  }

  /// Deletes a memory by [id].
  ///
  /// Deletes from both cloud and local storage.
  Future<bool> deleteMemory(String id) async {
    var cloudDeleted = false;
    var localDeleted = false;

    // Try cloud deletion
    if (ApiKeys.hasMem0) {
      try {
        cloudDeleted = await _deleteCloudMemory(id);
      } catch (_) {}
    }

    // Always try local deletion
    localDeleted = await _deleteLocalMemory(id);

    return cloudDeleted || localDeleted;
  }

  /// Gets all memories for a user (no filtering).
  Future<List<MemoryItem>> getAllMemories(String userId) async {
    return getMemories(userId);
  }

  /// Syncs local-only memories to the cloud.
  Future<SyncResult> syncToCloud(String userId) async {
    final localMemories = _searchLocalMemories(userId);
    final unsynced = localMemories.where((m) => m.source == MemorySource.local).toList();

    if (unsynced.isEmpty) {
      return const SyncResult(uploaded: 0, failed: 0, message: 'جميع الذكريات متزامنة');
    }

    var uploaded = 0;
    var failed = 0;

    for (final memory in unsynced) {
      try {
        final cloudMemory = await _addCloudMemory(memory.content, userId);
        // Update local record to mark as synced
        await _markLocalSynced(memory.id, cloudMemory.id);
        uploaded++;
      } catch (_) {
        failed++;
      }
    }

    return SyncResult(
      uploaded: uploaded,
      failed: failed,
      message: 'تم رفع $uploaded ذكرى${failed > 0 ? '، فشل $failed' : ''}',
    );
  }

  /// Returns the count of memories for a user.
  Future<int> getMemoryCount(String userId) async {
    final memories = await getMemories(userId);
    return memories.length;
  }

  // ── Cloud operations ──

  Future<MemoryItem> _addCloudMemory(String content, String userId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '',
      options: Options(headers: {
        'Authorization': 'Token ${ApiKeys.mem0ApiKey}',
      }),
      data: {
        'messages': [{'role': 'user', 'content': content}],
        'user_id': userId,
        if (ApiKeys.mem0OrgId.isNotEmpty) 'org_id': ApiKeys.mem0OrgId,
        if (ApiKeys.mem0ProjectId.isNotEmpty) 'project_id': ApiKeys.mem0ProjectId,
      },
    );

    final data = response.data!;
    final id = data['id'] as String? ?? 'cloud_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    return MemoryItem(
      id: id,
      content: content,
      userId: userId,
      createdAt: DateTime.tryParse(data['created_at'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(data['updated_at'] as String? ?? '') ?? now,
      source: MemorySource.cloud,
      cloudId: id,
    );
  }

  Future<List<MemoryItem>> _searchCloudMemories(String userId, {String? query}) async {
    final queryParams = <String, dynamic>{
      'user_id': userId,
    };
    if (query != null && query.isNotEmpty) {
      queryParams['query'] = query;
    }

    final response = await _dio.get<Map<String, dynamic>>(
      '',
      queryParameters: queryParams,
      options: Options(headers: {
        'Authorization': 'Token ${ApiKeys.mem0ApiKey}',
      }),
    );

    final data = response.data!;
    final results = data['results'] as List<dynamic>? ?? data['memories'] as List<dynamic>? ?? [];

    return results.map((item) {
      final m = item as Map<String, dynamic>;
      return MemoryItem(
        id: m['id'] as String? ?? '',
        content: m['memory'] as String? ?? m['content'] as String? ?? '',
        userId: userId,
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(m['updated_at'] as String? ?? '') ?? DateTime.now(),
        source: MemorySource.cloud,
        cloudId: m['id'] as String?,
        score: (m['score'] as num?)?.toDouble(),
      );
    }).toList();
  }

  Future<bool> _deleteCloudMemory(String id) async {
    try {
      await _dio.delete(
        '/$id',
        options: Options(headers: {
          'Authorization': 'Token ${ApiKeys.mem0ApiKey}',
        }),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Local operations ──

  Future<void> _addLocalMemory(MemoryItem memory) async {
    final memories = _getLocalMemoriesRaw();
    memories.add(_memoryToJson(memory));
    await _storage.setJsonList(_localMemoriesKey, memories);
  }

  List<MemoryItem> _searchLocalMemories(String userId, {String? query}) {
    final memories = _getLocalMemoriesRaw();
    return memories.map(_jsonToMemory).where((m) {
      if (m.userId != userId) return false;
      if (query == null || query.isEmpty) return true;
      return m.content.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  Future<bool> _deleteLocalMemory(String id) async {
    final memories = _getLocalMemoriesRaw();
    final initialLength = memories.length;
    memories.removeWhere((m) => m['id'] == id);
    if (memories.length < initialLength) {
      await _storage.setJsonList(_localMemoriesKey, memories);
      return true;
    }
    return false;
  }

  Future<void> _markLocalSynced(String localId, String cloudId) async {
    final memories = _getLocalMemoriesRaw();
    for (final m in memories) {
      if (m['id'] == localId) {
        m['source'] = MemorySource.synced.name;
        m['cloudId'] = cloudId;
        break;
      }
    }
    await _storage.setJsonList(_localMemoriesKey, memories);
  }

  List<Map<String, dynamic>> _getLocalMemoriesRaw() {
    return _storage.getJsonList(_localMemoriesKey);
  }

  // ── Merge logic ──

  List<MemoryItem> _mergeResults(
    List<MemoryItem> cloudMemories,
    List<MemoryItem> localMemories,
  ) {
    final seen = <String>{};
    final merged = <MemoryItem>[];

    for (final memory in cloudMemories) {
      final key = memory.cloudId ?? memory.id;
      if (!seen.contains(key)) {
        seen.add(key);
        merged.add(memory);
      }
    }

    for (final memory in localMemories) {
      final key = memory.cloudId ?? memory.id;
      if (!seen.contains(key)) {
        seen.add(key);
        merged.add(memory);
      }
    }

    // Sort by creation date, newest first
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  // ── Serialization helpers ──

  Map<String, dynamic> _memoryToJson(MemoryItem m) => {
    'id': m.id,
    'content': m.content,
    'userId': m.userId,
    'createdAt': m.createdAt.toIso8601String(),
    'updatedAt': m.updatedAt.toIso8601String(),
    'source': m.source.name,
    'cloudId': m.cloudId,
    'score': m.score,
  };

  MemoryItem _jsonToMemory(Map<String, dynamic> json) => MemoryItem(
    id: json['id'] as String? ?? '',
    content: json['content'] as String? ?? '',
    userId: json['userId'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    source: MemorySource.values.firstWhere(
      (s) => s.name == json['source'],
      orElse: () => MemorySource.local,
    ),
    cloudId: json['cloudId'] as String?,
    score: (json['score'] as num?)?.toDouble(),
  );
}

// ── Data models ──

enum MemorySource { cloud, local, synced }

class MemoryItem {
  final String id;
  final String content;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final MemorySource source;
  final String? cloudId;
  final double? score;

  const MemoryItem({
    required this.id,
    required this.content,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    required this.source,
    this.cloudId,
    this.score,
  });

  MemoryItem copyWith({
    String? id,
    String? content,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    MemorySource? source,
    String? cloudId,
    double? score,
  }) =>
      MemoryItem(
        id: id ?? this.id,
        content: content ?? this.content,
        userId: userId ?? this.userId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        source: source ?? this.source,
        cloudId: cloudId ?? this.cloudId,
        score: score ?? this.score,
      );
}

class SyncResult {
  final int uploaded;
  final int failed;
  final String message;

  const SyncResult({
    required this.uploaded,
    required this.failed,
    required this.message,
  });

  bool get success => failed == 0;
}
