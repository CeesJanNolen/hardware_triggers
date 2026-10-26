## 0.5.0

- `InterceptRule.any`: a catch-all rule reporting every hardware key natively with its device. A rule naming a key wins over it. Meant for detection screens.
- Trigger Identity: `TriggerDevice` and `CatalogEntry` carry the vendor and product id; the catalog requires the name to match and, when both sides have them, the ids as well. Two remotes that pair under the same name are told apart; two models sharing generic ids are not confused.
- `InputEvent.code`: the raw Android key code behind a native event. A code Flutter has no name for is no longer dropped; it becomes a key in Flutter's Android plane.
- Android: an observed key that Flutter leaves unhandled is redispatched through the window by Flutter's embedding; it is reported once now, not twice. Synthetic fallback keys are never reported.
- Catalog: Beauty-R1 (white Yggcoo N16500), M9 (Fanumuran 477465) and BLE-M3 (black Yggcoo N16500) ring remotes. Only their camera button is a key, alternating Volume Down and Volume Up; the rest is stylus input.
- `example/`: Trigger Lab, the detection app. Pair an unknown remote, press its buttons, label them, copy a ready Catalog Entry. CI builds it instead of a throwaway app.

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
