/// Physical key Triggers as a stream of Input Events, Press Patterns and
/// app-defined actions. Import `package:hardware_triggers/riverpod.dart` for
/// ready-made providers.
library;

export 'src/binding.dart';
export 'src/hardware_triggers.dart';
export 'src/input_event.dart';
export 'src/intercept_rule.dart';
export 'src/key_codes.dart';
export 'src/platform_interface.dart'
    show
        HardwareTriggersPlatform,
        MethodChannelHardwareTriggers,
        NativeKeyEvent,
        anyKeyCode;
export 'src/press_pattern.dart';
export 'src/trigger_catalog.dart';
