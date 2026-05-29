import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:audioplayers/audioplayers.dart'
    hide AVAudioSessionCategory, AVAudioSessionOptions;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vibration/vibration.dart';

import 'package:my_gym_bro/core/services/notification_service.dart';

class RestTimerService {
  /// Singleton-style reference so the notification action handler can reach
  /// the currently running timer without needing a Riverpod ref.
  static RestTimerService? activeInstance;

  StreamController<int>? _controller;
  Timer? _timer;
  int _remaining = 0;
  int _total = 0;
  bool _soundEnabled = true;
  VoidCallback? _onComplete;
  String _notificationTitle = 'Rest Complete!';
  String _notificationBody = 'Time to hit the next set!';

  /// Callback set by [ActiveSessionNotifier] so the notification handler
  /// can trigger "Complete Set" without a Riverpod ref.
  VoidCallback? completeSetFromNotification;

  /// Public accessor so the notification handler can invoke [_onComplete]
  /// when the user taps "Skip" from the notification shade.
  VoidCallback? get onCompleteCallback => _onComplete;

  Stream<int>? get stream => _controller?.stream;
  int get remaining => _remaining;
  int get total => _total;
  double get progress => _total > 0 ? _remaining / _total : 0;

  // ── Persistence helpers ──────────────────────────────────────────────────

  static const _kFileName = 'rest_timer_state.json';

  /// Returns the persistence file, creating the parent directory if needed.
  static Future<File> _stateFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_kFileName');
  }

  /// Write the timer deadline and total duration to disk so the timer can
  /// survive an OS-initiated app kill.
  Future<void> _persistState() async {
    try {
      final file = await _stateFile();
      final data = {
        'deadline': DateTime.now()
            .add(Duration(seconds: _remaining))
            .toIso8601String(),
        'total': _total,
        'soundEnabled': _soundEnabled,
        'notificationTitle': _notificationTitle,
        'notificationBody': _notificationBody,
      };
      await file.writeAsString(jsonEncode(data));
    } on Exception catch (e) {
      debugPrint('RestTimerService: failed to persist state: $e');
    }
  }

  /// Remove the persisted state (called on cancel or completion).
  static Future<void> _clearPersistedState() async {
    try {
      final file = await _stateFile();
      if (file.existsSync()) await file.delete();
    } on Exception catch (e) {
      debugPrint('RestTimerService: failed to clear persisted state: $e');
    }
  }

  /// Attempt to restore a previously persisted rest timer.
  ///
  /// Returns the remaining seconds if a valid, non-expired timer was found,
  /// along with the persisted total. Returns `null` if nothing to restore.
  static Future<({int remaining, int total, bool soundEnabled, String title, String body})?>
      loadPersistedState() async {
    try {
      final file = await _stateFile();
      if (!file.existsSync()) return null;

      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final deadline = DateTime.parse(json['deadline'] as String);
      final total = json['total'] as int;
      final soundEnabled = json['soundEnabled'] as bool? ?? true;
      final title = json['notificationTitle'] as String? ?? 'Rest Complete!';
      final body = json['notificationBody'] as String? ?? 'Time to hit the next set!';

      final remaining = deadline.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        // Timer already expired while we were killed — clean up.
        await file.delete();
        return null;
      }

      return (
        remaining: remaining,
        total: total,
        soundEnabled: soundEnabled,
        title: title,
        body: body,
      );
    } on Exception catch (e) {
      debugPrint('RestTimerService: failed to load persisted state: $e');
      return null;
    }
  }

  // ── Timer lifecycle ──────────────────────────────────────────────────────

  void start({
    required int seconds,
    required VoidCallback onComplete,
    bool soundEnabled = true,
    String? notificationTitle,
    String? notificationBody,
  }) {
    cancel();
    _remaining = seconds;
    _total = seconds;
    _soundEnabled = soundEnabled;
    _onComplete = onComplete;
    if (notificationTitle != null) _notificationTitle = notificationTitle;
    if (notificationBody != null) _notificationBody = notificationBody;
    _controller = StreamController<int>.broadcast();
    _controller!.add(_remaining);

    // Register this as the active instance for notification actions.
    activeInstance = this;

    // Persist deadline so the timer can survive OS app kills.
    unawaited(_persistState());

    _startTicking();
  }

  /// Resume a timer from a previously persisted state.
  ///
  /// This is the entry point called by the session notifier on app restart
  /// when [loadPersistedState] finds a valid, non-expired deadline.
  void restore({
    required int remaining,
    required int total,
    required VoidCallback onComplete,
    bool soundEnabled = true,
    String? notificationTitle,
    String? notificationBody,
  }) {
    cancel();
    _remaining = remaining;
    _total = total;
    _soundEnabled = soundEnabled;
    _onComplete = onComplete;
    if (notificationTitle != null) _notificationTitle = notificationTitle;
    if (notificationBody != null) _notificationBody = notificationBody;
    _controller = StreamController<int>.broadcast();
    _controller!.add(_remaining);

    activeInstance = this;
    _startTicking();
  }

  void _startTicking() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _remaining--;
      if (_remaining <= 0) {
        _remaining = 0;
        _controller?.add(_remaining);
        _complete();
      } else {
        _controller?.add(_remaining);
      }
    });
  }

  void addTime(int seconds) {
    _remaining = (_remaining + seconds).clamp(0, 600);
    // Keep _total >= _remaining so the progress ring (remaining/total) stays
    // bounded. Don't let _total grow past the clamp ceiling, and don't let
    // it dip below current remaining (would draw an over-full ring).
    _total = _remaining > _total ? _remaining : _total;
    _controller?.add(_remaining);
  }

  void _complete() {
    _timer?.cancel();
    _timer = null;

    // Clean up persisted state — timer is done.
    unawaited(_clearPersistedState());

    // Vibrate
    Vibration.vibrate(pattern: [0, 200, 100, 500, 100, 200]);

    // Sound — use audio ducking so background music is lowered, not stopped.
    if (_soundEnabled) {
      unawaited(_playWithDucking());
    }

    // Local notification (for backgrounded app)
    NotificationService.showRestComplete(
      title: _notificationTitle,
      body: _notificationBody,
    );

    _onComplete?.call();
  }

  /// Configures the OS audio session for ducking, plays the tone, then
  /// deactivates the session so the OS restores background music volume.
  Future<void> _playWithDucking() async {
    try {
      // 1. Configure the audio session for ducking on both platforms.
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.duckOthers |
                AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          usage: AndroidAudioUsage.assistanceSonification,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
      ));

      // 2. Activate the session — this triggers ducking immediately.
      await session.setActive(true);

      // 3. Play the timer tone.
      final player = AudioPlayer();
      await player.play(AssetSource('audio/rest_complete.mp3'));

      // 4. When playback finishes, deactivate the session to restore
      //    the original background music volume, then release the player.
      player.onPlayerComplete.listen((_) async {
        await session.setActive(false);
        await player.dispose();
      });
    } on Exception catch (e) {
      debugPrint('Audio ducking error: $e');
    }
  }

  /// Whether a timer is currently counting down. False when stopped,
  /// completed, or paused via [pause].
  bool get isRunning => _timer != null;

  /// Whether a timer is paused — counting is suspended but [_remaining]
  /// and [_total] still hold valid values for display.
  bool get isPaused => _timer == null && _remaining > 0;

  /// Suspend ticking without losing remaining time. The persisted deadline
  /// is cleared so a kill+restore doesn't keep counting through pause.
  void pause() {
    if (_timer == null) return;
    _timer?.cancel();
    _timer = null;
    unawaited(_clearPersistedState());
  }

  /// Resume after [pause]. No-op if not paused or already finished.
  void resume() {
    if (_timer != null || _remaining <= 0) return;
    unawaited(_persistState());
    _startTicking();
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    if (_controller != null && !_controller!.isClosed) {
      _controller!.close();
    }
    _controller = null;
    _remaining = 0;
    _total = 0;
    if (activeInstance == this) activeInstance = null;

    // Clean up persisted state — user explicitly cancelled.
    unawaited(_clearPersistedState());
  }

  void dispose() {
    cancel();
    completeSetFromNotification = null;
  }
}
