# False Delay Screen Triggers (e.g. Instagram comments / profiles)

## Background

The service tracks in-session navigation using two mechanisms:
- `lastForegroundPackage` — skips repeated events from the same package
- `activeRestrictedSessions` — skips processing if the app is already in an active session

The delay screen triggers when both of these checks are bypassed while grace period has also expired. Below are the plausible reasons that can happen during in-app navigation.

---

## Potential causes

### 1. SharedPreferences async write / sync read race (most likely)

Flutter's `shared_preferences` uses `apply()` (asynchronous) internally. After the user taps "Open App", `recordAccessGranted` writes the grace timestamp asynchronously. If the accessibility service reads `flutter.access_granted_<pkg>` before that write is committed to disk, `grantedAt` comes back as `0`, the grace check fails, and — if `pendingDelayPackages` was cleared (e.g. the user briefly visited the home screen) — `triggerDelay` fires again. The window is typically only a few milliseconds, but Android's SharedPreferences `apply()` can be deferred further under I/O pressure.

### 2. `lastForegroundPackage` reset by Gratify's own UI mid-session

Every time a Gratify screen is foregrounded (delay screen, settings, any overlay that fires `TYPE_WINDOW_STATE_CHANGED`), line 105–108 sets `lastForegroundPackage = null`. This is intentional for the delay screen itself, but the same reset happens if the service triggers an overlay or if the user briefly visits any Gratify screen and comes back. The next Instagram event is then treated as a fresh foreground event and goes through the full flow. If `activeRestrictedSessions` still contains the package this is harmless, but combined with cause #1 or #5 the session set can be empty at that point.

### 3. Intermediate launchable-app event changes `lastForegroundPackage`

`lastForegroundPackage` is updated for any launchable app, not only restricted ones. If Instagram launches an in-app browser, a sign-in activity from another package (Google, Facebook auth), or any Activity that happens to have a launcher intent and fires `TYPE_WINDOW_STATE_CHANGED`, `lastForegroundPackage` is updated to that package. The subsequent event from `com.instagram.android` (e.g. returning from comments) then fails the `pkg == lastForegroundPackage` de-dup and re-enters the full logic. If `activeRestrictedSessions` is populated at that point, line 139 saves it; if not (grace period check failed earlier), `triggerDelay` fires.

### 4. `ignoreEventsUntil` guard is too short for rapid event bursts

The 800 ms guard prevents reacting to the event the OS fires when `addView()` adds an overlay window. Instagram's in-app navigation (tapping comments, navigating to a profile) can produce several `TYPE_WINDOW_STATE_CHANGED` events in quick succession. If the banner or grayscale overlay happens to be added at the same time, the 800 ms window may mask the legitimate "Instagram is still foreground" event that would have set `lastForegroundPackage`, leaving it pointing to whatever was foreground before the guard period.

### 5. Home-debounce clears sessions on a false-positive home detection

`homePackages` is built by querying `CATEGORY_HOME`. On some OEM devices the set includes packages for "Recents" or proprietary launcher variants that briefly appear when swiping between apps or opening the notification shade. If one of these fires `TYPE_WINDOW_STATE_CHANGED`, the service schedules `buildSessionClearRunnable` with a 5 s delay. If the user then navigates to comments and back within 5 s, `cancelPendingSessionClear` fires correctly. But if the OEM package fires the event more than 5 s before the comments navigation (e.g. the user pulls down the notification shade and reads it), `activeRestrictedSessions` is cleared. The next Instagram event (opening comments) then fully re-triggers the delay.

### 6. `activeRestrictedSessions` not re-populated after a session-limit delay

When the session limit expires, `scheduleUsageLimit` removes the package from `activeRestrictedSessions` and calls `triggerDelay`. The delay screen fires. When the user taps "Open App", grace is re-stamped and Instagram returns. At this point the grace check should re-populate `activeRestrictedSessions` (line 146). But if the async write race (cause #1) hits here, the grace check fails, `pendingDelayPackages` still contains the package (blocking another immediate delay), and `activeRestrictedSessions` is never re-populated. The user appears to be in Instagram normally, but any subsequent event that resets `lastForegroundPackage` (causes #2, #3) will find `activeRestrictedSessions` empty and `pendingDelayPackages` empty (cleared by going home or by the session-limit timer path) and fire the delay again on a comments or profile tap.

### 7. `ignoreEventsUntil` is overwritten by concurrent overlay operations

Both `showReminderBanner` and `showOverlay` (grayscale) write to the same `ignoreEventsUntil` field. If both are triggered close together (e.g. a reminder fires at the same time the user navigates to a grayscale-covered app), the second write may set a shorter or longer guard window than intended, either letting self-generated events through or blocking legitimate foreground events that would have updated `lastForegroundPackage`.

### 8. `pendingDelayPackages` cleared independently of `activeRestrictedSessions`

`cancelAllSessionTimers()` clears `pendingDelayPackages` but a call path also exists where `pendingDelayPackages` is implicitly cleared via the grace-period branch (line 145) while `activeRestrictedSessions` is simultaneously populated. If the grace check passes on one event but something between events (notification shade, OEM overlay) resets `lastForegroundPackage`, a second event re-enters and finds `activeRestrictedSessions` populated → correctly skipped. However, if the order is reversed — `pendingDelayPackages.clear()` fires via `cancelAllSessionTimers` before `activeRestrictedSessions.add(pkg)` runs — the package is fully unprotected.
