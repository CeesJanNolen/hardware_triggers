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

    test('a third quick press is a triple', () async {
      expect(
        describe(await run([press(up, 0), press(up, 100), press(up, 200)])),
        'up:single@0 up:double@100 up:triple@200',
      );
    });

    test('a fourth quick press starts a new sequence', () async {
      expect(
        describe(
          await run([
            press(up, 0),
            press(up, 100),
            press(up, 200),
            press(up, 300),
          ]),
        ),
        'up:single@0 up:double@100 up:triple@200 up:single@300',
      );
    });

    test(
      'the window is measured from the previous press, not the first',
      () async {
        expect(
          describe(await run([press(up, 0), press(up, 300), press(up, 600)])),
          'up:single@0 up:double@300 up:triple@600',
        );
      },
    );

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
        async.elapse(const Duration(milliseconds: 100));
        controller.add(press(up, 100, phase: KeyPhase.up));
        async.elapse(const Duration(milliseconds: 200));
        expect(seen, isEmpty);
        async.elapse(const Duration(milliseconds: 100));
        expect(describe(seen), 'up:single@0');
      });
    });

    test('a press released after the window is reported at release', () {
      fakeAsync((async) {
        final controller = StreamController<InputEvent>();
        final seen = <PressPattern>[];
        controller.stream.transform(recognizer).listen(seen.add);

        controller.add(press(up, 0));
        async.elapse(const Duration(milliseconds: 400));
        expect(seen, isEmpty);
        controller.add(press(up, 400, phase: KeyPhase.up));
        async.elapse(Duration.zero);
        expect(describe(seen), 'up:single@0');
      });
    });

    test('a second press within the window is a double, no single', () {
      fakeAsync((async) {
        final controller = StreamController<InputEvent>();
        final seen = <PressPattern>[];
        controller.stream.transform(recognizer).listen(seen.add);

        controller.add(press(up, 0));
        async.elapse(const Duration(milliseconds: 100));
        controller.add(press(up, 100, phase: KeyPhase.up));
        async.elapse(const Duration(milliseconds: 100));
        controller.add(press(up, 200));
        async.elapse(const Duration(milliseconds: 100));
        controller.add(press(up, 300, phase: KeyPhase.up));
        async.elapse(const Duration(seconds: 1));
        expect(describe(seen), 'up:double@200');
      });
    });

    test('a triple is reported at once, with no single or double', () {
      fakeAsync((async) {
        final controller = StreamController<InputEvent>();
        final seen = <PressPattern>[];
        controller.stream.transform(recognizer).listen(seen.add);

        controller.add(press(up, 0));
        async.elapse(const Duration(milliseconds: 100));
        controller.add(press(up, 100));
        async.elapse(const Duration(milliseconds: 100));
        controller.add(press(up, 200));
        async.flushMicrotasks();
        expect(describe(seen), 'up:triple@200');
        async.elapse(const Duration(seconds: 1));
        expect(describe(seen), 'up:triple@200');
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

  group('long press', () {
    test('optimistic: the single is reported at once, the long press at the '
        'threshold, and the release reports nothing', () {
      fakeAsync((async) {
        final controller = StreamController<InputEvent>();
        final seen = <PressPattern>[];
        controller.stream
            .transform(const PressPatternRecognizer())
            .listen(seen.add);

        controller.add(press(up, 0));
        async.flushMicrotasks();
        expect(describe(seen), 'up:single@0');
        async.elapse(const Duration(milliseconds: 499));
        expect(describe(seen), 'up:single@0');
        async.elapse(const Duration(milliseconds: 1));
        expect(describe(seen), 'up:single@0 up:long@500');
        controller.add(press(up, 2000, phase: KeyPhase.up));
        async.elapse(const Duration(seconds: 1));
        expect(describe(seen), 'up:single@0 up:long@500');
      });
    });

    test('optimistic: a release before the threshold is no long press', () {
      fakeAsync((async) {
        final controller = StreamController<InputEvent>();
        final seen = <PressPattern>[];
        controller.stream
            .transform(const PressPatternRecognizer())
            .listen(seen.add);

        controller.add(press(up, 0));
        async.elapse(const Duration(milliseconds: 200));
        controller.add(press(up, 200, phase: KeyPhase.up));
        async.elapse(const Duration(seconds: 1));
        expect(describe(seen), 'up:single@0');
      });
    });

    test('a long press ends its sequence: the next press is a single', () {
      fakeAsync((async) {
        final controller = StreamController<InputEvent>();
        final seen = <PressPattern>[];
        controller.stream
            .transform(const PressPatternRecognizer())
            .listen(seen.add);

        controller.add(press(up, 0));
        async.elapse(const Duration(milliseconds: 600));
        controller.add(press(up, 600, phase: KeyPhase.up));
        async.elapse(const Duration(milliseconds: 100));
        controller.add(press(up, 700));
        async.flushMicrotasks();
        expect(describe(seen), 'up:single@0 up:long@500 up:single@700');
      });
    });

    test('delayed: a hold reports only the long press', () {
      fakeAsync((async) {
        final controller = StreamController<InputEvent>();
        final seen = <PressPattern>[];
        controller.stream
            .transform(const PressPatternRecognizer(optimistic: false))
            .listen(seen.add);

        controller.add(press(up, 0));
        async.elapse(const Duration(milliseconds: 499));
        expect(seen, isEmpty);
        async.elapse(const Duration(milliseconds: 1));
        expect(describe(seen), 'up:long@500');
        controller.add(press(up, 1500, phase: KeyPhase.up));
        async.elapse(const Duration(seconds: 1));
        expect(describe(seen), 'up:long@500');
      });
    });

    test('delayed: a hold on the second press ends the double', () {
      fakeAsync((async) {
        final controller = StreamController<InputEvent>();
        final seen = <PressPattern>[];
        controller.stream
            .transform(const PressPatternRecognizer(optimistic: false))
            .listen(seen.add);

        controller.add(press(up, 0));
        async.elapse(const Duration(milliseconds: 100));
        controller.add(press(up, 100, phase: KeyPhase.up));
        async.elapse(const Duration(milliseconds: 100));
        controller.add(press(up, 200));
        async.elapse(const Duration(seconds: 1));
        expect(describe(seen), 'up:long@700');
      });
    });

    test('the threshold is configurable', () {
      fakeAsync((async) {
        final controller = StreamController<InputEvent>();
        final seen = <PressPattern>[];
        controller.stream
            .transform(
              const PressPatternRecognizer(
                longPressThreshold: Duration(seconds: 1),
              ),
            )
            .listen(seen.add);

        controller.add(press(up, 0));
        async.elapse(const Duration(milliseconds: 999));
        expect(describe(seen), 'up:single@0');
        async.elapse(const Duration(milliseconds: 1));
        expect(describe(seen), 'up:single@0 up:long@1000');
      });
    });
  });
}
