import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_triggers/hardware_triggers.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePlatform extends HardwareTriggersPlatform
    with MockPlatformInterfaceMixin {
  final native = StreamController<NativeKeyEvent>.broadcast();
  List<InterceptRule>? started;
  var stopped = 0;

  @override
  Stream<NativeKeyEvent> get keyEvents => native.stream;

  @override
  Future<void> startIntercepting(List<InterceptRule> rules) async =>
      started = rules;

  @override
  Future<void> stopIntercepting() async => stopped++;

  @override
  Future<bool> isInterceptSupported() async => true;

  @override
  Future<List<TriggerDevice>> connectedDevices() async => const [
    TriggerDevice(id: 3, name: 'AB Shutter3', isExternal: true),
  ];
}

const up = LogicalKeyboardKey.audioVolumeUp;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakePlatform platform;
  late HardwareTriggers triggers;

  setUp(() {
    platform = FakePlatform();
    triggers = HardwareTriggers(platform: platform);
  });

  test('native key events come out as Input Events with the device', () async {
    final events = <InputEvent>[];
    final sub = triggers.events.listen(events.add);
    platform.native.add(
      NativeKeyEvent.fromMap({
        'code': 24,
        'phase': 'down',
        'timestamp': 1000,
        'deviceId': 3,
        'deviceName': 'AB Shutter3',
        'isExternal': true,
      }),
    );
    await Future<void>.delayed(Duration.zero);
    expect(events.single.key, up);
    expect(events.single.phase, KeyPhase.down);
    expect(events.single.source, InputSource.native);
    expect(events.single.device?.name, 'AB Shutter3');
    expect(events.single.at, DateTime.fromMillisecondsSinceEpoch(1000));
    await sub.cancel();
  });

  test('toInputEvent returns null for an unknown code', () {
    final native = NativeKeyEvent(
      code: 99999,
      phase: KeyPhase.down,
      at: DateTime(2026),
    );
    expect(native.toInputEvent(), isNull);
  });

  test('start and stop forward rules and track active state', () async {
    const rules = [InterceptRule(up, policy: InterceptPolicy.observe)];
    await triggers.startIntercepting(rules);
    expect(platform.started, rules);
    expect(triggers.isIntercepting, isTrue);
    expect(triggers.activeRules, rules);
    await triggers.stopIntercepting();
    expect(platform.stopped, 1);
    expect(triggers.isIntercepting, isFalse);
  });

  test('connected devices pass through', () async {
    final devices = await triggers.connectedDevices();
    expect(devices.single.name, 'AB Shutter3');
  });

  group('Flutter key path', () {
    late FakeKeyboard keyboard;

    setUp(() {
      keyboard = FakeKeyboard();
      triggers = HardwareTriggers(platform: platform, keyboard: keyboard);
    });

    test(
      'handler is attached on first listener and removed on last cancel',
      () async {
        expect(keyboard.handler, isNull);
        final sub = triggers.events.listen((_) {});
        expect(keyboard.handler, isNotNull);
        await sub.cancel();
        expect(keyboard.handler, isNull);
      },
    );

    test(
      'key events are reported while no native rule covers the key',
      () async {
        final events = <InputEvent>[];
        final sub = triggers.events.listen(events.add);

        keyboard.press(LogicalKeyboardKey.enter);
        await Future<void>.delayed(Duration.zero);
        expect(events.map((e) => e.phase), [KeyPhase.down, KeyPhase.up]);
        expect(events.first.key, LogicalKeyboardKey.enter);
        expect(events.first.source, InputSource.flutter);
        expect(events.first.device, isNull);

        await triggers.startIntercepting(const [
          InterceptRule(LogicalKeyboardKey.enter),
        ]);
        events.clear();
        keyboard.press(LogicalKeyboardKey.enter);
        await Future<void>.delayed(Duration.zero);
        expect(events, isEmpty);

        await triggers.stopIntercepting();
        await sub.cancel();
      },
    );

    test('repeats are ignored', () async {
      final events = <InputEvent>[];
      final sub = triggers.events.listen(events.add);
      keyboard.handler!(
        KeyRepeatEvent(
          physicalKey: PhysicalKeyboardKey.enter,
          logicalKey: LogicalKeyboardKey.enter,
          timeStamp: Duration.zero,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
      await sub.cancel();
    });

    test('consumedFlutterKeys marks only those keys as handled', () async {
      triggers.consumedFlutterKeys = {LogicalKeyboardKey.enter};
      final sub = triggers.events.listen((_) {});
      expect(keyboard.press(LogicalKeyboardKey.enter), isTrue);
      expect(keyboard.press(LogicalKeyboardKey.space), isFalse);
      await sub.cancel();
    });
  });
}

class FakeKeyboard extends HardwareKeyboard {
  KeyEventCallback? handler;

  @override
  void addHandler(KeyEventCallback h) => handler = h;

  @override
  void removeHandler(KeyEventCallback h) {
    if (handler == h) handler = null;
  }

  /// Sends down then up. Returns whether the down event was handled.
  bool press(LogicalKeyboardKey key) {
    final physical = PhysicalKeyboardKey(key.keyId);
    final handledDown = handler!(
      KeyDownEvent(
        physicalKey: physical,
        logicalKey: key,
        timeStamp: Duration.zero,
      ),
    );
    handler!(
      KeyUpEvent(
        physicalKey: physical,
        logicalKey: key,
        timeStamp: const Duration(milliseconds: 50),
      ),
    );
    return handledDown;
  }
}
