/// ═══════════════════════════════════════════════════════════════════════════════
/// 🗝️ OWJ Assistant — API Keys Configuration
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Centralized storage for all API keys used across the app.
/// Reads from environment variables via `flutter_dotenv`.
///
/// **Security Note:** Never commit real API keys to version control.
/// Use `.env` file for local development, and Codemagic environment
/// variables for CI/CD builds.
///
/// Usage:
///   await dotenv.load(fileName: ".env");
///   final key = ApiKeys.gemini;
///
/// ═══════════════════════════════════════════════════════════════════════════════

library;

import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiKeys {
  ApiKeys._();

  // ─── Environment Variable Helper ─────────────────────────────────────────
  //
  // Reads a value from dotenv first; falls back to empty string.
  // All keys must be provided via .env file or Codemagic environment variables.

  static String _env(String key) {
    try {
      final value = dotenv.env[key];
      if (value != null && value.isNotEmpty) return value;
    } catch (_) {
      // dotenv not loaded yet
    }
    return '';
  }

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

  static Map<String, String> debugMasked() {
    String mask(String value) {
      if (value.isEmpty) return '<not set>';
      if (value.length <= 12) return '***';
      return '${value.substring(0, 8)}...${value.substring(value.length - 4)}';
    }
    return {
      'gemini': mask(gemini),
      'groq': mask(groq),
      'bigModel': mask(bigModel),
      'openRouter': mask(openRouter),
      'openai': mask(openai),
      'cerebras': mask(cerebras),
      'mem0': mask(mem0),
      'tavily': mask(tavily),
      'elevenLabs': mask(elevenLabs),
      'github': mask(github),
      'notion': mask(notion),
      'youtube': mask(youtube),
    };
  }
}
