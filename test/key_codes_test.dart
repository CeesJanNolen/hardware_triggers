import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_triggers/hardware_triggers.dart';

void main() {
  test('Android volume and enter codes map to logical keys', () {
    expect(logicalKeyFromCode(24), LogicalKeyboardKey.audioVolumeUp);
    expect(logicalKeyFromCode(25), LogicalKeyboardKey.audioVolumeDown);
    expect(logicalKeyFromCode(66), LogicalKeyboardKey.enter);
    expect(logicalKeyFromCode(-1), isNull);
  });

  test('logical keys map back to every Android code they have', () {
    expect(codesForLogicalKey(LogicalKeyboardKey.audioVolumeUp), [24]);
    expect(codesForLogicalKey(LogicalKeyboardKey.enter), contains(66));
  });
}
