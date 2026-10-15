/// Riverpod 3 providers over the core library. Override
/// [pressPatternRecognizerProvider] to change the double-press window or mode.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'hardware_triggers.dart';

final hardwareTriggersProvider = Provider<HardwareTriggers>(
  (ref) => HardwareTriggers.instance,
);

final inputEventsProvider = StreamProvider<InputEvent>(
  (ref) => ref.watch(hardwareTriggersProvider).events,
);

final pressPatternRecognizerProvider = Provider<PressPatternRecognizer>(
  (ref) => const PressPatternRecognizer(),
);

final pressPatternsProvider = StreamProvider<PressPattern>(
  (ref) => ref
      .watch(hardwareTriggersProvider)
      .events
      .transform(ref.watch(pressPatternRecognizerProvider)),
);

/// Intercepts [rules] for as long as something watches this provider, and
/// stops when the last watcher goes away. Watch it from the screen that needs
/// the keys.
final interceptProvider = Provider.autoDispose
    .family<void, List<InterceptRule>>((ref, rules) {
      final triggers = ref.watch(hardwareTriggersProvider);
      triggers.startIntercepting(rules);
      ref.onDispose(triggers.stopIntercepting);
    });
