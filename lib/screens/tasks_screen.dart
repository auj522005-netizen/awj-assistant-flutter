/// ═══════════════════════════════════════════════════════════════════════════════
/// ✅ OWJ Assistant — Tasks Screen
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Full-featured task management screen with:
/// - Add tasks via text or voice
/// - Priority levels (low, medium, high, urgent)
/// - Due dates
/// - Complete/uncomplete toggle
/// - Filter by status
/// - Delete tasks
/// - Voice input for adding tasks
///
/// ═══════════════════════════════════════════════════════════════════════════════

library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:owj_assistant/config/theme.dart';
import 'package:owj_assistant/models/task.dart';
import 'package:owj_assistant/providers/app_provider.dart';
import 'package:owj_assistant/providers/chat_provider.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _taskController = TextEditingController();
  TaskPriority _selectedPriority = TaskPriority.medium;
  DateTime? _selectedDueDate;
  bool _showAddForm = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _taskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المهام'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic_rounded),
            tooltip: 'إضافة صوتية',
            onPressed: () => _addTaskByVoice(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'كل المهام'),
            Tab(text: 'اليوم'),
            Tab(text: 'المكتملة'),
          ],
          labelStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TaskList(filter: TaskFilter.all),
          _TaskList(filter: TaskFilter.today),
          _TaskList(filter: TaskFilter.completed),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTaskDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'مهمة جديدة',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
        ),
        backgroundColor: OwjColors.primary,
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: OwjColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _AddTaskForm(
          onAdd: (title, priority, dueDate) {
            context.read<AppProvider>().addTask(TaskItem(
              id: const Uuid().v4(),
              title: title,
              priority: priority,
              dueDate: dueDate,
              createdAt: DateTime.now(),
            ));
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  void _addTaskByVoice(BuildContext context) {
    // Navigate to chat with voice task intent
    final chatProvider = context.read<ChatProvider>();
    chatProvider.messageController.text = 'ضيف مهمة: ';
    DefaultTabController.of(context)?.animateTo(1);
    chatProvider.messageFocusNode.requestFocus();
  }
}

// ─── Task Filter ──────────────────────────────────────────────────────────────

enum TaskFilter { all, today, completed }

// ─── Task List ────────────────────────────────────────────────────────────────

class _TaskList extends StatelessWidget {
  final TaskFilter filter;

  const _TaskList({required this.filter});

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final allTasks = appProvider.tasks;

    final tasks = switch (filter) {
      TaskFilter.all => allTasks,
      TaskFilter.today => allTasks.where((t) => t.isDueToday || (!t.completed && t.dueDate == null)).toList(),
      TaskFilter.completed => allTasks.where((t) => t.completed).toList(),
    };

    // Sort: urgent first, then by due date
    final sortedTasks = List<TaskItem>.from(tasks)
      ..sort((a, b) {
        // Incomplete first
        if (a.completed != b.completed) return a.completed ? 1 : -1;
        // Then by priority
        final pCompare = b.priority.value.compareTo(a.priority.value);
        if (pCompare != 0) return pCompare;
        // Then by due date
        if (a.dueDate != null && b.dueDate != null) {
          return a.dueDate!.compareTo(b.dueDate!);
        }
        if (a.dueDate != null) return -1;
        if (b.dueDate != null) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

    if (sortedTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              filter == TaskFilter.completed
                  ? Icons.celebration_rounded
                  : Icons.checklist_rounded,
              size: 64,
              color: OwjColors.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              filter == TaskFilter.completed
                  ? 'مفيش مهام مكتملة لسه'
                  : filter == TaskFilter.today
                      ? 'مفيش مهام النهارده 🎉'
                      : 'مفيش مهام — ضيف مهمة جديدة!',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                color: OwjColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'اضغط + عشان تضيف مهمة',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: OwjColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    // Stats header
    final activeCount = sortedTasks.where((t) => !t.completed).length;
    final completedCount = sortedTasks.where((t) => t.completed).length;

    return Column(
      children: [
        // Progress bar
        if (filter != TaskFilter.completed) ...[
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: OwjColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: OwjColors.border, width: 0.5),
            ),
            child: Row(
              children: [
                Text(
                  '$activeCount نشط',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: OwjColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '$completedCount مكتمل',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: OwjColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
        // Task list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
            itemCount: sortedTasks.length,
            itemBuilder: (context, index) {
              return _TaskCard(
                task: sortedTasks[index],
                onToggle: () => context.read<AppProvider>().toggleTask(sortedTasks[index].id),
                onDelete: () => _confirmDelete(context, sortedTasks[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, TaskItem task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المهمة'),
        content: Text('متأكد إنك عايز تحذف "${task.title}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('لا'),
          ),
          TextButton(
            onPressed: () {
              context.read<AppProvider>().deleteTask(task.id);
              Navigator.pop(ctx);
            },
            child: const Text('احذف', style: TextStyle(color: OwjColors.error)),
          ),
        ],
      ),
    );
  }
}

// ─── Task Card ────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final TaskItem task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TaskCard({
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor(task.priority);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: OwjColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: task.completed
              ? OwjColors.border
              : priorityColor.withValues(alpha: 0.3),
          width: task.completed ? 0.5 : 1.5,
        ),
      ),
      child: Dismissible(
        key: ValueKey(task.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDelete(),
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          decoration: BoxDecoration(
            color: OwjColors.error.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.delete_rounded, color: OwjColors.error),
        ),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Checkbox
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: task.completed
                        ? OwjColors.success
                        : Colors.transparent,
                    border: Border.all(
                      color: task.completed
                          ? OwjColors.success
                          : priorityColor,
                      width: 2,
                    ),
                  ),
                  child: task.completed
                      ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: task.completed
                              ? OwjColors.textTertiary
                              : OwjColors.textPrimary,
                          decoration: task.completed
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (task.notes != null && task.notes!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          task.notes!,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: OwjColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Priority badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${task.priority.icon} ${task.priority.labelAr}',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: priorityColor,
                              ),
                            ),
                          ),
                          // Due date
                          if (task.dueDate != null) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: task.isOverdue
                                  ? OwjColors.error
                                  : OwjColors.textTertiary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              task.dueDateLabelAr,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 10,
                                color: task.isOverdue
                                    ? OwjColors.error
                                    : OwjColors.textTertiary,
                                fontWeight: task.isOverdue
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: OwjColors.textTertiary,
                  onPressed: onDelete,
                  tooltip: 'حذف',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return OwjColors.error;
      case TaskPriority.high:
        return OwjColors.warning;
      case TaskPriority.medium:
        return OwjColors.primary;
      case TaskPriority.low:
        return OwjColors.success;
    }
  }
}

// ─── Add Task Form ────────────────────────────────────────────────────────────

class _AddTaskForm extends StatefulWidget {
  final void Function(String title, TaskPriority priority, DateTime? dueDate) onAdd;

  const _AddTaskForm({required this.onAdd});

  @override
  State<_AddTaskForm> createState() => _AddTaskFormState();
}

class _AddTaskFormState extends State<_AddTaskForm> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _dueDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
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
          // Title
          const Text(
            'مهمة جديدة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: OwjColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // Task title field
          TextField(
            controller: _titleController,
            textDirection: TextDirection.rtl,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: 'إيه المهمة؟',
              hintStyle: const TextStyle(fontFamily: 'Cairo', color: OwjColors.textTertiary),
              prefixIcon: const Icon(Icons.edit_note_rounded, color: OwjColors.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: OwjColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: OwjColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: OwjColors.primary, width: 2),
              ),
            ),
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 16),
          ),
          const SizedBox(height: 12),
          // Notes field
          TextField(
            controller: _notesController,
            textDirection: TextDirection.rtl,
            maxLines: 2,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'ملاحظات (اختياري)',
              hintStyle: const TextStyle(fontFamily: 'Cairo', color: OwjColors.textTertiary),
              prefixIcon: const Icon(Icons.notes_rounded, color: OwjColors.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: OwjColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: OwjColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: OwjColors.primary, width: 2),
              ),
            ),
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
          ),
          const SizedBox(height: 16),
          // Priority selector
          const Text(
            'الأولوية:',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: OwjColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: TaskPriority.values.map((p) {
              final isSelected = p == _priority;
              final color = _priorityColor(p);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    label: Text(
                      '${p.icon} ${p.labelAr}',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        color: isSelected ? Colors.white : color,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: color,
                    backgroundColor: color.withValues(alpha: 0.1),
                    side: BorderSide(color: color.withValues(alpha: isSelected ? 1.0 : 0.3)),
                    onSelected: (_) => setState(() => _priority = p),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Due date
          Row(
            children: [
              const Text(
                'الموعد:',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: OwjColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              ActionChip(
                label: Text(
                  _dueDate != null
                      ? '${_dueDate!.day}/${_dueDate!.month}'
                      : 'مفيش موعد',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                ),
                avatar: const Icon(Icons.calendar_today_rounded, size: 16),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _dueDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _dueDate = date);
                  }
                },
              ),
              if (_dueDate != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () => setState(() => _dueDate = null),
                  tooltip: 'إزالة الموعد',
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          // Submit button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: OwjColors.primary,
                foregroundColor: OwjColors.textInverted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: OwjColors.textInverted,
                      ),
                    )
                  : const Text(
                      'ضيف المهمة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب عنوان المهمة الأول')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    widget.onAdd(title, _priority, _dueDate);
  }

  Color _priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return OwjColors.error;
      case TaskPriority.high:
        return OwjColors.warning;
      case TaskPriority.medium:
        return OwjColors.primary;
      case TaskPriority.low:
        return OwjColors.success;
    }
  }
}
