import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_triggers/hardware_triggers.dart';

final t0 = DateTime(2026, 10, 15, 19);
const up = LogicalKeyboardKey.audioVolumeUp;
const down = LogicalKeyboardKey.audioVolumeDown;

InputEvent press(
  LogicalKeyboardKey key,
  int ms, {
  KeyPhase phase = KeyPhase.down,
}) => InputEvent(
  key: key,
  phase: phase,
  at: t0.add(Duration(milliseconds: ms)),
  source: InputSource.native,
);

String describe(List<PressPattern> patterns) => patterns
    .map(
      (p) =>
          '${p.key == up ? 'up' : 'down'}:${p.kind.name}@${p.at.difference(t0).inMilliseconds}',
    )
    .join(' ');

void main() {
  group('optimistic', () {
    const recognizer = PressPatternRecognizer();

    Future<List<PressPattern>> run(List<InputEvent> events) =>
        Stream.fromIterable(events).transform(recognizer).toList();

    test('a lone press is a single press, reported at once', () async {
      expect(describe(await run([press(up, 0)])), 'up:single@0');
    });

    test('a second press within the window follows as a double', () async {
      expect(
        describe(await run([press(up, 0), press(up, 300)])),
        'up:single@0 up:double@300',
      );
    });

    test('a second press after the window is another single', () async {
      expect(
        describe(await run([press(up, 0), press(up, 400)])),
        'up:single@0 up:single@400',
      );
    });

    test('a third quick press starts over as a single', () async {
      expect(
        describe(await run([press(up, 0), press(up, 100), press(up, 200)])),
        'up:single@0 up:double@100 up:single@200',
      );
    });

    test('different keys do not pair up', () async {
      expect(
        describe(await run([press(up, 0), press(down, 100)])),
        'up:single@0 down:single@100',
      );
    });

    test('key up events are ignored', () async {
      expect(
        describe(await run([press(up, 0), press(up, 50, phase: KeyPhase.up)])),
        'up:single@0',
      );
    });

    test('carries the device of the completing press', () async {
      const device = TriggerDevice(
        id: 7,
        name: 'AB Shutter3',
        isExternal: true,
      );
      final patterns = await run([
        InputEvent(
          key: up,
          phase: KeyPhase.down,
          at: t0,
          source: InputSource.native,
          device: device,
        ),
      ]);
      expect(patterns.single.device, device);
    });
  });

  group('delayed', () {
    const recognizer = PressPatternRecognizer(optimistic: false);

    test('a lone press is reported after the window', () {
      fakeAsync((async) {
        final controller = StreamController<InputEvent>();
        final seen = <PressPattern>[];
        controller.stream.transform(recognizer).listen(seen.add);

        controller.add(press(up, 0));
        async.elapse(const Duration(milliseconds: 300));
        expect(seen, isEmpty);
        async.elapse(const Duration(milliseconds: 100));
        expect(describe(seen), 'up:single@0');
      });
    });

    test('a second press within the window is a double, no single', () {
      fakeAsync((async) {
        final controller = StreamController<InputEvent>();
        final seen = <PressPattern>[];
        controller.stream.transform(recognizer).listen(seen.add);

        controller.add(press(up, 0));
        async.elapse(const Duration(milliseconds: 200));
        controller.add(press(up, 200));
        async.elapse(const Duration(seconds: 1));
        expect(describe(seen), 'up:double@200');
      });
    });

    test('cancelling the subscription drops pending presses', () {
      fakeAsync((async) {
        final controller = StreamController<InputEvent>();
        final seen = <PressPattern>[];
        final sub = controller.stream.transform(recognizer).listen(seen.add);

        controller.add(press(up, 0));
        async.elapse(const Duration(milliseconds: 100));
        sub.cancel();
        async.elapse(const Duration(seconds: 1));
        expect(seen, isEmpty);
      });
    });
  });
}
