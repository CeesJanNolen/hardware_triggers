import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_triggers/hardware_triggers.dart';

void main() {
  test('the AB Shutter3 is found by its reported name', () {
    const shutter = TriggerDevice(id: 7, name: 'AB Shutter3', isExternal: true);
    final entry = TriggerCatalog.lookup(shutter);
    expect(entry, same(TriggerCatalog.abShutter3));
    expect(entry!.buttons.single.key, LogicalKeyboardKey.audioVolumeUp);
    final button = entry.buttons.single;
    expect(button.reliableOn(TargetPlatform.android), PressKind.values.toSet());
    expect(button.reliableOn(TargetPlatform.iOS), isEmpty);
  });

  test('name matching ignores case and padding', () {
    const padded = TriggerDevice(
      id: 7,
      name: ' ab shutter3 ',
      isExternal: true,
    );
    expect(TriggerCatalog.lookup(padded), isNotNull);
  });

  test('an unknown device has no entry', () {
    const rocker = TriggerDevice(id: 0, name: 'gpio-keys', isExternal: false);
    expect(TriggerCatalog.lookup(rocker), isNull);
  });

  group('Trigger Identity', () {
    final white = CatalogEntry(
      name: 'N16500',
      vendorId: 0x1111,
      productId: 0x0001,
      buttons: const [],
    );
    final black = CatalogEntry(
      name: 'N16500',
      vendorId: 0x2222,
      productId: 0x0002,
      buttons: const [],
    );

    test('two entries with the same name are told apart by their ids', () {
      const device = TriggerDevice(
        id: 9,
        name: 'N16500',
        isExternal: true,
        vendorId: 0x2222,
        productId: 0x0002,
      );
      expect(white.matches(device), isFalse);
      expect(black.matches(device), isTrue);
    });

    test('a device without ids falls back to the name', () {
      const device = TriggerDevice(id: 9, name: 'n16500', isExternal: true);
      expect(white.matches(device), isTrue);
      expect(black.matches(device), isTrue);
    });

    test('an entry without ids matches by name whatever the device has', () {
      const device = TriggerDevice(
        id: 9,
        name: 'AB Shutter3',
        isExternal: true,
        vendorId: 0x1234,
        productId: 0x5678,
      );
      expect(TriggerCatalog.abShutter3.matches(device), isTrue);
    });
  });
}
