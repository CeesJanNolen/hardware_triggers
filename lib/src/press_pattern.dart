import 'dart:async';

import 'package:flutter/services.dart';

import 'input_event.dart';

enum PressKind { single, double }

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
/// keys' presses in between are ignored.
///
/// Optimistic (the default): every press is reported as a single press at
/// once; a second press of the same key within [doubleWindow] is then
/// reported as a double press. The consumer undoes the single press it just
/// acted on. No press is ever delayed.
///
/// Delayed: a press is held for [doubleWindow] and reported as single if no
/// second press follows, or as double if one does.
class PressPatternRecognizer
    extends StreamTransformerBase<InputEvent, PressPattern> {
  const PressPatternRecognizer({
    this.doubleWindow = const Duration(milliseconds: 350),
    this.optimistic = true,
  });

  final Duration doubleWindow;
  final bool optimistic;

  @override
  Stream<PressPattern> bind(Stream<InputEvent> stream) {
    final lastDown = <LogicalKeyboardKey, InputEvent>{};
    final pending = <LogicalKeyboardKey, Timer>{};
    late final StreamController<PressPattern> controller;
    StreamSubscription<InputEvent>? subscription;

    PressPattern pattern(InputEvent e, PressKind kind) =>
        PressPattern(key: e.key, kind: kind, at: e.at, device: e.device);

    void onEvent(InputEvent event) {
      if (event.phase != KeyPhase.down) return;
      final key = event.key;

      if (optimistic) {
        final previous = lastDown.remove(key);
        if (previous != null &&
            event.at.difference(previous.at) <= doubleWindow) {
          controller.add(pattern(event, PressKind.double));
        } else {
          lastDown[key] = event;
          controller.add(pattern(event, PressKind.single));
        }
        return;
      }

      final timer = pending.remove(key);
      if (timer != null) {
        timer.cancel();
        controller.add(pattern(event, PressKind.double));
      } else {
        pending[key] = Timer(doubleWindow, () {
          pending.remove(key);
          controller.add(pattern(event, PressKind.single));
        });
      }
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
