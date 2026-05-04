# How App Blocking Works in Gratify

## Platform support

Android only. iOS does not expose a public API to detect foreground app changes from a third-party app, so the blocking mechanism described below is unavailable on iOS. A Screen Time / Family Controls approach would be required for iOS but needs a special Apple entitlement.

---

## Required permissions

The user must grant two Android permissions before monitoring works:

| Permission | Why needed |
|---|---|
| **Accessibility Service** (`android.permission.BIND_ACCESSIBILITY_SERVICE`) | Lets the app receive `TYPE_WINDOW_STATE_CHANGED` events so it knows which app just came to the foreground |
| **Display Over Other Apps** (`SYSTEM_ALERT_WINDOW`) | Allows Gratify's activity to overlay the restricted app while the delay screen is shown |

Additionally the manifest declares `QUERY_ALL_PACKAGES` so the app can enumerate all installed apps for the picker.

---

## Step-by-step interception flow

1. **User enables monitoring** in the home screen → Flutter calls `AppService.startMonitoring()` via the `com.gratify/app_monitor` MethodChannel → `MainActivity` sets `flutter.monitoring_enabled = true` in `FlutterSharedPreferences`.

2. **User opens a restricted app** from the launcher or any other app.

3. **`AppMonitorAccessibilityService.onAccessibilityEvent`** fires with event type `TYPE_WINDOW_STATE_CHANGED`. The service checks in order:
   - Is the package Gratify itself? → skip (prevent infinite loop).
   - Is the package a launchable user app? (checked against `launchableCache`, built once at runtime from packages that have a launcher intent) → skip system dialogs, keyboard, status bar, etc.
   - Is it the same app already in the foreground (`lastForegroundPkg`)? → skip in-app navigation events.
   - Is `flutter.monitoring_enabled` true in shared prefs? → if false, skip.
   - Is the package in the `flutter.restricted_apps` JSON list in shared prefs? → if not listed, skip.

4. **Service fires an Intent** to `MainActivity` with flags `FLAG_ACTIVITY_NEW_TASK | FLAG_ACTIVITY_SINGLE_TOP` and extras: `SHOW_DELAY=true`, `PKG`, `APP_NAME`, `DELAY_SECS`.

5. **`MainActivity.handleIntent`** is called (via `onNewIntent` if already running, or directly after `configureFlutterEngine`). It packages the extras into a map and calls `methodChannel.invokeMethod("onAppOpened", data)`. If the Flutter engine is not ready yet, it parks the data in `pendingDelay` and delivers it once the engine starts.

6. **`AppService.setOnAppOpened` callback** in Flutter receives the call, increments the `dailyAttempts` counter in `StorageService` (shared prefs), and pushes a `DelayScreen` route onto the navigator.

7. **`DelayScreen`** shows:
   - The app icon and name.
   - How many times the user has tried to open the app today.
   - A circular countdown ring animating from full to empty over `delaySeconds`.
   - "Are you sure you want to open this app?" prompt.

8. **After the countdown completes** the "Open App" button becomes active.
   - **Open App** → calls `AppService.openApp()` → `moveTaskToBack(true)` on `MainActivity` → Gratify moves to the background → the restricted app resurfaces.
   - **Never mind** → calls `AppService.goHome()` → launches the Android home screen intent → pops the delay route.

---

## When it doesn't work

- **Permissions revoked**: If the user disables the Accessibility Service or the overlay permission in Android Settings, the service stops firing and the blocking mechanism is completely inactive. The app has no way to re-enable these programmatically.
- **Gratify's process is killed**: Android's battery optimisation (Doze, App Standby, manufacturer-specific killers) can terminate the accessibility service's process. When this happens the service stops receiving events until the user relaunches Gratify or the service is automatically restarted by Android (not guaranteed).
- **Monitoring toggle is off**: The `flutter.monitoring_enabled` flag is `false` either because the user turned it off in-app or because `startMonitoring` was never called.
- **Restricted apps list is missing or corrupt**: If shared prefs cannot be read (e.g., after a data-clear, or a JSON parse error) `findRestrictedApp` returns null and no delay is shown.
- **App launched via ADB or automation**: An app started via `adb shell am start` does not always produce a `TYPE_WINDOW_STATE_CHANGED` event visible to a third-party accessibility service.
- **Android 14+ restricted accessibility services**: Some OEMs and future Android versions may further restrict which accessibility services can run in the background or may require additional whitelisting.

---

## Edge cases and known limitations

### Interception timing
The accessibility event fires *after* the target app's window is already visible. There is a brief moment (tens of milliseconds) where the user can see the restricted app before Gratify overlays it. It is not a true preemptive block.

### Launchable app cache is stale
`launchableCache` is built once the first time the service checks and never refreshed during the service's lifetime. Apps installed after the cache is built will not be in the cache and cannot be intercepted until the service restarts (e.g., device reboot or Gratify relaunch).

### X (close) button does not go home
The delay screen's top-left close icon calls `Navigator.pop(context)` unconditionally, even when `fromService=true`. This leaves the user on Gratify's home screen — the restricted app is still in the background task stack. If the user then minimises Gratify (e.g., via the recents button), Android may surface the restricted app directly without a new delay screen trigger. The "Never mind" button handles this correctly by going to the home screen first.

### Rapid re-opening after "Open App"
When "Open App" is tapped, `moveTaskToBack` surfaces the restricted app. If the user then switches to another app and back to the restricted app, the accessibility service fires again and a new delay screen is shown — which is intended behaviour, but may feel punishing to users who feel they already "earned" access.

### Apps that don't fire TYPE_WINDOW_STATE_CHANGED
Apps that use custom `SurfaceView`/`TextureView` rendering (many games, some video players) or apps launched as system overlays may not produce a `TYPE_WINDOW_STATE_CHANGED` event and cannot be intercepted.

### Countdown resets if Gratify is killed
The delay countdown lives in Flutter's `AnimationController`. If the system kills Gratify's process while the delay screen is showing (e.g., low memory) and the user later reopens the restricted app, a fresh countdown starts. There is no persistence of a partially elapsed timer.

### No iOS support
The iOS entitlements (`ScreenTime`/`ManagedSettings`) required to block apps at the OS level require an Apple-issued Family Controls entitlement and a Screen Time API integration. The app currently builds for iOS but has no blocking functionality there.

### Shared preferences race condition
The accessibility service reads `FlutterSharedPreferences` synchronously on the main thread. If Flutter is writing the restricted apps list at the exact same moment (e.g., during a save), the service might read a missing `restricted_apps` key and skip the interception. SharedPreferences `apply()` is atomic per-key so JSON corruption is unlikely, but a first-write scenario could cause a single missed trigger.
