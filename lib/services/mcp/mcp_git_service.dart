import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:owj_assistant/config/api_keys.dart';
import 'package:owj_assistant/services/storage_service.dart';

/// MCP Git service using the GitHub API.
///
/// Provides repository status, note saving, and commit history.
/// Uses GitHub Personal Access Token from [ApiKeys].
class McpGitService {
  McpGitService({Dio? dio, StorageService? storage})
      : _dio = dio ?? Dio(BaseOptions(
          baseUrl: 'https://api.github.com',
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        )),
        _storage = storage ?? StorageService.instance;

  final Dio _dio;
  final StorageService _storage;

  static const _notesPath = 'notes';
  static const _cacheKeyPrefix = 'git_cache_';

  // ── Public API ──

  /// Gets the current status of the configured repository.
  Future<RepoStatus> getRepoStatus() async {
    _ensureConfigured();

    try {
      // Get repo info
      final repoResponse = await _dio.get<Map<String, dynamic>>(
        '/repos/${ApiKeys.githubUsername}/${ApiKeys.githubRepo}',
        options: Options(headers: {'Authorization': 'Bearer ${ApiKeys.githubPat}'}),
      );

      final repoData = repoResponse.data!;

      // Get recent commits count
      final commitsResponse = await _dio.get<List<dynamic>>(
        '/repos/${ApiKeys.githubUsername}/${ApiKeys.githubRepo}/commits',
        queryParameters: {'per_page': 1},
        options: Options(headers: {'Authorization': 'Bearer ${ApiKeys.githubPat}'}),
      );

      // Get open issues count (used as notes count)
      final contentsResponse = await _dio.get<List<dynamic>>(
        '/repos/${ApiKeys.githubUsername}/${ApiKeys.githubRepo}/contents/$_notesPath',
        options: Options(headers: {'Authorization': 'Bearer ${ApiKeys.githubPat}'}),
      );

      final notesCount = contentsResponse.data?.length ?? 0;

      return RepoStatus(
        name: repoData['name'] as String? ?? ApiKeys.githubRepo,
        fullName: repoData['full_name'] as String? ?? '',
        description: repoData['description'] as String? ?? '',
        isPrivate: repoData['private'] as bool? ?? true,
        defaultBranch: repoData['default_branch'] as String? ?? 'main',
        stars: repoData['stargazers_count'] as int? ?? 0,
        forks: repoData['forks_count'] as int? ?? 0,
        notesCount: notesCount,
        lastActivity: DateTime.tryParse(repoData['pushed_at'] as String? ?? '') ?? DateTime.now(),
        url: repoData['html_url'] as String? ?? '',
      );
    } on DioException catch (e) {
      throw GitException('Failed to get repo status: ${e.message}');
    }
  }

  /// Saves a note as a markdown file in the repository.
  Future<NoteResult> saveNote(String content) async {
    _ensureConfigured();

    final title = _extractTitle(content);
    final filename = _sanitizeFilename(title);
    final path = '$_notesPath/$filename.md';
    final now = DateTime.now().toUtc().toIso8601String();

    final fullContent = '''---
title: $title
date: $now
tags: [owj-note]
---

$content
''';

    final contentBase64 = base64Encode(utf8.encode(fullContent));

    try {
      // Check if file already exists (to get SHA for update)
      String? existingSha;
      try {
        final existing = await _dio.get<Map<String, dynamic>>(
          '/repos/${ApiKeys.githubUsername}/${ApiKeys.githubRepo}/contents/$path',
          options: Options(headers: {'Authorization': 'Bearer ${ApiKeys.githubPat}'}),
        );
        existingSha = existing.data?['sha'] as String?;
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) rethrow;
        // File doesn't exist yet — that's fine
      }

      // Create or update the file
      final body = <String, dynamic>{
        'message': '📝 Add note: $title',
        'content': contentBase64,
      };
      if (existingSha != null) {
        body['sha'] = existingSha;
      }

      final response = await _dio.put<Map<String, dynamic>>(
        '/repos/${ApiKeys.githubUsername}/${ApiKeys.githubRepo}/contents/$path',
        options: Options(headers: {'Authorization': 'Bearer ${ApiKeys.githubPat}'}),
        data: body,
      );

      final commit = response.data?['commit'] as Map<String, dynamic>?;

      // Cache locally as backup
      await _cacheNoteLocally(title, fullContent);

      return NoteResult(
        title: title,
        path: path,
        commitSha: commit?['sha'] as String? ?? '',
        url: commit?['html_url'] as String? ?? '',
        savedAt: DateTime.now(),
      );
    } on DioException catch (e) {
      // Save locally as fallback
      await _cacheNoteLocally(title, fullContent);
      throw GitException('GitHub save failed (saved locally): ${e.message}');
    }
  }

  /// Gets recent commits from the repository.
  Future<List<CommitInfo>> getRecentCommits({int count = 10}) async {
    _ensureConfigured();

    try {
      final response = await _dio.get<List<dynamic>>(
        '/repos/${ApiKeys.githubUsername}/${ApiKeys.githubRepo}/commits',
        queryParameters: {'per_page': count},
        options: Options(headers: {'Authorization': 'Bearer ${ApiKeys.githubPat}'}),
      );

      return (response.data ?? []).map((c) {
        final commit = c as Map<String, dynamic>;
        final commitData = commit['commit'] as Map<String, dynamic>? ?? {};
        final author = commitData['author'] as Map<String, dynamic>? ?? {};

        return CommitInfo(
          sha: commit['sha'] as String? ?? '',
          message: commitData['message'] as String? ?? '',
          author: author['name'] as String? ?? 'Unknown',
          date: DateTime.tryParse(author['date'] as String? ?? '') ?? DateTime.now(),
          url: commit['html_url'] as String? ?? '',
        );
      }).toList();
    } on DioException catch (e) {
      throw GitException('Failed to get commits: ${e.message}');
    }
  }

  // ── Private helpers ──

  void _ensureConfigured() {
    if (!ApiKeys.hasGitHub) {
      throw GitException('GitHub not configured. Set GITHUB_PAT and GITHUB_USERNAME.');
    }
  }

  String _extractTitle(String content) {
    // Try to get first line or heading
    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('#')) return trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
      return trimmed.length > 50 ? '${trimmed.substring(0, 50)}...' : trimmed;
    }
    return 'Untitled Note ${DateTime.now().millisecondsSinceEpoch}';
  }

  String _sanitizeFilename(String title) {
    final sanitized = title
        .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${sanitized}_$timestamp';
  }

  Future<void> _cacheNoteLocally(String title, String content) async {
    final cached = _storage.getJsonList('$_cacheKeyPrefix${_notesPath}') ?? [];
    cached.add({
      'title': title,
      'content': content,
      'savedAt': DateTime.now().toIso8601String(),
    });
    await _storage.setJsonList('$_cacheKeyPrefix${_notesPath}', cached);
  }
}

// ── Data models ──

class RepoStatus {
  final String name;
  final String fullName;
  final String description;
  final bool isPrivate;
  final String defaultBranch;
  final int stars;
  final int forks;
  final int notesCount;
  final DateTime lastActivity;
  final String url;

  const RepoStatus({
    required this.name,
    required this.fullName,
    required this.description,
    required this.isPrivate,
    required this.defaultBranch,
    required this.stars,
    required this.forks,
    required this.notesCount,
    required this.lastActivity,
    required this.url,
  });
}

class NoteResult {
  final String title;
  final String path;
  final String commitSha;
  final String url;
  final DateTime savedAt;

  const NoteResult({
    required this.title,
    required this.path,
    required this.commitSha,
    required this.url,
    required this.savedAt,
  });
}

class CommitInfo {
  final String sha;
  final String message;
  final String author;
  final DateTime date;
  final String url;

  const CommitInfo({
    required this.sha,
    required this.message,
    required this.author,
    required this.date,
    required this.url,
  });

  String get shortSha => sha.length > 7 ? sha.substring(0, 7) : sha;
}

class GitException implements Exception {
  final String message;
  GitException(this.message);
  @override
  String toString() => 'GitException: $message';
}
