import 'dart:async';

import 'package:flutter/services.dart';

import 'input_event.dart';
import 'intercept_rule.dart';
import 'platform_interface.dart';

/// Entry point: one stream of Input Events from every Trigger, plus control
/// over native interception.
///
/// Two paths feed [events]. Keys under an active [InterceptRule] arrive from
/// the native side, with device info. Every other hardware key arrives
/// through Flutter's own keyboard handling. A key is never reported twice:
/// while a native rule covers it, the Flutter path ignores it.
class HardwareTriggers {
  HardwareTriggers({
    HardwareTriggersPlatform? platform,
    HardwareKeyboard? keyboard,
  }) : _platform = platform ?? HardwareTriggersPlatform.instance,
       _keyboardOverride = keyboard {
    _controller = StreamController<InputEvent>.broadcast(
      onListen: _attach,
      onCancel: _detach,
    );
  }

  static final HardwareTriggers instance = HardwareTriggers();

  final HardwareTriggersPlatform _platform;
  final HardwareKeyboard? _keyboardOverride;

  /// Resolved on first use so [instance] can be created before `runApp`.
  HardwareKeyboard get _keyboard =>
      _keyboardOverride ?? HardwareKeyboard.instance;
  late final StreamController<InputEvent> _controller;
  StreamSubscription<NativeKeyEvent>? _nativeSubscription;
  List<InterceptRule> _activeRules = const [];

  /// Keys the Flutter path reports and also marks as handled, so Flutter
  /// widgets never see them. Useful for a keyboard-mode remote sending Enter
  /// while a text field could have focus.
  Set<LogicalKeyboardKey> consumedFlutterKeys = {};

  Stream<InputEvent> get events => _controller.stream;

  List<InterceptRule> get activeRules => List.unmodifiable(_activeRules);

  bool get isIntercepting => _activeRules.isNotEmpty;

  Future<bool> isInterceptSupported() => _platform.isInterceptSupported();

  Future<List<TriggerDevice>> connectedDevices() =>
      _platform.connectedDevices();

  /// Replaces any previous rules. Call [stopIntercepting] when the screen
  /// that needs the keys goes away.
  Future<void> startIntercepting(List<InterceptRule> rules) async {
    _activeRules = List.of(rules);
    await _platform.startIntercepting(rules);
  }

  Future<void> stopIntercepting() async {
    _activeRules = const [];
    await _platform.stopIntercepting();
  }

  void _attach() {
    _keyboard.addHandler(_onFlutterKey);
    _nativeSubscription = _platform.keyEvents.listen((native) {
      final event = native.toInputEvent();
      if (event != null) _controller.add(event);
    });
  }

  void _detach() {
    _keyboard.removeHandler(_onFlutterKey);
    _nativeSubscription?.cancel();
    _nativeSubscription = null;
  }

  bool _onFlutterKey(KeyEvent event) {
    if (event is KeyRepeatEvent) return false;
    final key = event.logicalKey;
    if (_activeRules.any((r) => r.key == key)) return false;
    _controller.add(
      InputEvent(
        key: key,
        phase: event is KeyUpEvent ? KeyPhase.up : KeyPhase.down,
        at: DateTime.now(),
        source: InputSource.flutter,
      ),
    );
    return consumedFlutterKeys.contains(key);
  }
}
