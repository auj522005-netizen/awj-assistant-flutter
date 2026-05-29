import 'package:dio/dio.dart';
import 'package:owj_assistant/config/api_keys.dart';
import 'package:owj_assistant/services/storage_service.dart';

/// YouTube service using Data API v3.
///
/// Provides video search, detail retrieval, recommendations,
/// and trending discovery. Returns structured video data.
class YoutubeService {
  YoutubeService({Dio? dio, StorageService? storage})
      : _dio = dio ?? Dio(BaseOptions(
          baseUrl: 'https://www.googleapis.com/youtube/v3',
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        )),
        _storage = storage ?? StorageService.instance;

  final Dio _dio;
  final StorageService _storage;

  static const _historyKey = 'youtube_search_history';
  static const _favoritesKey = 'youtube_favorites';

  // ── Public API ──

  /// Searches YouTube videos matching [query].
  ///
  /// Supports Arabic and English queries. Returns up to [maxResults]
  /// videos with titles, thumbnails, channel info, and stats.
  Future<YoutubeSearchResult> searchVideos(
    String query, {
    int maxResults = 10,
    String regionCode = 'EG',
    String relevanceLanguage = 'ar',
    VideoType videoType = VideoType.any,
  }) async {
    _ensureConfigured();

    try {
      final params = <String, dynamic>{
        'part': 'snippet',
        'q': query,
        'type': 'video',
        'maxResults': maxResults,
        'key': ApiKeys.youtubeApiKey,
        'regionCode': regionCode,
        'relevanceLanguage': relevanceLanguage,
        'safeSearch': 'moderate',
      };

      if (videoType != VideoType.any) {
        params['videoType'] = videoType.name;
      }

      final response = await _dio.get<Map<String, dynamic>>('/search', queryParameters: params);

      final data = response.data!;
      final items = data['items'] as List<dynamic>? ?? [];

      // Get video IDs for stats
      final videoIds = items
          .map((item) => (item as Map<String, dynamic>)['id']?['videoId'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toList();

      // Fetch video statistics in batch
      final stats = videoIds.isNotEmpty ? await _getVideoStats(videoIds) : <String, VideoStats>{};

      final videos = items.map((item) {
        final i = item as Map<String, dynamic>;
        final snippet = i['snippet'] as Map<String, dynamic>? ?? {};
        final videoId = i['id']?['videoId'] as String? ?? '';
        final thumbnails = snippet['thumbnails'] as Map<String, dynamic>? ?? {};
        final defaultThumb = thumbnails['medium'] ?? thumbnails['high'] ?? thumbnails['default'] ?? {};

        return YoutubeVideo(
          id: videoId,
          title: snippet['title'] as String? ?? '',
          description: snippet['description'] as String? ?? '',
          thumbnailUrl: defaultThumb['url'] as String? ?? '',
          channelTitle: snippet['channelTitle'] as String? ?? '',
          channelId: snippet['channelId'] as String? ?? '',
          publishedAt: DateTime.tryParse(snippet['publishedAt'] as String? ?? '') ?? DateTime.now(),
          url: 'https://youtube.com/watch?v=$videoId',
          stats: stats[videoId],
        );
      }).toList();

      // Save search history
      await _saveSearchHistory(query);

      return YoutubeSearchResult(
        query: query,
        videos: videos,
        totalResults: data['pageInfo']?['totalResults'] as int? ?? 0,
        nextPageToken: data['nextPageToken'] as String?,
      );
    } on DioException catch (e) {
      throw YoutubeException('Search failed: ${e.message}');
    }
  }

  /// Gets detailed information for a specific video by [id].
  Future<YoutubeVideoDetail> getVideoDetails(String id) async {
    _ensureConfigured();

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/videos',
        queryParameters: {
          'part': 'snippet,statistics,contentDetails',
          'id': id,
          'key': ApiKeys.youtubeApiKey,
        },
      );

      final items = (response.data?['items'] as List<dynamic>? ?? []);
      if (items.isEmpty) {
        throw YoutubeException('Video not found: $id');
      }

      final item = items[0] as Map<String, dynamic>;
      final snippet = item['snippet'] as Map<String, dynamic>? ?? {};
      final statistics = item['statistics'] as Map<String, dynamic>? ?? {};
      final contentDetails = item['contentDetails'] as Map<String, dynamic>? ?? {};
      final thumbnails = snippet['thumbnails'] as Map<String, dynamic>? ?? {};
      final defaultThumb = thumbnails['maxres'] ?? thumbnails['high'] ?? thumbnails['medium'] ?? thumbnails['default'] ?? {};

      return YoutubeVideoDetail(
        id: id,
        title: snippet['title'] as String? ?? '',
        description: snippet['description'] as String? ?? '',
        thumbnailUrl: defaultThumb['url'] as String? ?? '',
        channelTitle: snippet['channelTitle'] as String? ?? '',
        channelId: snippet['channelId'] as String? ?? '',
        publishedAt: DateTime.tryParse(snippet['publishedAt'] as String? ?? '') ?? DateTime.now(),
        url: 'https://youtube.com/watch?v=$id',
        viewCount: _parseInt(statistics['viewCount']),
        likeCount: _parseInt(statistics['likeCount']),
        commentCount: _parseInt(statistics['commentCount']),
        favoriteCount: _parseInt(statistics['favoriteCount']),
        duration: _parseDuration(contentDetails['duration'] as String? ?? ''),
        tags: (snippet['tags'] as List<dynamic>? ?? []).cast<String>(),
        categoryId: snippet['categoryId'] as String? ?? '',
        defaultLanguage: snippet['defaultLanguage'] as String?,
      );
    } on DioException catch (e) {
      throw YoutubeException('Get video details failed: ${e.message}');
    }
  }

  /// Gets video recommendations based on user [interests].
  Future<List<YoutubeVideo>> getRecommendations(
    List<String> interests, {
    int maxResults = 10,
    String regionCode = 'EG',
  }) async {
    final allVideos = <YoutubeVideo>[];
    final seenIds = <String>{};

    for (final interest in interests.take(3)) {
      try {
        final result = await searchVideos(
          interest,
          maxResults: (maxResults / interests.take(3).length).ceil(),
          regionCode: regionCode,
        );

        for (final video in result.videos) {
          if (!seenIds.contains(video.id)) {
            seenIds.add(video.id);
            allVideos.add(video);
          }
        }
      } catch (_) {
        continue;
      }
    }

    return allVideos.take(maxResults).toList();
  }

  /// Gets trending videos for a [regionCode].
  Future<List<YoutubeVideo>> getTrending({
    String regionCode = 'EG',
    int maxResults = 10,
  }) async {
    _ensureConfigured();

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/videos',
        queryParameters: {
          'part': 'snippet,statistics',
          'chart': 'mostPopular',
          'regionCode': regionCode,
          'maxResults': maxResults,
          'key': ApiKeys.youtubeApiKey,
          'videoCategoryId': '0', // All categories
        },
      );

      final items = (response.data?['items'] as List<dynamic>? ?? []);
      return items.map((item) {
        final i = item as Map<String, dynamic>;
        final snippet = i['snippet'] as Map<String, dynamic>? ?? {};
        final statistics = i['statistics'] as Map<String, dynamic>? ?? {};
        final thumbnails = snippet['thumbnails'] as Map<String, dynamic>? ?? {};
        final defaultThumb = thumbnails['medium'] ?? thumbnails['high'] ?? thumbnails['default'] ?? {};

        return YoutubeVideo(
          id: i['id'] as String? ?? '',
          title: snippet['title'] as String? ?? '',
          description: snippet['description'] as String? ?? '',
          thumbnailUrl: defaultThumb['url'] as String? ?? '',
          channelTitle: snippet['channelTitle'] as String? ?? '',
          channelId: snippet['channelId'] as String? ?? '',
          publishedAt: DateTime.tryParse(snippet['publishedAt'] as String? ?? '') ?? DateTime.now(),
          url: 'https://youtube.com/watch?v=${i['id']}',
          stats: VideoStats(
            viewCount: _parseInt(statistics['viewCount']),
            likeCount: _parseInt(statistics['likeCount']),
            commentCount: _parseInt(statistics['commentCount']),
          ),
        );
      }).toList();
    } on DioException catch (e) {
      throw YoutubeException('Get trending failed: ${e.message}');
    }
  }

  /// Adds a video to favorites list.
  Future<void> addToFavorites(YoutubeVideo video) async {
    final favorites = _storage.getJsonList(_favoritesKey) ?? [];
    favorites.insert(0, {
      'id': video.id,
      'title': video.title,
      'url': video.url,
      'thumbnailUrl': video.thumbnailUrl,
      'channelTitle': video.channelTitle,
      'addedAt': DateTime.now().toIso8601String(),
    });
    if (favorites.length > 100) favorites.removeRange(100, favorites.length);
    await _storage.setJsonList(_favoritesKey, favorites);
  }

  /// Gets the list of favorite videos.
  List<Map<String, dynamic>> getFavorites() {
    return _storage.getJsonList(_favoritesKey) ?? [];
  }

  // ── Private helpers ──

  void _ensureConfigured() {
    if (!ApiKeys.hasYouTube) {
      throw YoutubeException('YouTube API key not configured');
    }
  }

  Future<Map<String, VideoStats>> _getVideoStats(List<String> videoIds) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/videos',
        queryParameters: {
          'part': 'statistics',
          'id': videoIds.join(','),
          'key': ApiKeys.youtubeApiKey,
        },
      );

      final items = (response.data?['items'] as List<dynamic>? ?? []);
      final statsMap = <String, VideoStats>{};

      for (final item in items) {
        final i = item as Map<String, dynamic>;
        final statistics = i['statistics'] as Map<String, dynamic>? ?? {};
        statsMap[i['id'] as String? ?? ''] = VideoStats(
          viewCount: _parseInt(statistics['viewCount']),
          likeCount: _parseInt(statistics['likeCount']),
          commentCount: _parseInt(statistics['commentCount']),
        );
      }

      return statsMap;
    } catch (_) {
      return {};
    }
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  Duration _parseDuration(String isoDuration) {
    // Parse ISO 8601 duration: PT#H#M#S
    final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final match = regex.firstMatch(isoDuration);
    if (match == null) return Duration.zero;

    return Duration(
      hours: int.tryParse(match.group(1) ?? '0') ?? 0,
      minutes: int.tryParse(match.group(2) ?? '0') ?? 0,
      seconds: int.tryParse(match.group(3) ?? '0') ?? 0,
    );
  }

  Future<void> _saveSearchHistory(String query) async {
    final history = _storage.getStringList(_historyKey) ?? [];
    history.remove(query);
    history.insert(0, query);
    if (history.length > 50) history.removeRange(50, history.length);
    await _storage.setStringList(_historyKey, history);
  }
}

// ── Data models ──

enum VideoType { any, episode, movie }

class YoutubeVideo {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String channelTitle;
  final String channelId;
  final DateTime publishedAt;
  final String url;
  final VideoStats? stats;

  const YoutubeVideo({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.channelTitle,
    required this.channelId,
    required this.publishedAt,
    required this.url,
    this.stats,
  });
}

class VideoStats {
  final int viewCount;
  final int likeCount;
  final int commentCount;

  const VideoStats({
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
  });

  String get formattedViews {
    if (viewCount >= 1000000) return '${(viewCount / 1000000).toStringAsFixed(1)}M';
    if (viewCount >= 1000) return '${(viewCount / 1000).toStringAsFixed(1)}K';
    return viewCount.toString();
  }
}

class YoutubeVideoDetail {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String channelTitle;
  final String channelId;
  final DateTime publishedAt;
  final String url;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final int favoriteCount;
  final Duration duration;
  final List<String> tags;
  final String categoryId;
  final String? defaultLanguage;

  const YoutubeVideoDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.channelTitle,
    required this.channelId,
    required this.publishedAt,
    required this.url,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.favoriteCount,
    required this.duration,
    required this.tags,
    required this.categoryId,
    this.defaultLanguage,
  });

  String get formattedDuration {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60);
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class YoutubeSearchResult {
  final String query;
  final List<YoutubeVideo> videos;
  final int totalResults;
  final String? nextPageToken;

  const YoutubeSearchResult({
    required this.query,
    required this.videos,
    required this.totalResults,
    this.nextPageToken,
  });
}

class YoutubeException implements Exception {
  final String message;
  YoutubeException(this.message);
  @override
  String toString() => 'YoutubeException: $message';
}
