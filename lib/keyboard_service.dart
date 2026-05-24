import 'dart:async';
import 'package:flutter/services.dart';
import 'models/key_event.dart';

class KeyboardService {
  static const _channel = EventChannel('com.kysy/keyboard_events');

  static final StreamController<GlobalKeyEvent> _controller =
      StreamController<GlobalKeyEvent>.broadcast();

  static Stream<GlobalKeyEvent> get keyEvents => _controller.stream;

  static StreamSubscription<dynamic>? _sub;
  static String? _lastError;

  static String? get lastError => _lastError;

  static void startListening() {
    _sub = _channel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          _lastError = null;
          _controller.add(GlobalKeyEvent.fromMap(event));
        }
      },
      onError: (error) {
        if (error is PlatformException) {
          _lastError = error.message;
          _controller.addError(error);
        }
      },
    );
  }

  static void stopListening() {
    _sub?.cancel();
    _sub = null;
  }
}
