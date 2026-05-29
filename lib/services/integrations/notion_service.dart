import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:owj_assistant/config/api_keys.dart';
import 'package:owj_assistant/services/storage_service.dart';

/// Notion service for page search, creation, and editing.
///
/// API: https://api.notion.com/v1/
/// Integrates with Notion workspaces for note-taking,
/// knowledge management, and task tracking.
class NotionService {
  NotionService({Dio? dio, StorageService? storage})
      : _dio = dio ?? Dio(BaseOptions(
          baseUrl: 'https://api.notion.com/v1',
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'Notion-Version': '2022-06-28',
          },
        )),
        _storage = storage ?? StorageService.instance;

  final Dio _dio;
  final StorageService _storage;

  static const _localDraftsKey = 'notion_local_drafts';
  static const _recentPagesKey = 'notion_recent_pages';

  // ── Public API ──

  /// Searches pages in the connected Notion workspace.
  ///
  /// Filters by [query] and optionally by page type.
  /// Returns a list of matching pages with basic info.
  Future<List<NotionPage>> searchPages(
    String query, {
    int pageSize = 10,
    String? filterType,
  }) async {
    _ensureConfigured();

    try {
      final body = <String, dynamic>{
        'query': query,
        'page_size': pageSize,
      };

      if (filterType != null) {
        body['filter'] = {
          'property': 'object',
          'value': filterType,
        };
      }

      final response = await _dio.post<Map<String, dynamic>>(
        '/search',
        options: Options(headers: {
          'Authorization': 'Bearer ${ApiKeys.notionApiKey}',
        }),
        data: body,
      );

      final data = response.data!;
      final results = data['results'] as List<dynamic>? ?? [];

      final pages = results.map((r) {
        final item = r as Map<String, dynamic>;
        return _parsePage(item);
      }).toList();

      // Cache recent pages
      await _cacheRecentPages(pages);

      return pages;
    } on DioException catch (e) {
      throw NotionException('Search failed: ${e.message}');
    }
  }

  /// Creates a new page in Notion.
  ///
  /// If [databaseId] is provided, creates a page in that database.
  /// Otherwise, creates a standalone page in the workspace.
  Future<NotionPage> createPage({
    required String title,
    required String content,
    String? databaseId,
    List<String>? tags,
  }) async {
    _ensureConfigured();

    try {
      final children = _contentToBlocks(content);

      final Map<String, dynamic> body;

      if (databaseId != null || ApiKeys.notionDatabaseId.isNotEmpty) {
        final dbId = databaseId ?? ApiKeys.notionDatabaseId;
        body = {
          'parent': {'database_id': dbId},
          'properties': _buildDatabaseProperties(title, tags: tags),
          'children': children,
        };
      } else {
        body = {
          'parent': {'page_id': ''}, // Will use workspace root
          'properties': {
            'title': {
              'title': [{'text': {'content': title}}],
            },
          },
          'children': children,
        };
      }

      final response = await _dio.post<Map<String, dynamic>>(
        '/pages',
        options: Options(headers: {
          'Authorization': 'Bearer ${ApiKeys.notionApiKey}',
        }),
        data: body,
      );

      final page = _parsePage(response.data!);

      // Also save locally as backup
      await _saveLocalDraft(title, content);

      return page;
    } on DioException catch (e) {
      // Save locally as fallback
      await _saveLocalDraft(title, content);
      throw NotionException('Create page failed (saved locally): ${e.message}');
    }
  }

  /// Appends content blocks to an existing page.
  ///
  /// Converts [content] text to Notion blocks and appends
  /// them after the last block of the specified page.
  Future<bool> appendToPage(String pageId, String content) async {
    _ensureConfigured();

    try {
      final children = _contentToBlocks(content);

      await _dio.patch<Map<String, dynamic>>(
        '/blocks/$pageId/children',
        options: Options(headers: {
          'Authorization': 'Bearer ${ApiKeys.notionApiKey}',
        }),
        data: {
          'children': children,
        },
      );

      return true;
    } on DioException catch (e) {
      throw NotionException('Append to page failed: ${e.message}');
    }
  }

  /// Gets a page's content as structured blocks.
  Future<List<NotionBlock>> getPageContent(String pageId) async {
    _ensureConfigured();

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/blocks/$pageId/children',
        options: Options(headers: {
          'Authorization': 'Bearer ${ApiKeys.notionApiKey}',
        }),
      );

      final results = response.data?['results'] as List<dynamic>? ?? [];
      return results.map((b) => _parseBlock(b as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw NotionException('Get page content failed: ${e.message}');
    }
  }

  /// Gets local drafts (unsynced content).
  List<LocalDraft> getLocalDrafts() {
    final drafts = _storage.getJsonList(_localDraftsKey) ?? [];
    return drafts.map((d) => LocalDraft(
      title: d['title'] as String? ?? '',
      content: d['content'] as String? ?? '',
      savedAt: DateTime.tryParse(d['savedAt'] as String? ?? '') ?? DateTime.now(),
    )).toList();
  }

  /// Deletes a local draft.
  Future<void> deleteLocalDraft(int index) async {
    final drafts = _storage.getJsonList(_localDraftsKey) ?? [];
    if (index >= 0 && index < drafts.length) {
      drafts.removeAt(index);
      await _storage.setJsonList(_localDraftsKey, drafts);
    }
  }

  // ── Private helpers ──

  void _ensureConfigured() {
    if (!ApiKeys.hasNotion) {
      throw NotionException('Notion API key not configured');
    }
  }

  NotionPage _parsePage(Map<String, dynamic> item) {
    final properties = item['properties'] as Map<String, dynamic>? ?? {};
    final titleProp = properties['title'] ?? properties['Name'] ?? properties['اسم'];
    final titleList = titleProp is Map<String, dynamic>
        ? titleProp['title'] as List<dynamic>? ?? []
        : [];
    final titleText = titleList.isNotEmpty
        ? (titleList[0] as Map<String, dynamic>)['plain_text'] as String? ?? ''
        : '';

    return NotionPage(
      id: item['id'] as String? ?? '',
      title: titleText,
      url: item['url'] as String? ?? '',
      createdTime: DateTime.tryParse(item['created_time'] as String? ?? '') ?? DateTime.now(),
      lastEditedTime: DateTime.tryParse(item['last_edited_time'] as String? ?? '') ?? DateTime.now(),
      parentId: item['parent']?['page_id'] as String? ?? item['parent']?['database_id'] as String? ?? '',
      isPage: (item['object'] as String? ?? '') == 'page',
    );
  }

  NotionBlock _parseBlock(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? 'paragraph';
    final textContent = data[type]?['rich_text'] as List<dynamic>? ?? [];
    final text = textContent.map((t) {
      final rt = t as Map<String, dynamic>;
      return rt['plain_text'] as String? ?? '';
    }).join();

    return NotionBlock(
      id: data['id'] as String? ?? '',
      type: type,
      text: text,
      hasChildren: data['has_children'] as bool? ?? false,
    );
  }

  List<Map<String, dynamic>> _contentToBlocks(String content) {
    final blocks = <Map<String, dynamic>>[];
    final lines = content.split('\n');

    var currentParagraph = StringBuffer();

    for (final line in lines) {
      final trimmed = line.trim();

      // Heading detection
      if (trimmed.startsWith('### ')) {
        _flushParagraph(blocks, currentParagraph);
        currentParagraph = StringBuffer();
        blocks.add(_headingBlock(trimmed.substring(4), 3));
      } else if (trimmed.startsWith('## ')) {
        _flushParagraph(blocks, currentParagraph);
        currentParagraph = StringBuffer();
        blocks.add(_headingBlock(trimmed.substring(3), 2));
      } else if (trimmed.startsWith('# ')) {
        _flushParagraph(blocks, currentParagraph);
        currentParagraph = StringBuffer();
        blocks.add(_headingBlock(trimmed.substring(2), 1));
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        _flushParagraph(blocks, currentParagraph);
        currentParagraph = StringBuffer();
        blocks.add(_bulletedListItem(trimmed.substring(2)));
      } else if (trimmed.startsWith('---')) {
        _flushParagraph(blocks, currentParagraph);
        currentParagraph = StringBuffer();
        blocks.add(_dividerBlock());
      } else if (trimmed.isEmpty) {
        _flushParagraph(blocks, currentParagraph);
        currentParagraph = StringBuffer();
      } else {
        if (currentParagraph.isNotEmpty) currentParagraph.write(' ');
        currentParagraph.write(trimmed);
      }
    }

    _flushParagraph(blocks, currentParagraph);

    return blocks;
  }

  void _flushParagraph(List<Map<String, dynamic>> blocks, StringBuffer paragraph) {
    if (paragraph.isNotEmpty) {
      blocks.add(_paragraphBlock(paragraph.toString()));
    }
  }

  Map<String, dynamic> _paragraphBlock(String text) => {
    'object': 'block',
    'type': 'paragraph',
    'paragraph': {
      'rich_text': [_richText(text)],
    },
  };

  Map<String, dynamic> _headingBlock(String text, int level) => {
    'object': 'block',
    'type': 'heading_$level',
    'heading_$level': {
      'rich_text': [_richText(text)],
    },
  };

  Map<String, dynamic> _bulletedListItem(String text) => {
    'object': 'block',
    'type': 'bulleted_list_item',
    'bulleted_list_item': {
      'rich_text': [_richText(text)],
    },
  };

  Map<String, dynamic> _dividerBlock() => {
    'object': 'block',
    'type': 'divider',
    'divider': {},
  };

  Map<String, dynamic> _richText(String text) => {
    'type': 'text',
    'text': {'content': text},
  };

  Map<String, dynamic> _buildDatabaseProperties(String title, {List<String>? tags}) {
    final props = <String, dynamic>{
      'Name': {
        'title': [{'text': {'content': title}}],
      },
    };

    if (tags != null && tags.isNotEmpty) {
      props['Tags'] = {
        'multi_select': tags.map((t) => {'name': t}).toList(),
      };
    }

    return props;
  }

  Future<void> _saveLocalDraft(String title, String content) async {
    final drafts = _storage.getJsonList(_localDraftsKey) ?? [];
    drafts.insert(0, {
      'title': title,
      'content': content,
      'savedAt': DateTime.now().toIso8601String(),
    });
    if (drafts.length > 50) drafts.removeRange(50, drafts.length);
    await _storage.setJsonList(_localDraftsKey, drafts);
  }

  Future<void> _cacheRecentPages(List<NotionPage> pages) async {
    final cached = _storage.getJsonList(_recentPagesKey) ?? [];
    for (final page in pages.take(10)) {
      cached.insert(0, {
        'id': page.id,
        'title': page.title,
        'url': page.url,
        'lastEdited': page.lastEditedTime.toIso8601String(),
      });
    }
    // Deduplicate by id
    final seen = <String>{};
    cached.removeWhere((p) {
      final id = p['id'] as String? ?? '';
      if (seen.contains(id)) return true;
      seen.add(id);
      return false;
    });
    if (cached.length > 30) cached.removeRange(30, cached.length);
    await _storage.setJsonList(_recentPagesKey, cached);
  }
}

// ── Data models ──

class NotionPage {
  final String id;
  final String title;
  final String url;
  final DateTime createdTime;
  final DateTime lastEditedTime;
  final String parentId;
  final bool isPage;

  const NotionPage({
    required this.id,
    required this.title,
    required this.url,
    required this.createdTime,
    required this.lastEditedTime,
    required this.parentId,
    required this.isPage,
  });
}

class NotionBlock {
  final String id;
  final String type;
  final String text;
  final bool hasChildren;

  const NotionBlock({
    required this.id,
    required this.type,
    required this.text,
    required this.hasChildren,
  });
}

class LocalDraft {
  final String title;
  final String content;
  final DateTime savedAt;

  const LocalDraft({
    required this.title,
    required this.content,
    required this.savedAt,
  });
}

class NotionException implements Exception {
  final String message;
  NotionException(this.message);
  @override
  String toString() => 'NotionException: $message';
}
