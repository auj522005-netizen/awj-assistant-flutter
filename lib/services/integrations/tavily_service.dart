import 'package:dio/dio.dart';
import 'package:owj_assistant/config/api_keys.dart';
import 'package:owj_assistant/services/storage_service.dart';

/// Tavily search service for web search and content extraction.
///
/// API: https://api.tavily.com/search
/// Provides search, search-with-answer, and trending discovery
/// with full Arabic language support.
class TavilyService {
  TavilyService({Dio? dio, StorageService? storage})
      : _dio = dio ?? Dio(BaseOptions(
          baseUrl: 'https://api.tavily.com',
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
          },
        )),
        _storage = storage ?? StorageService.instance;

  final Dio _dio;
  final StorageService _storage;

  static const _searchHistoryKey = 'tavily_search_history';
  static const _cacheKeyPrefix = 'tavily_cache_';

  // ── Public API ──

  /// Performs a web search with the given [query].
  ///
  /// Supports Arabic queries natively. Returns structured results
  /// with titles, URLs, content snippets, and scores.
  Future<Map<String, dynamic>> search(
    String query, {
    int maxResults = 5,
    bool includeRawContent = false,
    String searchDepth = 'basic',
    List<String>? includeDomains,
    List<String>? excludeDomains,
  }) async {
    if (!ApiKeys.hasTavily) {
      throw TavilyException('Tavily API key not configured');
    }

    // Check cache
    final cacheKey = '$_cacheKeyPrefix${query.hashCode}';
    final cached = _storage.getJson(cacheKey);
    if (cached != null) {
      final cacheTime = DateTime.tryParse(cached['cachedAt'] as String? ?? '');
      if (cacheTime != null && DateTime.now().difference(cacheTime).inMinutes < 15) {
        return cached;
      }
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/search',
        data: {
          'api_key': ApiKeys.tavilyApiKey,
          'query': query,
          'max_results': maxResults,
          'include_raw_content': includeRawContent,
          'search_depth': searchDepth,
          'include_answer': false,
          if (includeDomains != null) 'include_domains': includeDomains,
          if (excludeDomains != null) 'exclude_domains': excludeDomains,
        },
      );

      final data = response.data ?? {};

      // Save to search history
      await _saveSearchHistory(query);

      // Cache results
      data['cachedAt'] = DateTime.now().toIso8601String();
      await _storage.setJson(cacheKey, data);

      return data;
    } on DioException catch (e) {
      throw TavilyException('Search failed: ${e.message}');
    }
  }

  /// Performs a search and also generates an AI answer to the query.
  ///
  /// Combines search results with a synthesized answer,
  /// ideal for question-answering use cases.
  Future<TavilyAnswerResult> searchWithAnswer(
    String query, {
    int maxResults = 5,
    String searchDepth = 'advanced',
  }) async {
    if (!ApiKeys.hasTavily) {
      throw TavilyException('Tavily API key not configured');
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/search',
        data: {
          'api_key': ApiKeys.tavilyApiKey,
          'query': query,
          'max_results': maxResults,
          'include_raw_content': false,
          'search_depth': searchDepth,
          'include_answer': true,
        },
      );

      final data = response.data ?? {};
      final answer = data['answer'] as String? ?? '';
      final results = (data['results'] as List<dynamic>? ?? [])
          .map((r) => TavilySearchResult.fromJson(r as Map<String, dynamic>))
          .toList();

      return TavilyAnswerResult(
        query: query,
        answer: answer,
        results: results,
      );
    } on DioException catch (e) {
      throw TavilyException('Search with answer failed: ${e.message}');
    }
  }

  /// Gets trending topics by searching for current popular searches.
  Future<List<TavilySearchResult>> getTrending({String region = 'eg'}) async {
    final queries = [
      'trending news today $region 2025',
      'أخبار تريند اليوم مصر',
      'most searched topics today',
    ];

    final allResults = <TavilySearchResult>[];
    final seenUrls = <String>{};

    for (final query in queries) {
      try {
        final data = await search(query, maxResults: 3);
        final results = (data['results'] as List<dynamic>? ?? [])
            .map((r) => TavilySearchResult.fromJson(r as Map<String, dynamic>))
            .toList();

        for (final result in results) {
          if (!seenUrls.contains(result.url)) {
            seenUrls.add(result.url);
            allResults.add(result);
          }
        }
      } catch (_) {
        continue;
      }
    }

    return allResults;
  }

  /// Extracts content from a specific URL using Tavily's extract capability.
  Future<Map<String, dynamic>> extractUrl(String url) async {
    if (!ApiKeys.hasTavily) {
      throw TavilyException('Tavily API key not configured');
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/extract',
        data: {
          'api_key': ApiKeys.tavilyApiKey,
          'urls': [url],
        },
      );

      final data = response.data ?? {};
      final responses = data['results'] as List<dynamic>? ?? [];
      if (responses.isNotEmpty) {
        return responses[0] as Map<String, dynamic>;
      }
      return {'url': url, 'content': '', 'title': ''};
    } on DioException catch (e) {
      throw TavilyException('URL extraction failed: ${e.message}');
    }
  }

  /// Gets recent search history.
  Future<List<String>> getSearchHistory({int limit = 20}) async {
    return _storage.getStringList(_searchHistoryKey)?.take(limit).toList() ?? [];
  }

  /// Clears search history.
  Future<void> clearSearchHistory() async {
    await _storage.delete(_searchHistoryKey);
  }

  // ── Private helpers ──

  Future<void> _saveSearchHistory(String query) async {
    final history = _storage.getStringList(_searchHistoryKey) ?? [];
    // Remove duplicate if exists
    history.remove(query);
    history.insert(0, query);
    // Keep only last 50 entries
    if (history.length > 50) history.removeRange(50, history.length);
    await _storage.setStringList(_searchHistoryKey, history);
  }
}

// ── Data models ──

class TavilySearchResult {
  final String title;
  final String url;
  final String content;
  final String? rawContent;
  final double score;

  const TavilySearchResult({
    required this.title,
    required this.url,
    required this.content,
    this.rawContent,
    required this.score,
  });

  factory TavilySearchResult.fromJson(Map<String, dynamic> json) =>
      TavilySearchResult(
        title: json['title'] as String? ?? '',
        url: json['url'] as String? ?? '',
        content: json['content'] as String? ?? '',
        rawContent: json['raw_content'] as String?,
        score: (json['score'] as num?)?.toDouble() ?? 0.0,
      );
}

class TavilyAnswerResult {
  final String query;
  final String answer;
  final List<TavilySearchResult> results;

  const TavilyAnswerResult({
    required this.query,
    required this.answer,
    required this.results,
  });
}

class TavilyException implements Exception {
  final String message;
  TavilyException(this.message);
  @override
  String toString() => 'TavilyException: $message';
}
