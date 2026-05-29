/// ═══════════════════════════════════════════════════════════════════════════════
/// 🏛️ OWJ Assistant — Pillars Screen
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Displays the 5 life pillars with scores, icons, colors,
/// and suggested questions per pillar.
///
/// ═══════════════════════════════════════════════════════════════════════════════

library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:owj_assistant/config/theme.dart';
import 'package:owj_assistant/models/pillar.dart';
import 'package:owj_assistant/providers/app_provider.dart';
import 'package:owj_assistant/providers/chat_provider.dart';
import 'package:owj_assistant/widgets/pillar_card.dart';

class PillarsScreen extends StatelessWidget {
  const PillarsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final pillars = appProvider.pillars;

    return Scaffold(
      appBar: AppBar(
        title: const Text('المحاور الخمسة'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                'المعدل: ${appProvider.overallPillarScore.toStringAsFixed(1)}',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: OwjColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: pillars.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _PillarDetailCard(pillar: pillars[index]);
        },
      ),
    );
  }
}

// ─── Pillar Detail Card ────────────────────────────────────────────────────────

class _PillarDetailCard extends StatelessWidget {
  final PillarData pillar;

  const _PillarDetailCard({required this.pillar});

  @override
  Widget build(BuildContext context) {
    final pillarColor = _parseColor(pillar.colorHex);

    return Container(
      decoration: BoxDecoration(
        color: OwjColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OwjColors.border, width: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showPillarDetail(context),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ─── Header Row ─────────────────────────────────────────
                Row(
                  children: [
                    // Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: pillarColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          pillar.icon,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Name and description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pillar.nameAr,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: OwjColors.textPrimary,
                            ),
                          ),
                          Text(
                            pillar.type.descriptionAr,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: OwjColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Score Circle
                    _ScoreCircle(score: pillar.score, color: pillarColor),
                  ],
                ),

                // ─── Score Progress Bar ──────────────────────────────────
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pillar.score / 10.0,
                    minHeight: 8,
                    backgroundColor: OwjColors.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(pillarColor),
                  ),
                ),

                // ─── Trend Label ────────────────────────────────────────
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      pillar.trendLabelAr,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: pillar.trend > 0
                            ? OwjColors.success
                            : pillar.trend < 0
                                ? OwjColors.error
                                : OwjColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'آخر تحديث: ${_formatDate(pillar.lastUpdated)}',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: OwjColors.textTertiary,
                      ),
                    ),
                  ],
                ),

                // ─── Suggested Questions ─────────────────────────────────
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: pillar.type.suggestedQuestions.map((q) {
                    return ActionChip(
                      label: Text(
                        q,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: pillarColor,
                        ),
                      ),
                      side: BorderSide(color: pillarColor.withValues(alpha: 0.3)),
                      onPressed: () => _askQuestion(context, q),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPillarDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: OwjColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PillarDetailSheet(pillar: pillar),
    );
  }

  void _askQuestion(BuildContext context, String question) {
    final chatProvider = context.read<ChatProvider>();
    // Navigate to chat tab
    DefaultTabController.of(context)?.animateTo(1);
    chatProvider.sendMessage(question);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}';
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return OwjColors.primary;
    }
  }
}

// ─── Score Circle ──────────────────────────────────────────────────────────────

class _ScoreCircle extends StatelessWidget {
  final double score;
  final Color color;

  const _ScoreCircle({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color, width: 2.5),
      ),
      child: Center(
        child: Text(
          score.toStringAsFixed(1),
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

// ─── Pillar Detail Bottom Sheet ────────────────────────────────────────────────

class _PillarDetailSheet extends StatelessWidget {
  final PillarData pillar;

  const _PillarDetailSheet({required this.pillar});

  @override
  Widget build(BuildContext context) {
    final pillarColor = _parseColor(pillar.colorHex);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
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
              const SizedBox(height: 20),

              // Pillar header
              Row(
                children: [
                  Text(pillar.icon, style: const TextStyle(fontSize: 40)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pillar.nameAr,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: OwjColors.textPrimary,
                          ),
                        ),
                        Text(
                          pillar.type.descriptionAr,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            color: OwjColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ScoreCircle(score: pillar.score, color: pillarColor),
                ],
              ),

              const SizedBox(height: 24),

              // Score slider
              const Text(
                'حدّث النتيجة:',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: OwjColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _PillarScoreSlider(pillar: pillar, color: pillarColor),

              const SizedBox(height: 24),

              // Notes
              const Text(
                'ملاحظات:',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: OwjColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                pillar.notes.isEmpty ? 'مفيش ملاحظات لسه' : pillar.notes,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  color: OwjColors.textSecondary,
                ),
              ),

              const SizedBox(height: 24),

              // Suggested questions
              const Text(
                'أسئلة مقترحة:',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: OwjColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              ...pillar.type.suggestedQuestions.map((q) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.chat_bubble_outline, color: pillarColor, size: 20),
                      title: Text(
                        q,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: OwjColors.textPrimary,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        DefaultTabController.of(context)?.animateTo(1);
                        context.read<ChatProvider>().sendMessage(q);
                      },
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return OwjColors.primary;
    }
  }
}

// ─── Pillar Score Slider ───────────────────────────────────────────────────────

class _PillarScoreSlider extends StatefulWidget {
  final PillarData pillar;
  final Color color;

  const _PillarScoreSlider({required this.pillar, required this.color});

  @override
  State<_PillarScoreSlider> createState() => _PillarScoreSliderState();
}

class _PillarScoreSliderState extends State<_PillarScoreSlider> {
  late double _score;

  @override
  void initState() {
    super.initState();
    _score = widget.pillar.score;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: widget.color,
            thumbColor: widget.color,
            inactiveTrackColor: OwjColors.surfaceVariant,
            overlayColor: widget.color.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: _score,
            min: 0,
            max: 10,
            divisions: 20,
            label: _score.toStringAsFixed(1),
            onChanged: (value) {
              setState(() => _score = value);
            },
            onChangeEnd: (value) {
              context.read<AppProvider>().updatePillarScore(
                    widget.pillar.type,
                    value,
                  );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '0',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: OwjColors.textTertiary),
            ),
            Text(
              _score.toStringAsFixed(1),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: widget.color,
              ),
            ),
            const Text(
              '10',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: OwjColors.textTertiary),
            ),
          ],
        ),
      ],
    );
  }
}
