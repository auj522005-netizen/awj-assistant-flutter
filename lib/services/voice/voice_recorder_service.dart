/// ═══════════════════════════════════════════════════════════════════════════════
/// 🎤 OWJ Assistant — Voice Recorder Service
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Real voice recording service using the `record` package.
/// Records audio, saves to temp file, and returns the file path
/// for transcription via Groq Whisper or BigModel STT.
///
/// ═══════════════════════════════════════════════════════════════════════════════

library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceRecorderService {
  VoiceRecorderService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  bool _isRecording = false;
  bool _isPaused = false;
  String? _currentRecordingPath;
  Duration _recordingDuration = Duration.zero;
  Timer? _durationTimer;

  /// Whether the recorder is currently recording.
  bool get isRecording => _isRecording;

  /// Whether the recorder is currently paused.
  bool get isPaused => _isPaused;

  /// Whether the recorder is actively recording (not paused).
  bool get isActive => _isRecording && !_isPaused;

  /// The current recording duration.
  Duration get recordingDuration => _recordingDuration;

  /// The file path of the current recording.
  String? get currentRecordingPath => _currentRecordingPath;

  /// Stream of recording state changes.
  final _stateController = StreamController<VoiceRecorderState>.broadcast();
  Stream<VoiceRecorderState> get stateStream => _stateController.stream;

  /// Stream of recording duration updates.
  final _durationController = StreamController<Duration>.broadcast();
  Stream<Duration> get durationStream => _durationController.stream;

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Check if microphone permission is granted.
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;

    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  /// Check if the device supports recording.
  Future<bool> hasRecorderSupport() async {
    try {
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  /// Start recording audio.
  ///
  /// Returns the file path where the recording is being saved,
  /// or null if recording couldn't start.
  Future<String?> startRecording() async {
    if (_isRecording) return null;

    // Check permission
    final granted = await hasPermission();
    if (!granted) {
      _emitState(VoiceRecorderState.permissionDenied);
      return null;
    }

    try {
      // Generate file path
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/owj_voice_$timestamp.m4a';

      // Start recording
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          numChannels: 1,
          bitRate: 128000,
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      _isPaused = false;
      _recordingDuration = Duration.zero;
      _startDurationTimer();

      _emitState(VoiceRecorderState.recording);
      return _currentRecordingPath;
    } catch (e) {
      debugPrint('خطأ في بدء التسجيل: $e');
      _emitState(VoiceRecorderState.error);
      return null;
    }
  }

  /// Pause the current recording.
  Future<void> pauseRecording() async {
    if (!_isRecording || _isPaused) return;

    try {
      await _recorder.pause();
      _isPaused = true;
      _durationTimer?.cancel();
      _emitState(VoiceRecorderState.paused);
    } catch (e) {
      debugPrint('خطأ في إيقاف التسجيل مؤقتاً: $e');
    }
  }

  /// Resume a paused recording.
  Future<void> resumeRecording() async {
    if (!_isRecording || !_isPaused) return;

    try {
      await _recorder.resume();
      _isPaused = false;
      _startDurationTimer();
      _emitState(VoiceRecorderState.recording);
    } catch (e) {
      debugPrint('خطأ في استئناف التسجيل: $e');
    }
  }

  /// Stop recording and return the file path.
  ///
  /// Returns null if no recording was in progress or the file doesn't exist.
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      final path = await _recorder.stop();

      _isRecording = false;
      _isPaused = false;
      _durationTimer?.cancel();
      _durationTimer = null;

      // Verify the file exists
      if (path != null && File(path).existsSync()) {
        _currentRecordingPath = path;
        _emitState(VoiceRecorderState.stopped);
        return path;
      }

      _currentRecordingPath = null;
      _emitState(VoiceRecorderState.stopped);
      return null;
    } catch (e) {
      debugPrint('خطأ في إيقاف التسجيل: $e');
      _isRecording = false;
      _isPaused = false;
      _durationTimer?.cancel();
      _emitState(VoiceRecorderState.error);
      return null;
    }
  }

  /// Cancel the current recording without saving.
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    try {
      await _recorder.cancel();

      // Delete the file if it exists
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      _isRecording = false;
      _isPaused = false;
      _recordingDuration = Duration.zero;
      _currentRecordingPath = null;
      _durationTimer?.cancel();

      _emitState(VoiceRecorderState.cancelled);
    } catch (e) {
      debugPrint('خطأ في إلغاء التسجيل: $e');
    }
  }

  /// Get the amplitude of the current recording (for waveform visualization).
  Future<Amplitude> getAmplitude() async {
    if (!_isRecording) {
      return Amplitude(current: -160, max: -160);
    }
    try {
      return await _recorder.getAmplitude();
    } catch (_) {
      return Amplitude(current: -160, max: -160);
    }
  }

  /// Dispose of resources.
  void dispose() {
    _durationTimer?.cancel();
    _stateController.close();
    _durationController.close();
    _recorder.dispose();
  }

  // ─── Private helpers ───────────────────────────────────────────────────────

  void _startDurationTimer() {
    _durationTimer?.cancel();
    final startTime = DateTime.now().subtract(_recordingDuration);

    _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _recordingDuration = DateTime.now().difference(startTime);
      _durationController.add(_recordingDuration);
    });
  }

  void _emitState(VoiceRecorderState state) {
    _stateController.add(state);
  }
}

// ─── Data Models ──────────────────────────────────────────────────────────────

enum VoiceRecorderState {
  idle,
  permissionDenied,
  recording,
  paused,
  stopped,
  cancelled,
  error;

  bool get isIdle => this == VoiceRecorderState.idle;
  bool get isRecording => this == VoiceRecorderState.recording;
  bool get isPaused => this == VoiceRecorderState.paused;
  bool get isError => this == VoiceRecorderState.error;
  bool get isPermissionDenied => this == VoiceRecorderState.permissionDenied;
}

/// Formatted duration string (e.g., "01:23")
String formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
