# How Gratify Works

## Overview

Gratify has two independent parts that communicate through SharedPreferences:

1. **The Accessibility Service** (Kotlin, always running in the background) — detects when a restricted app is opened
2. **The Flutter UI** (only active when Gratify is on screen) — shows the countdown and handles user decisions

---

## Detection: How the service knows an app was opened

Android calls `onAccessibilityEvent()` on `AppMonitorAccessibilityService` every time any window appears on screen. The service filters down to what matters:

1. Event type must be `TYPE_WINDOW_STATE_CHANGED` (a new window came to the foreground)
2. The package must belong to a user-launchable app (filters out keyboard, status bar, system dialogs)
3. The package must be different from the last detected foreground app (filters out navigating between activities *within* the same app)
4. Monitoring must be enabled (`flutter.monitoring_enabled` flag in SharedPreferences)
5. The package must be in the restricted apps list (`flutter.restricted_apps` in SharedPreferences)
6. There must be no active grace period for this package (`gratify_grace` SharedPreferences)

If all six pass, the service fires an Intent that launches `MainActivity` with `SHOW_DELAY = true`.

### Why this is better than the old approach

The previous system used `UsageStatsManager` polled every 1 second. That had two fatal flaws:
- Instagram and TikTok run background sync activities that fire `ACTIVITY_RESUMED` events, causing the "last seen package" to update even when the user never opened the app
- `UsageStatsManager` has a reporting delay, so events could be missed between polls

`TYPE_WINDOW_STATE_CHANGED` fires synchronously when a window is *shown to the user*. Background sync threads never create visible windows, so they produce zero false events.

---

## Interruption: How Gratify appears on top

When the service fires the Intent:

- `FLAG_ACTIVITY_NEW_TASK` — required to start an activity from a non-activity context (the service)
- `FLAG_ACTIVITY_SINGLE_TOP` — if Gratify is already on top, reuse it rather than stacking a new instance

`MainActivity` receives the Intent, extracts the package name / app name / delay seconds, and calls `methodChannel.invokeMethod("onAppOpened", data)` to pass it to Flutter.

In Flutter (`main.dart`), `_handleAppOpened` is called, which:
1. Loads the restricted app from storage
2. Increments the daily attempt counter and saves it back
3. Pushes `DelayScreen` onto the navigator stack with `fromService: true`

---

## The Delay Screen

The countdown uses an `AnimationController` running for `delaySeconds`. The "Open App" button is disabled until the animation completes.

**"Open App" tapped:**
1. Calls `openApp()` — calls `moveTaskToBack(true)`, which pushes Gratify behind the restricted app (the restricted app resurfaces because it was already open underneath)

**"Never mind" tapped:**
1. Calls `goHome()` — fires a `ACTION_MAIN + CATEGORY_HOME` Intent, sending the user to the Android home screen
2. Pops the delay screen from the Flutter navigator

## The `lastForegroundPkg` Variable

The service keeps track of the last package it processed. If the same package fires another `TYPE_WINDOW_STATE_CHANGED` event (e.g., the user opens a different activity within the same app), it is skipped.

**Known failure mode:** If the user switches to a different launchable app (e.g., opens their browser) and then returns to the restricted app, `lastForegroundPkg` changes to the browser and then back — so the restricted app is treated as a fresh open and the service will check the grace period again. If the grace period is still active, nothing happens. If it expired, the delay fires again.

---

## The Monitoring Toggle

The toggle in the home screen does **not** start or stop the accessibility service. The service is always running once enabled in Android Settings. The toggle writes `flutter.monitoring_enabled = true/false` to SharedPreferences. The service reads this flag on every event and skips everything if it is false.

---

## Known Weak Points

1. **`lastForegroundPkg` is reset when the service process is killed.** Android can kill the service process under memory pressure. When it restarts, `lastForegroundPkg` is null, so the next foreground event for any app — including one with an active grace period — will re-evaluate. The grace period check will still protect the user in most cases, but if the grace period also expired, the delay fires again.

2. **`launchableCache` is rebuilt on every service restart.** This is a minor performance cost but not a correctness issue.

3. **New apps installed after the cache is built are not in the cache.** Currently `cacheFilled` is set to `true` permanently once built. Newly installed apps would not pass the `isLaunchableApp` check until the service restarts.

4. **The accessibility service can be disabled by the user in Android Settings** at any time. Gratify has no way to re-enable it automatically — it can only detect that it is off and show the permissions banner.
