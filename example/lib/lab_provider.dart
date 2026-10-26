import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hardware_triggers/hardware_triggers.dart';
import 'package:hardware_triggers/riverpod.dart';

import 'lab_state.dart';

/// Holds everything the lab learns in one run. Keeps a catch-all observe rule
/// active for its whole life, with a consume rule on top for each swallowed
/// key, and folds Input Events, Press Patterns and pointer signals into the
/// log and the per-device summaries.
class LabNotifier extends Notifier<LabState> {
  final _lastDown = <String, DateTime>{};

  @override
  LabState build() {
    final triggers = ref.watch(hardwareTriggersProvider);
    final events = triggers.events.listen(onInputEvent);
    final patterns = triggers.events
        .transform(ref.watch(pressPatternRecognizerProvider))
        .listen(onPattern);
    ref.onDispose(() {
      events.cancel();
      patterns.cancel();
      triggers.stopIntercepting();
    });
    _applyRules(const {});
    unawaited(_probe());
    return const LabState();
  }

  Future<void> _probe() async {
    final triggers = ref.read(hardwareTriggersProvider);
    final supported = await triggers.isInterceptSupported();
    state = state.copyWith(interceptSupported: supported);
    await refreshConnected();
  }

  Future<void> refreshConnected() async {
    final devices = await ref.read(hardwareTriggersProvider).connectedDevices();
    state = state.copyWith(connected: devices);
  }

  Future<void> _applyRules(Set<LogicalKeyboardKey> swallowed) =>
      ref.read(hardwareTriggersProvider).startIntercepting([
        for (final key in swallowed)
          InterceptRule(key, policy: InterceptPolicy.consume),
        const InterceptRule.any(),
      ]);

  // Input

  void onInputEvent(InputEvent event) {
    final deviceKey = _deviceKey(event.device);
    final summary = _summaryFor(deviceKey, event.device);
    final row =
        summary.buttons[event.key] ??
        ButtonRow(key: event.key, label: _defaultLabel(event.key), code: event.code);
    final holdKey = '$deviceKey/${event.key.keyId}';

    ButtonRow updated;
    String detail;
    if (event.phase == KeyPhase.down) {
      _lastDown[holdKey] = event.at;
      updated = row.copyWith(presses: row.presses + 1, code: event.code);
      detail = '';
    } else {
      final down = _lastDown.remove(holdKey);
      final held = down == null ? null : event.at.difference(down);
      final longest = held != null &&
              (row.longestHold == null || held > row.longestHold!)
          ? held
          : row.longestHold;
      updated = row.copyWith(longestHold: longest, code: event.code);
      detail = held == null ? '' : ' after ${held.inMilliseconds} ms';
    }

    _put(summary.copyWith(buttons: {...summary.buttons, event.key: updated}));
    _add(
      LogLine(
        at: event.at,
        kind: event.phase == KeyPhase.down ? LogKind.down : LogKind.up,
        deviceKey: deviceKey,
        text:
            '${event.phase == KeyPhase.down ? '↓' : '↑'} ${keyName(event.key)}'
            '${event.code == null ? '' : ' (code ${event.code})'}$detail'
            ' · ${_deviceLabel(event.device)} · ${event.source.name}',
      ),
    );
    if (event.device != null &&
        !state.connected.any((d) => d.id == event.device!.id)) {
      unawaited(refreshConnected());
    }
  }

  void onPattern(PressPattern pattern) => _add(
    LogLine(
      at: pattern.at,
      kind: LogKind.pattern,
      deviceKey: _deviceKey(pattern.device),
      text: '⇒ ${pattern.kind.name} ${keyName(pattern.key)}',
    ),
  );

  /// Mouse-style pointer signals from the whole screen. Touches are the user
  /// working the lab itself and are not logged.
  void onPointer(PointerEvent event) {
    if (event.kind == PointerDeviceKind.touch) return;
    final summary = _summaryFor(DeviceSummary.unknownDeviceKey, null);
    if (event is PointerDownEvent) {
      _put(summary.copyWith(pointerClicks: summary.pointerClicks + 1));
      _add(
        LogLine(
          at: DateTime.now(),
          kind: LogKind.pointer,
          deviceKey: DeviceSummary.unknownDeviceKey,
          text:
              '● pointer down, ${event.kind.name}, buttons ${event.buttons}'
              ' (device ${event.device})',
        ),
      );
    } else if (event is PointerUpEvent) {
      _add(
        LogLine(
          at: DateTime.now(),
          kind: LogKind.pointer,
          deviceKey: DeviceSummary.unknownDeviceKey,
          text: '○ pointer up, ${event.kind.name}',
        ),
      );
    } else if (event is PointerScrollEvent) {
      _put(summary.copyWith(pointerScrolls: summary.pointerScrolls + 1));
      _add(
        LogLine(
          at: DateTime.now(),
          kind: LogKind.pointer,
          deviceKey: DeviceSummary.unknownDeviceKey,
          text:
              '↕ scroll ${event.scrollDelta.dy.toStringAsFixed(0)}'
              ' (device ${event.device})',
        ),
      );
    }
  }

  // Editing

  void setEntryName(String deviceKey, String name) {
    final summary = state.summaries[deviceKey];
    if (summary != null) _put(summary.copyWith(entryName: name));
  }

  void setNotes(String deviceKey, String notes) {
    final summary = state.summaries[deviceKey];
    if (summary != null) _put(summary.copyWith(notes: notes));
  }

  void setLabel(String deviceKey, LogicalKeyboardKey key, String label) {
    _updateRow(deviceKey, key, (row) => row.copyWith(label: label));
  }

  void setReliable(
    String deviceKey,
    LogicalKeyboardKey key,
    PressKind kind,
    bool reliable,
  ) {
    _updateRow(deviceKey, key, (row) {
      final kinds = {...row.reliable};
      reliable ? kinds.add(kind) : kinds.remove(kind);
      return row.copyWith(reliable: kinds);
    });
  }

  void setSwallowed(LogicalKeyboardKey key, bool swallow) {
    final keys = {...state.swallowed};
    swallow ? keys.add(key) : keys.remove(key);
    state = state.copyWith(swallowed: keys);
    unawaited(_applyRules(keys));
    _add(
      LogLine(
        at: DateTime.now(),
        kind: LogKind.info,
        text: swallow
            ? '${keyName(key)} is now swallowed (consume)'
            : '${keyName(key)} is passed on again (observe)',
      ),
    );
  }

  void clear() {
    _lastDown.clear();
    state = state.copyWith(log: const [], summaries: const {});
  }

  // Helpers

  void _updateRow(
    String deviceKey,
    LogicalKeyboardKey key,
    ButtonRow Function(ButtonRow) change,
  ) {
    final summary = state.summaries[deviceKey];
    final row = summary?.buttons[key];
    if (summary == null || row == null) return;
    _put(summary.copyWith(buttons: {...summary.buttons, key: change(row)}));
  }

  DeviceSummary _summaryFor(String deviceKey, TriggerDevice? device) =>
      state.summaries[deviceKey] ??
      DeviceSummary(
        deviceKey: deviceKey,
        device: device,
        entryName: device?.name.trim().isNotEmpty == true
            ? device!.name.trim()
            : 'Unknown source',
      );

  void _put(DeviceSummary summary) => state = state.copyWith(
    summaries: {...state.summaries, summary.deviceKey: summary},
  );

  void _add(LogLine line) {
    final log = [line, ...state.log];
    if (log.length > LabState.maxLog) log.removeRange(LabState.maxLog, log.length);
    state = state.copyWith(log: log);
  }

  static String _deviceKey(TriggerDevice? device) =>
      device == null ? DeviceSummary.unknownDeviceKey : '${device.id}';

  static String _deviceLabel(TriggerDevice? device) {
    if (device == null) return 'no device info';
    final ext = switch (device.isExternal) {
      true => 'external',
      false => 'built-in',
      null => 'external?',
    };
    return '${device.name} #${device.id} $ext';
  }

  static String _defaultLabel(LogicalKeyboardKey key) =>
      keyName(key).toLowerCase();
}

/// Flutter's name for a key, or its Android code for keys Flutter has no
/// name for.
String keyName(LogicalKeyboardKey key) {
  final name = key.debugName;
  if (name != null && !name.startsWith('Key with ID')) return name;
  final code = key.keyId - LogicalKeyboardKey.androidPlane;
  return code >= 0 && code < 0x10000
      ? 'Android key $code'
      : 'Key 0x${key.keyId.toRadixString(16)}';
}

final labProvider = NotifierProvider<LabNotifier, LabState>(LabNotifier.new);
