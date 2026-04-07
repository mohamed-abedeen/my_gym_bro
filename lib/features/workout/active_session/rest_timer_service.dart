import 'dart:async';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

import '../../../core/services/notification_service.dart';

class RestTimerService {
  StreamController<int>? _controller;
  Timer? _timer;
  int _remaining = 0;
  int _total = 0;
  bool _soundEnabled = true;
  VoidCallback? _onComplete;

  Stream<int>? get stream => _controller?.stream;
  int get remaining => _remaining;
  int get total => _total;
  double get progress => _total > 0 ? _remaining / _total : 0;

  void start({
    required int seconds,
    required VoidCallback onComplete,
    bool soundEnabled = true,
  }) {
    cancel();
    _remaining = seconds;
    _total = seconds;
    _soundEnabled = soundEnabled;
    _onComplete = onComplete;
    _controller = StreamController<int>.broadcast();
    _controller!.add(_remaining);

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
    _total = _total + seconds > 0 ? _total + seconds : _total;
    _controller?.add(_remaining);
  }

  void _complete() {
    _timer?.cancel();
    _timer = null;

    // Vibrate
    Vibration.vibrate(pattern: [0, 200, 100, 500, 100, 200]);

    // Sound
    if (_soundEnabled) {
      try {
        AudioPlayer().play(AssetSource('audio/rest_complete.mp3'));
      } catch (_) {}
    }

    // Local notification (for backgrounded app)
    NotificationService.showRestComplete();

    _onComplete?.call();
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
  }

  void dispose() {
    cancel();
  }
}
