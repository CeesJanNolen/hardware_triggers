import 'package:flutter/services.dart';

/// A physical device that produces Input Events: a Bluetooth shutter button,
/// a keyboard-mode remote, or the device's own volume rocker.
class TriggerDevice {
  const TriggerDevice({
    required this.id,
    required this.name,
    this.isExternal,
    this.vendorId,
    this.productId,
  });

  /// The OS's id for the device, stable only while it stays connected.
  final int id;
  final String name;

  /// Whether the OS reports the device as external (Bluetooth, USB). Null when
  /// the platform cannot tell, which is the case on iOS.
  final bool? isExternal;

  /// USB-style vendor and product ids, the Trigger Identity: two devices that
  /// pair under the same name are told apart by these. Null when the platform
  /// does not report them (iOS) or the device has none (Android reports 0,
  /// which is kept as 0).
  final int? vendorId;
  final int? productId;

  bool get hasIdentity => vendorId != null && productId != null;

  @override
  bool operator ==(Object other) =>
      other is TriggerDevice &&
      other.id == id &&
      other.name == name &&
      other.isExternal == isExternal &&
      other.vendorId == vendorId &&
      other.productId == productId;

  @override
  int get hashCode => Object.hash(id, name, isExternal, vendorId, productId);

  @override
  String toString() =>
      'TriggerDevice($id, $name, external: $isExternal, '
      'vendor: $vendorId, product: $productId)';
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
    this.code,
  });

  /// The key as Flutter names it. A code Flutter has no name for becomes a
  /// key in Flutter's Android plane, so it still flows and can be bound.
  final LogicalKeyboardKey key;
  final KeyPhase phase;
  final DateTime at;
  final InputSource source;

  /// Null when the platform does not report the device.
  final TriggerDevice? device;

  /// The Android key code the native side sent. Null on the Flutter path.
  final int? code;

  @override
  bool operator ==(Object other) =>
      other is InputEvent &&
      other.key == key &&
      other.phase == phase &&
      other.at == at &&
      other.source == source &&
      other.device == device &&
      other.code == code;

  @override
  int get hashCode => Object.hash(key, phase, at, source, device, code);

  @override
  String toString() =>
      'InputEvent(${key.debugName}, $phase, $at, $source, $device, code: $code)';
}
