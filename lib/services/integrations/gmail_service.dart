import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:owj_assistant/config/api_keys.dart';
import 'package:owj_assistant/services/integrations/google_oauth_service.dart';
import 'package:owj_assistant/services/storage_service.dart';

/// Gmail service using Google API v1.
///
/// Requires Google OAuth token obtained via [GoogleOauthService].
/// Supports sending emails, checking unread count, and searching emails.
/// All user-facing strings are in Egyptian Arabic.
class GmailService {
  GmailService({Dio? dio, GoogleOauthService? oauth, StorageService? storage})
      : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
          },
        )),
        _oauth = oauth ?? GoogleOauthService(),
        _storage = storage ?? StorageService.instance;

  final Dio _dio;
  final GoogleOauthService _oauth;
  final StorageService _storage;

  /// Gmail API v1 base URL
  static const _baseUrl = 'https://gmail.googleapis.com/gmail/v1/users/me';

  /// Storage keys
  static const _sentHistoryKey = 'gmail_sent_history';
  static const _draftsKey = 'gmail_drafts';

  // ── Public API ──

  /// Sends an email to [to] with [subject] and [body].
  ///
  /// Returns the sent message ID on success.
  /// Throws [GmailException] on failure.
  Future<GmailSendResult> sendEmail({
    required String to,
    required String subject,
    required String body,
    List<String>? cc,
    List<String>? bcc,
  }) async {
    final token = await _ensureAuthToken();

    // Build the raw RFC 2822 email
    final rawMessage = _buildRawMessage(
      to: to,
      subject: subject,
      body: body,
      cc: cc,
      bcc: bcc,
    );

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/messages/send',
        data: {'raw': rawMessage},
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      final messageId = response.data?['id'] as String? ?? '';

      // Save to sent history
      await _saveToSentHistory(to: to, subject: subject, messageId: messageId);

      return GmailSendResult(
        messageId: messageId,
        threadId: response.data?['threadId'] as String?,
        to: to,
        subject: subject,
        label: 'تم إرسال الإيميل بنجاح ✉️',
      );
    } on DioException catch (e) {
      throw GmailException('فشل إرسال الإيميل: ${_mapDioError(e)}');
    }
  }

  /// Gets the count of unread emails in the inbox.
  ///
  /// Returns an [UnreadCountResult] with the count and label.
  Future<UnreadCountResult> getUnreadCount() async {
    final token = await _ensureAuthToken();

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/labels/INBOX',
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      final count = response.data?['messagesUnread'] as int? ?? 0;

      return UnreadCountResult(
        count: count,
        label: count == 0
            ? 'مفيش إيميلات جديدة 📭'
            : count == 1
                ? 'عندك إيميل واحد جديد 📧'
                : count <= 10
                    ? 'عندك $count إيميلات جديدة 📬'
                    : 'عندك $count إيميل جديدة! 📨',
      );
    } on DioException catch (e) {
      throw GmailException('فشل جلب عدد الإيميلات: ${_mapDioError(e)}');
    }
  }

  /// Searches emails matching the given [query].
  ///
  /// Supports Gmail search operators (from:, to:, subject:, label:, etc.).
  /// Returns up to [maxResults] results.
  Future<List<GmailMessage>> searchEmails(
    String query, {
    int maxResults = 10,
  }) async {
    final token = await _ensureAuthToken();

    try {
      // First, search for message IDs
      final searchResponse = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/messages',
        queryParameters: {
          'q': query,
          'maxResults': maxResults,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
        }),
      );

      final messages = searchResponse.data?['messages'] as List<dynamic>? ?? [];
      if (messages.isEmpty) {
        return [];
      }

      // Fetch details for each message
      final results = <GmailMessage>[];
      for (final msg in messages) {
        final msgId = msg['id'] as String?;
        if (msgId == null) continue;

        try {
          final detail = await _fetchMessageDetail(msgId, token);
          results.add(detail);
        } catch (_) {
          // Skip messages that fail to fetch
          continue;
        }
      }

      return results;
    } on DioException catch (e) {
      throw GmailException('فشل البحث في الإيميلات: ${_mapDioError(e)}');
    }
  }

  /// Gets recent emails from the inbox.
  Future<List<GmailMessage>> getRecentEmails({int maxResults = 5}) async {
    return searchEmails('in:inbox', maxResults: maxResults);
  }

  /// Gets a specific email by message ID.
  Future<GmailMessage> getEmail(String messageId) async {
    final token = await _ensureAuthToken();
    return _fetchMessageDetail(messageId, token);
  }

  /// Checks if Gmail is authenticated and configured.
  Future<bool> isAvailable() async {
    if (!ApiKeys.isAvailable('gmailId')) return false;
    return _oauth.isAuthenticated();
  }

  /// Gets the authenticated user's email address.
  Future<String?> getUserEmail() async {
    final profile = await _oauth.getUserProfile();
    return profile?.email;
  }

  // ── Private helpers ──

  /// Ensures a valid OAuth token is available.
  Future<String> _ensureAuthToken() async {
    final token = await _oauth.getAccessToken();
    if (token == null) {
      throw GmailException(
        'مش متصل بحساب جوجل. سجل دخول الأول 🔐',
      );
    }
    return token;
  }

  /// Fetches a single message's detail.
  Future<GmailMessage> _fetchMessageDetail(
    String messageId,
    String token,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_baseUrl/messages/$messageId',
      queryParameters: {'format': 'metadata', 'metadataHeaders': ['From', 'To', 'Subject', 'Date']},
      options: Options(headers: {
        'Authorization': 'Bearer $token',
      }),
    );

    final data = response.data!;
    final headers = (data['payload']?['headers'] as List<dynamic>? ?? []);

    String getHeader(String name) {
      for (final h in headers) {
        if ((h['name'] as String?)?.toLowerCase() == name.toLowerCase()) {
          return h['value'] as String? ?? '';
        }
      }
      return '';
    }

    final labels = (data['labelIds'] as List<dynamic>? ?? [])
        .cast<String>();

    return GmailMessage(
      id: data['id'] as String? ?? '',
      threadId: data['threadId'] as String? ?? '',
      from: getHeader('From'),
      to: getHeader('To'),
      subject: getHeader('Subject'),
      date: getHeader('Date'),
      snippet: data['snippet'] as String? ?? '',
      labels: labels,
      isUnread: labels.contains('UNREAD'),
      isStarred: labels.contains('STARRED'),
      isImportant: labels.contains('IMPORTANT'),
    );
  }

  /// Builds a base64url-encoded RFC 2822 raw message.
  String _buildRawMessage({
    required String to,
    required String subject,
    required String body,
    List<String>? cc,
    List<String>? bcc,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('To: $to');
    if (cc != null && cc.isNotEmpty) {
      buffer.writeln('Cc: ${cc.join(', ')}');
    }
    if (bcc != null && bcc.isNotEmpty) {
      buffer.writeln('Bcc: ${bcc.join(', ')}');
    }
    buffer.writeln('Subject: =?utf-8?B?${base64Encode(utf8.encode(subject))}?=');
    buffer.writeln('Content-Type: text/plain; charset=utf-8');
    buffer.writeln('MIME-Version: 1.0');
    buffer.writeln();
    buffer.write(body);

    final raw = buffer.toString();
    return base64Encode(utf8.encode(raw)).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
  }

  /// Maps DioException to user-friendly Arabic error messages.
  String _mapDioError(DioException e) {
    switch (e.response?.statusCode) {
      case 401:
        return 'التوكن انتهى، سجل دخول تاني';
      case 403:
        return 'ممنوع الوصول، اتأكد من الصلاحيات';
      case 404:
        return 'الإيميل مش موجود';
      case 429:
        return 'طلبات كتير أوي، استنى شوية';
      case 500:
        return 'خطأ في سيرفر جوجل';
      default:
        return e.message ?? 'خطأ غير معروف';
    }
  }

  /// Saves a sent email to local history.
  Future<void> _saveToSentHistory({
    required String to,
    required String subject,
    required String messageId,
  }) async {
    final history = _storage.getStringList(_sentHistoryKey);
    final entry = jsonEncode({
      'to': to,
      'subject': subject,
      'messageId': messageId,
      'sentAt': DateTime.now().toIso8601String(),
    });
    history.insert(0, entry);
    // Keep only last 50
    if (history.length > 50) history.removeRange(50, history.length);
    await _storage.setStringList(_sentHistoryKey, history);
  }
}

// ── Data models ──

/// Result of sending an email.
class GmailSendResult {
  /// Gmail message ID.
  final String messageId;

  /// Thread ID (for conversation grouping).
  final String? threadId;

  /// Recipient email.
  final String to;

  /// Email subject.
  final String subject;

  /// Arabic success label.
  final String label;

  const GmailSendResult({
    required this.messageId,
    this.threadId,
    required this.to,
    required this.subject,
    required this.label,
  });
}

/// Result of checking unread count.
class UnreadCountResult {
  /// Number of unread emails.
  final int count;

  /// Arabic label describing the count.
  final String label;

  const UnreadCountResult({
    required this.count,
    required this.label,
  });

  bool get hasUnread => count > 0;
}

/// A Gmail message with metadata.
class GmailMessage {
  /// Message ID.
  final String id;

  /// Thread ID.
  final String threadId;

  /// Sender (From header).
  final String from;

  /// Recipient (To header).
  final String to;

  /// Subject line.
  final String subject;

  /// Date string from header.
  final String date;

  /// Snippet (short preview of body).
  final String snippet;

  /// Gmail labels (INBOX, UNREAD, STARRED, etc.).
  final List<String> labels;

  /// Whether the message is unread.
  final bool isUnread;

  /// Whether the message is starred.
  final bool isStarred;

  /// Whether the message is marked important.
  final bool isImportant;

  const GmailMessage({
    required this.id,
    required this.threadId,
    required this.from,
    required this.to,
    required this.subject,
    required this.date,
    required this.snippet,
    required this.labels,
    required this.isUnread,
    required this.isStarred,
    required this.isImportant,
  });

  /// Egyptian Arabic summary for display.
  String get summaryAr {
    final fromName = from.split('<').first.trim();
    if (isUnread) {
      return '📧 جديد من $fromName: $subject';
    }
    return '✉️ من $fromName: $subject';
  }
}

/// Gmail service exception.
class GmailException implements Exception {
  final String message;
  GmailException(this.message);

  @override
  String toString() => 'GmailException: $message';
}
