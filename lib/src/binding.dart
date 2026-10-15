import 'package:flutter/services.dart';

import 'press_pattern.dart';

/// A key plus the kind of press, the thing a Binding keys on.
class PressSpec {
  const PressSpec(this.key, this.kind);

  const PressSpec.single(LogicalKeyboardKey key) : this(key, PressKind.single);

  const PressSpec.double(LogicalKeyboardKey key) : this(key, PressKind.double);

  const PressSpec.triple(LogicalKeyboardKey key) : this(key, PressKind.triple);

  final LogicalKeyboardKey key;
  final PressKind kind;

  @override
  bool operator ==(Object other) =>
      other is PressSpec && other.key == key && other.kind == kind;

  @override
  int get hashCode => Object.hash(key, kind);

  @override
  String toString() => 'PressSpec(${key.debugName}, $kind)';
}

/// Maps Press Patterns to an app-defined action type [A].
///
/// ```dart
/// final binding = Binding<ScoreAction>({
///   PressSpec.single(LogicalKeyboardKey.audioVolumeUp): ScoreAction.pointLeft,
///   PressSpec.double(LogicalKeyboardKey.audioVolumeUp): ScoreAction.pointRight,
/// });
/// binding.bind(patterns).listen(dispatch);
/// ```
class Binding<A> {
  const Binding(this._actions);

  final Map<PressSpec, A> _actions;

  Map<PressSpec, A> get actions => Map.unmodifiable(_actions);

  A? lookup(PressPattern pattern) =>
      _actions[PressSpec(pattern.key, pattern.kind)];

  /// Patterns with no action bound are dropped.
  Stream<A> bind(Stream<PressPattern> patterns) =>
      patterns.map(lookup).where((action) => action != null).cast<A>();

  Binding<A> copyWith(Map<PressSpec, A> overrides) =>
      Binding({..._actions, ...overrides});
}
