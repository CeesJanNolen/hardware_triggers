import 'package:flutter/services.dart';

/// A physical device that produces Input Events: a Bluetooth shutter button,
/// a keyboard-mode remote, or the device's own volume rocker.
class TriggerDevice {
  const TriggerDevice({required this.id, required this.name, this.isExternal});

  final int id;
  final String name;

  /// Whether the OS reports the device as external (Bluetooth, USB). Null when
  /// the platform cannot tell, which is the case on iOS.
  final bool? isExternal;

  @override
  bool operator ==(Object other) =>
      other is TriggerDevice &&
      other.id == id &&
      other.name == name &&
      other.isExternal == isExternal;

  @override
  int get hashCode => Object.hash(id, name, isExternal);

  @override
  String toString() => 'TriggerDevice($id, $name, external: $isExternal)';
}

enum KeyPhase { down, up }

/// Where an Input Event came from.
enum InputSource {
  /// Intercepted by the native side before Flutter saw it.
  native,

  /// An ordinary Flutter hardware key event.
  flutter,
}

/// A raw key signal with no meaning attached.
class InputEvent {
  const InputEvent({
    required this.key,
    required this.phase,
    required this.at,
    required this.source,
    this.device,
  });

  final LogicalKeyboardKey key;
  final KeyPhase phase;
  final DateTime at;
  final InputSource source;

  /// Null when the platform does not report the device.
  final TriggerDevice? device;

  @override
  bool operator ==(Object other) =>
      other is InputEvent &&
      other.key == key &&
      other.phase == phase &&
      other.at == at &&
      other.source == source &&
      other.device == device;

  @override
  int get hashCode => Object.hash(key, phase, at, source, device);

  @override
  String toString() =>
      'InputEvent(${key.debugName}, $phase, $at, $source, $device)';
}
