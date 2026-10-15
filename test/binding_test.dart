import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_triggers/hardware_triggers.dart';

enum ScoreAction { pointLeft, pointRight, undo }

const up = LogicalKeyboardKey.audioVolumeUp;
const down = LogicalKeyboardKey.audioVolumeDown;
final t0 = DateTime(2026, 10, 15, 19);

PressPattern pattern(LogicalKeyboardKey key, PressKind kind) =>
    PressPattern(key: key, kind: kind, at: t0);

void main() {
  final binding = Binding<ScoreAction>({
    PressSpec.single(up): ScoreAction.pointLeft,
    PressSpec.double(up): ScoreAction.pointRight,
    PressSpec.single(down): ScoreAction.pointRight,
  });

  test('looks up by key and kind', () {
    expect(
      binding.lookup(pattern(up, PressKind.single)),
      ScoreAction.pointLeft,
    );
    expect(
      binding.lookup(pattern(up, PressKind.double)),
      ScoreAction.pointRight,
    );
    expect(binding.lookup(pattern(down, PressKind.double)), isNull);
  });

  test('bind maps a stream and drops unbound patterns', () async {
    final actions = await binding
        .bind(
          Stream.fromIterable([
            pattern(up, PressKind.single),
            pattern(down, PressKind.double),
            pattern(down, PressKind.single),
          ]),
        )
        .toList();
    expect(actions, [ScoreAction.pointLeft, ScoreAction.pointRight]);
  });

  test('copyWith overrides and keeps the rest', () {
    final changed = binding.copyWith({
      PressSpec.double(down): ScoreAction.undo,
    });
    expect(changed.lookup(pattern(down, PressKind.double)), ScoreAction.undo);
    expect(
      changed.lookup(pattern(up, PressKind.single)),
      ScoreAction.pointLeft,
    );
  });
}
