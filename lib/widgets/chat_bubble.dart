/// ═══════════════════════════════════════════════════════════════════════════════
/// 💬 OWJ Assistant — Chat Bubble Widget
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Chat bubble with different styling for user (right, gold) vs
/// assistant (left, dark surface). Supports markdown, YouTube embeds,
/// action results, timestamps, provider badges, and long-press menu.
///
/// ═══════════════════════════════════════════════════════════════════════════════

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:owj_assistant/config/theme.dart';
import 'package:owj_assistant/models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onCopy;
  final VoidCallback? onSpeak;
  final VoidCallback? onDelete;

  const ChatBubble({
    super.key,
    required this.message,
    this.onCopy,
    this.onSpeak,
    this.onDelete,
  });

  bool get isUser => message.role == ChatRole.user;
  bool get isAssistant => message.role == ChatRole.assistant;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: GestureDetector(
          onLongPress: () => _showContextMenu(context),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUser
                  ? OwjColors.primary.withValues(alpha: 0.12)
                  : OwjColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 4 : 16),
                bottomRight: Radius.circular(isUser ? 16 : 4),
              ),
              border: isUser
                  ? Border.all(color: OwjColors.primary.withValues(alpha: 0.3), width: 1)
                  : Border.all(color: OwjColors.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Provider Badge (assistant only) ───────────────────────
                if (isAssistant && message.provider != null)
                  _ProviderBadge(provider: message.provider!),

                // ─── Message Content ──────────────────────────────────────
                _MessageContent(message: message),

                // ─── YouTube Results ──────────────────────────────────────
                if (message.hasYouTubeResults)
                  ...message.youtubeResults.map((yt) => _YouTubeCard(result: yt)),

                // ─── Action Results ───────────────────────────────────────
                if (message.hasActionResults)
                  ...message.actionResults.map((ar) => _ActionResultCard(result: ar)),

                // ─── Streaming Indicator ──────────────────────────────────
                if (message.isStreaming) const _StreamingIndicator(),

                // ─── Timestamp ────────────────────────────────────────────
                _Timestamp(message: message),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: OwjColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: OwjColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: OwjColors.primary),
              title: const Text('نسخ النص', style: TextStyle(fontFamily: 'Cairo')),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: message.content));
                onCopy?.call();
              },
            ),
            if (isAssistant && onSpeak != null)
              ListTile(
                leading: const Icon(Icons.volume_up_rounded, color: OwjColors.primary),
                title: const Text('انطق الرسالة', style: TextStyle(fontFamily: 'Cairo')),
                onTap: () {
                  Navigator.pop(ctx);
                  onSpeak?.call();
                },
              ),
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: OwjColors.error),
                title: const Text('امسح الرسالة', style: TextStyle(fontFamily: 'Cairo', color: OwjColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete?.call();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Provider Badge ────────────────────────────────────────────────────────────

class _ProviderBadge extends StatelessWidget {
  final String provider;

  const _ProviderBadge({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: OwjColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          provider,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: OwjColors.primary,
          ),
        ),
      ),
    );
  }
}

// ─── Message Content ───────────────────────────────────────────────────────────

class _MessageContent extends StatelessWidget {
  final ChatMessage message;

  const _MessageContent({required this.message});

  @override
  Widget build(BuildContext context) {
    // Simple markdown-like rendering
    final content = message.content;

    if (content.isEmpty && message.isStreaming) {
      return const Text(
        '...',
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          color: OwjColors.textTertiary,
        ),
      );
    }

    return SelectableText(
      content,
      textDirection: _detectTextDirection(content),
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 14,
        color: message.role == ChatRole.user
            ? OwjColors.textPrimary
            : OwjColors.textPrimary,
        height: 1.6,
      ),
    );
  }

  TextDirection _detectTextDirection(String text) {
    final arabicRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]');
    if (text.isNotEmpty && arabicRegex.hasMatch(text.substring(0, text.length > 5 ? 5 : text.length))) {
      return TextDirection.rtl;
    }
    return TextDirection.ltr;
  }
}

// ─── YouTube Card ──────────────────────────────────────────────────────────────

class _YouTubeCard extends StatelessWidget {
  final YouTubeResult result;

  const _YouTubeCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: OwjColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OwjColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 36,
            decoration: BoxDecoration(
              color: OwjColors.error.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(
              child: Icon(Icons.play_arrow_rounded, color: OwjColors.error, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: OwjColors.textPrimary,
                  ),
                ),
                Text(
                  result.channelName,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10,
                    color: OwjColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action Result Card ────────────────────────────────────────────────────────

class _ActionResultCard extends StatelessWidget {
  final ActionResult result;

  const _ActionResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: (result.success ? OwjColors.success : OwjColors.error)
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (result.success ? OwjColors.success : OwjColors.error)
              .withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            result.success ? Icons.check_circle_rounded : Icons.error_rounded,
            color: result.success ? OwjColors.success : OwjColors.error,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result.actionType,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: result.success ? OwjColors.success : OwjColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Streaming Indicator ───────────────────────────────────────────────────────

class _StreamingIndicator extends StatefulWidget {
  const _StreamingIndicator();

  @override
  State<_StreamingIndicator> createState() => _StreamingIndicatorState();
}

class _StreamingIndicatorState extends State<_StreamingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              final offset = (index * 0.3) % 1.0;
              final progress = (_controller.value + offset) % 1.0;
              final opacity = 0.3 + 0.7 * (0.5 - (progress - 0.5).abs());
              return Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: OwjColors.primary.withValues(alpha: opacity.clamp(0.2, 1.0)),
                  shape: BoxShape.circle,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// ─── Timestamp ─────────────────────────────────────────────────────────────────

class _Timestamp extends StatelessWidget {
  final ChatMessage message;

  const _Timestamp({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTime(message.timestamp),
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10,
              color: OwjColors.textTertiary,
            ),
          ),
          if (message.latencyMs != null) ...[
            const SizedBox(width: 6),
            Text(
              '${message.latencyMs}ms',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 9,
                color: OwjColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
