import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'input_event.dart';
import 'intercept_rule.dart';
import 'key_codes.dart';

/// A key event as the native side reports it, before Dart maps the key.
class NativeKeyEvent {
  const NativeKeyEvent({
    required this.code,
    required this.phase,
    required this.at,
    this.device,
  });

  factory NativeKeyEvent.fromMap(Map<Object?, Object?> map) {
    final deviceId = map['deviceId'] as int?;
    return NativeKeyEvent(
      code: map['code'] as int,
      phase: map['phase'] == 'up' ? KeyPhase.up : KeyPhase.down,
      at: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      device: deviceId == null
          ? null
          : TriggerDevice(
              id: deviceId,
              name: map['deviceName'] as String? ?? '',
              isExternal: map['isExternal'] as bool?,
              vendorId: map['vendorId'] as int?,
              productId: map['productId'] as int?,
            ),
    );
  }

  /// Android key code, on every platform.
  final int code;
  final KeyPhase phase;
  final DateTime at;
  final TriggerDevice? device;

  /// A code Flutter has no name for becomes a key in Flutter's Android
  /// plane, the same id Flutter itself would give it.
  InputEvent toInputEvent() => InputEvent(
    key:
        logicalKeyFromCode(code) ??
        LogicalKeyboardKey(LogicalKeyboardKey.androidPlane + code),
    phase: phase,
    at: at,
    source: InputSource.native,
    device: device,
    code: code,
  );
}

abstract class HardwareTriggersPlatform extends PlatformInterface {
  HardwareTriggersPlatform() : super(token: _token);

  static final Object _token = Object();

  static HardwareTriggersPlatform _instance = MethodChannelHardwareTriggers();

  static HardwareTriggersPlatform get instance => _instance;

  static set instance(HardwareTriggersPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Keys intercepted natively. Only emits while interception is active.
  Stream<NativeKeyEvent> get keyEvents;

  Future<void> startIntercepting(List<InterceptRule> rules);

  Future<void> stopIntercepting();

  /// Whether this platform can intercept keys at all.
  Future<bool> isInterceptSupported();

  Future<List<TriggerDevice>> connectedDevices();
}

/// Talks to the native plugin. On a platform where the plugin is not
/// registered (iOS, desktop, web) every call degrades: interception is
/// unsupported, no devices are listed and nothing is thrown.
class MethodChannelHardwareTriggers extends HardwareTriggersPlatform {
  MethodChannelHardwareTriggers({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methods = methodChannel ?? const MethodChannel('hardware_triggers'),
       _events = eventChannel ?? const EventChannel('hardware_triggers/events');

  final MethodChannel _methods;
  final EventChannel _events;
  Stream<NativeKeyEvent>? _keyEvents;

  @override
  Stream<NativeKeyEvent> get keyEvents => _keyEvents ??= _events
      .receiveBroadcastStream()
      .handleError((_) {}, test: (e) => e is MissingPluginException)
      .map((e) => NativeKeyEvent.fromMap(e as Map<Object?, Object?>));

  /// Null when the plugin is not registered on this platform.
  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _methods.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> startIntercepting(List<InterceptRule> rules) =>
      _invoke<void>('startIntercepting', {
        'rules': [
          for (final rule in rules)
            for (final code in _codesFor(rule))
              {
                'code': code,
                'policy': rule.policy.name,
                'externalOnly': rule.externalOnly,
              },
        ],
      });

  @override
  Future<void> stopIntercepting() => _invoke<void>('stopIntercepting');

  @override
  Future<bool> isInterceptSupported() async =>
      await _invoke<bool>('isInterceptSupported') ?? false;

  @override
  Future<List<TriggerDevice>> connectedDevices() async {
    final devices =
        await _invoke<List<Object?>>('connectedDevices') ?? const [];
    return [
      for (final d in devices.cast<Map<Object?, Object?>>())
        TriggerDevice(
          id: d['id'] as int,
          name: d['name'] as String? ?? '',
          isExternal: d['isExternal'] as bool?,
          vendorId: d['vendorId'] as int?,
          productId: d['productId'] as int?,
        ),
    ];
  }
}

/// The wire code for a catch-all rule; no Android key code is negative.
const int anyKeyCode = -1;

List<int> _codesFor(InterceptRule rule) {
  final key = rule.key;
  return key == null ? const [anyKeyCode] : codesForLogicalKey(key);
}
