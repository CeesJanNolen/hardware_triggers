import 'package:flutter/services.dart';

/// Android key codes are the wire format between the native sides and Dart on
/// every platform. Flutter ships the Android table, so no second table exists.
LogicalKeyboardKey? logicalKeyFromCode(int code) => kAndroidToLogicalKey[code];

/// All Android key codes that map to [key]. Usually one, sometimes several.
List<int> codesForLogicalKey(LogicalKeyboardKey key) => [
  for (final entry in kAndroidToLogicalKey.entries)
    if (entry.value == key) entry.key,
];
