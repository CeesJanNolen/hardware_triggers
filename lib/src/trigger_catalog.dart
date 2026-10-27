import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'input_event.dart';
import 'press_pattern.dart';

/// One physical button on a catalogued Trigger and what it sends.
class CatalogButton {
  const CatalogButton({
    required this.label,
    required this.key,
    required this.reliable,
  });

  /// How the button is referred to in the app ("the button", "iOS side").
  final String label;

  /// The key the button sends, as the app sees it.
  final LogicalKeyboardKey key;

  /// Per platform, the Press Kinds verified to be recognised reliably on
  /// this button. A platform that is missing has not been verified.
  final Map<TargetPlatform, Set<PressKind>> reliable;

  Set<PressKind> reliableOn(TargetPlatform platform) =>
      reliable[platform] ?? const {};

  /// Reliable Press Kinds on the platform the app runs on.
  Set<PressKind> get reliableKinds => reliableOn(defaultTargetPlatform);
}

/// A Trigger that was verified against this package. Apps show the catalog
/// in their settings so users know which accessories are supported; any other
/// device may or may not work depending on what it sends.
class CatalogEntry {
  const CatalogEntry({
    required this.name,
    required this.buttons,
    this.notes = '',
  });

  /// The name the device reports when paired, matched case-insensitively.
  final String name;
  final List<CatalogButton> buttons;

  /// Free text for the app's settings screen: quirks, pairing hints.
  final String notes;

  /// Whether [device] is this catalogued Trigger.
  bool matches(TriggerDevice device) =>
      device.name.trim().toLowerCase() == name.toLowerCase();
}

/// The Triggers verified against this package.
class TriggerCatalog {
  const TriggerCatalog._();

  /// "AB Shutter3": the common Bluetooth camera shutter. One button, pairs
  /// as a keyboard and sends Volume Up, and keeps the key down while held.
  /// Verified on Android 14 and 17: single, double and triple presses about
  /// 160 ms apart, and holds of two to three seconds. Verified on iOS 27
  /// the same way, presses about 180 ms apart, though there it cannot be told
  /// from the phone's own volume-up button.
  static final abShutter3 = CatalogEntry(
    name: 'AB Shutter3',
    buttons: [
      CatalogButton(
        label: 'button',
        key: LogicalKeyboardKey.audioVolumeUp,
        reliable: const {
          TargetPlatform.android: {
            PressKind.single,
            PressKind.double,
            PressKind.triple,
            PressKind.long,
          },
          TargetPlatform.iOS: {
            PressKind.single,
            PressKind.double,
            PressKind.triple,
            PressKind.long,
          },
        },
      ),
    ],
    notes:
        'Pairs as a keyboard. Needs Android 10 or newer to be told apart '
        'from the volume rocker of the phone or tablet; on iOS it cannot be.',
  );

  static final List<CatalogEntry> entries = List.unmodifiable([abShutter3]);

  /// The catalog entry for [device], or null for an unknown Trigger.
  static CatalogEntry? lookup(TriggerDevice device) {
    for (final entry in entries) {
      if (entry.matches(device)) return entry;
    }
    return null;
  }
}
