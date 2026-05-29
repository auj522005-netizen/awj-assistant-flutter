import 'dart:convert';

import 'package:owj_assistant/services/storage_service.dart';

/// MCP Sequential Thinking service (from official MCP servers).
///
/// Supports branching, revision, and dynamic thought adjustment
/// for structured problem-solving and reasoning chains.
///
/// Tracks thought history with full branching support, allowing
/// exploration of multiple reasoning paths and backtracking.
///
/// Compatible with the official @modelcontextprotocol/server-sequential-thinking
/// format. All user-facing strings are in Egyptian Arabic.
class McpSequentialThinkingService {
  McpSequentialThinkingService({StorageService? storage})
      : _storage = storage ?? StorageService.instance;

  final StorageService _storage;

  /// Storage keys
  static const _thoughtHistoryKey = 'mcp_seq_thinking_history';
  static const _sessionsKey = 'mcp_seq_thinking_sessions';

  /// In-memory thought history for the current chain.
  /// Map of thoughtNumber → ThoughtData.
  final Map<int, ThoughtData> _thoughtHistory = {};

  /// Branch tracking: branchId → list of thought numbers.
  final Map<String, List<int>> _branches = {};

  /// The main branch identifier.
  static const _mainBranch = 'main';

  /// Maximum thoughts per session (safety limit).
  static const _maxThoughts = 1000;

  // ── Public API ──

  /// Process a single thought in a sequential thinking chain.
  ///
  /// Parameters:
  ///   - [thought]           — The thought content to process
  ///   - [thoughtNumber]     — Current thought number (1-based)
  ///   - [totalThoughts]     — Estimated total thoughts in the chain
  ///   - [isRevision]        — Whether this revises a previous thought
  ///   - [revisesThought]    — Which thought number this revises (if isRevision)
  ///   - [branchFromThought] — Thought number to branch from
  ///   - [branchId]          — Branch identifier for the new branch
  ///   - [needsMoreThoughts] — Whether more thoughts are needed beyond totalThoughts
  ///   - [nextThoughtNeeded] — Whether another thought follows
  ///
  /// Returns a [ThoughtResult] with the processed thought data and metadata.
  Future<ThoughtResult> processThought({
    required String thought,
    required int thoughtNumber,
    required int totalThoughts,
    bool isRevision = false,
    int? revisesThought,
    int? branchFromThought,
    String? branchId,
    bool needsMoreThoughts = false,
    bool nextThoughtNeeded = true,
  }) async {
    // Validate inputs
    _validateThoughtInput(
      thought: thought,
      thoughtNumber: thoughtNumber,
      totalThoughts: totalThoughts,
      isRevision: isRevision,
      revisesThought: revisesThought,
      branchFromThought: branchFromThought,
    );

    // Safety check
    if (_thoughtHistory.length >= _maxThoughts) {
      throw SequentialThinkingException(
        'وصلت للحد الأقصى من الأفكار ($_maxThoughts) — ابدأ سلسلة جديدة 🧠',
      );
    }

    // Determine the effective branch
    final effectiveBranchId = _determineBranch(
      branchFromThought: branchFromThought,
      branchId: branchId,
    );

    // Handle dynamic thought adjustment
    var effectiveTotalThoughts = totalThoughts;
    if (needsMoreThoughts) {
      effectiveTotalThoughts = thoughtNumber + 10; // Add buffer
    }

    // Handle revision
    if (isRevision && revisesThought != null) {
      final original = _thoughtHistory[revisesThought];
      if (original != null) {
        // Mark the original as superseded
        _thoughtHistory[revisesThought] = original.copyWith(
          isSuperseded: true,
        );
      }
    }

    // Handle branching
    if (branchFromThought != null && branchId != null) {
      _branches.putIfAbsent(branchId, () => []);
      _branches[branchId]!.add(thoughtNumber);
    } else {
      _branches.putIfAbsent(_mainBranch, () => []);
      _branches[_mainBranch]!.add(thoughtNumber);
    }

    // Create the thought data
    final thoughtData = ThoughtData(
      thought: thought,
      thoughtNumber: thoughtNumber,
      totalThoughts: effectiveTotalThoughts,
      isRevision: isRevision,
      revisesThought: revisesThought,
      branchFromThought: branchFromThought,
      branchId: branchId ?? effectiveBranchId,
      needsMoreThoughts: needsMoreThoughts,
      nextThoughtNeeded: nextThoughtNeeded,
      isSuperseded: false,
      timestamp: DateTime.now(),
    );

    // Store the thought
    _thoughtHistory[thoughtNumber] = thoughtData;

    // Persist to storage
    await _persistThought(thoughtData);

    // Build the chain context
    final chainContext = _buildChainContext(effectiveBranchId);
    final branchesInfo = _getBranchesInfo();

    return ThoughtResult(
      thoughtData: thoughtData,
      chainContext: chainContext,
      branches: branchesInfo,
      totalThoughtsInChain: _countActiveThoughts(effectiveBranchId),
      label: _thoughtLabelAr(thoughtData),
    );
  }

  /// Get the full thought history for a specific branch.
  ///
  /// If [branchId] is null, returns the main branch.
  List<ThoughtData> getThoughtHistory({String? branchId}) {
    final bid = branchId ?? _mainBranch;
    final thoughtNumbers = _branches[bid] ?? [];
    return thoughtNumbers
        .map((n) => _thoughtHistory[n])
        .where((t) => t != null && !t.isSuperseded)
        .cast<ThoughtData>()
        .toList()
      ..sort((a, b) => a.thoughtNumber.compareTo(b.thoughtNumber));
  }

  /// Get all branches with their metadata.
  Map<String, BranchInfo> getAllBranches() {
    return _getBranchesInfo();
  }

  /// Get the current chain summary.
  ChainSummary getChainSummary() {
    final totalThoughts = _thoughtHistory.length;
    final activeThoughts =
        _thoughtHistory.values.where((t) => !t.isSuperseded).length;
    final revisions =
        _thoughtHistory.values.where((t) => t.isRevision).length;
    final branchCount = _branches.length;

    return ChainSummary(
      totalThoughts: totalThoughts,
      activeThoughts: activeThoughts,
      revisionCount: revisions,
      branchCount: branchCount,
      mainBranchLength: _branches[_mainBranch]?.length ?? 0,
      label: _chainSummaryLabelAr(
        activeThoughts,
        revisions,
        branchCount,
      ),
    );
  }

  /// Clear the current thinking chain and start fresh.
  Future<void> clearChain() async {
    _thoughtHistory.clear();
    _branches.clear();
    await _storage.delete(_thoughtHistoryKey);
    await _storage.delete(_sessionsKey);
  }

  /// Load a previously saved thinking session.
  Future<void> loadSession(String sessionId) async {
    final sessions = _storage.getMap(_sessionsKey);
    final sessionData = sessions[sessionId];
    if (sessionData == null) {
      throw SequentialThinkingException(
        'الجلسة دي مش موجودة: $sessionId 🧠',
      );
    }

    // Clear current state
    _thoughtHistory.clear();
    _branches.clear();

    // Load from saved data
    final historyMap = sessionData as Map<String, dynamic>? ?? {};
    for (final entry in historyMap.entries) {
      final thoughtNum = int.tryParse(entry.key);
      if (thoughtNum == null) continue;
      final thoughtJson = entry.value;
      if (thoughtJson is Map<String, dynamic>) {
        _thoughtHistory[thoughtNum] = ThoughtData.fromJson(thoughtJson);
      }
    }

    // Rebuild branch index
    for (final thought in _thoughtHistory.values) {
      final bid = thought.branchId ?? _mainBranch;
      _branches.putIfAbsent(bid, () => []);
      if (!_branches[bid]!.contains(thought.thoughtNumber)) {
        _branches[bid]!.add(thought.thoughtNumber);
      }
    }
  }

  /// Save the current session with a given ID.
  Future<void> saveSession(String sessionId) async {
    final sessions = _storage.getMap(_sessionsKey);
    final historyMap = <String, dynamic>{};
    for (final entry in _thoughtHistory.entries) {
      historyMap[entry.key.toString()] = entry.value.toJson();
    }
    sessions[sessionId] = historyMap;
    await _storage.setMap(_sessionsKey, sessions);
  }

  // ── Private helpers ──

  /// Validate thought input parameters.
  void _validateThoughtInput({
    required String thought,
    required int thoughtNumber,
    required int totalThoughts,
    required bool isRevision,
    int? revisesThought,
    int? branchFromThought,
  }) {
    if (thought.trim().isEmpty) {
      throw SequentialThinkingException(
        'الفكرة فاضية — اكتب حاجة 🧠',
      );
    }
    if (thoughtNumber < 1) {
      throw SequentialThinkingException(
        'رقم الفكرة لازم يكون 1 أو أكتر 🧠',
      );
    }
    if (totalThoughts < 1) {
      throw SequentialThinkingException(
        'عدد الأفكار الكلي لازم يكون 1 على الأقل 🧠',
      );
    }
    if (isRevision && revisesThought == null) {
      throw SequentialThinkingException(
        'لما تعدّل فكرة لازم تحدد رقم الفكرة القديمة 🧠',
      );
    }
    if (revisesThought != null && revisesThought < 1) {
      throw SequentialThinkingException(
        'رقم الفكرة القديمة لازم يكون 1 أو أكتر 🧠',
      );
    }
    if (branchFromThought != null && branchFromThought < 1) {
      throw SequentialThinkingException(
        'رقم نقطة التفرع لازم يكون 1 أو أكتر 🧠',
      );
    }
    if (revisesThought != null && !_thoughtHistory.containsKey(revisesThought)) {
      throw SequentialThinkingException(
        'الفكرة رقم $revisesThought مش موجودة في السلسلة 🧠',
      );
    }
    if (branchFromThought != null && !_thoughtHistory.containsKey(branchFromThought)) {
      throw SequentialThinkingException(
        'نقطة التفرع رقم $branchFromThought مش موجودة في السلسلة 🧠',
      );
    }
  }

  /// Determine the effective branch ID.
  String _determineBranch({
    int? branchFromThought,
    String? branchId,
  }) {
    if (branchId != null) return branchId;
    if (branchFromThought != null) {
      return 'branch_$branchFromThought';
    }
    return _mainBranch;
  }

  /// Build chain context string from previous thoughts.
  String _buildChainContext(String branchId) {
    final thoughts = getThoughtHistory(branchId: branchId);
    if (thoughts.isEmpty) return '';

    final buffer = StringBuffer();
    for (final t in thoughts) {
      final revisionTag = t.isRevision ? ' [تعديل]' : '';
      buffer.writeln('فكرة ${t.thoughtNumber}$revisionTag: ${t.thought}');
    }
    return buffer.toString().trimRight();
  }

  /// Get information about all branches.
  Map<String, BranchInfo> _getBranchesInfo() {
    final result = <String, BranchInfo>{};

    for (final entry in _branches.entries) {
      final bid = entry.key;
      final thoughtNums = entry.value;
      final activeThoughts = thoughtNums
          .where((n) => _thoughtHistory[n]?.isSuperseded != true)
          .length;
      final revisions = thoughtNums
          .where((n) => _thoughtHistory[n]?.isRevision == true)
          .length;

      result[bid] = BranchInfo(
        branchId: bid,
        thoughtCount: activeThoughts,
        revisionCount: revisions,
        isMainBranch: bid == _mainBranch,
        label: bid == _mainBranch
            ? 'السلسلة الرئيسية ($activeThoughts أفكار)'
            : 'تفرع "$bid" ($activeThoughts أفكار)',
      );
    }

    return result;
  }

  /// Count active (non-superseded) thoughts in a branch.
  int _countActiveThoughts(String branchId) {
    final thoughtNums = _branches[branchId] ?? [];
    return thoughtNums
        .where((n) => _thoughtHistory[n]?.isSuperseded != true)
        .length;
  }

  /// Generate an Arabic label for a thought.
  String _thoughtLabelAr(ThoughtData data) {
    final buffer = StringBuffer();

    buffer.write('فكرة ${data.thoughtNumber}/${data.totalThoughts}');

    if (data.isRevision) {
      buffer.write(' (تعديل الفكرة ${data.revisesThought})');
    }
    if (data.branchFromThought != null) {
      buffer.write(' [تفرع من ${data.branchFromThought}]');
    }
    if (data.needsMoreThoughts) {
      buffer.write(' + محتاج أفكار أكتر');
    }
    if (!data.nextThoughtNeeded) {
      buffer.write(' ✅ الأخيرة');
    }

    return buffer.toString();
  }

  /// Generate an Arabic chain summary label.
  String _chainSummaryLabelAr(
    int activeThoughts,
    int revisions,
    int branchCount,
  ) {
    final parts = <String>['$activeThoughts أفكار'];
    if (revisions > 0) parts.add('$revisions تعديلات');
    if (branchCount > 1) parts.add('$branchCount تفرعات');
    return 'سلسلة التفكير: ${parts.join(" • ")} 🧠';
  }

  /// Persist a single thought to storage.
  Future<void> _persistThought(ThoughtData data) async {
    final historyMap = _storage.getMap(_thoughtHistoryKey);
    historyMap[data.thoughtNumber.toString()] = data.toJson();
    await _storage.setMap(_thoughtHistoryKey, historyMap);
  }
}

// ── Data models ──

/// A single thought in a sequential thinking chain.
class ThoughtData {
  /// The thought content.
  final String thought;

  /// Current thought number (1-based).
  final int thoughtNumber;

  /// Estimated total thoughts in the chain.
  final int totalThoughts;

  /// Whether this thought revises a previous one.
  final bool isRevision;

  /// Which thought number this revises (if isRevision).
  final int? revisesThought;

  /// Thought number to branch from.
  final int? branchFromThought;

  /// Branch identifier.
  final String? branchId;

  /// Whether more thoughts are needed beyond totalThoughts.
  final bool needsMoreThoughts;

  /// Whether another thought follows after this one.
  final bool nextThoughtNeeded;

  /// Whether this thought has been superseded by a revision.
  final bool isSuperseded;

  /// When this thought was created.
  final DateTime timestamp;

  const ThoughtData({
    required this.thought,
    required this.thoughtNumber,
    required this.totalThoughts,
    this.isRevision = false,
    this.revisesThought,
    this.branchFromThought,
    this.branchId,
    this.needsMoreThoughts = false,
    this.nextThoughtNeeded = true,
    this.isSuperseded = false,
    required this.timestamp,
  });

  ThoughtData copyWith({
    String? thought,
    int? thoughtNumber,
    int? totalThoughts,
    bool? isRevision,
    int? revisesThought,
    int? branchFromThought,
    String? branchId,
    bool? needsMoreThoughts,
    bool? nextThoughtNeeded,
    bool? isSuperseded,
    DateTime? timestamp,
  }) {
    return ThoughtData(
      thought: thought ?? this.thought,
      thoughtNumber: thoughtNumber ?? this.thoughtNumber,
      totalThoughts: totalThoughts ?? this.totalThoughts,
      isRevision: isRevision ?? this.isRevision,
      revisesThought: revisesThought ?? this.revisesThought,
      branchFromThought: branchFromThought ?? this.branchFromThought,
      branchId: branchId ?? this.branchId,
      needsMoreThoughts: needsMoreThoughts ?? this.needsMoreThoughts,
      nextThoughtNeeded: nextThoughtNeeded ?? this.nextThoughtNeeded,
      isSuperseded: isSuperseded ?? this.isSuperseded,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  factory ThoughtData.fromJson(Map<String, dynamic> json) => ThoughtData(
        thought: json['thought'] as String? ?? '',
        thoughtNumber: json['thoughtNumber'] as int? ?? 1,
        totalThoughts: json['totalThoughts'] as int? ?? 1,
        isRevision: json['isRevision'] as bool? ?? false,
        revisesThought: json['revisesThought'] as int?,
        branchFromThought: json['branchFromThought'] as int?,
        branchId: json['branchId'] as String?,
        needsMoreThoughts: json['needsMoreThoughts'] as bool? ?? false,
        nextThoughtNeeded: json['nextThoughtNeeded'] as bool? ?? true,
        isSuperseded: json['isSuperseded'] as bool? ?? false,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'thought': thought,
        'thoughtNumber': thoughtNumber,
        'totalThoughts': totalThoughts,
        'isRevision': isRevision,
        'revisesThought': revisesThought,
        'branchFromThought': branchFromThought,
        'branchId': branchId,
        'needsMoreThoughts': needsMoreThoughts,
        'nextThoughtNeeded': nextThoughtNeeded,
        'isSuperseded': isSuperseded,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Compatible with official MCP sequential-thinking server format.
  Map<String, dynamic> toMcpFormat() => {
        'thought': thought,
        'thoughtNumber': thoughtNumber,
        'totalThoughts': totalThoughts,
        'nextThoughtNeeded': nextThoughtNeeded,
        if (isRevision) 'isRevision': isRevision,
        if (revisesThought != null) 'revisesThought': revisesThought,
        if (branchFromThought != null) 'branchFromThought': branchFromThought,
        if (branchId != null) 'branchId': branchId,
        if (needsMoreThoughts) 'needsMoreThoughts': needsMoreThoughts,
      };

  /// Progress as a percentage (0.0 to 1.0).
  double get progress {
    if (totalThoughts == 0) return 0;
    return (thoughtNumber / totalThoughts).clamp(0.0, 1.0);
  }

  /// Whether this is the final thought in the chain.
  bool get isFinal => !nextThoughtNeeded;

  /// Egyptian Arabic label.
  String get labelAr {
    final buffer = StringBuffer();
    buffer.write('فكرة $thoughtNumber من $totalThoughts');
    if (isRevision) buffer.write(' (تعديل)');
    if (isSuperseded) buffer.write(' [استُبدلت]');
    return buffer.toString();
  }
}

/// Result of processing a thought.
class ThoughtResult {
  /// The processed thought data.
  final ThoughtData thoughtData;

  /// Full context of the thinking chain up to this point.
  final String chainContext;

  /// Information about all branches.
  final Map<String, BranchInfo> branches;

  /// Total active thoughts in the current branch.
  final int totalThoughtsInChain;

  /// Arabic label summarizing this thought's position.
  final String label;

  const ThoughtResult({
    required this.thoughtData,
    required this.chainContext,
    required this.branches,
    required this.totalThoughtsInChain,
    required this.label,
  });

  /// Whether this is the final thought in the chain.
  bool get isComplete => !thoughtData.nextThoughtNeeded;

  /// Progress percentage.
  double get progress => thoughtData.progress;
}

/// Information about a branch in the thinking chain.
class BranchInfo {
  /// Branch identifier.
  final String branchId;

  /// Number of active thoughts in this branch.
  final int thoughtCount;

  /// Number of revisions in this branch.
  final int revisionCount;

  /// Whether this is the main branch.
  final bool isMainBranch;

  /// Arabic label.
  final String label;

  const BranchInfo({
    required this.branchId,
    required this.thoughtCount,
    required this.revisionCount,
    required this.isMainBranch,
    required this.label,
  });
}

/// Summary of the entire thinking chain.
class ChainSummary {
  /// Total thoughts (including superseded).
  final int totalThoughts;

  /// Active (non-superseded) thoughts.
  final int activeThoughts;

  /// Number of revisions.
  final int revisionCount;

  /// Number of branches.
  final int branchCount;

  /// Number of thoughts in the main branch.
  final int mainBranchLength;

  /// Arabic label.
  final String label;

  const ChainSummary({
    required this.totalThoughts,
    required this.activeThoughts,
    required this.revisionCount,
    required this.branchCount,
    required this.mainBranchLength,
    required this.label,
  });

  /// Progress estimate based on active thoughts vs typical chain length.
  double get estimatedProgress {
    if (activeThoughts == 0) return 0;
    // Assume a typical chain is 5-10 thoughts
    return (activeThoughts / 10).clamp(0.0, 1.0);
  }
}

/// Sequential thinking service exception.
class SequentialThinkingException implements Exception {
  final String message;
  SequentialThinkingException(this.message);

  @override
  String toString() => 'SequentialThinkingException: $message';
}
