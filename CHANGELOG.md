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
