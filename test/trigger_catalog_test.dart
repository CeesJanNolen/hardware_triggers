import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_triggers/hardware_triggers.dart';

void main() {
  test('the AB Shutter3 is found by its reported name', () {
    const shutter = TriggerDevice(id: 7, name: 'AB Shutter3', isExternal: true);
    final entry = TriggerCatalog.lookup(shutter);
    expect(entry, same(TriggerCatalog.abShutter3));
    expect(entry!.buttons.single.key, LogicalKeyboardKey.audioVolumeUp);
    expect(entry.buttons.single.reliableKinds, PressKind.values.toSet());
  });

  test('name matching ignores case and padding', () {
    const padded = TriggerDevice(id: 7, name: ' ab shutter3 ', isExternal: true);
    expect(TriggerCatalog.lookup(padded), isNotNull);
  });

  test('an unknown device has no entry', () {
    const rocker = TriggerDevice(id: 0, name: 'gpio-keys', isExternal: false);
    expect(TriggerCatalog.lookup(rocker), isNull);
  });
}
