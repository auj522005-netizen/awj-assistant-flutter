import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:owj_assistant/services/storage_service.dart';

/// MCP Filesystem service (from the official MCP servers repo).
///
/// Provides file system operations within allowed directories with
/// security validation. Uses `path_provider` for app directories
/// and ensures all operations stay within permitted boundaries.
///
/// Methods:
///   - listDirectory(path)     — List files in directory
///   - readFile(path)          — Read file content
///   - writeFile(path, content)— Write file content
///   - createDirectory(path)   — Create directory
///   - moveFile(source, dest)  — Move/rename file
///   - searchFiles(path, pattern) — Search files by pattern
///   - getFileInfo(path)       — Get file metadata
///   - listAllowedDirectories()— List allowed directories
///
/// All user-facing strings are in Egyptian Arabic.
class McpFilesystemService {
  McpFilesystemService({StorageService? storage})
      : _storage = storage ?? StorageService.instance;

  final StorageService _storage;

  /// Storage key for allowed directories config.
  static const _allowedDirsKey = 'mcp_fs_allowed_dirs';

  /// Storage key for filesystem access log.
  static const _accessLogKey = 'mcp_fs_access_log';

  /// Cached list of allowed directories.
  List<String>? _allowedDirectories;

  /// Maximum file size for reading (10 MB).
  static const int _maxReadSize = 10 * 1024 * 1024;

  /// Maximum number of search results.
  static const int _maxSearchResults = 100;

  // ── Initialization & Configuration ────────────────────────────────────

  /// Initialize the filesystem service with default allowed directories.
  ///
  /// Sets up app-specific directories as allowed paths.
  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    final tempDir = await getTemporaryDirectory();
    final supportDir = await getApplicationSupportDirectory();

    final defaultDirs = [
      appDir.path,
      tempDir.path,
      supportDir.path,
    ];

    // Load any previously saved directories
    final saved = _storage.getStringList(_allowedDirsKey);

    final allDirs = <String>{...defaultDirs};
    if (saved != null) {
      allDirs.addAll(saved);
    }

    _allowedDirectories = allDirs.toList();
    await _storage.setStringList(_allowedDirsKey, _allowedDirectories!);
  }

  /// Add an allowed directory path.
  Future<void> addAllowedDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      throw FilesystemException(
        'المسار ده مش موجود: $path 📁',
      );
    }

    _allowedDirectories ??= _storage.getStringList(_allowedDirsKey);
    if (!_allowedDirectories!.contains(path)) {
      _allowedDirectories!.add(path);
      await _storage.setStringList(_allowedDirsKey, _allowedDirectories!);
    }
  }

  /// Remove an allowed directory path.
  Future<void> removeAllowedDirectory(String path) async {
    _allowedDirectories ??= _storage.getStringList(_allowedDirsKey);
    _allowedDirectories!.remove(path);
    await _storage.setStringList(_allowedDirsKey, _allowedDirectories!);
  }

  /// List all allowed directories.
  Future<List<String>> listAllowedDirectories() async {
    if (_allowedDirectories == null) {
      await initialize();
    }
    return List.unmodifiable(_allowedDirectories!);
  }

  // ── File Operations ───────────────────────────────────────────────────

  /// List files and directories in [path].
  ///
  /// Returns a list of [FileEntry] with name, type, and size.
  Future<List<FileEntry>> listDirectory(String path) async {
    await _validatePath(path);
    final dir = Directory(path);

    if (!await dir.exists()) {
      throw FilesystemException(
        'المجلد ده مش موجود: $path 📁',
      );
    }

    final entries = <FileEntry>[];
    try {
      await for (final entity in dir.list()) {
        final name = entity.path.split(Platform.pathSeparator).last;
        final isDir = entity is Directory;

        int? size;
        if (entity is File) {
          try {
            size = await entity.length();
          } catch (_) {
            size = null;
          }
        }

        entries.add(FileEntry(
          name: name,
          path: entity.path,
          isDirectory: isDir,
          size: size,
        ));
      }
    } catch (e) {
      throw FilesystemException(
        'مقدرش أقرأ محتويات المجلد: $path ❌',
      );
    }

    // Sort: directories first, then files, alphabetically
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    await _logAccess('list', path);
    return entries;
  }

  /// Read file content at [path].
  ///
  /// Returns the file content as a string.
  /// Throws if the file is too large or the path is not allowed.
  Future<String> readFile(String path) async {
    await _validatePath(path);
    final file = File(path);

    if (!await file.exists()) {
      throw FilesystemException(
        'الملف ده مش موجود: $path 📄',
      );
    }

    // Check file size
    final size = await file.length();
    if (size > _maxReadSize) {
      throw FilesystemException(
        'الملف كبير أوي (${_formatSize(size)}) — الحد الأقصى ${_formatSize(_maxReadSize)} 📄',
      );
    }

    try {
      final content = await file.readAsString();
      await _logAccess('read', path);
      return content;
    } catch (e) {
      // Try reading as bytes and encode if not UTF-8
      try {
        final bytes = await file.readAsBytes();
        await _logAccess('read', path);
        return utf8.decode(bytes, allowMalformed: true);
      } catch (e2) {
        throw FilesystemException(
          'مقدرش أقرأ الملف: $path ❌',
        );
      }
    }
  }

  /// Write [content] to file at [path].
  ///
  /// Creates the file if it doesn't exist, overwrites if it does.
  /// Parent directories must exist.
  Future<FileWriteResult> writeFile(String path, String content) async {
    await _validatePath(path);
    final file = File(path);

    // Ensure parent directory exists
    final parent = file.parent;
    if (!await parent.exists()) {
      throw FilesystemException(
        'المجلد الأب مش موجود: ${parent.path} 📁',
      );
    }

    final existed = await file.exists();
    try {
      await file.writeAsString(content, flush: true);
      await _logAccess('write', path);

      return FileWriteResult(
        path: path,
        bytesWritten: utf8.encode(content).length,
        isCreate: !existed,
        message: existed
            ? 'تم تعديل الملف بنجاح ✏️'
            : 'تم إنشاء الملف بنجاح 📄',
      );
    } catch (e) {
      throw FilesystemException(
        'مقدرش أكتب في الملف: $path ❌',
      );
    }
  }

  /// Create a directory at [path].
  ///
  /// Creates parent directories if needed (like `mkdir -p`).
  Future<DirectoryCreateResult> createDirectory(String path) async {
    await _validatePath(path);
    final dir = Directory(path);

    if (await dir.exists()) {
      return DirectoryCreateResult(
        path: path,
        alreadyExisted: true,
        message: 'المجلد ده موجود بالفعل 📁',
      );
    }

    try {
      await dir.create(recursive: true);
      await _logAccess('mkdir', path);

      return DirectoryCreateResult(
        path: path,
        alreadyExisted: false,
        message: 'تم إنشاء المجلد بنجاح 📁',
      );
    } catch (e) {
      throw FilesystemException(
        'مقدرش أنشئ المجلد: $path ❌',
      );
    }
  }

  /// Move a file from [source] to [destination].
  ///
  /// Can also be used for renaming. The source must exist and
  /// the destination parent directory must exist.
  Future<FileMoveResult> moveFile(String source, String destination) async {
    await _validatePath(source);
    await _validatePath(destination);

    final sourceFile = File(source);
    final sourceDir = Directory(source);

    final isFile = await sourceFile.exists();
    final isDir = await sourceDir.exists();

    if (!isFile && !isDir) {
      throw FilesystemException(
        'المصدر مش موجود: $source 📄',
      );
    }

    try {
      if (isFile) {
        await sourceFile.rename(destination);
      } else {
        await sourceDir.rename(destination);
      }

      await _logAccess('move', '$source → $destination');

      return FileMoveResult(
        source: source,
        destination: destination,
        message: 'تم النقل/إعادة التسمية بنجاح ✅',
      );
    } catch (e) {
      throw FilesystemException(
        'مقدرش أنقل الملف: $source → $destination ❌',
      );
    }
  }

  /// Search for files matching [pattern] starting from [path].
  ///
  /// [pattern] is a simple glob-like pattern (e.g., "*.dart", "test_*").
  /// Returns up to 100 results.
  Future<List<FileEntry>> searchFiles(String path, String pattern) async {
    await _validatePath(path);
    final dir = Directory(path);

    if (!await dir.exists()) {
      throw FilesystemException(
        'مسار البحث مش موجود: $path 📁',
      );
    }

    final results = <FileEntry>[];
    final normalizedPattern = _normalizePattern(pattern);

    try {
      await for (final entity in dir.list(recursive: true)) {
        if (results.length >= _maxSearchResults) break;

        final name = entity.path.split(Platform.pathSeparator).last;

        if (_matchesPattern(name, normalizedPattern)) {
          final isDir = entity is Directory;
          int? size;
          if (entity is File) {
            try {
              size = await entity.length();
            } catch (_) {
              size = null;
            }
          }

          results.add(FileEntry(
            name: name,
            path: entity.path,
            isDirectory: isDir,
            size: size,
          ));
        }
      }
    } catch (e) {
      throw FilesystemException(
        'حصل خطأ أثناء البحث: $path ❌',
      );
    }

    await _logAccess('search', '$path [pattern: $pattern]');
    return results;
  }

  /// Get file/directory metadata at [path].
  ///
  /// Returns a [FileInfo] with size, dates, and permissions.
  Future<FileInfo> getFileInfo(String path) async {
    await _validatePath(path);

    final file = File(path);
    final dir = Directory(path);

    final isFile = await file.exists();
    final isDir = await dir.exists();

    if (!isFile && !isDir) {
      throw FilesystemException(
        'المسار ده مش موجود: $path 📄',
      );
    }

    try {
      if (isFile) {
        final stat = await file.stat();
        return FileInfo(
          path: path,
          name: path.split(Platform.pathSeparator).last,
          isDirectory: false,
          size: stat.size,
          modified: stat.modified,
          accessed: stat.accessed,
          changed: stat.changed,
          type: _statTypeToString(stat.type),
          message: 'معلومات الملف 📄',
        );
      } else {
        final stat = await dir.stat();
        return FileInfo(
          path: path,
          name: path.split(Platform.pathSeparator).last,
          isDirectory: true,
          size: stat.size,
          modified: stat.modified,
          accessed: stat.accessed,
          changed: stat.changed,
          type: _statTypeToString(stat.type),
          message: 'معلومات المجلد 📁',
        );
      }
    } catch (e) {
      throw FilesystemException(
        'مقدرش أجيب معلومات الملف: $path ❌',
      );
    }
  }

  // ── Security ──────────────────────────────────────────────────────────

  /// Validate that a path is within allowed directories.
  Future<void> _validatePath(String path) async {
    if (_allowedDirectories == null) {
      await initialize();
    }

    // Normalize the path
    final normalizedPath = _normalizePath(path);

    // Check if path is within any allowed directory
    bool isAllowed = false;
    for (final allowedDir in _allowedDirectories!) {
      final normalizedAllowed = _normalizePath(allowedDir);
      if (normalizedPath.startsWith(normalizedAllowed)) {
        isAllowed = true;
        break;
      }
    }

    if (!isAllowed) {
      throw FilesystemException(
        'الوصول مرفوض — المسار خارج المجلدات المسموحة: $path 🔒',
      );
    }

    // Check for path traversal attacks
    if (path.contains('..') || path.contains('~')) {
      throw FilesystemException(
        'المسار فيه رموز مش مسموح بيها: $path 🔒',
      );
    }
  }

  /// Normalize a path for comparison.
  String _normalizePath(String path) {
    return Directory(path).absolute.path.replaceAll('\\', '/');
  }

  /// Log a filesystem access.
  Future<void> _logAccess(String operation, String path) async {
    final log = _storage.getStringList(_accessLogKey);
    final entry = jsonEncode({
      'operation': operation,
      'path': path,
      'timestamp': DateTime.now().toIso8601String(),
    });
    log.insert(0, entry);
    // Keep only last 200 entries
    if (log.length > 200) log.removeRange(200, log.length);
    await _storage.setStringList(_accessLogKey, log);
  }

  // ── Pattern matching helpers ──────────────────────────────────────────

  /// Normalize a glob pattern for matching.
  String _normalizePattern(String pattern) {
    return pattern.toLowerCase();
  }

  /// Simple glob-like pattern matching.
  bool _matchesPattern(String name, String pattern) {
    final lowerName = name.toLowerCase();

    // Exact match
    if (lowerName == pattern) return true;

    // Wildcard patterns
    if (pattern.startsWith('*.')) {
      // *.dart → match extension
      final ext = pattern.substring(1); // .dart
      return lowerName.endsWith(ext);
    }

    if (pattern.endsWith('*')) {
      // test_* → match prefix
      final prefix = pattern.substring(0, pattern.length - 1);
      return lowerName.startsWith(prefix);
    }

    if (pattern.startsWith('*') && pattern.endsWith('*')) {
      // *test* → match contains
      final middle = pattern.substring(1, pattern.length - 1);
      return lowerName.contains(middle);
    }

    // Simple contains match
    return lowerName.contains(pattern);
  }

  /// Convert FileSystemEntityType to string.
  String _statTypeToString(FileSystemEntityType type) {
    switch (type) {
      case FileSystemEntityType.file:
        return 'ملف';
      case FileSystemEntityType.directory:
        return 'مجلد';
      case FileSystemEntityType.link:
        return 'رابط';
      case FileSystemEntityType.notFound:
        return 'مش موجود';
      default:
        return 'غير معروف';
    }
  }

  /// Format file size in human-readable Arabic.
  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes بايت';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} ك.ب';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} م.ب';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} ج.ب';
  }
}

// ── Data models ──

/// A file or directory entry.
class FileEntry {
  /// Entry name (filename or directory name).
  final String name;

  /// Full path to the entry.
  final String path;

  /// Whether this is a directory.
  final bool isDirectory;

  /// File size in bytes (null for directories).
  final int? size;

  const FileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
  });

  /// Arabic type label.
  String get typeLabel => isDirectory ? 'مجلد 📁' : 'ملف 📄';

  /// Human-readable size in Arabic.
  String get sizeLabel {
    if (size == null) return '';
    if (size! < 1024) return '$size بايت';
    if (size! < 1024 * 1024) return '${(size! / 1024).toStringAsFixed(1)} ك.ب';
    return '${(size! / (1024 * 1024)).toStringAsFixed(1)} م.ب';
  }
}

/// Result of a file write operation.
class FileWriteResult {
  /// Path of the written file.
  final String path;

  /// Number of bytes written.
  final int bytesWritten;

  /// Whether a new file was created (vs. overwriting).
  final bool isCreate;

  /// Arabic success message.
  final String message;

  const FileWriteResult({
    required this.path,
    required this.bytesWritten,
    required this.isCreate,
    required this.message,
  });
}

/// Result of a directory creation operation.
class DirectoryCreateResult {
  /// Path of the created directory.
  final String path;

  /// Whether the directory already existed.
  final bool alreadyExisted;

  /// Arabic message.
  final String message;

  const DirectoryCreateResult({
    required this.path,
    required this.alreadyExisted,
    required this.message,
  });
}

/// Result of a file move/rename operation.
class FileMoveResult {
  /// Source path.
  final String source;

  /// Destination path.
  final String destination;

  /// Arabic success message.
  final String message;

  const FileMoveResult({
    required this.source,
    required this.destination,
    required this.message,
  });
}

/// File/directory metadata.
class FileInfo {
  /// Full path.
  final String path;

  /// Entry name.
  final String name;

  /// Whether this is a directory.
  final bool isDirectory;

  /// Size in bytes.
  final int size;

  /// Last modified time.
  final DateTime modified;

  /// Last accessed time.
  final DateTime accessed;

  /// Last changed time.
  final DateTime changed;

  /// Type string in Arabic.
  final String type;

  /// Arabic message.
  final String message;

  const FileInfo({
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.modified,
    required this.accessed,
    required this.changed,
    required this.type,
    required this.message,
  });

  /// Human-readable size.
  String get sizeLabel {
    if (size < 1024) return '$size بايت';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} ك.ب';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} م.ب';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} ج.ب';
  }

  /// Arabic summary.
  String get summaryAr =>
      '$type: $name (${sizeLabel}) — آخر تعديل: ${_formatDate(modified)}';

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// Filesystem service exception.
class FilesystemException implements Exception {
  final String message;
  FilesystemException(this.message);

  @override
  String toString() => 'FilesystemException: $message';
}
