# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run on a connected Android device (primary target platform)
flutter run

# Build release APK
flutter build apk --release

# Analyze Dart code
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart
```

There is no iOS-specific setup; the app is Android-only in practice due to its reliance on Android's `AccessibilityService`.

## Architecture

Gratify is a **Flutter + Android Kotlin hybrid**. Flutter handles all UI; a Kotlin `AccessibilityService` runs as a background Android service that intercepts app launches. These two layers communicate through two channels:

### 1. MethodChannel (`com.gratify/app_monitor`)

`lib/services/app_service.dart` wraps every cross-layer call. Flutter calls Kotlin for:

- Permission checks/requests
- `recordAccessGranted(packageName)` — stamps a timestamp so the grace period can be measured
- `previewReminder(appName, intervalSeconds)` — sends a broadcast to trigger the reminder banner

Kotlin calls Flutter for:

- `onAppOpened({packageName, appName, delaySeconds})` — fired by `AppMonitorAccessibilityService` when a restricted app needs to be intercepted; handled in `main.dart` which pushes `DelayScreen`

### 2. SharedPreferences as IPC

Flutter's `shared_preferences` package stores keys with a `flutter.` prefix automatically (e.g., Dart key `restricted_apps` → Android key `flutter.restricted_apps`). The `AccessibilityService` reads these directly from `FlutterSharedPreferences` at runtime — no additional IPC needed.

Keys read by Kotlin:
| Dart key | Kotlin reads as | Purpose |
|---|---|---|
| `restricted_apps` | `flutter.restricted_apps` | JSON array of restricted app configs |
| `monitoring_enabled` | `flutter.monitoring_enabled` | Global on/off switch |
| `access_granted_<pkg>` | `flutter.access_granted_<pkg>` | Grace period timestamp |
| `reminder_position` | `flutter.reminder_position` | Int index into `ReminderPosition` enum |
| `reminder_animation` | `flutter.reminder_animation` | Int index selecting the banner enter/exit animation (see Banner animation) |
| `reminder_color_mode` | `flutter.reminder_color_mode` | Int index into `BannerColorMode` enum |
| `reminder_custom_color` | `flutter.reminder_custom_color` | RGB int (0xRRGGBB, no alpha, fits in int32) |
| `reminder_opacity` | `flutter.reminder_opacity` | Int 0–100 (percent); default 92. Controls banner background alpha. |
| `reminder_duration` | `flutter.reminder_duration` | Int 1–5 (seconds); default 4. How long the banner stays on screen. |
| `reminder_message` | `flutter.reminder_message` | Template string with `{app}` and `{time}` |

**Important:** Custom banner colors are stored as 24-bit RGB (`0xRRGGBB`, max `0xFFFFFF = 16,777,215`) to stay within signed int32 range and avoid SharedPreferences overflow issues. Never store a full ARGB Flutter color value as an int.

**Important:** Flutter's `shared_preferences` stores Dart `int` values as `Long` in Android's `SharedPreferences`. Kotlin code must read them with `getLong(key, defaultL).toInt()`, **not** `getInt()`. Calling `getInt()` on a Long-typed key throws `ClassCastException`, which — if uncaught — crashes the accessibility service process. Boolean and String values are unaffected. Timestamps (already Long in Dart) should remain as `getLong()`.

### Flutter layer (`lib/`)

| Path                                      | Purpose                                                                                      |
| ----------------------------------------- | -------------------------------------------------------------------------------------------- |
| `main.dart`                               | App entry, `MethodChannel` listener for `onAppOpened`, pushes `DelayScreen`                  |
| `models/restricted_app.dart`              | Per-app restriction config (delay, grace, grayscale, reminder interval, session limit)       |
| `models/reminder_settings.dart`           | Global reminder appearance (animation, position, color mode, custom color, message template) |
| `models/app_settings.dart`                | Delay screen UI customisation (fonts, toggle visibility, countdown style)                    |
| `services/storage_service.dart`           | JSON persistence of `RestrictedApp` list via `shared_preferences`                            |
| `services/app_service.dart`               | All `MethodChannel` calls to Kotlin                                                          |
| `services/reminder_settings_service.dart` | Load/save `ReminderSettings` via `shared_preferences`                                        |
| `services/settings_service.dart`          | Load/save `AppSettings`                                                                      |
| `screens/home_screen.dart`                | App list, monitoring toggle, permission banner                                               |
| `screens/add_app_screen.dart`             | Create/edit a `RestrictedApp`; links to `ReminderSettingsScreen`                             |
| `screens/delay_screen.dart`               | Full-screen countdown shown when intercepting an app launch                                  |
| `screens/settings_screen.dart`            | Delay screen appearance customisation                                                        |
| `screens/reminder_settings_screen.dart`   | Global reminder banner appearance (animation, position, color, message)                      |
| `screens/permissions_screen.dart`         | Onboarding flow for accessibility + overlay permissions                                      |
| `widgets/countdown_ring.dart`             | Animated countdown (ring / fill / bar / breath / none styles)                                |
| `widgets/app_icon_widget.dart`            | Loads and caches app icons via `getAppIcon` MethodChannel call                               |

### Kotlin layer (`android/app/src/main/kotlin/com/example/gratify/`)

**`AppMonitorAccessibilityService.kt`** — the core background service:

- Listens for `TYPE_WINDOW_STATE_CHANGED` accessibility events to detect the foreground app
- Maintains `activeRestrictedSessions: MutableSet<String>` — an app is in the set once its grace period is verified; it stays in until the home launcher is detected. This prevents re-triggering for in-app navigation (comments, image viewers, in-app browsers).
- Session timers: `pendingReminderRunnables` (fires `showReminderBanner` at intervals) and `pendingLimitRunnables` (fires `triggerDelay` after the session limit expires)
- `showReminderBanner` — adds a `FrameLayout` (with padding to prevent clipping during scale/slide animations) containing a pill `TextView` to `WindowManager` using `TYPE_ACCESSIBILITY_OVERLAY`. It reads all reminder settings from `FlutterSharedPreferences` at call time. The banner window is kept fully opaque (`container.alpha = 1f`) and all enter/exit animation is delegated to the window manager via `params.windowAnimations` (see Banner animation). The padding headroom is intentional: scale/slide animations can move the pill past the layout bounds, which would clip its rounded corners without it.
- Grayscale overlay — a separate full-screen semi-transparent `View` added to `WindowManager`; shown/hidden based on per-app toggle and optional time window.
- `previewReceiver` — a `BroadcastReceiver` registered in `onServiceConnected` that triggers `showReminderBanner` directly from the settings UI.

**`MainActivity.kt`** — `FlutterActivity` with MethodChannel setup:

- `finishAndRemoveTask()` is called after `openApp` and `goHome` to remove Gratify from Android recents.
- `handleIntent` / `onNewIntent` deliver the `SHOW_DELAY` intent from the accessibility service to Flutter via `onAppOpened`.
- `pendingDelay` buffers the intent data if the Flutter engine isn't ready yet when the intent arrives.

### Banner animation

The reminder banner is a window added to `WindowManager` with type `TYPE_ACCESSIBILITY_OVERLAY`. **All entrance/exit animation is done at the window level by the OS, not by animating the views inside the window.** This is deliberate and the history matters:

- Animating the view content (`ValueAnimator`/`ViewPropertyAnimator` driving the root view's `alpha`) caused the banner to **flicker** — animating the alpha of a freshly-added overlay window makes the compositor re-composite the whole surface each frame.
- Animating an inner child view instead avoided the flicker but did not start reliably on a just-added overlay (the banner sometimes never appeared).
- The robust solution is `WindowManager.LayoutParams.windowAnimations`: point it at a style that declares `windowEnterAnimation` / `windowExitAnimation`, and the OS plays them at the surface level when the window is added (`addView`) and removed (`removeView`). No per-frame view changes, no flicker.

Because the OS owns the animation, `showReminderBanner` only has to: add the window (enter animation plays automatically), then schedule a single `removeRunnable` at `BANNER_DURATION_MS` that calls `removeView` (exit animation plays automatically). The forced-dismiss path also goes through `removeView`, so it animates out too.

**Caveat:** a few OEM ROMs / Android versions ignore `windowEnterAnimation`/`windowExitAnimation` for accessibility-overlay windows. On those, the banner simply appears/disappears instantly — no flicker, no animation — which is acceptable degradation.

#### How the user chooses an animation

`showReminderBanner` reads `flutter.reminder_animation` (a `Long` index, read with `getLong(...).toInt()`) and maps it to a window-animation style:

| Index         | Meaning                          | `windowAnimations` value       |
| ------------- | -------------------------------- | ------------------------------ |
| `0` (default) | Pop (fade + scale + small slide) | `R.style.BannerAnimation`      |
| `1`           | Fade (alpha only)                | `R.style.BannerAnimationFade`  |
| `2`           | Slide (translate + fade)         | `R.style.BannerAnimationSlide` |
| `3`           | None (instant)                   | `0`                            |

The pref is written from Flutter (`ReminderSettings` → `reminder_settings_service.dart`, surfaced in `reminder_settings_screen.dart`). It is read at banner-show time, so changes apply immediately with no service restart.

Resource files involved (under `android/app/src/main/res/`):

- `anim/banner_enter.xml`, `anim/banner_exit.xml` — Pop
- `anim/banner_fade_enter.xml`, `anim/banner_fade_exit.xml` — Fade
- `anim/banner_slide_enter.xml`, `anim/banner_slide_exit.xml` — Slide
- `values/styles.xml` — declares `BannerAnimation`, `BannerAnimationFade`, `BannerAnimationSlide` (alongside Flutter's `LaunchTheme`/`NormalTheme`). There is no style for "None"; index `3` uses `windowAnimations = 0`.

#### Adding a new animation style

The pattern is fixed — five steps, no logic rewrite:

1. Create `res/anim/banner_<name>_enter.xml` (an `<set>` of `<alpha>`/`<scale>`/`<translate>`; use `decelerate_interpolator` for enter).
2. Create `res/anim/banner_<name>_exit.xml` (use `accelerate_interpolator` for exit).
3. Add a `<style name="BannerAnimation<Name>">` to `res/values/styles.xml` referencing those two anims via `android:windowEnterAnimation` / `android:windowExitAnimation`.
4. Add a new index branch to the `when (animIdx)` mapping in `showReminderBanner`, returning `R.style.BannerAnimation<Name>`.
5. Add the matching option (label + index) to the picker in `reminder_settings_screen.dart` and to the `ReminderSettings` model so the index round-trips through `shared_preferences`.

Keep the `FrameLayout` container padding in mind: animations that scale up or overshoot must stay within the padding headroom or the pill's rounded corners will clip at the window bounds.

### Session / grace period flow

1. Accessibility event fires for a restricted app package
2. If `activeRestrictedSessions` already contains the package → skip (in-session navigation)
3. Check `flutter.access_granted_<pkg>` timestamp; if within grace window → add to sessions and start timers, skip delay
4. Otherwise → `triggerDelay`: start `MainActivity` with `SHOW_DELAY` intent → Flutter shows `DelayScreen` → user taps "Open App" → `recordAccessGranted` stamps timestamp → `finishAndRemoveTask`

## Design tokens

| Token          | Value        | Usage                           |
| -------------- | ------------ | ------------------------------- |
| Primary purple | `0xFF7B6FD4` | Main actions, selected state    |
| Teal           | `0xFF6BBFB5` | Monitoring active, grace period |
| Orange         | `0xFFE8927C` | Warnings, usage reminder accent |
| Pink           | `0xFFD474AA` | Session limit accent            |
| Muted          | `0xFF9896B0` | Secondary text, disabled state  |
