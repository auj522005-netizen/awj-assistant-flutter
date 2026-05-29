import 'package:dio/dio.dart';
import 'package:owj_assistant/config/api_keys.dart';
import 'package:owj_assistant/services/integrations/tavily_service.dart';
import 'package:owj_assistant/services/storage_service.dart';

/// MCP News service using Tavily for search and extraction.
///
/// Provides personalized news, trending topics, and tech news
/// with full Arabic language support.
class McpNewsService {
  McpNewsService({TavilyService? tavilyService, StorageService? storage})
      : _tavilyService = tavilyService ?? TavilyService(),
        _storage = storage ?? StorageService.instance;

  final TavilyService _tavilyService;
  final StorageService _storage;

  static const _interestsKey = 'news_interests';
  static const _readArticlesKey = 'news_read_articles';
  static const _trendingCacheKey = 'news_trending_cache';

  // ── Public API ──

  /// Gets personalized news based on [interests].
  ///
  /// If no interests are provided, uses cached interests from previous sessions.
  /// Results are ranked by relevance and freshness.
  Future<NewsResult> getPersonalizedNews({List<String>? interests}) async {
    final userInterests = interests ?? await _getCachedInterests();
    if (userInterests.isEmpty) {
      return const NewsResult(
        articles: [],
        source: NewsSource.personalized,
        message: 'لم يتم تحديد اهتمامات بعد. أضف اهتماماتك للحصول على أخبار مخصصة.',
      );
    }

    // Cache interests for future use
    await _cacheInterests(userInterests);

    final allArticles = <NewsArticle>[];

    // Search for each interest topic
    for (final interest in userInterests.take(5)) {
      try {
        final query = '$interest أخبار اليوم';
        final results = await _tavilyService.search(query);
        final articles = _parseSearchResults(results, category: interest);
        allArticles.addAll(articles);
      } catch (_) {
        // Continue with other interests even if one fails
      }
    }

    // Deduplicate and sort by date
    final deduped = _deduplicateArticles(allArticles);
    deduped.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    return NewsResult(
      articles: deduped.take(20).toList(),
      source: NewsSource.personalized,
      interests: userInterests,
    );
  }

  /// Gets trending topics globally and in the Arab world.
  Future<TrendingResult> getTrendingTopics() async {
    // Check cache first (cache for 30 minutes)
    final cached = _storage.getJson(_trendingCacheKey);
    if (cached != null) {
      final cacheTime = DateTime.tryParse(cached['cachedAt'] as String? ?? '');
      if (cacheTime != null && DateTime.now().difference(cacheTime).inMinutes < 30) {
        return _parseTrendingCache(cached);
      }
    }

    final topics = <TrendingTopic>[];

    // Global trending
    try {
      final globalResults = await _tavilyService.search('trending topics today 2025');
      topics.addAll(_parseTrendingResults(globalResults, region: 'عالمي'));
    } catch (_) {}

    // Arabic trending
    try {
      final arabicResults = await _tavilyService.search('أخبار تريند اليوم');
      topics.addAll(_parseTrendingResults(arabicResults, region: 'عربي'));
    } catch (_) {}

    // Tech trending
    try {
      final techResults = await _tavilyService.search('tech trending news today');
      topics.addAll(_parseTrendingResults(techResults, region: 'تقني'));
    } catch (_) {}

    final result = TrendingResult(
      topics: topics,
      fetchedAt: DateTime.now(),
    );

    // Cache the result
    await _cacheTrending(result);

    return result;
  }

  /// Gets technology news with Arabic and international sources.
  Future<NewsResult> getTechNews() async {
    final allArticles = <NewsArticle>[];

    // English tech news
    try {
      final enResults = await _tavilyService.search('latest technology news AI programming');
      allArticles.addAll(_parseSearchResults(enResults, category: 'تقنية'));
    } catch (_) {}

    // Arabic tech news
    try {
      final arResults = await _tavilyService.search('أخبار التقنية والذكاء الاصطناعي اليوم');
      allArticles.addAll(_parseSearchResults(arResults, category: 'تقنية'));
    } catch (_) {}

    final deduped = _deduplicateArticles(allArticles);
    deduped.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    return NewsResult(
      articles: deduped,
      source: NewsSource.tech,
    );
  }

  /// Marks an article as read for personalization.
  Future<void> markArticleRead(String articleUrl) async {
    final read = _storage.getStringList(_readArticlesKey) ?? [];
    if (!read.contains(articleUrl)) {
      read.add(articleUrl);
      await _storage.setStringList(_readArticlesKey, read);
    }
  }

  /// Adds an interest topic for personalization.
  Future<void> addInterest(String interest) async {
    final interests = await _getCachedInterests();
    if (!interests.contains(interest)) {
      interests.add(interest);
      await _cacheInterests(interests);
    }
  }

  /// Removes an interest topic.
  Future<void> removeInterest(String interest) async {
    final interests = await _getCachedInterests();
    interests.remove(interest);
    await _cacheInterests(interests);
  }

  // ── Private helpers ──

  List<NewsArticle> _parseSearchResults(
    Map<String, dynamic> results, {
    String category = 'عام',
  }) {
    final articles = <NewsArticle>[];
    final resultsList = results['results'] as List<dynamic>? ?? [];

    for (final result in resultsList) {
      final r = result as Map<String, dynamic>;
      articles.add(NewsArticle(
        title: r['title'] as String? ?? '',
        url: r['url'] as String? ?? '',
        content: r['content'] as String? ?? '',
        snippet: (r['content'] as String? ?? '').length > 200
            ? '${(r['content'] as String).substring(0, 200)}...'
            : r['content'] as String? ?? '',
        source: r['raw_content'] != null ? _extractSource(r['url'] as String? ?? '') : '',
        category: category,
        publishedAt: _parseDate(r['published_date'] as String?),
        isRead: _isArticleRead(r['url'] as String? ?? ''),
        language: _detectLanguage(r['title'] as String? ?? ''),
      ));
    }

    return articles;
  }

  List<TrendingTopic> _parseTrendingResults(
    Map<String, dynamic> results, {
    required String region,
  }) {
    final topics = <TrendingTopic>[];
    final resultsList = results['results'] as List<dynamic>? ?? [];

    for (final result in resultsList.take(5)) {
      final r = result as Map<String, dynamic>;
      topics.add(TrendingTopic(
        title: r['title'] as String? ?? '',
        snippet: (r['content'] as String? ?? '').length > 150
            ? '${(r['content'] as String).substring(0, 150)}...'
            : r['content'] as String? ?? '',
        url: r['url'] as String? ?? '',
        region: region,
        language: _detectLanguage(r['title'] as String? ?? ''),
      ));
    }

    return topics;
  }

  List<NewsArticle> _deduplicateArticles(List<NewsArticle> articles) {
    final seen = <String>{};
    return articles.where((article) {
      final key = article.url;
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();
  }

  String _extractSource(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceAll('www.', '');
    } catch (_) {
      return '';
    }
  }

  DateTime _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return DateTime.now();
    }
    return DateTime.tryParse(dateStr) ?? DateTime.now();
  }

  bool _isArticleRead(String url) {
    final read = _storage.getStringList(_readArticlesKey) ?? [];
    return read.contains(url);
  }

  String _detectLanguage(String text) {
    final arabicChars = RegExp(r'[\u0600-\u06FF]').allMatches(text).length;
    final latinChars = RegExp(r'[a-zA-Z]').allMatches(text).length;
    if (arabicChars > latinChars) return 'ar';
    if (latinChars > arabicChars) return 'en';
    return 'mixed';
  }

  Future<List<String>> _getCachedInterests() async {
    return _storage.getStringList(_interestsKey) ?? [];
  }

  Future<void> _cacheInterests(List<String> interests) async {
    await _storage.setStringList(_interestsKey, interests);
  }

  Future<void> _cacheTrending(TrendingResult result) async {
    await _storage.setJson(_trendingCacheKey, {
      'cachedAt': DateTime.now().toIso8601String(),
      'topics': result.topics.map((t) => {
        'title': t.title,
        'snippet': t.snippet,
        'url': t.url,
        'region': t.region,
        'language': t.language,
      }).toList(),
    });
  }

  TrendingResult _parseTrendingCache(Map<String, dynamic> cached) {
    final topicsList = cached['topics'] as List<dynamic>? ?? [];
    return TrendingResult(
      topics: topicsList.map((t) {
        final data = t as Map<String, dynamic>;
        return TrendingTopic(
          title: data['title'] as String? ?? '',
          snippet: data['snippet'] as String? ?? '',
          url: data['url'] as String? ?? '',
          region: data['region'] as String? ?? '',
          language: data['language'] as String? ?? 'en',
        );
      }).toList(),
      fetchedAt: DateTime.tryParse(cached['cachedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

// ── Data models ──

enum NewsSource { personalized, trending, tech }

class NewsArticle {
  final String title;
  final String url;
  final String content;
  final String snippet;
  final String source;
  final String category;
  final DateTime publishedAt;
  final bool isRead;
  final String language;

  const NewsArticle({
    required this.title,
    required this.url,
    required this.content,
    required this.snippet,
    required this.source,
    required this.category,
    required this.publishedAt,
    required this.isRead,
    required this.language,
  });
}

class NewsResult {
  final List<NewsArticle> articles;
  final NewsSource source;
  final List<String>? interests;
  final String? message;

  const NewsResult({
    required this.articles,
    required this.source,
    this.interests,
    this.message,
  });
}

class TrendingTopic {
  final String title;
  final String snippet;
  final String url;
  final String region;
  final String language;

  const TrendingTopic({
    required this.title,
    required this.snippet,
    required this.url,
    required this.region,
    required this.language,
  });
}

class TrendingResult {
  final List<TrendingTopic> topics;
  final DateTime fetchedAt;

  const TrendingResult({
    required this.topics,
    required this.fetchedAt,
  });
}
