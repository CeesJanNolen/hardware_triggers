import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_triggers/hardware_triggers.dart';
import 'package:hardware_triggers/riverpod.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:trigger_lab/catalog_entry_code.dart';
import 'package:trigger_lab/lab_provider.dart';
import 'package:trigger_lab/lab_state.dart';
import 'package:trigger_lab/main.dart';

class FakePlatform extends HardwareTriggersPlatform
    with MockPlatformInterfaceMixin {
  final native = StreamController<NativeKeyEvent>.broadcast();
  List<InterceptRule>? started;

  @override
  Stream<NativeKeyEvent> get keyEvents => native.stream;

  @override
  Future<void> startIntercepting(List<InterceptRule> rules) async =>
      started = rules;

  @override
  Future<void> stopIntercepting() async {}

  @override
  Future<bool> isInterceptSupported() async => true;

  @override
  Future<List<TriggerDevice>> connectedDevices() async => const [
    TriggerDevice(
      id: 5,
      name: 'N16500',
      isExternal: true,
      vendorId: 0x1234,
      productId: 0x0002,
    ),
  ];
}

NativeKeyEvent native(int code, String phase, int at) =>
    NativeKeyEvent.fromMap({
      'code': code,
      'phase': phase,
      'timestamp': at,
      'deviceId': 5,
      'deviceName': 'N16500',
      'isExternal': true,
      'vendorId': 0x1234,
      'productId': 0x0002,
    });

void main() {
  late FakePlatform platform;

  setUp(() => platform = FakePlatform());

  Widget app() => ProviderScope(
    overrides: [
      hardwareTriggersProvider.overrideWithValue(
        HardwareTriggers(platform: platform),
      ),
    ],
    child: const TriggerLabApp(),
  );

  testWidgets('starts with a catch-all observe rule', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    expect(platform.started, const [InterceptRule.any()]);
    expect(find.text('N16500 #5 1234:2'), findsOneWidget);
  });

  testWidgets('a press builds a button row for its device', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    platform.native.add(native(19, 'down', 1000)); // DPAD_UP
    await tester.pump();
    platform.native.add(native(19, 'up', 1120));
    await tester.pump();

    expect(find.textContaining('↓ Arrow Up (code 19)'), findsOneWidget);
    expect(find.textContaining('↑ Arrow Up (code 19) after 120 ms'), findsOneWidget);
    expect(find.textContaining('⇒ single Arrow Up'), findsOneWidget);
    expect(find.byKey(const ValueKey('summary-5')), findsOneWidget);
    expect(find.textContaining('1 press, longest hold 120 ms'), findsOneWidget);
  });

  testWidgets('swallowing a key adds a consume rule before the catch-all', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump();
    platform.native.add(native(24, 'down', 1000));
    platform.native.add(native(24, 'up', 1050));
    await tester.pump();
    await tester.pump();
    await tester.ensureVisible(find.byType(Switch).first);
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(platform.started, const [
      InterceptRule(LogicalKeyboardKey.audioVolumeUp),
      InterceptRule.any(),
    ]);
  });

  group('catalog entry code', () {
    test('known key, identity, ticked kinds and notes', () {
      final summary = DeviceSummary(
        deviceKey: '5',
        device: const TriggerDevice(
          id: 5,
          name: 'N16500',
          isExternal: true,
          vendorId: 0x1234,
          productId: 0x0002,
        ),
        entryName: 'Yggcoo N16500 white',
        notes: 'Android mode.',
        buttons: {
          LogicalKeyboardKey.arrowUp: const ButtonRow(
            key: LogicalKeyboardKey.arrowUp,
            label: 'up',
            code: 19,
            reliable: {PressKind.single, PressKind.long},
          ),
          LogicalKeyboardKey.audioVolumeUp: const ButtonRow(
            key: LogicalKeyboardKey.audioVolumeUp,
            label: 'camera',
            code: 24,
          ),
        },
      );
      expect(catalogEntryCode(summary), '''
  /// "Yggcoo N16500 white": verified with Trigger Lab.
  static final yggcooN16500White = CatalogEntry(
    name: 'N16500',
    vendorId: 0x1234,
    productId: 0x0002,
    buttons: [
      CatalogButton(
        label: 'camera',
        key: LogicalKeyboardKey.audioVolumeUp,
        reliable: const {TargetPlatform.android: {}},
      ),
      CatalogButton(
        label: 'up',
        key: LogicalKeyboardKey.arrowUp,
        reliable: const {TargetPlatform.android: {PressKind.single, PressKind.long}},
      ),
    ],
    notes: 'Android mode.',
  );''');
    });

    test('an unnamed key is written with its Android code', () {
      final key = LogicalKeyboardKey(LogicalKeyboardKey.androidPlane + 999);
      expect(
        keyExpression(key),
        'LogicalKeyboardKey(0x11000003e7) /* Android key 999 */',
      );
      expect(keyName(key), 'Android key 999');
    });

    test('named keys map to their Flutter constants', () {
      expect(keyExpression(LogicalKeyboardKey.mediaPlayPause),
          'LogicalKeyboardKey.mediaPlayPause');
      expect(keyExpression(LogicalKeyboardKey.enter), 'LogicalKeyboardKey.enter');
      expect(keyExpression(LogicalKeyboardKey.digit1), 'LogicalKeyboardKey.digit1');
    });
  });
}
