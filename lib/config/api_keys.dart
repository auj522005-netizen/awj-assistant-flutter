/// ═══════════════════════════════════════════════════════════════════════════════
/// 🗝️ OWJ Assistant — API Keys Configuration
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Centralized storage for all API keys used across the app.
/// Reads from THREE sources in priority order:
///   1. `--dart-define` compile-time constants (Codemagic builds)
///   2. `flutter_dotenv` .env file (local development)
///   3. `Platform.environment` system env vars (fallback)
///
/// **Security Note:** Never commit real API keys to version control.
/// Use `.env` file for local development, and Codemagic `--dart-define`
/// flags for CI/CD builds.
///
/// ═══════════════════════════════════════════════════════════════════════════════

library;

import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiKeys {
  ApiKeys._();

  // ─── Multi-Source Key Reader ─────────────────────────────────────────────
  //
  // Priority: dart-define (compile-time) > dotenv (asset) > Platform.environment
  //
  // In Codemagic builds, --dart-define flags bake the keys into the binary.
  // In local dev, .env file provides the keys.
  // Platform.environment is a last resort for desktop/emulator testing.

  static String _env(String key) {
    // 1. Try compile-time --dart-define (always available, baked into binary)
    // We can't use const String.fromEnvironment directly in a getter,
    // so we use a static map populated at class initialization.
    final compileTime = _dartDefines[key];
    if (compileTime != null && compileTime.isNotEmpty) return compileTime;

    // 2. Try dotenv (.env file bundled as asset)
    try {
      final value = dotenv.env[key];
      if (value != null && value.isNotEmpty) return value;
    } catch (_) {
      // dotenv not loaded yet
    }

    // 3. Try Platform.environment (system env vars)
    try {
      final value = Platform.environment[key];
      if (value != null && value.isNotEmpty) return value;
    } catch (_) {
      // Platform not available
    }

    return '';
  }

  // ─── Compile-Time Defines (from --dart-define flags) ──────────────────────
  //
  // These are populated by Codemagic at build time via:
  //   flutter build apk --dart-define=GEMINI_API_KEY=xxx ...
  //
  // String.fromEnvironment MUST be const, so we read them once into a map.

  static final Map<String, String> _dartDefines = {
    'GEMINI_API_KEY': const String.fromEnvironment('GEMINI_API_KEY', defaultValue: ''),
    'GROQ_API_KEY': const String.fromEnvironment('GROQ_API_KEY', defaultValue: ''),
    'CEREBRAS_API_KEY': const String.fromEnvironment('CEREBRAS_API_KEY', defaultValue: ''),
    'OPENROUTER_API_KEY': const String.fromEnvironment('OPENROUTER_API_KEY', defaultValue: ''),
    'OPENAI_API_KEY': const String.fromEnvironment('OPENAI_API_KEY', defaultValue: ''),
    'BIGMODEL_API_KEY': const String.fromEnvironment('BIGMODEL_API_KEY', defaultValue: ''),
    'MEM0_API_KEY': const String.fromEnvironment('MEM0_API_KEY', defaultValue: ''),
    'TAVILY_API_KEY': const String.fromEnvironment('TAVILY_API_KEY', defaultValue: ''),
    'TAVILY_MCP_KEY': const String.fromEnvironment('TAVILY_MCP_KEY', defaultValue: ''),
    'ELEVENLABS_API_KEY': const String.fromEnvironment('ELEVENLABS_API_KEY', defaultValue: ''),
    'GITHUB_TOKEN': const String.fromEnvironment('GITHUB_TOKEN', defaultValue: ''),
    'NOTION_TOKEN': const String.fromEnvironment('NOTION_TOKEN', defaultValue: ''),
    'YOUTUBE_API_KEY': const String.fromEnvironment('YOUTUBE_API_KEY', defaultValue: ''),
    'GMAIL_CLIENT_ID': const String.fromEnvironment('GMAIL_CLIENT_ID', defaultValue: ''),
    'GMAIL_CLIENT_SECRET': const String.fromEnvironment('GMAIL_CLIENT_SECRET', defaultValue: ''),
    'FIREBASE_API_KEY': const String.fromEnvironment('FIREBASE_API_KEY', defaultValue: ''),
    'FIREBASE_PROJECT_ID': const String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: ''),
    'FIREBASE_APP_ID': const String.fromEnvironment('FIREBASE_APP_ID', defaultValue: ''),
  };

  // ─── AI Provider Keys ─────────────────────────────────────────────────────

  /// Google Gemini API Key
  static String get gemini => _env('GEMINI_API_KEY');

  /// Groq API Key
  static String get groq => _env('GROQ_API_KEY');

  /// BigModel (ZhipuAI) API Key
  static String get bigModel => _env('BIGMODEL_API_KEY');

  /// OpenRouter API Key
  static String get openRouter => _env('OPENROUTER_API_KEY');

  /// OpenAI API Key
  static String get openai => _env('OPENAI_API_KEY');

  /// Cerebras API Key
  static String get cerebras => _env('CEREBRAS_API_KEY');

  // ─── Memory & Knowledge Keys ─────────────────────────────────────────────

  /// Mem0 API Key
  static String get mem0 => _env('MEM0_API_KEY');

  // ─── Search & Research Keys ──────────────────────────────────────────────

  /// Tavily Search API Key
  static String get tavily => _env('TAVILY_API_KEY');

  /// Tavily MCP API Key
  static String get tavilyMcp => _env('TAVILY_MCP_KEY');

  // ─── Voice & TTS Keys ────────────────────────────────────────────────────

  /// ElevenLabs API Key
  static String get elevenLabs => _env('ELEVENLABS_API_KEY');

  // ─── Integration Keys ────────────────────────────────────────────────────

  /// GitHub Personal Access Token
  static String get github => _env('GITHUB_TOKEN');

  /// Notion Integration Token
  static String get notion => _env('NOTION_TOKEN');

  /// YouTube Data API Key
  static String get youtube => _env('YOUTUBE_API_KEY');

  // ─── Google / Gmail OAuth Keys ───────────────────────────────────────────

  /// Gmail OAuth Client ID
  static String get gmailId => _env('GMAIL_CLIENT_ID');

  /// Gmail OAuth Client Secret
  static String get gmailSecret => _env('GMAIL_CLIENT_SECRET');

  // ─── Firebase Keys ───────────────────────────────────────────────────────

  /// Firebase Web API Key
  static String get firebaseApi => _env('FIREBASE_API_KEY');

  /// Firebase Project ID
  static String get firebaseProject => _env('FIREBASE_PROJECT_ID');

  /// Firebase App ID (Android)
  static String get firebaseAppId => _env('FIREBASE_APP_ID');

  // ─── Convenience Boolean Getters ──────────────────────────────────────

  static bool get hasGemini => gemini.isNotEmpty;
  static bool get hasGroq => groq.isNotEmpty;
  static bool get hasBigModel => bigModel.isNotEmpty;
  static bool get hasOpenRouter => openRouter.isNotEmpty;
  static bool get hasOpenAI => openai.isNotEmpty;
  static bool get hasCerebras => cerebras.isNotEmpty;
  static bool get hasMem0 => mem0.isNotEmpty;
  static bool get hasTavily => tavily.isNotEmpty;
  static bool get hasElevenLabs => elevenLabs.isNotEmpty;
  static bool get hasGithub => github.isNotEmpty;
  static bool get hasNotion => notion.isNotEmpty;
  static bool get hasYoutube => youtube.isNotEmpty;
  static bool get hasYouTube => youtube.isNotEmpty;
  static bool get hasGmail => gmailId.isNotEmpty;
  static bool get hasGitHub => github.isNotEmpty;

  // ─── Aliased Getters (for compatibility) ──────────────────────────────

  static String get groqApiKey => groq;
  static String get openaiApiKey => openai;
  static String get bigModelApiKey => bigModel;
  static String get bigmodelApiKey => bigModel;
  static String get mem0ApiKey => mem0;
  static String get elevenLabsApiKey => elevenLabs;
  static String get mem0OrgId => 'owj';
  static String get mem0ProjectId => 'default';
  static String get openrouterApiKey => openRouter;
  static String get geminiApiKey => gemini;
  static String get cerebrasApiKey => cerebras;
  static String get youtubeApiKey => youtube;
  static String get notionApiKey => notion;
  static String get tavilyApiKey => tavily;
  static String get gmailClientId => gmailId;
  static String get gmailClientSecret => gmailSecret;
  static String get notionDatabaseId => '';
  static String get githubRepo => '';
  static String get githubUsername => '';
  static String get githubPat => github;

  static bool hasKey(String keyName) => isAvailable(keyName);

  static List<String> get configuredProviders {
    final providers = <String>[];
    if (hasGemini) providers.add('gemini');
    if (hasGroq) providers.add('groq');
    if (hasBigModel) providers.add('bigmodel');
    if (hasOpenRouter) providers.add('openrouter');
    if (hasOpenAI) providers.add('openai');
    if (hasCerebras) providers.add('cerebras');
    return providers;
  }

  // ─── Utility Methods ─────────────────────────────────────────────────────

  static bool isAvailable(String keyName) {
    switch (keyName) {
      case 'gemini':      return gemini.isNotEmpty;
      case 'groq':        return groq.isNotEmpty;
      case 'bigModel':    return bigModel.isNotEmpty;
      case 'openRouter':  return openRouter.isNotEmpty;
      case 'openai':      return openai.isNotEmpty;
      case 'cerebras':    return cerebras.isNotEmpty;
      case 'mem0':        return mem0.isNotEmpty;
      case 'tavily':      return tavily.isNotEmpty;
      case 'tavilyMcp':   return tavilyMcp.isNotEmpty;
      case 'elevenLabs':  return elevenLabs.isNotEmpty;
      case 'github':      return github.isNotEmpty;
      case 'notion':      return notion.isNotEmpty;
      case 'youtube':     return youtube.isNotEmpty;
      case 'gmailId':     return gmailId.isNotEmpty;
      case 'gmailSecret': return gmailSecret.isNotEmpty;
      case 'firebaseApi':     return firebaseApi.isNotEmpty;
      case 'firebaseProject': return firebaseProject.isNotEmpty;
      case 'firebaseAppId':   return firebaseAppId.isNotEmpty;
      default: return false;
    }
  }

  /// Check which key source is active for a given key
  static String keySource(String key) {
    if (_dartDefines[key] != null && _dartDefines[key]!.isNotEmpty) {
      return 'dart-define';
    }
    try {
      if (dotenv.env[key] != null && dotenv.env[key]!.isNotEmpty) {
        return '.env';
      }
    } catch (_) {}
    try {
      if (Platform.environment[key] != null && Platform.environment[key]!.isNotEmpty) {
        return 'platform';
      }
    } catch (_) {}
    return 'none';
  }

  static Map<String, String> debugMasked() {
    String mask(String value) {
      if (value.isEmpty) return '<not set>';
      if (value.length <= 12) return '***';
      return '${value.substring(0, 8)}...${value.substring(value.length - 4)}';
    }
    return {
      'gemini': '${mask(gemini)} [${keySource('GEMINI_API_KEY')}]',
      'groq': '${mask(groq)} [${keySource('GROQ_API_KEY')}]',
      'bigModel': '${mask(bigModel)} [${keySource('BIGMODEL_API_KEY')}]',
      'openRouter': '${mask(openRouter)} [${keySource('OPENROUTER_API_KEY')}]',
      'openai': '${mask(openai)} [${keySource('OPENAI_API_KEY')}]',
      'cerebras': '${mask(cerebras)} [${keySource('CEREBRAS_API_KEY')}]',
      'mem0': '${mask(mem0)} [${keySource('MEM0_API_KEY')}]',
      'tavily': '${mask(tavily)} [${keySource('TAVILY_API_KEY')}]',
      'elevenLabs': '${mask(elevenLabs)} [${keySource('ELEVENLABS_API_KEY')}]',
    };
  }
}
