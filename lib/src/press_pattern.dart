import 'dart:async';

import 'package:flutter/services.dart';

import 'input_event.dart';

enum PressKind { single, double, triple }

/// A single or double press of one key, recognised from Input Events.
class PressPattern {
  const PressPattern({
    required this.key,
    required this.kind,
    required this.at,
    this.device,
  });

  final LogicalKeyboardKey key;
  final PressKind kind;

  /// Time of the press that completed the pattern.
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

/// Turns key-down Input Events into Press Patterns. Key-up events and other
/// keys' presses in between are ignored. Presses of one key count as a
/// sequence while each follows the previous within [pressWindow]; a sequence
/// ends after a triple press, so a fourth quick press starts a new one.
///
/// Optimistic (the default): every press is reported at once, as single,
/// double or triple according to its place in the sequence. The consumer
/// undoes what it did for the earlier presses. No press is ever delayed.
///
/// Delayed: a sequence is held until [pressWindow] passes without another
/// press, or until it reaches a triple, and is then reported once.
class PressPatternRecognizer
    extends StreamTransformerBase<InputEvent, PressPattern> {
  const PressPatternRecognizer({
    this.pressWindow = const Duration(milliseconds: 350),
    this.optimistic = true,
  });

  final Duration pressWindow;
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

    void onEvent(InputEvent event) {
      if (event.phase != KeyPhase.down) return;
      final key = event.key;
      final count = advance(event);

      if (optimistic) {
        controller.add(pattern(event, count));
        return;
      }

      pending.remove(key)?.cancel();
      if (count == _maxPresses) {
        controller.add(pattern(event, count));
        return;
      }
      pending[key] = Timer(pressWindow, () {
        pending.remove(key);
        controller.add(pattern(event, count));
      });
    }

    controller = StreamController<PressPattern>(
      onListen: () {
        subscription = stream.listen(
          onEvent,
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () {
        for (final timer in pending.values) {
          timer.cancel();
        }
        pending.clear();
        return subscription?.cancel();
      },
    );
    return controller.stream;
  }
}
