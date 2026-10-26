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
2. `PressPatternRecognizer`: a stream transformer turning key events into
   single, double, triple and long presses. A long press is a key held for
   500 ms, reported while still held; it ends its sequence. Optimistic by
   default: every key-down is reported at once as single, double or triple
   according to its place in the sequence, so the consumer undoes what it did
   for the earlier presses when a double, triple or long press follows. Pass
   `optimistic: false` to report once, after release and the window, so
   nothing ever has to be undone at the price of a short delay.
3. `Binding<A>`: a map from `PressSpec` (key plus press kind) to your action
   type. `binding.bind(patterns)` is a `Stream<A>`.
4. `package:hardware_triggers/riverpod.dart`: ready providers for the above
   plus `interceptProvider(rules)`, which intercepts while watched.

`TriggerCatalog` lists the accessories verified against the package (today:
the AB Shutter3 shutter button) with what each button sends and which Press
Kinds are reliable. Show it in a settings screen so users know what is
supported; `TriggerCatalog.lookup(device)` tells whether a connected device is
one of them. Other devices may or may not work depending on what they send.
An entry can carry a Trigger Identity (vendor and product id); when both the
entry and the device have one, the ids decide the match, so two remotes that
pair under the same name are told apart. Otherwise the name decides.

To catalogue a new accessory, run Trigger Lab in `example/`: it shows every
key the remote sends with its device, lets you label the buttons and tick the
Press Kinds you verified, and copies a ready `CatalogEntry`.

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

`InterceptRule.any()` is a catch-all: every hardware key the window receives
is reported natively with its device, observed by default. A rule naming a
key wins over it, so a detection screen can swallow one key while watching
the rest. Keys Flutter has no name for are not dropped; they become keys in
Flutter's Android plane and `InputEvent.code` carries the raw Android code.

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
event: name, id, vendor and product id, and `isExternal`, which needs
Android 10 and is null below that. Home and Power are handled by the system
before any window and are never reported.

**iOS / iPadOS, compiles, unverified on a device**: CI builds the Swift side
on a macOS runner, but nobody has run it on an iPhone yet; see the checklist
below. iOS never hands volume keys to apps and hides
paired HID devices from them, so the plugin watches
`AVAudioSession.outputVolume`. A held button makes iOS step the volume
repeatedly; the first step is reported as key-down and key-up follows once no
step has arrived for 300 ms, so holds reach the Dart recogniser as real
down/up pairs. A rise is Volume Up, a drop is Volume Down.
Under `consume` a hidden `MPVolumeView` sets the level back to a baseline
(kept between 10% and 90% so a press is always detectable) and keeps the
system popup away. Device info is never available, so `externalOnly` rules
match nothing, and `connectedDevices` is empty. Keyboard-mode remotes work on
iOS through the Flutter key path without any of this.

### iOS device checklist

To be run once on an iPhone with the AB Shutter3 paired, from a Mac with
Xcode. Record the outcome in the catalog entry and in this README.

1. Scoreboard: single press scores, double press flips, triple press undoes.
2. Scoreboard: hold for two seconds resets the Set once; the release does
   nothing more. If the hold only scores a point, iOS does not auto-repeat
   the volume for the shutter and the long press is Android-only.
3. Scoreboard: the system volume popup never appears while the board is open,
   and presses keep working at the volume limits (the baseline reset).
4. Scoreboard: on the home screen the shutter changes the volume as usual.
5. Redrive: the button does nothing anywhere, and the settings screen says the
   platform is unsupported for it.

## Wire format

Both native sides send Android key codes; Dart maps them with Flutter's own
`kAndroidToLogicalKey` table, so no second table exists.
