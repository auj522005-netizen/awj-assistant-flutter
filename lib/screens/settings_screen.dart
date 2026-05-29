/// ═══════════════════════════════════════════════════════════════════════════════
/// ⚙️ OWJ Assistant — Settings Screen
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Settings screen with sections for AI model, voice, language,
/// integrations, API status, and about info.
///
/// ═══════════════════════════════════════════════════════════════════════════════

library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:owj_assistant/config/app_config.dart';
import 'package:owj_assistant/config/api_keys.dart';
import 'package:owj_assistant/config/theme.dart';
import 'package:owj_assistant/models/ai_model.dart';
import 'package:owj_assistant/providers/app_provider.dart';
import 'package:owj_assistant/providers/chat_provider.dart';
import 'package:owj_assistant/services/ai/ai_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          // ─── AI Model Section ──────────────────────────────────────────
          _SettingsSection(
            title: 'الموديل الذكي',
            icon: Icons.smart_toy_rounded,
            children: [
              _ModelSettingTile(),
              _QuickModelTile(),
              _DeepModelTile(),
            ],
          ),

          SizedBox(height: 20),

          // ─── Voice Section ──────────────────────────────────────────────
          _SettingsSection(
            title: 'الصوت',
            icon: Icons.record_voice_over_rounded,
            children: [
              _TtsProviderTile(),
              _TtsSpeedTile(),
            ],
          ),

          SizedBox(height: 20),

          // ─── Language Section ───────────────────────────────────────────
          _SettingsSection(
            title: 'اللغة',
            icon: Icons.language_rounded,
            children: [
              _LanguageTile(),
            ],
          ),

          SizedBox(height: 20),

          // ─── Integrations Section ───────────────────────────────────────
          _SettingsSection(
            title: 'التكاملات',
            icon: Icons.extension_rounded,
            children: [
              _IntegrationTile(name: 'جوجل', icon: Icons.g_mobiledata, connected: false),
              _IntegrationTile(name: 'نوشن', icon: Icons.note_rounded, connected: false),
              _IntegrationTile(name: 'يوتيوب', icon: Icons.play_circle, connected: true),
            ],
          ),

          SizedBox(height: 20),

          // ─── API Status Section ─────────────────────────────────────────
          _ApiStatusSection(),

          SizedBox(height: 20),

          // ─── About Section ──────────────────────────────────────────────
          _SettingsSection(
            title: 'عن أوج',
            icon: Icons.info_outline_rounded,
            children: [
              _AboutTile(),
            ],
          ),

          SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── Settings Section ──────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: OwjColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: OwjColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: OwjColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: OwjColors.border, width: 0.5),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

// ─── Model Setting Tiles ───────────────────────────────────────────────────────

class _ModelSettingTile extends StatelessWidget {
  const _ModelSettingTile();

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final config = appProvider.modelConfig;

    return _SettingsTile(
      title: 'موديل المحادثة',
      subtitle: config.chatModel,
      icon: Icons.chat_rounded,
      onTap: () => _showModelPicker(context, 'chat'),
    );
  }
}

class _QuickModelTile extends StatelessWidget {
  const _QuickModelTile();

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final config = appProvider.modelConfig;

    return _SettingsTile(
      title: 'موديل الرد السريع',
      subtitle: config.quickModel,
      icon: Icons.bolt_rounded,
      onTap: () => _showModelPicker(context, 'quick'),
    );
  }
}

class _DeepModelTile extends StatelessWidget {
  const _DeepModelTile();

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final config = appProvider.modelConfig;

    return _SettingsTile(
      title: 'موديل التحليل العميق',
      subtitle: config.deepModel,
      icon: Icons.psychology_rounded,
      onTap: () => _showModelPicker(context, 'deep'),
    );
  }
}

void _showModelPicker(BuildContext context, String taskType) {
  final chatProvider = context.read<ChatProvider>();
  final models = chatProvider.allModels.take(15).toList();

  showModalBottomSheet(
    context: context,
    backgroundColor: OwjColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: OwjColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'اختر الموديل',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...models.map((model) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  model.nameAr,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                ),
                subtitle: Text(
                  model.id,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10,
                    color: OwjColors.textTertiary,
                  ),
                ),
                trailing: model.isFree
                    ? const Text(
                        'مجاني',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          color: OwjColors.success,
                        ),
                      )
                    : null,
                onTap: () {
                  final appProvider = context.read<AppProvider>();
                  final config = appProvider.modelConfig;
                  ModelConfig newConfig;

                  switch (taskType) {
                    case 'chat':
                      newConfig = config.copyWith(chatModel: model.id);
                      break;
                    case 'quick':
                      newConfig = config.copyWith(quickModel: model.id);
                      break;
                    case 'deep':
                      newConfig = config.copyWith(deepModel: model.id);
                      break;
                    default:
                      newConfig = config.copyWith(chatModel: model.id);
                  }

                  appProvider.updateModelConfig(newConfig);
                  Navigator.pop(ctx);
                },
              )),
        ],
      ),
    ),
  );
}

// ─── Voice Settings ────────────────────────────────────────────────────────────

class _TtsProviderTile extends StatelessWidget {
  const _TtsProviderTile();

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final provider = appProvider.getSetting('ttsProvider', 'elevenLabs');

    final providerNames = {
      'elevenLabs': 'ElevenLabs',
      'openAI': 'OpenAI TTS',
      'bigModel': 'GLM-4 صوت',
      'system': 'النظام',
    };

    return _SettingsTile(
      title: 'مزود الصوت',
      subtitle: providerNames[provider] ?? provider,
      icon: Icons.speaker_rounded,
      onTap: () {
        // Show TTS provider picker
        showModalBottomSheet(
          context: context,
          backgroundColor: OwjColors.surfaceElevated,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: providerNames.entries.map((e) => ListTile(
                    title: Text(e.value, style: const TextStyle(fontFamily: 'Cairo')),
                    trailing: e.key == provider
                        ? const Icon(Icons.check, color: OwjColors.primary)
                        : null,
                    onTap: () {
                      context.read<AppProvider>().setSetting('ttsProvider', e.key);
                      Navigator.pop(ctx);
                    },
                  )).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _TtsSpeedTile extends StatelessWidget {
  const _TtsSpeedTile();

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final speed = appProvider.getSetting<double>('ttsSpeed', 1.0);

    return _SettingsTile(
      title: 'سرعة الصوت',
      subtitle: '${(speed * 100).toInt()}%',
      icon: Icons.speed_rounded,
      onTap: () {
        // Show speed picker
      },
    );
  }
}

// ─── Language Setting ──────────────────────────────────────────────────────────

class _LanguageTile extends StatelessWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final lang = appProvider.getSetting('language', 'ar');

    return _SettingsTile(
      title: 'لغة التطبيق',
      subtitle: lang == 'ar' ? 'العربية (مصري)' : 'English',
      icon: Icons.translate_rounded,
      onTap: () {
        final newLang = lang == 'ar' ? 'en' : 'ar';
        appProvider.setSetting('language', newLang);
      },
    );
  }
}

// ─── Integration Tiles ─────────────────────────────────────────────────────────

class _IntegrationTile extends StatelessWidget {
  final String name;
  final IconData icon;
  final bool connected;

  const _IntegrationTile({
    required this.name,
    required this.icon,
    required this.connected,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      title: name,
      subtitle: connected ? 'متصل ✅' : 'مش متصل',
      icon: icon,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: connected
              ? OwjColors.success.withValues(alpha: 0.15)
              : OwjColors.surfaceVariant,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          connected ? 'متصل' : 'اتصل',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: connected ? OwjColors.success : OwjColors.textSecondary,
          ),
        ),
      ),
      onTap: () {
        if (!connected) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('جاري الاتصال بـ $name...')),
          );
        }
      },
    );
  }
}

// ─── API Status Section ────────────────────────────────────────────────────────

class _ApiStatusSection extends StatefulWidget {
  const _ApiStatusSection();

  @override
  State<_ApiStatusSection> createState() => _ApiStatusSectionState();
}

class _ApiStatusSectionState extends State<_ApiStatusSection> {
  List<ProviderStatus> _statuses = [];
  bool _testing = false;

  Future<void> _testConnections() async {
    setState(() => _testing = true);
    try {
      final chatProvider = context.read<ChatProvider>();
      _statuses = await chatProvider.testAllConnections();
    } catch (_) {
      _statuses = [];
    }
    setState(() => _testing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.wifi_tethering_rounded, color: OwjColors.primary, size: 20),
            const SizedBox(width: 8),
            const Text(
              'حالة الاتصال',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: OwjColors.textPrimary,
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _testing ? null : _testConnections,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
              ),
              child: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: OwjColors.textInverted),
                    )
                  : const Text(
                      'اختبر',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: OwjColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: OwjColors.border, width: 0.5),
          ),
          child: _statuses.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'اضغط "اختبر" عشان تتأكد من الاتصال',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: OwjColors.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : Column(
                  children: _statuses.map((s) => _ApiStatusTile(status: s)).toList(),
                ),
        ),
      ],
    );
  }
}

class _ApiStatusTile extends StatelessWidget {
  final ProviderStatus status;

  const _ApiStatusTile({required this.status});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        status.isAvailable ? Icons.check_circle : Icons.cancel,
        color: status.isAvailable ? OwjColors.success : OwjColors.error,
        size: 20,
      ),
      title: Text(
        status.provider,
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
      ),
      subtitle: status.errorMessage != null
          ? Text(
              status.errorMessage!,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: OwjColors.error),
            )
          : null,
      trailing: status.latency != null
          ? Text(
              '${status.latency!.inMilliseconds}ms',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: OwjColors.textTertiary,
              ),
            )
          : null,
    );
  }
}

// ─── About Tile ────────────────────────────────────────────────────────────────

class _AboutTile extends StatelessWidget {
  const _AboutTile();

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      title: 'أوج — مساعدك الذكي المصري',
      subtitle: 'v${AppConfig.version} (${AppConfig.buildNumber})',
      icon: Icons.star_rounded,
      onTap: () {
        // Show API key status for debugging
        final debug = ApiKeys.debugMasked();
        final configCount = ApiKeys.configuredProviders;
        debugPrint('=== أوج API Keys Debug ===');
        debug.forEach((k, v) => debugPrint('  $k: $v'));
        debugPrint('Configured providers: $configCount');

        showAboutDialog(
          context: context,
          applicationName: AppConfig.appNameAr,
          applicationVersion: 'v${AppConfig.version} (${AppConfig.buildNumber})',
          applicationIcon: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              gradient: OwjColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('🌟', style: TextStyle(fontSize: 24))),
          ),
          children: [
            Text(
              'أوج هو مساعد ذكي مصري بيتكلم مصري وبيفهمك.\n'
              'بيستخدم أحدث موديلات الذكاء الاصطناعي عشان يساعدك في حياتك اليومية.\n\n'
              'المزودين المتصلين: ${configCount.isEmpty ? "لا يوجد" : configCount.join("، ")}',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
              textDirection: TextDirection.rtl,
            ),
          ],
        );
      },
    );
  }
}

// ─── Settings Tile (Reusable) ──────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: Icon(icon, color: OwjColors.primary, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: OwjColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11,
          color: OwjColors.textSecondary,
        ),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_left, size: 20, color: OwjColors.textTertiary),
      onTap: onTap,
    );
  }
}
