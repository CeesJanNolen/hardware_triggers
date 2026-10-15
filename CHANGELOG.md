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
