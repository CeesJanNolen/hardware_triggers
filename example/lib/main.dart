import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lab_screen.dart';

void main() => runApp(const ProviderScope(child: TriggerLabApp()));

class TriggerLabApp extends StatelessWidget {
  const TriggerLabApp({super.key});

  /// Flutter's defaults let arrow, Tab, Enter and Space keys move focus and
  /// press buttons. A remote's D-pad would wander into a text field and open
  /// the keyboard, which then eats keys before the window sees them. The lab
  /// observes keys; it never lets them act on its own widgets.
  static final Map<ShortcutActivator, Intent> shortcuts = Map.of(
    WidgetsApp.defaultShortcuts,
  )..removeWhere(
    (_, intent) =>
        intent is DirectionalFocusIntent ||
        intent is NextFocusIntent ||
        intent is PreviousFocusIntent ||
        intent is ActivateIntent ||
        intent is ButtonActivateIntent,
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Trigger Lab',
    shortcuts: shortcuts,
    theme: ThemeData(
      colorSchemeSeed: Colors.teal,
      brightness: Brightness.dark,
      useMaterial3: true,
    ),
    home: const LabScreen(),
  );
}
