import 'package:flutter/services.dart';
import 'package:hardware_triggers/hardware_triggers.dart';

import 'lab_state.dart';

/// Dart source for a `CatalogEntry` describing [summary], ready to paste into
/// `trigger_catalog.dart`. Buttons without a verified Press Kind are included
/// with an empty Android set so the key is on record.
String catalogEntryCode(DeviceSummary summary) {
  final device = summary.device;
  final field = _fieldName(summary.entryName);
  final buttons = summary.buttons.values.toList()
    ..sort((a, b) => a.label.compareTo(b.label));
  final notes = [
    if (summary.notes.trim().isNotEmpty) summary.notes.trim(),
    if (summary.pointerClicks > 0 || summary.pointerScrolls > 0)
      'Also sends pointer input (${summary.pointerClicks} clicks, '
          '${summary.pointerScrolls} scrolls seen), which the package '
          'does not report.',
  ].join(' ');

  final b = StringBuffer()
    ..writeln('  /// "${summary.entryName}": verified with Trigger Lab.')
    ..writeln('  static final $field = CatalogEntry(')
    ..writeln("    name: ${_string(device?.name ?? summary.entryName)},");
  if (device != null && device.hasIdentity) {
    b
      ..writeln('    vendorId: ${_hex(device.vendorId!)},')
      ..writeln('    productId: ${_hex(device.productId!)},');
  }
  b.writeln('    buttons: [');
  for (final row in buttons) {
    final kinds = row.reliable.isEmpty
        ? '{}'
        : '{${(PressKind.values.where(row.reliable.contains)).map((k) => 'PressKind.${k.name}').join(', ')}}';
    b
      ..writeln('      CatalogButton(')
      ..writeln('        label: ${_string(row.label)},')
      ..writeln('        key: ${keyExpression(row.key)},')
      ..writeln('        reliable: const {TargetPlatform.android: $kinds},')
      ..writeln('      ),');
  }
  b.writeln('    ],');
  if (notes.isNotEmpty) b.writeln('    notes: ${_string(notes)},');
  b.write('  );');
  return b.toString();
}

/// `LogicalKeyboardKey.arrowUp` for a key Flutter names, the raw constructor
/// with its Android code for one it does not.
String keyExpression(LogicalKeyboardKey key) {
  final name = key.debugName;
  if (name != null && !name.startsWith('Key with ID')) {
    return 'LogicalKeyboardKey.${_lowerCamel(name)}';
  }
  final code = key.keyId - LogicalKeyboardKey.androidPlane;
  final comment = code >= 0 && code < 0x10000 ? ' /* Android key $code */' : '';
  return 'LogicalKeyboardKey(${_hex(key.keyId)})$comment';
}

String _lowerCamel(String words) {
  final parts = words
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'unknown';
  final first = parts.first;
  final head = first.length > 1 && first == first.toUpperCase()
      ? first.toLowerCase()
      : first[0].toLowerCase() + first.substring(1);
  final tail = parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1));
  final name = head + tail.join();
  return RegExp(r'^[0-9]').hasMatch(name) ? 'digit$name' : name;
}

String _fieldName(String entryName) {
  final camel = _lowerCamel(entryName);
  return camel == 'unknown' ? 'newEntry' : camel;
}

String _hex(int value) => '0x${value.toRadixString(16).padLeft(4, '0')}';

String _string(String value) =>
    "'${value.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll('\n', ' ')}'";
