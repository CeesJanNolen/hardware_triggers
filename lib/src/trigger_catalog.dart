import 'package:flutter/services.dart';

import 'input_event.dart';
import 'press_pattern.dart';

/// One physical button on a catalogued Trigger and what it sends.
class CatalogButton {
  const CatalogButton({
    required this.label,
    required this.key,
    this.reliableKinds = const {PressKind.single},
  });

  /// How the button is referred to in the app ("the button", "iOS side").
  final String label;

  /// The key the button sends, as the app sees it.
  final LogicalKeyboardKey key;

  /// Press Kinds that were verified to be recognised reliably on this button.
  final Set<PressKind> reliableKinds;
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
  /// as a keyboard and sends Volume Up. Verified on Android 14 and 17 with
  /// single, double and triple presses about 160 ms apart.
  static final abShutter3 = CatalogEntry(
    name: 'AB Shutter3',
    buttons: [
      CatalogButton(
        label: 'button',
        key: LogicalKeyboardKey.audioVolumeUp,
        reliableKinds: const {
          PressKind.single,
          PressKind.double,
          PressKind.triple,
        },
      ),
    ],
    notes: 'Pairs as a keyboard. Needs Android 10 or newer to be told apart '
        'from the volume rocker of the phone or tablet.',
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
