import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:owj_assistant/config/api_keys.dart';
import 'package:owj_assistant/services/integrations/tavily_service.dart';
import 'package:owj_assistant/services/storage_service.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// MCP Client Service — Model Context Protocol Client for OWJ Assistant
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// A comprehensive MCP (Model Context Protocol) client that connects to
/// MCP servers via JSON-RPC 2.0 over HTTP/SSE, supporting:
///
///   - Multiple simultaneous MCP server connections
///   - Tool discovery and invocation via JSON-RPC protocol
///   - SSE (Server-Sent Events) for streaming responses
///   - Tool definition caching for performance
///   - Tavily MCP integration (search, extract, crawl)
///   - Graceful error handling with Arabic messages
///   - Fallback to direct Tavily API when MCP is unavailable
///
/// MCP Protocol Reference:
///   - Transport: HTTP POST with JSON-RPC 2.0
///   - Initialize: `initialize` method with capabilities negotiation
///   - Tool listing: `tools/list` method
///   - Tool invocation: `tools/call` method with arguments
///   - SSE streaming for long-running tool calls
///
/// All user-facing strings are in Egyptian Arabic.
/// ═══════════════════════════════════════════════════════════════════════════════

class McpClientService {
  McpClientService({
    Dio? dio,
    TavilyService? tavilyService,
    StorageService? storage,
  })  : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json, text/event-stream',
              },
            )),
        _tavilyService = tavilyService ?? TavilyService(),
        _storage = storage ?? StorageService.instance;

  final Dio _dio;
  final TavilyService _tavilyService;
  final StorageService _storage;

  // ── Storage Keys ────────────────────────────────────────────────────────

  static const _toolCacheKey = 'mcp_tool_cache';
  static const _serverConfigKey = 'mcp_server_configs';
  static const _callHistoryKey = 'mcp_call_history';
  static const _serverStatusKey = 'mcp_server_status';

  // ── In-Memory State ─────────────────────────────────────────────────────

  /// Registered MCP servers, keyed by server ID.
  final Map<String, McpServerConnection> _servers = {};

  /// Cached tool definitions, keyed by "serverId:toolName".
  final Map<String, McpToolDefinition> _toolCache = {};

  /// JSON-RPC request ID counter.
  int _nextRequestId = 1;

  /// Whether the service has been initialized.
  bool _initialized = false;

  /// Stream controllers for SSE events.
  final Map<String, StreamController<McpSseEvent>> _sseControllers = {};

  // ── Initialization ──────────────────────────────────────────────────────

  /// Initialize the MCP client service.
  ///
  /// Loads cached server configs and tool definitions,
  /// then attempts to connect to all configured servers.
  Future<void> initialize() async {
    if (_initialized) return;

    // Load cached tool definitions
    _loadToolCache();

    // Load and register saved servers
    await _loadServerConfigs();

    // Register built-in Tavily MCP server
    _registerBuiltinServers();

    _initialized = true;
  }

  /// Register built-in MCP servers (Tavily).
  void _registerBuiltinServers() {
    if (!_servers.containsKey('tavily')) {
      registerServer(McpServerConfig(
        id: 'tavily',
        name: 'Tavily MCP',
        description: 'بحث واستخراج وتحليل محتوى الويب',
        endpoint: 'https://mcp.tavily.com/mcp',
        transport: McpTransport.httpJsonRpc,
        apiKey: ApiKeys.tavilyMcp,
        isEnabled: ApiKeys.tavilyMcp.isNotEmpty,
        isBuiltin: true,
        icon: '🔍',
      ));
    }
  }

  // ── Server Management ───────────────────────────────────────────────────

  /// Register a new MCP server.
  ///
  /// The server will be connected immediately if [config.isEnabled] is true.
  /// Server configuration is persisted for future sessions.
  Future<McpServerStatus> registerServer(McpServerConfig config) async {
    final connection = McpServerConnection(
      config: config,
      status: McpConnectionStatus.disconnected,
      connectedAt: null,
      serverInfo: null,
      capabilities: null,
    );

    _servers[config.id] = connection;

    // Persist config
    await _saveServerConfigs();

    // Auto-connect if enabled
    if (config.isEnabled && config.apiKey.isNotEmpty) {
      return connectServer(config.id);
    }

    return McpServerStatus(
      serverId: config.id,
      name: config.name,
      status: McpConnectionStatus.disconnected,
      message: 'السيرفر مسجل لكن مش متصل',
    );
  }

  /// Remove an MCP server by ID.
  ///
  /// Disconnects the server first if connected.
  Future<void> removeServer(String serverId) async {
    await disconnectServer(serverId);
    _servers.remove(serverId);

    // Remove cached tools for this server
    _toolCache.removeWhere((key, _) => key.startsWith('$serverId:'));
    await _saveToolCache();
    await _saveServerConfigs();
  }

  /// Connect to a registered MCP server.
  ///
  /// Sends the MCP `initialize` handshake to negotiate capabilities
  /// and discover available tools.
  Future<McpServerStatus> connectServer(String serverId) async {
    final connection = _servers[serverId];
    if (connection == null) {
      throw McpClientException(
        'السيرفر "$serverId" مش مسجل عندنا ❌',
      );
    }

    final config = connection.config;

    if (config.apiKey.isEmpty) {
      _updateConnectionStatus(serverId, McpConnectionStatus.error);
      return McpServerStatus(
        serverId: serverId,
        name: config.name,
        status: McpConnectionStatus.error,
        message: 'مفتاح API مش موجود — لازم تضيفه الأول 🔑',
      );
    }

    _updateConnectionStatus(serverId, McpConnectionStatus.connecting);

    try {
      // MCP Initialize handshake
      final initResponse = await _sendJsonRpc(
        serverId: serverId,
        method: 'initialize',
        params: {
          'protocolVersion': '2024-11-05',
          'capabilities': {
            'tools': {},
            'sampling': {},
          },
          'clientInfo': {
            'name': 'OWJ-Assistant',
            'version': '1.0.0',
          },
        },
      );

      // Parse server info and capabilities
      final result = initResponse['result'] as Map<String, dynamic>? ?? {};
      final serverInfo = McpServerInfo.fromJson(result);
      final capabilities = result['capabilities'] as Map<String, dynamic>? ?? {};

      // Send initialized notification
      await _sendJsonRpcNotification(
        serverId: serverId,
        method: 'notifications/initialized',
      );

      // Update connection state
      _servers[serverId] = connection.copyWith(
        status: McpConnectionStatus.connected,
        connectedAt: DateTime.now(),
        serverInfo: serverInfo,
        capabilities: capabilities,
      );

      // Discover tools
      await discoverTools(serverId);

      // Persist status
      await _saveServerStatus(serverId);

      return McpServerStatus(
        serverId: serverId,
        name: config.name,
        status: McpConnectionStatus.connected,
        message: 'تم الاتصال بـ "${config.name}" بنجاح ✅',
        serverInfo: serverInfo,
        toolCount: _getServerToolCount(serverId),
      );
    } on McpClientException {
      rethrow;
    } catch (e) {
      _updateConnectionStatus(serverId, McpConnectionStatus.error);

      // Try fallback for Tavily
      if (serverId == 'tavily' && ApiKeys.hasTavily) {
        _servers[serverId] = connection.copyWith(
          status: McpConnectionStatus.fallback,
          connectedAt: DateTime.now(),
        );
        _registerTavilyFallbackTools();
        await _saveServerStatus(serverId);

        return McpServerStatus(
          serverId: serverId,
          name: config.name,
          status: McpConnectionStatus.fallback,
          message: 'الاتصال بـ MCP فشل — بنستخدم Tavily API المباشر كـ بديل ⚠️',
          toolCount: _getServerToolCount(serverId),
        );
      }

      return McpServerStatus(
        serverId: serverId,
        name: config.name,
        status: McpConnectionStatus.error,
        message: 'فشل الاتصال بـ "${config.name}": ${_arabicError(e)} ❌',
      );
    }
  }

  /// Disconnect from a specific MCP server.
  Future<void> disconnectServer(String serverId) async {
    final connection = _servers[serverId];
    if (connection == null) return;

    // Close any SSE streams
    _sseControllers[serverId]?.close();
    _sseControllers.remove(serverId);

    _updateConnectionStatus(serverId, McpConnectionStatus.disconnected);
    await _saveServerStatus(serverId);
  }

  /// Connect to all registered and enabled servers.
  Future<List<McpServerStatus>> connectAll() async {
    await initialize();
    final results = <McpServerStatus>[];

    for (final entry in _servers.entries) {
      if (entry.value.config.isEnabled) {
        try {
          final status = await connectServer(entry.key);
          results.add(status);
        } catch (e) {
          results.add(McpServerStatus(
            serverId: entry.key,
            name: entry.value.config.name,
            status: McpConnectionStatus.error,
            message: 'فشل الاتصال: ${_arabicError(e)} ❌',
          ));
        }
      }
    }

    return results;
  }

  /// Disconnect from all servers.
  Future<void> disconnectAll() async {
    for (final serverId in _servers.keys.toList()) {
      await disconnectServer(serverId);
    }
  }

  /// Get the status of a specific server.
  McpServerStatus getServerStatus(String serverId) {
    final connection = _servers[serverId];
    if (connection == null) {
      return McpServerStatus(
        serverId: serverId,
        name: '',
        status: McpConnectionStatus.disconnected,
        message: 'السيرفر مش مسجل',
      );
    }

    return McpServerStatus(
      serverId: serverId,
      name: connection.config.name,
      status: connection.status,
      message: _statusMessageAr(connection),
      serverInfo: connection.serverInfo,
      toolCount: _getServerToolCount(serverId),
    );
  }

  /// Get statuses of all registered servers.
  List<McpServerStatus> getAllServerStatuses() {
    return _servers.keys.map(getServerStatus).toList();
  }

  /// Enable or disable a server.
  Future<void> setServerEnabled(String serverId, bool enabled) async {
    final connection = _servers[serverId];
    if (connection == null) return;

    _servers[serverId] = connection.copyWith(
      config: connection.config.copyWith(isEnabled: enabled),
    );

    await _saveServerConfigs();

    if (enabled) {
      await connectServer(serverId);
    } else {
      await disconnectServer(serverId);
    }
  }

  // ── Tool Discovery ──────────────────────────────────────────────────────

  /// Discover available tools from a specific MCP server.
  ///
  /// Sends `tools/list` JSON-RPC request and caches the results.
  Future<List<McpToolDefinition>> discoverTools(String serverId) async {
    final connection = _servers[serverId];
    if (connection == null) {
      throw McpClientException(
        'السيرفر "$serverId" مش مسجل ❌',
      );
    }

    if (connection.status != McpConnectionStatus.connected &&
        connection.status != McpConnectionStatus.fallback) {
      throw McpClientException(
        'السيرفر "${connection.config.name}" مش متصل — اتصل بيه الأول 🔌',
      );
    }

    // For fallback mode, return already registered tools
    if (connection.status == McpConnectionStatus.fallback) {
      return _toolCache.entries
          .where((e) => e.key.startsWith('$serverId:'))
          .map((e) => e.value)
          .toList();
    }

    try {
      final response = await _sendJsonRpc(
        serverId: serverId,
        method: 'tools/list',
        params: {},
      );

      final result = response['result'] as Map<String, dynamic>? ?? {};
      final toolsList = result['tools'] as List<dynamic>? ?? [];

      // Remove old tools for this server
      _toolCache.removeWhere((key, _) => key.startsWith('$serverId:'));

      // Parse and cache new tools
      final tools = <McpToolDefinition>[];
      for (final toolJson in toolsList) {
        final tool = McpToolDefinition.fromJson(
          toolJson as Map<String, dynamic>,
          serverId: serverId,
          serverName: connection.config.name,
        );
        _toolCache['$serverId:${tool.name}'] = tool;
        tools.add(tool);
      }

      await _saveToolCache();
      return tools;
    } catch (e) {
      throw McpClientException(
        'فشل اكتشاف الأدوات من "${connection.config.name}": ${_arabicError(e)} ❌',
      );
    }
  }

  /// Discover tools from all connected servers.
  Future<List<McpToolDefinition>> discoverAllTools() async {
    final allTools = <McpToolDefinition>[];

    for (final entry in _servers.entries) {
      if (entry.value.status == McpConnectionStatus.connected) {
        try {
          final tools = await discoverTools(entry.key);
          allTools.addAll(tools);
        } catch (_) {
          // Skip servers that fail tool discovery
        }
      }
    }

    return allTools;
  }

  /// Get all cached tool definitions.
  List<McpToolDefinition> getAllTools() {
    return _toolCache.values.toList();
  }

  /// Get tools for a specific server.
  List<McpToolDefinition> getServerTools(String serverId) {
    return _toolCache.entries
        .where((e) => e.key.startsWith('$serverId:'))
        .map((e) => e.value)
        .toList();
  }

  /// Get a specific tool definition by server and name.
  McpToolDefinition? getTool(String serverId, String toolName) {
    return _toolCache['$serverId:$toolName'];
  }

  /// Search tools by name or description.
  List<McpToolDefinition> searchTools(String query) {
    final lowerQuery = query.toLowerCase();
    return _toolCache.values.where((tool) {
      return tool.name.toLowerCase().contains(lowerQuery) ||
          tool.description.toLowerCase().contains(lowerQuery) ||
          tool.descriptionAr.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  // ── Tool Invocation ─────────────────────────────────────────────────────

  /// Call an MCP tool with the given arguments.
  ///
  /// Routes the call to the appropriate server and returns the result.
  /// Falls back to direct Tavily API for Tavily tools when MCP is unavailable.
  Future<McpToolResult> callTool({
    required String serverId,
    required String toolName,
    Map<String, dynamic> arguments = const {},
    Duration? timeout,
  }) async {
    final connection = _servers[serverId];
    if (connection == null) {
      throw McpClientException(
        'السيرفر "$serverId" مش مسجل ❌',
      );
    }

    // Check if tool is known
    final toolDef = _toolCache['$serverId:$toolName'];

    // Validate arguments against tool schema
    if (toolDef != null) {
      _validateToolArguments(toolDef, arguments);
    }

    // Record call start
    final callStart = DateTime.now();
    final callId = 'call_${serverId}_${toolName}_${callStart.millisecondsSinceEpoch}';

    try {
      McpToolResult result;

      if (connection.status == McpConnectionStatus.fallback) {
        // Use direct API fallback
        result = await _callToolFallback(
          serverId: serverId,
          toolName: toolName,
          arguments: arguments,
        );
      } else if (connection.status == McpConnectionStatus.connected) {
        // Use MCP JSON-RPC protocol
        result = await _callToolMcp(
          serverId: serverId,
          toolName: toolName,
          arguments: arguments,
          timeout: timeout,
        );
      } else {
        throw McpClientException(
          'السيرفر "${connection.config.name}" مش متصل — اتصل بيه الأول 🔌',
        );
      }

      // Record successful call
      await _recordCallHistory(McpCallRecord(
        callId: callId,
        serverId: serverId,
        toolName: toolName,
        arguments: arguments,
        result: result,
        duration: DateTime.now().difference(callStart),
        status: McpCallStatus.success,
        timestamp: callStart,
      ));

      return result;
    } on McpClientException {
      rethrow;
    } catch (e) {
      // Record failed call
      await _recordCallHistory(McpCallRecord(
        callId: callId,
        serverId: serverId,
        toolName: toolName,
        arguments: arguments,
        result: null,
        duration: DateTime.now().difference(callStart),
        status: McpCallStatus.failed,
        error: e.toString(),
        timestamp: callStart,
      ));

      throw McpClientException(
        'فشل تنفيذ الأداة "$toolName": ${_arabicError(e)} ❌',
      );
    }
  }

  /// Call a tool by its fully qualified name (serverId:toolName).
  Future<McpToolResult> callToolByFqn(
    String fqn, {
    Map<String, dynamic> arguments = const {},
    Duration? timeout,
  }) async {
    final parts = fqn.split(':');
    if (parts.length != 2) {
      throw McpClientException(
        'صيغة اسم الأداة غلط — لازم تكون "serverId:toolName" ❌',
      );
    }
    return callTool(
      serverId: parts[0],
      toolName: parts[1],
      arguments: arguments,
      timeout: timeout,
    );
  }

  /// Call a tool with SSE streaming support.
  ///
  /// Returns a stream of [McpSseEvent] for progressive results.
  Stream<McpSseEvent> callToolStream({
    required String serverId,
    required String toolName,
    Map<String, dynamic> arguments = const {},
  }) async* {
    final connection = _servers[serverId];
    if (connection == null) {
      throw McpClientException(
        'السيرفر "$serverId" مش مسجل ❌',
      );
    }

    if (connection.status != McpConnectionStatus.connected) {
      throw McpClientException(
        'السيرفر "${connection.config.name}" مش متصل 🔌',
      );
    }

    final requestId = _getNextRequestId();

    try {
      // Use SSE transport for streaming
      final request = _buildJsonRpcRequest(
        id: requestId,
        method: 'tools/call',
        params: {
          'name': toolName,
          'arguments': arguments,
        },
      );

      final endpoint = connection.config.endpoint;
      final headers = _buildHeaders(connection.config);

      // Start SSE connection
      final response = await _dio.post<ResponseBody>(
        endpoint,
        data: jsonEncode(request),
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      // Parse SSE events from response stream
      final stream = response.data!.stream;
      String buffer = '';

      await for (final chunk in stream) {
        buffer += utf8.decode(chunk, allowMalformed: true);
        final lines = buffer.split('\n');
        buffer = lines.removeLast(); // Keep incomplete line in buffer

        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            if (data.isEmpty) continue;
            if (data == '[DONE]') return;

            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              yield McpSseEvent(
                eventId: json['id']?.toString() ?? requestId.toString(),
                eventType: json['type'] as String? ?? 'message',
                data: json,
                timestamp: DateTime.now(),
              );
            } catch (_) {
              // Skip malformed JSON
            }
          }
        }
      }
    } on DioException catch (e) {
      throw McpClientException(
        'فشل البث من "$toolName": ${_arabicDioError(e)} ❌',
      );
    }
  }

  // ── Convenience Methods for Tavily Tools ────────────────────────────────

  /// Search the web using Tavily.
  ///
  /// Uses MCP protocol if connected, falls back to direct Tavily API.
  Future<McpToolResult> tavilySearch(
    String query, {
    int maxResults = 5,
    String searchDepth = 'basic',
    List<String>? includeDomains,
    List<String>? excludeDomains,
  }) async {
    return callTool(
      serverId: 'tavily',
      toolName: 'tavily_search',
      arguments: {
        'query': query,
        'max_results': maxResults,
        'search_depth': searchDepth,
        if (includeDomains != null) 'include_domains': includeDomains,
        if (excludeDomains != null) 'exclude_domains': excludeDomains,
      },
    );
  }

  /// Extract content from URLs using Tavily.
  Future<McpToolResult> tavilyExtract(List<String> urls) async {
    return callTool(
      serverId: 'tavily',
      toolName: 'tavily_extract',
      arguments: {
        'urls': urls,
      },
    );
  }

  /// Crawl a website using Tavily.
  Future<McpToolResult> tavilyCrawl(
    String url, {
    int maxDepth = 1,
    int maxPages = 10,
    String? query,
  }) async {
    return callTool(
      serverId: 'tavily',
      toolName: 'tavily_crawl',
      arguments: {
        'url': url,
        'max_depth': maxDepth,
        'max_pages': maxPages,
        if (query != null) 'query': query,
      },
    );
  }

  // ── Call History ────────────────────────────────────────────────────────

  /// Get recent MCP tool call history.
  Future<List<McpCallRecord>> getCallHistory({int limit = 50}) async {
    final history = _storage.getJsonList(_callHistoryKey);
    return history.take(limit).map(_parseCallRecord).toList();
  }

  /// Clear call history.
  Future<void> clearCallHistory() async {
    await _storage.delete(_callHistoryKey);
  }

  // ── JSON-RPC Protocol ───────────────────────────────────────────────────

  /// Send a JSON-RPC 2.0 request and return the response.
  Future<Map<String, dynamic>> _sendJsonRpc({
    required String serverId,
    required String method,
    Map<String, dynamic> params = const {},
  }) async {
    final connection = _servers[serverId];
    if (connection == null) {
      throw McpClientException('السيرفر مش مسجل ❌');
    }

    final requestId = _getNextRequestId();
    final request = _buildJsonRpcRequest(
      id: requestId,
      method: method,
      params: params,
    );

    final endpoint = connection.config.endpoint;
    final headers = _buildHeaders(connection.config);

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        endpoint,
        data: jsonEncode(request),
        options: Options(headers: headers),
      );

      final data = response.data ?? {};

      // Check for JSON-RPC error
      if (data.containsKey('error')) {
        final error = data['error'] as Map<String, dynamic>;
        throw McpClientException(
          'خطأ من السيرفر: ${error["message"] ?? "خطأ غير معروف"} (كود: ${error["code"]}) ❌',
        );
      }

      return data;
    } on DioException catch (e) {
      throw McpClientException(
        'فشل الاتصال بالسيرفر: ${_arabicDioError(e)} ❌',
      );
    }
  }

  /// Send a JSON-RPC 2.0 notification (no response expected).
  Future<void> _sendJsonRpcNotification({
    required String serverId,
    required String method,
    Map<String, dynamic> params = const {},
  }) async {
    final connection = _servers[serverId];
    if (connection == null) return;

    final notification = {
      'jsonrpc': '2.0',
      'method': method,
      if (params.isNotEmpty) 'params': params,
    };

    final endpoint = connection.config.endpoint;
    final headers = _buildHeaders(connection.config);

    try {
      await _dio.post(
        endpoint,
        data: jsonEncode(notification),
        options: Options(headers: headers),
      );
    } on DioException {
      // Notifications are fire-and-forget
    }
  }

  /// Build a JSON-RPC 2.0 request object.
  Map<String, dynamic> _buildJsonRpcRequest({
    required int id,
    required String method,
    Map<String, dynamic> params = const {},
  }) {
    return {
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      if (params.isNotEmpty) 'params': params,
    };
  }

  /// Build request headers for a server connection.
  Map<String, String> _buildHeaders(McpServerConfig config) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json, text/event-stream',
    };

    if (config.apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${config.apiKey}';
    }

    // Add custom headers
    headers.addAll(config.customHeaders);

    return headers;
  }

  /// Get the next JSON-RPC request ID.
  int _getNextRequestId() => _nextRequestId++;

  // ── MCP Tool Call via Protocol ──────────────────────────────────────────

  /// Call a tool via the MCP JSON-RPC protocol.
  Future<McpToolResult> _callToolMcp({
    required String serverId,
    required String toolName,
    required Map<String, dynamic> arguments,
    Duration? timeout,
  }) async {
    final connection = _servers[serverId]!;
    final requestId = _getNextRequestId();

    final request = _buildJsonRpcRequest(
      id: requestId,
      method: 'tools/call',
      params: {
        'name': toolName,
        'arguments': arguments,
      },
    );

    final endpoint = connection.config.endpoint;
    final headers = _buildHeaders(connection.config);

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        endpoint,
        data: jsonEncode(request),
        options: Options(
          headers: headers,
          sendTimeout: timeout ?? const Duration(seconds: 60),
          receiveTimeout: timeout ?? const Duration(seconds: 60),
        ),
      );

      final data = response.data ?? {};

      // Check for JSON-RPC error
      if (data.containsKey('error')) {
        final error = data['error'] as Map<String, dynamic>;
        return McpToolResult(
          toolName: toolName,
          serverId: serverId,
          isError: true,
          content: [
            McpToolContent.text(
              text: 'خطأ من السيرفر: ${error["message"] ?? "خطأ غير معروف"} ❌',
            ),
          ],
          metadata: data,
        );
      }

      final result = data['result'] as Map<String, dynamic>? ?? {};

      // Parse tool result content
      final contentList = result['content'] as List<dynamic>? ?? [];
      final content = contentList
          .map((c) => McpToolContent.fromJson(c as Map<String, dynamic>))
          .toList();

      final isError = result['isError'] as bool? ?? false;

      return McpToolResult(
        toolName: toolName,
        serverId: serverId,
        isError: isError,
        content: content,
        metadata: result,
      );
    } on DioException catch (e) {
      throw McpClientException(
        'فشل تنفيذ الأداة عبر MCP: ${_arabicDioError(e)} ❌',
      );
    }
  }

  // ── Fallback Tool Calls ─────────────────────────────────────────────────

  /// Call a tool using the direct API fallback (when MCP is unavailable).
  Future<McpToolResult> _callToolFallback({
    required String serverId,
    required String toolName,
    required Map<String, dynamic> arguments,
  }) async {
    if (serverId == 'tavily') {
      return _callTavilyFallback(toolName, arguments);
    }

    throw McpClientException(
      'مفيش بديل متاح للسيرفر "$serverId" — الاتصال بـ MCP مطلوب ❌',
    );
  }

  /// Handle Tavily tool calls via direct API.
  Future<McpToolResult> _callTavilyFallback(
    String toolName,
    Map<String, dynamic> arguments,
  ) async {
    try {
      switch (toolName) {
        case 'tavily_search':
          return await _tavilySearchFallback(arguments);
        case 'tavily_extract':
          return await _tavilyExtractFallback(arguments);
        case 'tavily_crawl':
          return await _tavilyCrawlFallback(arguments);
        default:
          throw McpClientException(
            'الأداة "$toolName" مش متوفرة في وضع البديل ❌',
          );
      }
    } on TavilyException catch (e) {
      return McpToolResult(
        toolName: toolName,
        serverId: 'tavily',
        isError: true,
        content: [
          McpToolContent.text(
            text: 'خطأ في بحث Tavily: ${e.message} ❌',
          ),
        ],
        metadata: {},
      );
    }
  }

  /// Tavily search fallback via direct API.
  Future<McpToolResult> _tavilySearchFallback(
    Map<String, dynamic> arguments,
  ) async {
    final query = arguments['query'] as String? ?? '';
    if (query.isEmpty) {
      throw McpClientException(
        'لازم تكتب كلمة بحث 🔍',
      );
    }

    final data = await _tavilyService.search(
      query,
      maxResults: arguments['max_results'] as int? ?? 5,
      searchDepth: arguments['search_depth'] as String? ?? 'basic',
      includeDomains: (arguments['include_domains'] as List<dynamic>?)
          ?.cast<String>(),
      excludeDomains: (arguments['exclude_domains'] as List<dynamic>?)
          ?.cast<String>(),
    );

    final results = data['results'] as List<dynamic>? ?? [];
    final content = results.map((r) {
      final result = r as Map<String, dynamic>;
      return McpToolContent.text(
        text: '📌 ${result["title"] ?? ""}\n🔗 ${result["url"] ?? ""}\n${result["content"] ?? ""}',
      );
    }).toList();

    if (content.isEmpty) {
      content.add(McpToolContent.text(
        text: 'مفيش نتائج بحث لـ "$query" 😕',
      ));
    }

    return McpToolResult(
      toolName: 'tavily_search',
      serverId: 'tavily',
      isError: false,
      content: content,
      metadata: data,
      usedFallback: true,
    );
  }

  /// Tavily extract fallback via direct API.
  Future<McpToolResult> _tavilyExtractFallback(
    Map<String, dynamic> arguments,
  ) async {
    final urls = arguments['urls'] as List<dynamic>? ?? [];
    if (urls.isEmpty) {
      throw McpClientException(
        'لازم تحط رابط واحد على الأقل 🔗',
      );
    }

    final content = <McpToolContent>[];
    for (final url in urls) {
      try {
        final data = await _tavilyService.extractUrl(url as String);
        content.add(McpToolContent.text(
          text: '📄 ${data["title"] ?? ""}\n🔗 $url\n${data["content"] ?? ""}',
        ));
      } catch (e) {
        content.add(McpToolContent.text(
          text: 'فشل استخراج المحتوى من $url: ${_arabicError(e)} ❌',
        ));
      }
    }

    return McpToolResult(
      toolName: 'tavily_extract',
      serverId: 'tavily',
      isError: false,
      content: content,
      metadata: {'urls': urls, 'extractedCount': content.length},
      usedFallback: true,
    );
  }

  /// Tavily crawl fallback (uses search + extract as approximation).
  Future<McpToolResult> _tavilyCrawlFallback(
    Map<String, dynamic> arguments,
  ) async {
    final url = arguments['url'] as String? ?? '';
    if (url.isEmpty) {
      throw McpClientException(
        'لازم تحط الرابط اللي عايز تمشيه 🕷️',
      );
    }

    final query = arguments['query'] as String? ?? '';
    final maxPages = arguments['max_pages'] as int? ?? 10;

    // Use search to find related pages, then extract from the main URL
    final content = <McpToolContent>[];

    // Extract from the main URL
    try {
      final data = await _tavilyService.extractUrl(url);
      content.add(McpToolContent.text(
        text: '🕷️ صفحة رئيسية: ${data["title"] ?? ""}\n🔗 $url\n${data["content"] ?? ""}',
      ));
    } catch (e) {
      content.add(McpToolContent.text(
        text: 'فشل استخراج الصفحة الرئيسية: ${_arabicError(e)} ❌',
      ));
    }

    // Search for related pages
    if (query.isNotEmpty || maxPages > 1) {
      try {
        final searchQuery = query.isNotEmpty ? query : 'site:$url';
        final searchData = await _tavilyService.search(
          searchQuery,
          maxResults: maxPages - 1,
        );
        final results = searchData['results'] as List<dynamic>? ?? [];
        for (final r in results.take(maxPages - 1)) {
          final result = r as Map<String, dynamic>;
          content.add(McpToolContent.text(
            text: '📄 ${result["title"] ?? ""}\n🔗 ${result["url"] ?? ""}\n${result["content"] ?? ""}',
          ));
        }
      } catch (_) {
        // Skip search failures
      }
    }

    return McpToolResult(
      toolName: 'tavily_crawl',
      serverId: 'tavily',
      isError: false,
      content: content,
      metadata: {'url': url, 'pagesCrawled': content.length},
      usedFallback: true,
    );
  }

  /// Register Tavily fallback tools in the cache.
  void _registerTavilyFallbackTools() {
    const tools = [
      McpToolDefinition(
        name: 'tavily_search',
        serverId: 'tavily',
        serverName: 'Tavily MCP',
        description: 'Search the web for information using Tavily',
        descriptionAr: 'بحث في الويب عن معلومات باستخدام Tavily',
        inputSchema: {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': 'Search query',
            },
            'max_results': {
              'type': 'integer',
              'description': 'Maximum number of results',
              'default': 5,
            },
            'search_depth': {
              'type': 'string',
              'enum': ['basic', 'advanced'],
              'default': 'basic',
            },
            'include_domains': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'exclude_domains': {
              'type': 'array',
              'items': {'type': 'string'},
            },
          },
          'required': ['query'],
        },
        isFallback: true,
      ),
      McpToolDefinition(
        name: 'tavily_extract',
        serverId: 'tavily',
        serverName: 'Tavily MCP',
        description: 'Extract content from URLs using Tavily',
        descriptionAr: 'استخراج محتوى من روابط باستخدام Tavily',
        inputSchema: {
          'type': 'object',
          'properties': {
            'urls': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'List of URLs to extract content from',
            },
          },
          'required': ['urls'],
        },
        isFallback: true,
      ),
      McpToolDefinition(
        name: 'tavily_crawl',
        serverId: 'tavily',
        serverName: 'Tavily MCP',
        description: 'Crawl a website for data using Tavily',
        descriptionAr: 'الزحف لموقع ويب وجمع البيانات باستخدام Tavily',
        inputSchema: {
          'type': 'object',
          'properties': {
            'url': {
              'type': 'string',
              'description': 'Starting URL to crawl',
            },
            'max_depth': {
              'type': 'integer',
              'description': 'Maximum crawl depth',
              'default': 1,
            },
            'max_pages': {
              'type': 'integer',
              'description': 'Maximum pages to crawl',
              'default': 10,
            },
            'query': {
              'type': 'string',
              'description': 'Optional query to focus the crawl',
            },
          },
          'required': ['url'],
        },
        isFallback: true,
      ),
    ];

    for (final tool in tools) {
      _toolCache['tavily:${tool.name}'] = tool;
    }
  }

  // ── Argument Validation ─────────────────────────────────────────────────

  /// Validate tool call arguments against the tool's input schema.
  void _validateToolArguments(
    McpToolDefinition tool,
    Map<String, dynamic> arguments,
  ) {
    final schema = tool.inputSchema;
    if (schema.isEmpty) return;

    final required = schema['required'] as List<dynamic>? ?? [];
    final properties = schema['properties'] as Map<String, dynamic>? ?? {};

    // Check required arguments
    for (final req in required) {
      final key = req as String;
      if (!arguments.containsKey(key)) {
        final propDesc = properties[key]?['description'] as String? ?? key;
        throw McpClientException(
          'ال аргумент "$propDesc" مطلوب بس مش موجود ❌',
        );
      }
    }

    // Validate types for provided arguments
    for (final entry in arguments.entries) {
      final propSchema = properties[entry.key] as Map<String, dynamic>?;
      if (propSchema == null) continue;

      final expectedType = propSchema['type'] as String?;
      if (expectedType == null) continue;

      if (!_isValidType(entry.value, expectedType, propSchema)) {
        throw McpClientException(
          'نوع ال аргument "${entry.key}" غلط — المفروض يكون $expectedType ❌',
        );
      }
    }
  }

  /// Check if a value matches the expected JSON Schema type.
  bool _isValidType(
    dynamic value,
    String expectedType,
    Map<String, dynamic> schema,
  ) {
    switch (expectedType) {
      case 'string':
        return value is String;
      case 'integer':
        return value is int;
      case 'number':
        return value is num;
      case 'boolean':
        return value is bool;
      case 'array':
        if (value is! List) return false;
        final items = schema['items'] as Map<String, dynamic>?;
        if (items == null) return true;
        final itemType = items['type'] as String?;
        if (itemType == null) return true;
        return value.every((item) => _isValidType(item, itemType, items));
      case 'object':
        return value is Map;
      default:
        return true;
    }
  }

  // ── Persistence ─────────────────────────────────────────────────────────

  /// Load cached tool definitions from storage.
  void _loadToolCache() {
    final cached = _storage.getJson(_toolCacheKey);
    if (cached.isEmpty) return;

    final tools = cached['tools'] as Map<String, dynamic>? ?? {};
    for (final entry in tools.entries) {
      try {
        _toolCache[entry.key] = McpToolDefinition.fromJson(
          entry.value as Map<String, dynamic>,
        );
      } catch (_) {
        // Skip malformed entries
      }
    }
  }

  /// Save tool definitions cache to storage.
  Future<void> _saveToolCache() async {
    final toolsMap = <String, dynamic>{};
    for (final entry in _toolCache.entries) {
      toolsMap[entry.key] = entry.value.toJson();
    }
    await _storage.setJson(_toolCacheKey, {
      'tools': toolsMap,
      'cachedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Load server configurations from storage.
  Future<void> _loadServerConfigs() async {
    final configs = _storage.getJson(_serverConfigKey);
    if (configs.isEmpty) return;

    final servers = configs['servers'] as Map<String, dynamic>? ?? {};
    for (final entry in servers.entries) {
      try {
        final config = McpServerConfig.fromJson(entry.value as Map<String, dynamic>);
        // Don't re-register builtins
        if (!config.isBuiltin) {
          _servers[entry.key] = McpServerConnection(
            config: config,
            status: McpConnectionStatus.disconnected,
            connectedAt: null,
            serverInfo: null,
            capabilities: null,
          );
        }
      } catch (_) {
        // Skip malformed entries
      }
    }
  }

  /// Save server configurations to storage.
  Future<void> _saveServerConfigs() async {
    final serversMap = <String, dynamic>{};
    for (final entry in _servers.entries) {
      serversMap[entry.key] = entry.value.config.toJson();
    }
    await _storage.setJson(_serverConfigKey, {
      'servers': serversMap,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Save server connection status.
  Future<void> _saveServerStatus(String serverId) async {
    final connection = _servers[serverId];
    if (connection == null) return;

    final statuses = _storage.getJson(_serverStatusKey);
    final statusMap = statuses['statuses'] as Map<String, dynamic>? ?? {};

    statusMap[serverId] = {
      'status': connection.status.name,
      'connectedAt': connection.connectedAt?.toIso8601String(),
      'serverInfo': connection.serverInfo?.toJson(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    await _storage.setJson(_serverStatusKey, {
      'statuses': statusMap,
    });
  }

  /// Record a tool call in history.
  Future<void> _recordCallHistory(McpCallRecord record) async {
    final history = _storage.getJsonList(_callHistoryKey);
    history.insert(0, record.toJson());
    // Keep last 200 entries
    if (history.length > 200) history.removeRange(200, history.length);
    await _storage.setJsonList(_callHistoryKey, history);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Update the connection status of a server.
  void _updateConnectionStatus(
    String serverId,
    McpConnectionStatus status,
  ) {
    final connection = _servers[serverId];
    if (connection == null) return;

    _servers[serverId] = connection.copyWith(status: status);
  }

  /// Get the number of tools for a server.
  int _getServerToolCount(String serverId) {
    return _toolCache.keys
        .where((key) => key.startsWith('$serverId:'))
        .length;
  }

  /// Generate an Arabic status message for a connection.
  String _statusMessageAr(McpServerConnection connection) {
    switch (connection.status) {
      case McpConnectionStatus.disconnected:
        return 'غير متصل';
      case McpConnectionStatus.connecting:
        return 'بيتصل...';
      case McpConnectionStatus.connected:
        return 'متصل ✅';
      case McpConnectionStatus.fallback:
        return 'بيستخدم البديل ⚠️';
      case McpConnectionStatus.error:
        return 'فيه خطأ ❌';
    }
  }

  /// Convert an error to an Arabic-friendly message.
  String _arabicError(dynamic error) {
    final msg = error.toString();
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'مفيش اتصال بالإنترنت';
    }
    if (msg.contains('TimeoutException') || msg.contains('timed out')) {
      return 'الطلب اخد وقت طويل أوي';
    }
    if (msg.contains('401') || msg.contains('Unauthorized')) {
      return 'مفتاح API مش صح أو منتهي';
    }
    if (msg.contains('403') || msg.contains('Forbidden')) {
      return 'مش مسموح لك بالوصول';
    }
    if (msg.contains('404') || msg.contains('Not Found')) {
      return 'السيرفر مش موجود';
    }
    if (msg.contains('429') || msg.contains('Too Many Requests')) {
      return 'طلبات كتير — استنى شوية';
    }
    if (msg.contains('500') || msg.contains('Internal Server Error')) {
      return 'السيرفر فيه مشكلة';
    }
    if (msg.length > 100) return 'حصل خطأ تقني';
    return msg;
  }

  /// Convert a DioException to an Arabic-friendly message.
  String _arabicDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'انتهى وقت الاتصال';
      case DioExceptionType.sendTimeout:
        return 'انتهى وقت إرسال البيانات';
      case DioExceptionType.receiveTimeout:
        return 'انتهى وقت استقبال البيانات';
      case DioExceptionType.connectionError:
        return 'مفيش اتصال بالسيرفر';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        switch (code) {
          case 401:
            return 'مفتاح API مش صح';
          case 403:
            return 'مش مسموح بالوصول';
          case 404:
            return 'السيرفر مش موجود';
          case 429:
            return 'طلبات كتير — استنى شوية';
          case 500:
            return 'السيرفر فيه مشكلة';
          default:
            return 'خطأ من السيرفر ($code)';
        }
      case DioExceptionType.cancel:
        return 'الطلب اتلغى';
      case DioExceptionType.unknown:
        return 'خطأ غير معروف: ${e.message ?? ""}';
      default:
        return 'خطأ في الاتصال';
    }
  }

  /// Parse a call record from stored JSON.
  McpCallRecord _parseCallRecord(Map<String, dynamic> data) {
    return McpCallRecord(
      callId: data['callId'] as String? ?? '',
      serverId: data['serverId'] as String? ?? '',
      toolName: data['toolName'] as String? ?? '',
      arguments: data['arguments'] as Map<String, dynamic>? ?? {},
      result: data['result'] != null
          ? McpToolResult.fromJson(data['result'] as Map<String, dynamic>)
          : null,
      duration: Duration(milliseconds: data['durationMs'] as int? ?? 0),
      status: McpCallStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => McpCallStatus.failed,
      ),
      error: data['error'] as String?,
      timestamp: DateTime.tryParse(data['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Data Models
// ═══════════════════════════════════════════════════════════════════════════════

/// MCP server connection state.
enum McpConnectionStatus {
  disconnected,
  connecting,
  connected,
  fallback,
  error,
}

/// MCP transport protocol.
enum McpTransport {
  httpJsonRpc,
  sse,
  stdio,
}

/// MCP tool call status.
enum McpCallStatus {
  success,
  failed,
  timeout,
}

/// Configuration for an MCP server connection.
class McpServerConfig {
  final String id;
  final String name;
  final String description;
  final String endpoint;
  final McpTransport transport;
  final String apiKey;
  final bool isEnabled;
  final bool isBuiltin;
  final String icon;
  final Map<String, String> customHeaders;

  const McpServerConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.endpoint,
    this.transport = McpTransport.httpJsonRpc,
    this.apiKey = '',
    this.isEnabled = true,
    this.isBuiltin = false,
    this.icon = '🔌',
    this.customHeaders = const {},
  });

  factory McpServerConfig.fromJson(Map<String, dynamic> json) =>
      McpServerConfig(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        endpoint: json['endpoint'] as String? ?? '',
        transport: McpTransport.values.firstWhere(
          (t) => t.name == json['transport'],
          orElse: () => McpTransport.httpJsonRpc,
        ),
        apiKey: json['apiKey'] as String? ?? '',
        isEnabled: json['isEnabled'] as bool? ?? true,
        isBuiltin: json['isBuiltin'] as bool? ?? false,
        icon: json['icon'] as String? ?? '🔌',
        customHeaders: (json['customHeaders'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v.toString())),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'endpoint': endpoint,
        'transport': transport.name,
        'apiKey': apiKey,
        'isEnabled': isEnabled,
        'isBuiltin': isBuiltin,
        'icon': icon,
        'customHeaders': customHeaders,
      };

  McpServerConfig copyWith({
    String? id,
    String? name,
    String? description,
    String? endpoint,
    McpTransport? transport,
    String? apiKey,
    bool? isEnabled,
    bool? isBuiltin,
    String? icon,
    Map<String, String>? customHeaders,
  }) {
    return McpServerConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      endpoint: endpoint ?? this.endpoint,
      transport: transport ?? this.transport,
      apiKey: apiKey ?? this.apiKey,
      isEnabled: isEnabled ?? this.isEnabled,
      isBuiltin: isBuiltin ?? this.isBuiltin,
      icon: icon ?? this.icon,
      customHeaders: customHeaders ?? this.customHeaders,
    );
  }
}

/// Active connection to an MCP server.
class McpServerConnection {
  final McpServerConfig config;
  final McpConnectionStatus status;
  final DateTime? connectedAt;
  final McpServerInfo? serverInfo;
  final Map<String, dynamic>? capabilities;

  const McpServerConnection({
    required this.config,
    required this.status,
    this.connectedAt,
    this.serverInfo,
    this.capabilities,
  });

  McpServerConnection copyWith({
    McpServerConfig? config,
    McpConnectionStatus? status,
    DateTime? connectedAt,
    McpServerInfo? serverInfo,
    Map<String, dynamic>? capabilities,
  }) {
    return McpServerConnection(
      config: config ?? this.config,
      status: status ?? this.status,
      connectedAt: connectedAt ?? this.connectedAt,
      serverInfo: serverInfo ?? this.serverInfo,
      capabilities: capabilities ?? this.capabilities,
    );
  }
}

/// Server information returned during MCP handshake.
class McpServerInfo {
  final String name;
  final String version;
  final String protocolVersion;

  const McpServerInfo({
    required this.name,
    required this.version,
    required this.protocolVersion,
  });

  factory McpServerInfo.fromJson(Map<String, dynamic> json) => McpServerInfo(
        name: (json['serverInfo'] as Map<String, dynamic>?)?['name']
                as String? ??
            '',
        version: (json['serverInfo'] as Map<String, dynamic>?)?['version']
                as String? ??
            '',
        protocolVersion:
            json['protocolVersion'] as String? ?? '2024-11-05',
      );

  Map<String, dynamic> toJson() => {
        'serverInfo': {
          'name': name,
          'version': version,
        },
        'protocolVersion': protocolVersion,
      };
}

/// Status of an MCP server connection.
class McpServerStatus {
  final String serverId;
  final String name;
  final McpConnectionStatus status;
  final String message;
  final McpServerInfo? serverInfo;
  final int toolCount;

  const McpServerStatus({
    required this.serverId,
    required this.name,
    required this.status,
    required this.message,
    this.serverInfo,
    this.toolCount = 0,
  });

  bool get isConnected =>
      status == McpConnectionStatus.connected ||
      status == McpConnectionStatus.fallback;

  bool get isReady => status == McpConnectionStatus.connected;

  String get statusLabel {
    switch (status) {
      case McpConnectionStatus.disconnected:
        return 'غير متصل';
      case McpConnectionStatus.connecting:
        return 'بيتصل...';
      case McpConnectionStatus.connected:
        return 'متصل ✅ ($toolCount أداة)';
      case McpConnectionStatus.fallback:
        return 'بديل ⚠️ ($toolCount أداة)';
      case McpConnectionStatus.error:
        return 'خطأ ❌';
    }
  }
}

/// Definition of an MCP tool.
class McpToolDefinition {
  final String name;
  final String serverId;
  final String serverName;
  final String description;
  final String descriptionAr;
  final Map<String, dynamic> inputSchema;
  final bool isFallback;

  const McpToolDefinition({
    required this.name,
    required this.serverId,
    required this.serverName,
    required this.description,
    this.descriptionAr = '',
    this.inputSchema = const {},
    this.isFallback = false,
  });

  factory McpToolDefinition.fromJson(
    Map<String, dynamic> json, {
    String? serverId,
    String? serverName,
  }) =>
      McpToolDefinition(
        name: json['name'] as String? ?? '',
        serverId: json['serverId'] as String? ?? serverId ?? '',
        serverName: json['serverName'] as String? ?? serverName ?? '',
        description: json['description'] as String? ?? '',
        descriptionAr: json['descriptionAr'] as String? ?? '',
        inputSchema: json['inputSchema'] as Map<String, dynamic>? ?? {},
        isFallback: json['isFallback'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'serverId': serverId,
        'serverName': serverName,
        'description': description,
        'descriptionAr': descriptionAr,
        'inputSchema': inputSchema,
        'isFallback': isFallback,
      };

  /// Fully qualified name (serverId:toolName).
  String get fqn => '$serverId:$name';

  /// Best available description (Arabic preferred).
  String get bestDescription =>
      descriptionAr.isNotEmpty ? descriptionAr : description;

  /// Required parameter names from schema.
  List<String> get requiredParams {
    final required = inputSchema['required'] as List<dynamic>? ?? [];
    return required.cast<String>();
  }

  /// Optional parameter names from schema.
  List<String> get optionalParams {
    final properties = inputSchema['properties'] as Map<String, dynamic>? ?? {};
    final requiredSet = requiredParams.toSet();
    return properties.keys
        .where((key) => !requiredSet.contains(key))
        .toList();
  }
}

/// Result of an MCP tool call.
class McpToolResult {
  final String toolName;
  final String serverId;
  final bool isError;
  final List<McpToolContent> content;
  final Map<String, dynamic> metadata;
  final bool usedFallback;

  const McpToolResult({
    required this.toolName,
    required this.serverId,
    required this.isError,
    required this.content,
    required this.metadata,
    this.usedFallback = false,
  });

  factory McpToolResult.fromJson(Map<String, dynamic> json) => McpToolResult(
        toolName: json['toolName'] as String? ?? '',
        serverId: json['serverId'] as String? ?? '',
        isError: json['isError'] as bool? ?? false,
        content: (json['content'] as List<dynamic>? ?? [])
            .map((c) => McpToolContent.fromJson(c as Map<String, dynamic>))
            .toList(),
        metadata: json['metadata'] as Map<String, dynamic>? ?? {},
        usedFallback: json['usedFallback'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'toolName': toolName,
        'serverId': serverId,
        'isError': isError,
        'content': content.map((c) => c.toJson()).toList(),
        'metadata': metadata,
        'usedFallback': usedFallback,
      };

  /// Get all text content joined.
  String get textContent {
    return content
        .where((c) => c.type == McpContentType.text)
        .map((c) => c.text ?? '')
        .join('\n\n');
  }

  /// Get all image URLs.
  List<String> get imageUrls {
    return content
        .where((c) => c.type == McpContentType.image)
        .map((c) => c.data ?? '')
        .toList();
  }

  /// Egyptian Arabic summary.
  String get summaryAr {
    if (isError) return 'حصل خطأ في تنفيذ الأداة ❌';
    if (content.isEmpty) return 'مفيش نتائج';
    final textCount =
        content.where((c) => c.type == McpContentType.text).length;
    final imageCount =
        content.where((c) => c.type == McpContentType.image).length;
    final parts = <String>[];
    if (textCount > 0) parts.add('$textCount نتائج نصية');
    if (imageCount > 0) parts.add('$imageCount صور');
    return parts.join(' و ');
  }
}

/// Content item in an MCP tool result.
class McpToolContent {
  final McpContentType type;
  final String? text;
  final String? data;
  final String? mimeType;
  final Map<String, dynamic>? annotations;

  const McpToolContent({
    required this.type,
    this.text,
    this.data,
    this.mimeType,
    this.annotations,
  });

  /// Create a text content item.
  factory McpToolContent.text({required String text}) =>
      McpToolContent(type: McpContentType.text, text: text);

  /// Create an image content item.
  factory McpToolContent.image({
    required String data,
    String mimeType = 'image/png',
  }) =>
      McpToolContent(
        type: McpContentType.image,
        data: data,
        mimeType: mimeType,
      );

  /// Create a resource content item.
  factory McpToolContent.resource({
    required String uri,
    String? mimeType,
    String? text,
  }) =>
      McpToolContent(
        type: McpContentType.resource,
        data: uri,
        mimeType: mimeType,
        text: text,
      );

  factory McpToolContent.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'text';
    return McpToolContent(
      type: McpContentType.values.firstWhere(
        (t) => t.name == typeStr,
        orElse: () => McpContentType.text,
      ),
      text: json['text'] as String?,
      data: json['data'] as String?,
      mimeType: json['mimeType'] as String?,
      annotations: json['annotations'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (text != null) 'text': text,
        if (data != null) 'data': data,
        if (mimeType != null) 'mimeType': mimeType,
        if (annotations != null) 'annotations': annotations,
      };
}

/// MCP content types.
enum McpContentType {
  text,
  image,
  resource,
}

/// An SSE event from an MCP server.
class McpSseEvent {
  final String eventId;
  final String eventType;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const McpSseEvent({
    required this.eventId,
    required this.eventType,
    required this.data,
    required this.timestamp,
  });

  bool get isError => eventType == 'error';
  bool get isResult => eventType == 'result' || eventType == 'message';
  bool get isProgress => eventType == 'progress';
}

/// Record of a tool call for history tracking.
class McpCallRecord {
  final String callId;
  final String serverId;
  final String toolName;
  final Map<String, dynamic> arguments;
  final McpToolResult? result;
  final Duration duration;
  final McpCallStatus status;
  final String? error;
  final DateTime timestamp;

  const McpCallRecord({
    required this.callId,
    required this.serverId,
    required this.toolName,
    required this.arguments,
    required this.result,
    required this.duration,
    required this.status,
    this.error,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'callId': callId,
        'serverId': serverId,
        'toolName': toolName,
        'arguments': arguments,
        'result': result?.toJson(),
        'durationMs': duration.inMilliseconds,
        'status': status.name,
        'error': error,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Egyptian Arabic summary.
  String get summaryAr {
    final durationStr =
        duration.inSeconds > 0 ? '${duration.inSeconds}s' : '${duration.inMilliseconds}ms';
    switch (status) {
      case McpCallStatus.success:
        return '$toolName — تم بنجاح ($durationStr) ✅';
      case McpCallStatus.failed:
        return '$toolName — فشل ($durationStr) ❌';
      case McpCallStatus.timeout:
        return '$toolName — انتهى الوقت ($durationStr) ⏱️';
    }
  }
}

/// MCP client exception with Arabic error messages.
class McpClientException implements Exception {
  final String message;
  McpClientException(this.message);

  @override
  String toString() => 'McpClientException: $message';
}
