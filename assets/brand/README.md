# assets/brand — Lingo Mate app icon

Concept **"Two sides of the table"**: two facing speech bubbles. The light bubble (paper) is you speaking (waveform); the dark bubble (ink) is the other person replying (dots). No letters, so the mark works in every language and survives any future rename.

Colours: Lagoon `#0F766E` (background) · Ink `#14161F` · Paper `#FAF8F4` · Lagoon light `#2DD4BF`. Dev flavor uses Graphite `#475569` as background so test builds are easy to tell apart.

## Files

| File | What | Use |
|------|------|-----|
| `ic_launcher_background.svg` / `png/icon_background_1024.png` | Solid Lagoon, 108×108 canvas | Adaptive icon background |
| `ic_launcher_foreground.svg` / `png/icon_foreground_1024.png` | Bubbles on transparent, art inside the 66 dp safe zone | Adaptive icon foreground |
| `ic_launcher_monochrome.svg` / `png/icon_monochrome_1024.png` | Single-colour (white) silhouette with cut-outs | Themed icons (Android 13+) |
| `ic_launcher_foreground_dev.svg` / `png/icon_foreground_dev_1024.png`, `ic_launcher_background_dev.svg` | Dev variant (gap colour + background graphite) | `dev` flavor |
| `app_icon_full.svg` | Background + foreground composited (108 canvas) | Previews |
| `play_store_icon.svg` / `png/play_store_icon_512.png` | Full-bleed square, art enlarged | Play Console store icon (512×512, 32-bit PNG, ≤ 1 MB; no rounded corners or shadow — Play adds them) |
| `png/app_icon_1024.png`, `png/app_icon_dev_1024.png` | Full-bleed composite | `image_path` for flutter_launcher_icons |
| `ic_stat_lingomate.svg` / `png/ic_stat_lingomate_<density>_<px>.png` | White silhouette on transparent, 24 dp | Notification small icon (foreground service, reminders) |

Adaptive icon rules followed: all layers 108×108 dp; important art inside the centred 66 dp circle; background fully opaque; monochrome layer provided.

## Flutter setup (T-1.1)

`pubspec.yaml` (dev dependency `flutter_launcher_icons`) — one config per flavor, e.g. `flutter_launcher_icons-prod.yaml`:

```yaml
flutter_launcher_icons:
  android: true
  ios: false
  min_sdk_android: 26
  image_path: "assets/brand/png/app_icon_1024.png"
  adaptive_icon_background: "#0F766E"
  adaptive_icon_foreground: "assets/brand/png/icon_foreground_1024.png"
  adaptive_icon_monochrome: "assets/brand/png/icon_monochrome_1024.png"
```

`flutter_launcher_icons-dev.yaml`: same keys with `app_icon_dev_1024.png`, background `#475569`, foreground `icon_foreground_dev_1024.png`. Run `dart run flutter_launcher_icons -f flutter_launcher_icons-<flavor>.yaml` (check key names against the plugin version you install).

Notification icon: copy `png/ic_stat_lingomate_<density>_<px>.png` to `android/app/src/main/res/drawable-<density>/ic_stat_lingomate.png` (or import `ic_stat_lingomate.svg` with Android Studio → Vector Asset), then reference `@drawable/ic_stat_lingomate` from the foreground-service notification. Never use the colour launcher icon as a notification icon.

Splash (Android 12+ system splash): background `#0F766E`, icon = adaptive foreground.
