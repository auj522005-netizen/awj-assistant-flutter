/// ═══════════════════════════════════════════════════════════════════════════════
/// 🎯 OWJ Assistant — Skills Screen
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Skills grid showing 23+ skills organized by category.
/// Each skill is a card with icon, name, and tap-to-execute.
///
/// ═══════════════════════════════════════════════════════════════════════════════

library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:owj_assistant/config/theme.dart';
import 'package:owj_assistant/providers/chat_provider.dart';
import 'package:owj_assistant/widgets/skill_card.dart';

class SkillsScreen extends StatelessWidget {
  const SkillsScreen({super.key});

  /// All skill categories with their skills.
  static const _categories = [
    _SkillCategory(
      name: 'الإنتاجية',
      icon: Icons.bolt_rounded,
      color: OwjColors.primary,
      skills: [
        _Skill(name: 'المهام', icon: Icons.checklist_rounded, prompt: 'عايز أضيف مهمة: '),
        _Skill(name: 'العادات', icon: Icons.repeat_rounded, prompt: 'عايز أتابع عادة: '),
        _Skill(name: 'الأهداف', icon: Icons.flag_rounded, prompt: 'عايز أحط هدف: '),
        _Skill(name: 'المؤقت', icon: Icons.timer_rounded, prompt: 'شغّلي مؤقت '),
        _Skill(name: 'بومودورو', icon: Icons.hourglass_top_rounded, prompt: 'ابدأ جلسة بومودورو'),
      ],
    ),
    _SkillCategory(
      name: 'المعرفة',
      icon: Icons.school_rounded,
      color: OwjColors.info,
      skills: [
        _Skill(name: 'بحث', icon: Icons.search_rounded, prompt: 'دور لي على '),
        _Skill(name: 'يوتيوب', icon: Icons.play_circle_rounded, prompt: 'دور على فيديو يوتيوب عن '),
        _Skill(name: 'أخبار', icon: Icons.newspaper_rounded, prompt: 'إيه أخبار اليوم؟'),
        _Skill(name: 'ترجمة', icon: Icons.translate_rounded, prompt: 'ترجم لي: '),
        _Skill(name: 'كتب', icon: Icons.menu_book_rounded, prompt: 'اقترح لي كتاب عن '),
      ],
    ),
    _SkillCategory(
      name: 'الصحة',
      icon: Icons.favorite_rounded,
      color: OwjColors.success,
      skills: [
        _Skill(name: 'يوميات', icon: Icons.book_rounded, prompt: 'عايز أكتب في اليوميات'),
        _Skill(name: 'مزاج', icon: Icons.mood_rounded, prompt: 'مزاجي النهارده '),
        _Skill(name: 'تأمل', icon: Icons.self_improvement_rounded, prompt: 'وجهني في تأمل '),
        _Skill(name: 'تنفس', icon: Icons.air_rounded, prompt: 'علميني تمرين تنفس'),
        _Skill(name: 'نوم', icon: Icons.bedtime_rounded, prompt: 'ساعدني أنام أحسن'),
      ],
    ),
    _SkillCategory(
      name: 'اجتماعي',
      icon: Icons.people_rounded,
      color: OwjColors.pillarMood,
      skills: [
        _Skill(name: 'جيميل', icon: Icons.email_rounded, prompt: 'ابعت إيميل عن '),
        _Skill(name: 'نوشن', icon: Icons.note_rounded, prompt: 'ضيف في نوشن: '),
        _Skill(name: 'تقويم', icon: Icons.calendar_month_rounded, prompt: 'ضيف موعد في التقويم '),
        _Skill(name: 'جهات اتصال', icon: Icons.contacts_rounded, prompt: 'دور على جهة اتصال '),
      ],
    ),
    _SkillCategory(
      name: 'إبداعي',
      icon: Icons.palette_rounded,
      color: OwjColors.pillarCreativity,
      skills: [
        _Skill(name: 'كتابة', icon: Icons.edit_note_rounded, prompt: 'ساعدني أكتب '),
        _Skill(name: 'عصف ذهني', icon: Icons.lightbulb_rounded, prompt: 'اعمل عصف ذهني عن '),
        _Skill(name: 'قصة', icon: Icons.auto_stories_rounded, prompt: 'اكتب قصة عن '),
        _Skill(name: 'شعر', icon: Icons.format_quote_rounded, prompt: 'اكتب قصيدة عن '),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المهارات'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 20),
        itemBuilder: (context, index) {
          final category = _categories[index];
          return _SkillCategorySection(category: category);
        },
      ),
    );
  }
}

// ─── Skill Category Section ────────────────────────────────────────────────────

class _SkillCategorySection extends StatelessWidget {
  final _SkillCategory category;

  const _SkillCategorySection({required this.category});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(category.icon, color: category.color, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                category.name,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: category.color,
                ),
              ),
            ],
          ),
        ),

        // Skills grid
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.9,
          children: category.skills.map((skill) {
            return SkillCard(
              name: skill.name,
              icon: skill.icon,
              color: category.color,
              onTap: () => _executeSkill(context, skill),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _executeSkill(BuildContext context, _Skill skill) {
    final chatProvider = context.read<ChatProvider>();

    // Navigate to chat tab and set prompt
    DefaultTabController.of(context)?.animateTo(1);

    // Set prompt in text field or send directly
    if (skill.prompt.endsWith(' ') || skill.prompt.endsWith(': ')) {
      // Needs user input - set in text field
      chatProvider.messageController.text = skill.prompt;
      chatProvider.messageFocusNode.requestFocus();
    } else {
      // Send directly
      chatProvider.sendMessage(skill.prompt);
    }
  }
}

// ─── Data Models ───────────────────────────────────────────────────────────────

class _SkillCategory {
  final String name;
  final IconData icon;
  final Color color;
  final List<_Skill> skills;

  const _SkillCategory({
    required this.name,
    required this.icon,
    required this.color,
    required this.skills,
  });
}

class _Skill {
  final String name;
  final IconData icon;
  final String prompt;

  const _Skill({
    required this.name,
    required this.icon,
    required this.prompt,
  });
}
