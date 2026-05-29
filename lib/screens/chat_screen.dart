/// ═══════════════════════════════════════════════════════════════════════════════
/// 💬 OWJ Assistant — Chat Screen
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Main chat screen with message list, streaming support,
/// voice input, model selector, and quick action chips.
///
/// ═══════════════════════════════════════════════════════════════════════════════

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:owj_assistant/config/theme.dart';
import 'package:owj_assistant/models/chat_message.dart';
import 'package:owj_assistant/providers/chat_provider.dart';
import 'package:owj_assistant/widgets/chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-scroll when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ChatProvider>();
      provider.scrollController.addListener(_onScroll);
    });
  }

  void _onScroll() {
    // Could add scroll-based logic here
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // ─── Quick Action Chips ──────────────────────────────────────
          _QuickActionChips(),

          // ─── Message List ────────────────────────────────────────────
          Expanded(child: _MessageList()),

          // ─── Input Bar ───────────────────────────────────────────────
          _InputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🌟', style: TextStyle(fontSize: 20)),
          SizedBox(width: 6),
          Text('أوج'),
        ],
      ),
      actions: [
        // ─── Voice Input Button ──────────────────────────────────────
        IconButton(
          icon: const Icon(Icons.mic_none_rounded),
          tooltip: 'إدخال صوتي',
          onPressed: () => _showVoiceInput(context),
        ),
        // ─── Model Selector ──────────────────────────────────────────
        _ModelSelectorButton(),
        // ─── Clear Chat ──────────────────────────────────────────────
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 20),
          tooltip: 'مسح المحادثة',
          onPressed: () => _showClearDialog(context),
        ),
      ],
    );
  }

  void _showVoiceInput(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('الإدخال الصوتي هيكون متاح قريب 🎤'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مسح المحادثة'),
        content: const Text('متأكد إنك عايز تمسح كل الرسائل؟ العملية دي مش هترجع.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('لا'),
          ),
          TextButton(
            onPressed: () {
              context.read<ChatProvider>().clearChat();
              Navigator.pop(ctx);
            },
            child: const Text('أه، امسح', style: TextStyle(color: OwjColors.error)),
          ),
        ],
      ),
    );
  }
}

// ─── Model Selector ────────────────────────────────────────────────────────────

class _ModelSelectorButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();

    return PopupMenuButton<String>(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.smart_toy_outlined,
            size: 18,
            color: chatProvider.isBusy
                ? OwjColors.warning
                : OwjColors.primary,
          ),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down, size: 16, color: OwjColors.textSecondary),
        ],
      ),
      tooltip: 'اختر الموديل',
      onSelected: (modelId) {
        context.read<ChatProvider>().switchModel(modelId);
      },
      itemBuilder: (ctx) {
        final models = chatProvider.allModels.take(12).toList();
        return models.map((model) {
          final isSelected = model.id == chatProvider.currentModel;
          return PopupMenuItem<String>(
            value: model.id,
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 18,
                  color: isSelected ? OwjColors.primary : OwjColors.textTertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    model.nameAr,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected ? OwjColors.primary : OwjColors.textPrimary,
                    ),
                  ),
                ),
                if (model.isFree)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: OwjColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'مجاني',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 9,
                        color: OwjColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}

// ─── Quick Action Chips ────────────────────────────────────────────────────────

class _QuickActionChips extends StatelessWidget {
  static const _chips = [
    _ChipData(label: '🔍 بحث', prompt: 'دور لي على '),
    _ChipData(label: '🧠 فكّر', prompt: 'فكّر معايا بعمق في '),
    _ChipData(label: '▶️ يوتيوب', prompt: 'دور على فيديو يوتيوب عن '),
    _ChipData(label: '📰 أخبار', prompt: 'إيه الأخبار اليوم؟'),
  ];

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();

    // Only show chips when chat is empty or not busy
    if (chatProvider.isBusy) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _chips.map((chip) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ActionChip(
                label: Text(
                  chip.label,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: () {
                  if (chip.label.contains('أخبار')) {
                    chatProvider.sendMessage(chip.prompt);
                  } else {
                    // Set the prompt prefix in the text field
                    chatProvider.messageController.text = chip.prompt;
                    chatProvider.messageFocusNode.requestFocus();
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ChipData {
  final String label;
  final String prompt;
  const _ChipData({required this.label, required this.prompt});
}

// ─── Message List ──────────────────────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();

    if (chatProvider.isEmpty) {
      return _EmptyState(onSuggestionTap: (prompt) {
        chatProvider.sendMessage(prompt);
      });
    }

    return ListView.builder(
      controller: chatProvider.scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: chatProvider.messageCount,
      itemBuilder: (context, index) {
        final message = chatProvider.messages[index];
        return ChatBubble(
          message: message,
          onCopy: () => _copyMessage(context, message.content),
          onSpeak: () => chatProvider.speakMessage(message.id),
          onDelete: () => chatProvider.deleteMessage(message.id),
        );
      },
    );
  }

  void _copyMessage(BuildContext context, String text) {
    // Copy to clipboard
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم النسخ ✅'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

// ─── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final void Function(String prompt) onSuggestionTap;

  const _EmptyState({required this.onSuggestionTap});

  static const _suggestions = [
    'إيه أخبارك؟ عايز أساعدك في إيه النهارده؟ 😊',
    'وريني بريف يومي',
    'عايز أضيف مهمة جديدة',
    'فكّر معايا في موضوع',
    'دور لي على معلومات عن ',
    'ساعدني أكتب حاجة',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo / Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: OwjColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🌟', style: TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'أوج — مساعدك الذكي المصري',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: OwjColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'اكتب رسالة أو اختر من الاقتراحات',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: OwjColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Suggestion chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _suggestions.map((s) {
                return ActionChip(
                  label: Text(
                    s,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                    ),
                  ),
                  onPressed: () => onSuggestionTap(s),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Input Bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: const BoxDecoration(
        color: OwjColors.surface,
        border: Border(
          top: BorderSide(color: OwjColors.border, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ─── Voice Button ────────────────────────────────────────
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              child: IconButton(
                icon: Icon(
                  Icons.mic_rounded,
                  color: chatProvider.isBusy
                      ? OwjColors.textTertiary
                      : OwjColors.primary,
                  size: 24,
                ),
                onPressed: chatProvider.isBusy
                    ? null
                    : () => _showVoiceInput(context),
                tooltip: 'إدخال صوتي',
              ),
            ),

            // ─── Text Field ──────────────────────────────────────────
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                child: TextField(
                  controller: chatProvider.messageController,
                  focusNode: chatProvider.messageFocusNode,
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  textDirection: TextDirection.rtl,
                  enabled: !chatProvider.isBusy,
                  decoration: InputDecoration(
                    hintText: chatProvider.isStreaming
                        ? 'أوج بيكتب...'
                        : 'اكتب رسالتك هنا...',
                    hintStyle: const TextStyle(
                      fontFamily: 'Cairo',
                      color: OwjColors.textTertiary,
                    ),
                    suffixIcon: chatProvider.isStreaming
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: OwjColors.primary,
                              ),
                            ),
                          )
                        : null,
                  ),
                  onSubmitted: (text) {
                    if (text.trim().isNotEmpty) {
                      chatProvider.sendMessage(text);
                    }
                  },
                ),
              ),
            ),

            // ─── Send Button ─────────────────────────────────────────
            Container(
              margin: const EdgeInsets.only(bottom: 4, right: 4),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: chatProvider.isBusy
                        ? OwjColors.surfaceVariant
                        : OwjColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    chatProvider.isStreaming
                        ? Icons.stop_rounded
                        : Icons.send_rounded,
                    color: chatProvider.isBusy
                        ? OwjColors.textTertiary
                        : OwjColors.textInverted,
                    size: 18,
                  ),
                ),
                onPressed: () {
                  final text = chatProvider.messageController.text.trim();
                  if (text.isNotEmpty) {
                    chatProvider.sendMessage(text);
                  }
                },
                tooltip: 'إرسال',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVoiceInput(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('الإدخال الصوتي هيكون متاح قريب 🎤'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
