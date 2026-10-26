# Trigger Lab

The detection app for `hardware_triggers`. Pair a remote nobody has
catalogued yet, press its buttons, and leave with a `CatalogEntry` on the
clipboard. Android only: iOS hides paired devices from apps.

```sh
cd example
flutter run -d <android device>
```

What it does:

- Keeps a catch-all `InterceptRule.any()` active (observe policy), so every
  hardware key the window receives arrives natively with its device name, id,
  vendor and product id. The system still acts on the key, so the tablet
  stays usable.
- Logs every Input Event with its hold duration, the Press Pattern the
  default optimistic recogniser makes of it, and mouse-style pointer clicks and
  scrolls, so a button that pairs as a mouse shows up as such instead of as
  silence.
- Builds one card per device: an editable entry name, a row per key seen with
  an editable label and checkboxes for the Press Kinds you verified, a per-key
  "swallow" switch that puts a consume rule on top of the catch-all to try the
  consume policy, and a notes field.
- "Copy as catalog entry" puts ready Dart on the clipboard to paste into
  `lib/src/trigger_catalog.dart`.

Nothing is persisted; the paste into the catalog is the record. Home and
Power never reach an app on Android; write them in the notes.
