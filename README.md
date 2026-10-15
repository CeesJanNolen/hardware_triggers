# hardware_triggers

Physical key Triggers (Bluetooth shutter buttons, keyboard-mode remotes, the
device's own volume rocker) as one stream of Input Events, recognised into
Press Patterns, bound to your own action type. Built for the Sport Scoreboard
and the Redrive app; see ADR 0003 in the scoreboard repo for the reasoning.

## Layers

Each layer works without the one above it.

1. `HardwareTriggers.instance.events`: a `Stream<InputEvent>` with the
   `LogicalKeyboardKey`, down/up, timestamp, source and (on Android) the
   `TriggerDevice` that sent it.
2. `PressPatternRecognizer`: a stream transformer turning key-down events into
   single and double presses. Optimistic by default: every press is reported
   as a single press at once, and a second press within the window follows as
   a double press, so the consumer undoes what it did for the single. Pass
   `optimistic: false` to wait the window instead.
3. `Binding<A>`: a map from `PressSpec` (key plus press kind) to your action
   type. `binding.bind(patterns)` is a `Stream<A>`.
4. `package:hardware_triggers/riverpod.dart`: ready providers for the above
   plus `interceptProvider(rules)`, which intercepts while watched.

## Interception

Volume keys never reach Flutter reliably on Android (flutter/flutter#71144),
and the system would change the volume anyway. `startIntercepting` installs a
native intercept for the keys you name, with a policy each:

- `InterceptPolicy.consume`: report the press, swallow the key. No volume
  change, no popup.
- `InterceptPolicy.observe`: report the press and let the system act on it.

`externalOnly: true` limits a rule to external devices, so a Bluetooth shutter
is consumed while the tablet's own rocker still changes the volume. Call
`stopIntercepting` when the screen that needs the keys goes away, or use the
Riverpod `interceptProvider` and let it follow the screen's lifetime.

Keys without a rule arrive through Flutter's normal key path (source
`flutter`), so a keyboard-mode remote sending Enter or Space works everywhere
with no interception at all. A key under an active rule is never reported
twice.

## Single click in Redrive

```dart
enum TripmasterAction { resetSegment }

final binding = Binding<TripmasterAction>({
  PressSpec.single(LogicalKeyboardKey.audioVolumeUp): TripmasterAction.resetSegment,
});

// In the tripmaster screen, while it is visible:
ref.watch(interceptProvider(const [
  InterceptRule(LogicalKeyboardKey.audioVolumeUp,
      policy: InterceptPolicy.consume, externalOnly: true),
]));
ref.listen(pressPatternsProvider, (_, next) {
  final pattern = next.value;
  if (pattern != null && binding.lookup(pattern) == TripmasterAction.resetSegment) {
    ref.read(standaloneSegmentDistanceProvider.notifier).state = 0;
  }
});
```

With `externalOnly: true` the tablet's own volume buttons keep raising the
volume. Use `InterceptPolicy.observe` if the shutter should do both.

## Platforms

**Android**: the plugin wraps the Activity window's `Window.Callback` and
intercepts `dispatchKeyEvent` there, before Flutter's view. No change to
`MainActivity` is needed. Device info comes from the `InputDevice` of the
event; `isExternal` needs Android 10 and is null below that.

**iOS / iPadOS, unverified**: iOS never hands volume keys to apps and hides
paired HID devices from them, so the plugin watches
`AVAudioSession.outputVolume`. A rise is Volume Up, a drop is Volume Down.
Under `consume` a hidden `MPVolumeView` sets the level back to a baseline
(kept between 10% and 90% so a press is always detectable) and keeps the
system popup away. Device info is never available, so `externalOnly` rules
match nothing, and `connectedDevices` is empty. This side was written without
a Mac to compile or run it. Keyboard-mode remotes work on iOS through the
Flutter key path without any of this.

## Wire format

Both native sides send Android key codes; Dart maps them with Flutter's own
`kAndroidToLogicalKey` table, so no second table exists.
