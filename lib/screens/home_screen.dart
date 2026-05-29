/// ═══════════════════════════════════════════════════════════════════════════════
/// 🏠 OWJ Assistant — Home Screen
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Dashboard showing greeting, daily brief, pillar summary,
/// quick actions, and character overlay.
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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => context.read<AppProvider>().loadAll(),
        color: OwjColors.primary,
        backgroundColor: OwjColors.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ─── Custom App Bar with Greeting ──────────────────────────────
            SliverToBoxAdapter(
              child: _GreetingHeader(),
            ),

            // ─── Daily Brief Card ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: _DailyBriefCard(),
            ),

            // ─── Pillar Summary ────────────────────────────────────────────
            const SliverToBoxAdapter(
              child: _SectionTitle(title: 'المحاور الخمسة'),
            ),
            SliverToBoxAdapter(
              child: _PillarSummaryRow(),
            ),

            // ─── Quick Actions ─────────────────────────────────────────────
            const SliverToBoxAdapter(
              child: _SectionTitle(title: 'إجراءات سريعة'),
            ),
            SliverToBoxAdapter(
              child: _QuickActionsGrid(),
            ),

            // ─── Bottom Padding ────────────────────────────────────────────
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
      // ─── Character FAB ──────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to chat with character
          DefaultTabController.of(context)?.animateTo(1);
        },
        tooltip: 'تحدث مع أوج',
        child: const Text('🌟', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}

// ─── Greeting Header ───────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      decoration: const BoxDecoration(
        gradient: OwjColors.heroGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appProvider.personalizedGreeting,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: OwjColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _getSubGreeting(),
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              color: OwjColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getDateLabel(),
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: OwjColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  String _getSubGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'يوم حلو ومليان إنجازات إن شاء الله ☀️';
    } else if (hour < 17) {
      return 'كمل يومك بنشاط وتركيز 💪';
    } else {
      return 'خلص اليوم براحة واستجمام 🌙';
    }
  }

  String _getDateLabel() {
    final now = DateTime.now();
    final weekdays = [
      '', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'
    ];
    return '${weekdays[now.weekday]}، ${now.day}/${now.month}/${now.year}';
  }
}

// ─── Daily Brief Card ──────────────────────────────────────────────────────────

class _DailyBriefCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final tasksToday = appProvider.todayTasks.length;
    final appointmentsToday = appProvider.todayAppointments.length;
    final completedTasks = appProvider.completedTaskCount;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: OwjColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OwjColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny_rounded, color: OwjColors.primary, size: 22),
              const SizedBox(width: 8),
              const Text(
                'البريف اليومي',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: OwjColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${appProvider.overallPillarScore.toStringAsFixed(1)}/10',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: OwjColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _BriefStat(label: 'مهام', value: '$tasksToday', icon: Icons.checklist),
              const SizedBox(width: 16),
              _BriefStat(label: 'مواعيد', value: '$appointmentsToday', icon: Icons.event),
              const SizedBox(width: 16),
              _BriefStat(label: 'مكتمل', value: '$completedTasks', icon: Icons.done_all),
            ],
          ),
        ],
      ),
    );
  }
}

class _BriefStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _BriefStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: OwjColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: OwjColors.primary, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: OwjColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: OwjColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: OwjColors.textPrimary,
        ),
      ),
    );
  }
}

// ─── Pillar Summary Row ────────────────────────────────────────────────────────

class _PillarSummaryRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final pillars = appProvider.pillars;

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: pillars.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return PillarCard(
            pillar: pillars[index],
            compact: true,
            onTap: () {
              // Navigate to pillars tab
              DefaultTabController.of(context)?.animateTo(2);
            },
          );
        },
      ),
    );
  }
}

// ─── Quick Actions Grid ────────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  static const _actions = [
    _QuickAction(label: 'محادثة', icon: Icons.chat_rounded, color: OwjColors.primary, tabIndex: 1),
    _QuickAction(label: 'مهام', icon: Icons.checklist_rounded, color: OwjColors.success, tabIndex: -1),
    _QuickAction(label: 'يوميات', icon: Icons.book_rounded, color: OwjColors.info, tabIndex: -1),
    _QuickAction(label: 'إنجازات', icon: Icons.emoji_events_rounded, color: OwjColors.warning, tabIndex: -1),
    _QuickAction(label: 'تذكيرات', icon: Icons.alarm_rounded, color: OwjColors.pillarMood, tabIndex: -1),
    _QuickAction(label: 'صوتي', icon: Icons.mic_rounded, color: OwjColors.pillarCreativity, tabIndex: -1),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.2,
        children: _actions.map((action) {
          return _QuickActionButton(
            action: action,
            onTap: () => _handleAction(context, action),
          );
        }).toList(),
      ),
    );
  }

  void _handleAction(BuildContext context, _QuickAction action) {
    if (action.tabIndex >= 0) {
      DefaultTabController.of(context)?.animateTo(action.tabIndex);
    } else {
      // For other actions, navigate to chat with a prompt
      final chatProvider = context.read<ChatProvider>();
      final prompts = {
        'مهام': 'وريني مهامي النهارده',
        'يوميات': 'عايز أكتب في اليوميات',
        'إنجازات': 'إيه إنجازاتي؟',
        'تذكيرات': 'إيه عندي من تذكيرات؟',
        'صوتي': 'استنى بسجل صوتي',
      };
      final prompt = prompts[action.label] ?? '';
      if (prompt.isNotEmpty) {
        DefaultTabController.of(context)?.animateTo(1);
        chatProvider.sendMessage(prompt);
      }
    }
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final int tabIndex;

  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.tabIndex,
  });
}

class _QuickActionButton extends StatelessWidget {
  final _QuickAction action;
  final VoidCallback onTap;

  const _QuickActionButton({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OwjColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: OwjColors.border, width: 0.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(action.icon, color: action.color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                action.label,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: OwjColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
