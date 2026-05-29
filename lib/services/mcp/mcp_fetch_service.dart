import 'package:dio/dio.dart';
import 'package:owj_assistant/config/api_keys.dart';
import 'package:owj_assistant/services/integrations/tavily_service.dart';

/// MCP Fetch service for URL fetching and content extraction.
///
/// Extracts readable content from web URLs with Arabic content support.
/// Falls back to Tavily extract when direct fetching fails.
class McpFetchService {
  McpFetchService({Dio? dio, TavilyService? tavilyService})
      : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'ar,en;q=0.9',
            'User-Agent': 'OWJAssistant/1.0',
          },
        )),
        _tavilyService = tavilyService ?? TavilyService();

  final Dio _dio;
  final TavilyService _tavilyService;

  // ── Public API ──

  /// Fetches raw content from [url]. Returns extracted text with metadata.
  Future<FetchResult> fetchUrl(String url) async {
    try {
      final result = await _directFetch(url);
      if (result != null) return result;
    } catch (_) {
      // Direct fetch failed; try Tavily fallback
    }

    // Fallback to Tavily extract
    if (ApiKeys.hasTavily) {
      try {
        final tavilyResult = await _tavilyService.extractUrl(url);
        return FetchResult(
          url: url,
          title: tavilyResult['title'] as String? ?? '',
          content: tavilyResult['content'] as String? ?? '',
          rawHtml: null,
          fetchMethod: FetchMethod.tavily,
        );
      } catch (_) {
        // Tavily also failed
      }
    }

    throw FetchException('Could not fetch content from $url. Both direct and Tavily methods failed.');
  }

  /// Fetches a URL and produces a summary of its content.
  Future<UrlSummary> summarizeUrl(String url) async {
    final fetchResult = await fetchUrl(url);
    final content = fetchResult.content;

    // Simple extractive summarization – take first ~500 meaningful chars
    final summary = _extractSummary(content);
    final keyPoints = _extractKeyPoints(content);

    return UrlSummary(
      url: url,
      title: fetchResult.title,
      summary: summary,
      keyPoints: keyPoints,
      wordCount: content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
      language: _detectLanguage(content),
    );
  }

  /// Extracts information from [url] matching the given [query].
  Future<ExtractResult> extractFromUrl(String url, String query) async {
    final fetchResult = await fetchUrl(url);
    final content = fetchResult.content;

    // Simple keyword-based extraction
    final relevantSections = _extractRelevantSections(content, query);

    return ExtractResult(
      url: url,
      query: query,
      extractedContent: relevantSections,
      relevanceScore: _calculateRelevance(content, query),
      sourceTitle: fetchResult.title,
    );
  }

  // ── Private helpers ──

  Future<FetchResult?> _directFetch(String url) async {
    final response = await _dio.get<String>(url);

    final html = response.data;
    if (html == null || html.isEmpty) return null;

    final title = _extractTitle(html);
    final content = _stripHtml(html);

    if (content.trim().isEmpty) return null;

    return FetchResult(
      url: url,
      title: title,
      content: content,
      rawHtml: html,
      fetchMethod: FetchMethod.direct,
    );
  }

  String _extractTitle(String html) {
    final titleRegex = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true);
    final match = titleRegex.firstMatch(html);
    if (match != null) {
      return _decodeHtmlEntities(match.group(1)!.trim());
    }
    // Try og:title
    final ogRegex = RegExp(r'''property=["']og:title["'][^>]*content=["']([^"']*)["']''', caseSensitive: false);
    final ogMatch = ogRegex.firstMatch(html);
    if (ogMatch != null) {
      return _decodeHtmlEntities(ogMatch.group(1)!.trim());
    }
    return '';
  }

  String _stripHtml(String html) {
    // Remove script and style blocks
    var text = html.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<nav[^>]*>[\s\S]*?</nav>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<footer[^>]*>[\s\S]*?</footer>', caseSensitive: false), '');

    // Remove HTML tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');

    // Decode entities
    text = _decodeHtmlEntities(text);

    // Collapse whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }

  String _decodeHtmlEntities(String text) {
    const entities = {
      '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"',
      '&#39;': "'", '&apos;': "'", '&nbsp;': ' ', '&rlm;': '\u200F',
      '&lrm;': '\u200E', '&ndash;': '–', '&mdash;': '—',
      '&laquo;': '«', '&raquo;': '»',
    };
    var result = text;
    entities.forEach((entity, replacement) {
      result = result.replaceAll(entity, replacement);
    });
    // Handle numeric entities
    result = result.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (m) => String.fromCharCode(int.parse(m.group(1)!)),
    );
    return result;
  }

  String _extractSummary(String content) {
    // Take the first ~500 characters, preferring sentence boundaries
    if (content.length <= 500) return content;

    final first500 = content.substring(0, 500);
    // Try to end at a sentence boundary
    final sentenceEnders = ['. ', '؟ ', '! ', '.\n', '؟\n', '!\n'];
    int lastSentenceEnd = 0;
    for (final ender in sentenceEnders) {
      final idx = first500.lastIndexOf(ender);
      if (idx > lastSentenceEnd) lastSentenceEnd = idx + ender.trim().length;
    }
    if (lastSentenceEnd > 100) {
      return content.substring(0, lastSentenceEnd).trim();
    }
    return '$first500…';
  }

  List<String> _extractKeyPoints(String content) {
    // Split by sentences and take the most "important" ones
    final sentences = content.split(RegExp(r'(?<=[.؟!])\s+'));
    if (sentences.length <= 5) return sentences;

    // Simple heuristic: longer sentences with key terms are more important
    final scored = sentences.asMap().entries.map((entry) {
      final idx = entry.key;
      final sentence = entry.value;
      // Prefer first few sentences and longer ones
      double score = sentence.length / 50.0;
      if (idx < 3) score += 2.0;
      // Arabic key indicators
      if (sentence.contains(RegExp(r'[أإآا]'))) score += 0.5;
      return MapEntry(sentence, score);
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return scored.take(5).map((e) => e.key).toList();
  }

  List<String> _extractRelevantSections(String content, String query) {
    final queryTerms = query.toLowerCase().split(RegExp(r'\s+'));
    final paragraphs = content.split(RegExp(r'\n\n+'));

    final relevant = <MapEntry<String, double>>[];
    for (final para in paragraphs) {
      double score = 0;
      final lower = para.toLowerCase();
      for (final term in queryTerms) {
        final count = _countOccurrences(lower, term);
        score += count;
      }
      if (score > 0) {
        relevant.add(MapEntry(para, score));
      }
    }

    relevant.sort((a, b) => b.value.compareTo(a.value));
    return relevant.take(5).map((e) => e.key).toList();
  }

  int _countOccurrences(String text, String term) {
    int count = 0;
    int idx = 0;
    while ((idx = text.indexOf(term, idx)) != -1) {
      count++;
      idx += term.length;
    }
    return count;
  }

  double _calculateRelevance(String content, String query) {
    final queryTerms = query.toLowerCase().split(RegExp(r'\s+'));
    final lower = content.toLowerCase();
    int totalHits = 0;
    for (final term in queryTerms) {
      totalHits += _countOccurrences(lower, term);
    }
    // Normalize: 0.0 to 1.0
    return (totalHits / (content.split(RegExp(r'\s+')).length)).clamp(0.0, 1.0);
  }

  String _detectLanguage(String text) {
    final arabicChars = RegExp(r'[\u0600-\u06FF]').allMatches(text).length;
    final latinChars = RegExp(r'[a-zA-Z]').allMatches(text).length;
    if (arabicChars > latinChars) return 'ar';
    if (latinChars > arabicChars) return 'en';
    return 'mixed';
  }
}

// ── Data models ──

enum FetchMethod { direct, tavily }

class FetchResult {
  final String url;
  final String title;
  final String content;
  final String? rawHtml;
  final FetchMethod fetchMethod;

  const FetchResult({
    required this.url,
    required this.title,
    required this.content,
    this.rawHtml,
    required this.fetchMethod,
  });
}

class UrlSummary {
  final String url;
  final String title;
  final String summary;
  final List<String> keyPoints;
  final int wordCount;
  final String language;

  const UrlSummary({
    required this.url,
    required this.title,
    required this.summary,
    required this.keyPoints,
    required this.wordCount,
    required this.language,
  });
}

class ExtractResult {
  final String url;
  final String query;
  final List<String> extractedContent;
  final double relevanceScore;
  final String sourceTitle;

  const ExtractResult({
    required this.url,
    required this.query,
    required this.extractedContent,
    required this.relevanceScore,
    required this.sourceTitle,
  });
}

class FetchException implements Exception {
  final String message;
  FetchException(this.message);
  @override
  String toString() => 'FetchException: $message';
}
