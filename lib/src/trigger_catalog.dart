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
    this.vendorId,
    this.productId,
    this.notes = '',
  });

  /// The name the device reports when paired, matched case-insensitively.
  final String name;
  final List<CatalogButton> buttons;

  /// The Trigger Identity, when known. Two devices pairing under the same
  /// name are told apart by it; see [matches].
  final int? vendorId;
  final int? productId;

  /// Free text for the app's settings screen: quirks, pairing hints, which
  /// mode of the remote the entry describes, buttons no app can see.
  final String notes;

  bool get hasIdentity => vendorId != null && productId != null;

  /// Whether [device] is this catalogued Trigger. When both the entry and the
  /// device carry a Trigger Identity, the ids decide; otherwise the name does.
  bool matches(TriggerDevice device) {
    if (hasIdentity && device.hasIdentity) {
      return device.vendorId == vendorId && device.productId == productId;
    }
    return device.name.trim().toLowerCase() == name.toLowerCase();
  }
}

/// The Triggers verified against this package.
class TriggerCatalog {
  const TriggerCatalog._();

  /// "AB Shutter3": the common Bluetooth camera shutter. One button, pairs
  /// as a keyboard and sends Volume Up, and keeps the key down while held.
  /// Verified on Android 14 and 17: single, double and triple presses about
  /// 160 ms apart, and holds of two to three seconds. Not yet verified on
  /// iOS, where the package itself is unverified.
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
        },
      ),
    ],
    notes:
        'Pairs as a keyboard. Needs Android 10 or newer to be told apart '
        'from the volume rocker of the phone or tablet.',
  );

  /// "Beauty-R1": a TikTok-style ring remote with up, down, left, right,
  /// ok, camera and a side button. Verified with Trigger Lab on Android 14
  /// (Galaxy Tab A8). Only the camera button is a key, and it alternates:
  /// one press sends Volume Down, the next Volume Up. The other buttons act
  /// as a stylus touching the screen at fixed spots and never reach the
  /// package.
  static final beautyR1 = CatalogEntry(
    name: 'Beauty-R1',
    vendorId: 0x0e05,
    productId: 0x0a00,
    buttons: [
      CatalogButton(
        label: 'camera',
        key: LogicalKeyboardKey.audioVolumeDown,
        reliable: const {
          TargetPlatform.android: {PressKind.single},
        },
      ),
      CatalogButton(
        label: 'camera (every other press)',
        key: LogicalKeyboardKey.audioVolumeUp,
        reliable: const {
          TargetPlatform.android: {PressKind.single},
        },
      ),
    ],
    notes:
        'Pairs as a keyboard plus a stylus. The camera button alternates '
        'between Volume Down and Volume Up on successive presses, so bind '
        'both keys to the same Action. A double press arrives as one press '
        'of each key and a hold is a short press: only single presses are '
        'usable. Up, left, right, ok and the side button act as a stylus on '
        'the screen (swipe down, swipe right, swipe left, tap, tap at '
        'another spot), not as keys. Down is a swipe up from the bottom '
        'edge, which Android gesture navigation takes for itself.',
  );

  static final List<CatalogEntry> entries = List.unmodifiable([
    abShutter3,
    beautyR1,
  ]);

  /// The catalog entry for [device], or null for an unknown Trigger.
  static CatalogEntry? lookup(TriggerDevice device) {
    for (final entry in entries) {
      if (entry.matches(device)) return entry;
    }
    return null;
  }
}
