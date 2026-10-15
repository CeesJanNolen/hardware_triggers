import 'package:flutter/services.dart';

/// What the native side does with an intercepted key.
enum InterceptPolicy {
  /// Report the press and swallow the key. The system never acts on it, so a
  /// volume key does not change the volume.
  consume,

  /// Report the press and let the system act on it as usual.
  observe,
}

/// One key the native side should intercept while interception is active.
class InterceptRule {
  const InterceptRule(
    this.key, {
    this.policy = InterceptPolicy.consume,
    this.externalOnly = false,
  });

  final LogicalKeyboardKey key;
  final InterceptPolicy policy;

  /// Only intercept presses from external devices (Bluetooth, USB). The
  /// device's own buttons keep their normal behaviour. Matches nothing on
  /// platforms that cannot tell devices apart.
  final bool externalOnly;

  @override
  bool operator ==(Object other) =>
      other is InterceptRule &&
      other.key == key &&
      other.policy == policy &&
      other.externalOnly == externalOnly;

  @override
  int get hashCode => Object.hash(key, policy, externalOnly);
}
