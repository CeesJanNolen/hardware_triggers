import 'package:flutter/services.dart';
import 'package:hardware_triggers/hardware_triggers.dart';

/// One line in the live log: a raw Input Event, a recognised Press Pattern or
/// a pointer signal.
class LogLine {
  const LogLine({
    required this.at,
    required this.text,
    required this.kind,
    this.deviceKey,
  });

  final DateTime at;
  final String text;
  final LogKind kind;
  final String? deviceKey;
}

enum LogKind { down, up, pattern, pointer, info }

/// A key seen from one device, with the label and verified Press Kinds you
/// give it.
class ButtonRow {
  const ButtonRow({
    required this.key,
    required this.label,
    this.code,
    this.reliable = const {},
    this.presses = 0,
    this.longestHold,
  });

  final LogicalKeyboardKey key;
  final String label;

  /// Android key code when the event came natively.
  final int? code;
  final Set<PressKind> reliable;
  final int presses;
  final Duration? longestHold;

  ButtonRow copyWith({
    String? label,
    int? code,
    Set<PressKind>? reliable,
    int? presses,
    Duration? longestHold,
  }) => ButtonRow(
    key: key,
    label: label ?? this.label,
    code: code ?? this.code,
    reliable: reliable ?? this.reliable,
    presses: presses ?? this.presses,
    longestHold: longestHold ?? this.longestHold,
  );
}

/// Everything learned about one Trigger during this run: the device as
/// Android reports it, the entry name and notes you type, and a row per key.
class DeviceSummary {
  const DeviceSummary({
    required this.deviceKey,
    required this.device,
    required this.entryName,
    this.notes = '',
    this.buttons = const {},
    this.pointerClicks = 0,
    this.pointerScrolls = 0,
  });

  /// Groups events: the device id, or [unknownDeviceKey] for events without
  /// device info (the Flutter path, injected input).
  final String deviceKey;
  final TriggerDevice? device;
  final String entryName;
  final String notes;
  final Map<LogicalKeyboardKey, ButtonRow> buttons;
  final int pointerClicks;
  final int pointerScrolls;

  static const unknownDeviceKey = 'unknown';

  CatalogEntry? get catalogEntry =>
      device == null ? null : TriggerCatalog.lookup(device!);

  DeviceSummary copyWith({
    TriggerDevice? device,
    String? entryName,
    String? notes,
    Map<LogicalKeyboardKey, ButtonRow>? buttons,
    int? pointerClicks,
    int? pointerScrolls,
  }) => DeviceSummary(
    deviceKey: deviceKey,
    device: device ?? this.device,
    entryName: entryName ?? this.entryName,
    notes: notes ?? this.notes,
    buttons: buttons ?? this.buttons,
    pointerClicks: pointerClicks ?? this.pointerClicks,
    pointerScrolls: pointerScrolls ?? this.pointerScrolls,
  );
}

class LabState {
  const LabState({
    this.log = const [],
    this.summaries = const {},
    this.connected = const [],
    this.swallowed = const {},
    this.interceptSupported,
  });

  /// Newest first, capped.
  final List<LogLine> log;
  final Map<String, DeviceSummary> summaries;
  final List<TriggerDevice> connected;

  /// Keys under a consume rule instead of the catch-all observe rule.
  final Set<LogicalKeyboardKey> swallowed;
  final bool? interceptSupported;

  static const maxLog = 200;

  LabState copyWith({
    List<LogLine>? log,
    Map<String, DeviceSummary>? summaries,
    List<TriggerDevice>? connected,
    Set<LogicalKeyboardKey>? swallowed,
    bool? interceptSupported,
  }) => LabState(
    log: log ?? this.log,
    summaries: summaries ?? this.summaries,
    connected: connected ?? this.connected,
    swallowed: swallowed ?? this.swallowed,
    interceptSupported: interceptSupported ?? this.interceptSupported,
  );
}
