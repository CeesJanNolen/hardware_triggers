import 'dart:async';

import 'package:flutter/services.dart';

import 'input_event.dart';

enum PressKind { single, double, triple, long }

/// A single, double, triple or long press of one key, recognised from Input
/// Events.
class PressPattern {
  const PressPattern({
    required this.key,
    required this.kind,
    required this.at,
    this.device,
  });

  final LogicalKeyboardKey key;
  final PressKind kind;

  /// Time of the press that completed the pattern. For a long press, the
  /// moment the hold crossed the threshold.
  final DateTime at;
  final TriggerDevice? device;

  @override
  bool operator ==(Object other) =>
      other is PressPattern &&
      other.key == key &&
      other.kind == kind &&
      other.at == at &&
      other.device == device;

  @override
  int get hashCode => Object.hash(key, kind, at, device);

  @override
  String toString() => 'PressPattern(${key.debugName}, $kind, $at, $device)';
}

/// Turns Input Events into Press Patterns. Other keys' presses in between are
/// ignored. Presses of one key count as a sequence while each key-down
/// follows the previous within [pressWindow]; a sequence ends after a triple
/// press, so a fourth quick press starts a new one.
///
/// A key held down for [longPressThreshold] is a long press, reported the
/// moment the threshold passes, while the key is still down. A long press
/// ends its sequence: the release reports nothing and does not count toward
/// a double.
///
/// Optimistic (the default): every key-down is reported at once, as single,
/// double or triple according to its place in the sequence, and a long press
/// follows later if the key stays down. The consumer undoes what it did for
/// the earlier reports. No press is ever delayed.
///
/// Delayed: a sequence is reported once, after the key is released and
/// [pressWindow] has passed since its last key-down (so a double can still
/// follow), or at once on reaching a triple. A release after a long press
/// reports nothing. Nothing ever has to be undone, at the price of a short
/// delay.
class PressPatternRecognizer
    extends StreamTransformerBase<InputEvent, PressPattern> {
  const PressPatternRecognizer({
    this.pressWindow = const Duration(milliseconds: 350),
    this.longPressThreshold = const Duration(milliseconds: 500),
    this.optimistic = true,
  });

  final Duration pressWindow;
  final Duration longPressThreshold;
  final bool optimistic;

  static const _maxPresses = 3;

  static PressKind _kind(int count) => switch (count) {
    1 => PressKind.single,
    2 => PressKind.double,
    _ => PressKind.triple,
  };

  @override
  Stream<PressPattern> bind(Stream<InputEvent> stream) {
    final sequences = <LogicalKeyboardKey, ({int count, InputEvent last})>{};
    final pending = <LogicalKeyboardKey, Timer>{};
    final holds = <LogicalKeyboardKey, Timer>{};
    final heldLong = <LogicalKeyboardKey>{};
    late final StreamController<PressPattern> controller;
    StreamSubscription<InputEvent>? subscription;

    PressPattern pattern(InputEvent e, int count) => PressPattern(
      key: e.key,
      kind: _kind(count),
      at: e.at,
      device: e.device,
    );

    int advance(InputEvent event) {
      final previous = sequences[event.key];
      final continues =
          previous != null &&
          previous.count < _maxPresses &&
          event.at.difference(previous.last.at) <= pressWindow;
      final count = continues ? previous.count + 1 : 1;
      sequences[event.key] = (count: count, last: event);
      return count;
    }

    void onDown(InputEvent event) {
      final key = event.key;
      heldLong.remove(key);
      final count = advance(event);

      holds.remove(key)?.cancel();
      holds[key] = Timer(longPressThreshold, () {
        holds.remove(key);
        heldLong.add(key);
        pending.remove(key)?.cancel();
        sequences.remove(key);
        controller.add(
          PressPattern(
            key: key,
            kind: PressKind.long,
            at: event.at.add(longPressThreshold),
            device: event.device,
          ),
        );
      });

      if (optimistic) {
        controller.add(pattern(event, count));
        return;
      }

      pending.remove(key)?.cancel();
      if (count == _maxPresses) {
        holds.remove(key)?.cancel();
        controller.add(pattern(event, count));
      }
    }

    void onUp(InputEvent event) {
      final key = event.key;
      holds.remove(key)?.cancel();
      if (heldLong.remove(key) || optimistic) return;

      final sequence = sequences[key];
      if (sequence == null || sequence.count == _maxPresses) return;
      final remaining = pressWindow - event.at.difference(sequence.last.at);
      pending[key] = Timer(
        remaining.isNegative ? Duration.zero : remaining,
        () {
          pending.remove(key);
          controller.add(pattern(sequence.last, sequence.count));
        },
      );
    }

    void onEvent(InputEvent event) => switch (event.phase) {
      KeyPhase.down => onDown(event),
      KeyPhase.up => onUp(event),
    };

    void cancelTimers() {
      for (final timer in [...pending.values, ...holds.values]) {
        timer.cancel();
      }
      pending.clear();
      holds.clear();
    }

    controller = StreamController<PressPattern>(
      onListen: () {
        subscription = stream.listen(
          onEvent,
          onError: controller.addError,
          onDone: () {
            cancelTimers();
            controller.close();
          },
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () {
        cancelTimers();
        return subscription?.cancel();
      },
    );
    return controller.stream;
  }
}
