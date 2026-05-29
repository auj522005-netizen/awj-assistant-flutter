import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage service for the OWJ Assistant.
///
/// Uses `shared_preferences` for key-value storage and `path_provider`
/// for file-based storage. Supports String, List, Map, and file operations
/// including knowledge graph JSON persistence.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  SharedPreferences? _prefs;
  Directory? _appDir;

  /// Initialize the storage service. Must be called before any other method.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _appDir = await getApplicationDocumentsDirectory();
  }

  /// Ensure the service is initialized.
  SharedPreferences get _ensurePrefs {
    if (_prefs == null) {
      throw StateError(
        'StorageService not initialized. Call init() first.',
      );
    }
    return _prefs!;
  }

  /// Ensure the app directory is available.
  Directory get _ensureAppDir {
    if (_appDir == null) {
      throw StateError(
        'StorageService not initialized. Call init() first.',
      );
    }
    return _appDir!;
  }

  // ─── String Operations ─────────────────────────────────────────────

  /// Get a string value from storage.
  String? getString(String key) => _ensurePrefs.getString(key);

  /// Set a string value in storage.
  Future<bool> setString(String key, String value) =>
      _ensurePrefs.setString(key, value);

  // ─── List Operations ───────────────────────────────────────────────

  /// Get a list of strings from storage.
  List<String> getStringList(String key) =>
      _ensurePrefs.getStringList(key) ?? [];

  /// Set a list of strings in storage.
  Future<bool> setStringList(String key, List<String> value) =>
      _ensurePrefs.setStringList(key, value);

  // ─── Map Operations ────────────────────────────────────────────────

  /// Get a map from storage (stored as JSON string).
  Map<String, dynamic> getMap(String key) {
    final jsonStr = _ensurePrefs.getString(key);
    if (jsonStr == null) return {};
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Set a map in storage (stored as JSON string).
  Future<bool> setMap(String key, Map<String, dynamic> value) =>
      _ensurePrefs.setString(key, jsonEncode(value));

  // ─── Generic Get/Set with Type Inference ───────────────────────────

  /// Get a value of any supported type.
  dynamic get(String key) => _ensurePrefs.get(key);

  /// Set a value of any supported type.
  Future<bool> set(String key, dynamic value) async {
    final prefs = _ensurePrefs;
    if (value is String) {
      return prefs.setString(key, value);
    } else if (value is int) {
      return prefs.setInt(key, value);
    } else if (value is double) {
      return prefs.setDouble(key, value);
    } else if (value is bool) {
      return prefs.setBool(key, value);
    } else if (value is List<String>) {
      return prefs.setStringList(key, value);
    } else if (value is Map) {
      return prefs.setString(key, jsonEncode(value));
    } else {
      throw ArgumentError('Unsupported type: ${value.runtimeType}');
    }
  }

  // ─── Delete & Clear ────────────────────────────────────────────────

  /// Delete a specific key from storage.
  Future<bool> delete(String key) => _ensurePrefs.remove(key);

  /// Clear all storage data.
  Future<bool> clear() => _ensurePrefs.clear();

  /// Check if a key exists in storage.
  bool containsKey(String key) => _ensurePrefs.containsKey(key);

  /// Get all keys in storage.
  Set<String> get keys => _ensurePrefs.getKeys();

  // ─── File Operations ───────────────────────────────────────────────

  /// Get the path for a named file in the app documents directory.
  String _filePath(String filename) =>
      '${_ensureAppDir.path}/$filename';

  /// Write a string to a file.
  Future<void> writeFile(String filename, String content) async {
    final file = File(_filePath(filename));
    await file.writeAsString(content, flush: true);
  }

  /// Read a string from a file. Returns null if the file doesn't exist.
  Future<String?> readFile(String filename) async {
    final file = File(_filePath(filename));
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  /// Write JSON data to a file.
  Future<void> writeJsonFile(
    String filename,
    Map<String, dynamic> data,
  ) async {
    await writeFile(filename, jsonEncode(data));
  }

  /// Read JSON data from a file. Returns empty map if file doesn't exist.
  Future<Map<String, dynamic>> readJsonFile(String filename) async {
    final content = await readFile(filename);
    if (content == null) return {};
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Delete a file.
  Future<bool> deleteFile(String filename) async {
    final file = File(_filePath(filename));
    if (!await file.exists()) return false;
    await file.delete();
    return true;
  }

  /// Check if a file exists.
  Future<bool> fileExists(String filename) async {
    final file = File(_filePath(filename));
    return file.exists();
  }

  /// List all files in the app documents directory.
  Future<List<String>> listFiles() async {
    final dir = _ensureAppDir;
    if (!await dir.exists()) return [];
    return dir
        .list()
        .where((entity) => entity is File)
        .map((entity) => entity.path.split('/').last)
        .toList();
  }

  // ─── Knowledge Graph Operations ────────────────────────────────────

  /// Knowledge graph filename.
  static const String _kgFilename = 'knowledge_graph.json';

  /// Save the knowledge graph to persistent storage.
  Future<void> saveKnowledgeGraph(Map<String, dynamic> graph) async {
    await writeJsonFile(_kgFilename, graph);
    // Also save a backup to shared preferences
    await setMap('kg_backup', graph);
  }

  /// Load the knowledge graph from persistent storage.
  /// Falls back to shared preferences backup if file is unavailable.
  Future<Map<String, dynamic>> loadKnowledgeGraph() async {
    // Try file first
    final fileData = await readJsonFile(_kgFilename);
    if (fileData.isNotEmpty) return fileData;

    // Fall back to shared preferences backup
    final backupData = getMap('kg_backup');
    if (backupData.isNotEmpty) {
      // Restore file from backup
      await writeJsonFile(_kgFilename, backupData);
    }
    return backupData;
  }

  /// Add a node to the knowledge graph.
  Future<void> addKnowledgeNode(
    String nodeId,
    Map<String, dynamic> nodeData, {
    List<String>? connections,
  }) async {
    final graph = await loadKnowledgeGraph();
    final nodes = graph['nodes'] as Map<String, dynamic>? ?? {};

    nodes[nodeId] = {
      ...nodeData,
      'connections': connections ?? [],
      'updatedAt': DateTime.now().toIso8601String(),
    };

    graph['nodes'] = nodes;
    await saveKnowledgeGraph(graph);
  }

  /// Remove a node from the knowledge graph.
  Future<void> removeKnowledgeNode(String nodeId) async {
    final graph = await loadKnowledgeGraph();
    final nodes = graph['nodes'] as Map<String, dynamic>? ?? {};

    nodes.remove(nodeId);

    // Remove connections to this node
    for (final node in nodes.values) {
      if (node is Map<String, dynamic>) {
        final connections =
            (node['connections'] as List<dynamic>?) ?? [];
        node['connections'] =
            connections.where((c) => c != nodeId).toList();
      }
    }

    graph['nodes'] = nodes;
    await saveKnowledgeGraph(graph);
  }

  /// Search the knowledge graph for nodes matching a query.
  Future<List<MapEntry<String, Map<String, dynamic>>>>
      searchKnowledgeGraph(String query) async {
    final graph = await loadKnowledgeGraph();
    final nodes = graph['nodes'] as Map<String, dynamic>? ?? {};
    final normalizedQuery = query.toLowerCase();

    final results = <MapEntry<String, Map<String, dynamic>>>[];

    for (final entry in nodes.entries) {
      final node = entry.value;
      if (node is! Map<String, dynamic>) continue;

      // Search in all string values of the node
      bool matches = false;
      for (final value in node.values) {
        if (value is String &&
            value.toLowerCase().contains(normalizedQuery)) {
          matches = true;
          break;
        }
      }

      // Also match on node ID
      if (entry.key.toLowerCase().contains(normalizedQuery)) {
        matches = true;
      }

      if (matches) {
        results.add(MapEntry(entry.key, node));
      }
    }

    return results;
  }

  // ─── JSON List Operations ────────────────────────────────────────────

  /// Get a list of JSON maps from storage (stored as JSON string).
  List<Map<String, dynamic>> getJsonList(String key) {
    final jsonStr = _ensurePrefs.getString(key);
    if (jsonStr == null) return [];
    try {
      final list = jsonDecode(jsonStr) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Set a list of JSON maps in storage (stored as JSON string).
  Future<bool> setJsonList(String key, List<Map<String, dynamic>> value) =>
      _ensurePrefs.setString(key, jsonEncode(value));

  /// Get a JSON map from storage (alias for getMap with consistent naming).
  Map<String, dynamic> getJson(String key) => getMap(key);

  /// Set a JSON map in storage (alias for setMap with consistent naming).
  Future<bool> setJson(String key, Map<String, dynamic> value) =>
      setMap(key, value);

  // ─── Chat History Operations ───────────────────────────────────────

  /// Save chat messages for a conversation.
  Future<void> saveChatHistory(
    String conversationId,
    List<Map<String, dynamic>> messages,
  ) async {
    await setMap('chat_$conversationId', {
      'id': conversationId,
      'messages': messages,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Load chat messages for a conversation.
  List<Map<String, dynamic>> loadChatHistory(String conversationId) {
    final data = getMap('chat_$conversationId');
    if (data.isEmpty) return [];
    final messages = data['messages'];
    if (messages is List) {
      return messages.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Get all conversation IDs.
  List<String> getConversationIds() {
    return keys
        .where((k) => k.startsWith('chat_'))
        .map((k) => k.substring(5))
        .toList();
  }

  /// Delete a conversation.
  Future<bool> deleteConversation(String conversationId) =>
      delete('chat_$conversationId');

  // ─── Settings Operations ───────────────────────────────────────────

  /// Get a setting value with a default.
  T getSetting<T>(String key, T defaultValue) {
    final prefs = _ensurePrefs;
    if (!prefs.containsKey(key)) return defaultValue;

    final value = prefs.get(key);
    if (value is T) return value;

    return defaultValue;
  }

  /// Set a setting value.
  Future<bool> setSetting<T>(String key, T value) => set(key, value);

  // ─── Cache Operations ──────────────────────────────────────────────

  /// Save data to cache with an optional TTL (time-to-live) in seconds.
  Future<bool> setCache(
    String key,
    Map<String, dynamic> data, {
    int ttlSeconds = 3600,
  }) async {
    final cacheEntry = {
      'data': data,
      'expiresAt':
          DateTime.now().add(Duration(seconds: ttlSeconds)).toIso8601String(),
    };
    return setMap('cache_$key', cacheEntry);
  }

  /// Get data from cache. Returns null if expired or not found.
  Map<String, dynamic>? getCache(String key) {
    final cacheEntry = getMap('cache_$key');
    if (cacheEntry.isEmpty) return null;

    final expiresAt = cacheEntry['expiresAt'] as String?;
    if (expiresAt != null) {
      final expiry = DateTime.tryParse(expiresAt);
      if (expiry != null && DateTime.now().isAfter(expiry)) {
        delete('cache_$key');
        return null;
      }
    }

    return cacheEntry['data'] as Map<String, dynamic>?;
  }

  /// Clear all cached data.
  Future<void> clearCache() async {
    final cacheKeys = keys.where((k) => k.startsWith('cache_')).toList();
    for (final key in cacheKeys) {
      await delete(key);
    }
  }

  // ─── Usage Statistics ──────────────────────────────────────────────

  /// Save daily usage statistics for a provider.
  Future<void> saveUsageStats(
    String provider,
    Map<String, dynamic> stats,
  ) async {
    final key = 'usage_${provider}_${_todayKey()}';
    await setMap(key, stats);
  }

  /// Load daily usage statistics for a provider.
  Map<String, dynamic> loadUsageStats(String provider) {
    final key = 'usage_${provider}_${_todayKey()}';
    return getMap(key);
  }

  /// Get today's date key.
  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Clean up old usage stats (older than 30 days).
  Future<void> cleanupOldUsageStats() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final usageKeys =
        keys.where((k) => k.startsWith('usage_')).toList();

    for (final key in usageKeys) {
      // Extract date from key format: usage_provider_YYYY-MM-DD
      final parts = key.split('_');
      if (parts.length >= 4) {
        final dateStr = parts.sublist(parts.length - 3).join('-');
        final date = DateTime.tryParse(dateStr);
        if (date != null && date.isBefore(cutoff)) {
          await delete(key);
        }
      }
    }
  }
}
