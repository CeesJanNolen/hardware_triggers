## 0.4.1

- iOS: verified on a device (iOS 27, AB Shutter3). Presses were never seen: the audio session was `.ambient`, where with nothing playing the buttons step the ringer, which `outputVolume` does not follow. It is `.playback` now, which the mute switch also leaves alone; a playing category the app chose is kept.
- iOS: quick presses about 180 ms apart were merged into one hold. A step within 100 ms of the previous one is the held key's repeat; a later one is a new press.
- iOS: a level the user sets with the buttons that no rule covers becomes the baseline, so a consumed press no longer jumps back to an old level.
- `systemVolume()` and `setSystemVolume()`: the system output volume, iOS only. A consume rule takes the volume buttons away there, so an app can offer the volume itself. Levels the app sets are not reported as presses.
- Catalog: AB Shutter3 verified on iOS for all four Press Kinds.

## 0.4.0

- Long press as a fourth Press Kind: a key held for `longPressThreshold` (500 ms), reported while still held. A long press ends its sequence.
- Delayed mode now reports after the key is released, so a hold never produces a single first.
- Catalog buttons list their reliable Press Kinds per platform.
- iOS: a held button becomes a real key-down/key-up pair from the repeated volume steps. iOS is registered again; CI compiles it on macOS, behaviour on a device is still unverified.
- CI: analyze and test on Ubuntu, throwaway-app compiles for Android and iOS.

## 0.3.0

- `TriggerCatalog`: verified accessories with what each button sends. First entry: AB Shutter3.
- iOS is no longer registered as a plugin platform until the Swift side is compiled. The method channel degrades to "unsupported" where the plugin is missing instead of throwing.

## 0.2.0

- Triple press as a third Press Kind. `doubleWindow` renamed to `pressWindow`; it now bounds the gap between consecutive presses.

## 0.1.0

- Input Event stream merging native interception and Flutter key events.
- Press Pattern recogniser (optimistic and delayed) and generic Binding.
- Android interception via Window.Callback proxy with consume/observe policies and external-only filtering.
- iOS volume observation implementation, unverified.
- Riverpod 3 providers.
