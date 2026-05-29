/// ═══════════════════════════════════════════════════════════════════════════════
/// 🧠 OWJ Assistant — Memory Screen
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Memory/Knowledge screen with search, memory list,
/// entity list, relation view, and category tabs.
///
/// ═══════════════════════════════════════════════════════════════════════════════

library;

import 'package:flutter/material.dart';

import 'package:owj_assistant/config/theme.dart';
import 'package:owj_assistant/models/memory.dart';
import 'package:owj_assistant/services/memory/mem0_service.dart';
import 'package:owj_assistant/services/memory/knowledge_graph_service.dart';
import 'package:owj_assistant/services/storage_service.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Services
  final _mem0Service = Mem0Service();
  final _kgService = KnowledgeGraphService();

  // State
  List<MemoryItem> _memories = [];
  List<Entity> _entities = [];
  List<Relation> _relations = [];
  List<KnowledgeEntity> _facts = [];
  bool _isLoading = true;
  String _searchQuery = '';

  // Tabs
  static const _tabs = [
    Tab(text: 'الكل'),
    Tab(text: 'كيانات'),
    Tab(text: 'علاقات'),
    Tab(text: 'حقائق'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load memories from Mem0
      final memories = await _mem0Service.getMemories('owj_user');

      // Load knowledge graph entities and relations
      final kgStats = await _kgService.getStats();

      // Search all entities
      final allEntities = await _kgService.searchEntities('');

      // Load default facts from model
      _facts = [
        KnowledgeEntity(
          name: 'أوج',
          type: EntityType.concept,
          observations: ['المساعد الذكي المصري', 'بيتكلم مصري', 'بيستخدم ذكاء اصطناعي متعدد'],
        ),
        KnowledgeEntity(
          name: 'المستخدم',
          type: EntityType.person,
          observations: ['بيستخدم تطبيق أوج', 'مصري'],
        ),
      ];

      setState(() {
        _memories = memories;
        _entities = allEntities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _search(String query) async {
    setState(() => _searchQuery = query);

    if (query.isEmpty) {
      await _loadData();
      return;
    }

    try {
      final memories = await _mem0Service.getMemories(
        'owj_user',
        query: query,
      );
      final entities = await _kgService.searchEntities(query);

      setState(() {
        _memories = memories;
        _entities = entities;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الذاكرة والمعرفة'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs,
        ),
      ),
      body: Column(
        children: [
          // ─── Search Bar ────────────────────────────────────────────
          _SearchBar(
            onSearch: _search,
            onClear: () => _search(''),
          ),

          // ─── Tab Content ───────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: OwjColors.primary),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _AllTab(memories: _memories, entities: _entities, facts: _facts),
                      _EntitiesTab(entities: _entities),
                      _RelationsTab(entities: _entities, kgService: _kgService),
                      _FactsTab(facts: _facts),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMemoryDialog,
        tooltip: 'إضافة ذكرى',
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showAddMemoryDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة ذكرى جديدة'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(
            hintText: 'اكتب الذكرى هنا...',
            hintStyle: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                await _mem0Service.addMemory(text, userId: 'owj_user');
                Navigator.pop(ctx);
                _loadData();
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

// ─── Search Bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final void Function(String) onSearch;
  final VoidCallback onClear;

  const _SearchBar({required this.onSearch, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: 'ابحث في الذاكرة...',
          hintStyle: const TextStyle(fontFamily: 'Cairo', color: OwjColors.textTertiary),
          prefixIcon: const Icon(Icons.search_rounded, color: OwjColors.textTertiary),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear_rounded, size: 20),
            onPressed: onClear,
          ),
        ),
        onChanged: onSearch,
      ),
    );
  }
}

// ─── All Tab ───────────────────────────────────────────────────────────────────

class _AllTab extends StatelessWidget {
  final List<MemoryItem> memories;
  final List<Entity> entities;
  final List<KnowledgeEntity> facts;

  const _AllTab({
    required this.memories,
    required this.entities,
    required this.facts,
  });

  @override
  Widget build(BuildContext context) {
    if (memories.isEmpty && entities.isEmpty) {
      return _EmptyState(
        message: 'مفيش ذكريات لسه.\nابدأ محادثة مع أوج وهيتذكر كل حاجة! 🧠',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Memories section
        if (memories.isNotEmpty) ...[
          const _SectionLabel('الذكريات'),
          ...memories.take(10).map((m) => _MemoryCard(memory: m)),
        ],

        // Entities section
        if (entities.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _SectionLabel('الكيانات'),
          ...entities.take(5).map((e) => _EntityCard(entity: e)),
        ],

        // Facts section
        if (facts.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _SectionLabel('حقائق'),
          ...facts.map((f) => _FactCard(entity: f)),
        ],
      ],
    );
  }
}

// ─── Entities Tab ──────────────────────────────────────────────────────────────

class _EntitiesTab extends StatelessWidget {
  final List<Entity> entities;

  const _EntitiesTab({required this.entities});

  @override
  Widget build(BuildContext context) {
    if (entities.isEmpty) {
      return const _EmptyState(message: 'مفيش كيانات محفوظة لسه');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _EntityCard(entity: entities[index]),
    );
  }
}

// ─── Relations Tab ─────────────────────────────────────────────────────────────

class _RelationsTab extends StatelessWidget {
  final List<Entity> entities;
  final KnowledgeGraphService kgService;

  const _RelationsTab({required this.entities, required this.kgService});

  @override
  Widget build(BuildContext context) {
    if (entities.isEmpty) {
      return const _EmptyState(message: 'مفيش علاقات محفوظة لسه');
    }

    return FutureBuilder<List<Relation>>(
      future: _loadRelations(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: OwjColors.primary),
          );
        }

        final relations = snapshot.data!;
        if (relations.isEmpty) {
          return const _EmptyState(message: 'مفيش علاقات محفوظة لسه');
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: relations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final r = relations[index];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: OwjColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: OwjColors.border, width: 0.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      r.from,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: OwjColors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: OwjColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      r.relationType,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: OwjColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      r.to,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: OwjColors.info,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Relation>> _loadRelations() async {
    final allRelations = <Relation>[];
    for (final entity in entities.take(10)) {
      try {
        final relations = await kgService.getEntityRelations(entity.name);
        allRelations.addAll(relations);
      } catch (_) {}
    }
    return allRelations;
  }
}

// ─── Facts Tab ─────────────────────────────────────────────────────────────────

class _FactsTab extends StatelessWidget {
  final List<KnowledgeEntity> facts;

  const _FactsTab({required this.facts});

  @override
  Widget build(BuildContext context) {
    if (facts.isEmpty) {
      return const _EmptyState(message: 'مفيش حقائق محفوظة لسه');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: facts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _FactCard(entity: facts[index]),
    );
  }
}

// ─── Shared Widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: OwjColors.textPrimary,
        ),
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  final MemoryItem memory;
  const _MemoryCard({required this.memory});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OwjColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OwjColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            memory.content,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: OwjColors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (memory.source == MemorySource.cloud
                          ? OwjColors.info
                          : OwjColors.warning)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  memory.source == MemorySource.cloud ? 'سحابي' : 'محلي',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10,
                    color: memory.source == MemorySource.cloud
                        ? OwjColors.info
                        : OwjColors.warning,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(memory.createdAt),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  color: OwjColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _EntityCard extends StatelessWidget {
  final Entity entity;
  const _EntityCard({required this.entity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OwjColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OwjColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _typeIcon(entity.type),
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entity.name,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OwjColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: OwjColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  entity.type,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10,
                    color: OwjColors.primary,
                  ),
                ),
              ),
            ],
          ),
          if (entity.observations.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...entity.observations.map((obs) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: OwjColors.primary)),
                      Expanded(
                        child: Text(
                          obs,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: OwjColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  String _typeIcon(String type) {
    const icons = {
      'User': '👤', 'Preference': '❤️', 'Goal': '🎯', 'Struggle': '⚠️',
      'Interest': '💡', 'Person': '👤', 'Place': '📍', 'Organization': '🏢',
      'Concept': '💡', 'Skill': '🎯', 'Event': '📅', 'Hobby': '🎮',
    };
    return icons[type] ?? '📌';
  }
}

class _FactCard extends StatelessWidget {
  final KnowledgeEntity entity;
  const _FactCard({required this.entity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OwjColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OwjColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(entity.type.name, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                entity.name,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: OwjColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: OwjColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  entity.type.labelAr,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10,
                    color: OwjColors.success,
                  ),
                ),
              ),
            ],
          ),
          if (entity.observations.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...entity.observations.map((obs) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $obs',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: OwjColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 15,
            color: OwjColors.textSecondary,
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
